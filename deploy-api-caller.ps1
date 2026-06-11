#Requires -RunAsAdministrator

$ErrorActionPreference = 'Stop'

$APP_NAME    = 'project-api-caller'
$INSTALL_DIR = "$env:ProgramFiles\$APP_NAME"
$SCRIPT_NAME = 'call-apis.ps1'
$SCRIPT_DIR  = Split-Path -Parent $MyInvocation.MyCommand.Path
$SOURCE_SCRIPT = Join-Path $SCRIPT_DIR $SCRIPT_NAME
$API_URL     = if ($args.Count -gt 0) { $args[0] } else { 'http://localhost:5000' }

Write-Host "=== Deploying $APP_NAME as a scheduled task ==="

if (-not (Test-Path $SOURCE_SCRIPT)) {
    Write-Error "$SOURCE_SCRIPT not found."
    exit 1
}

Write-Host "Installing $SCRIPT_NAME to $INSTALL_DIR..."
New-Item -ItemType Directory -Path $INSTALL_DIR -Force | Out-Null
Copy-Item $SOURCE_SCRIPT (Join-Path $INSTALL_DIR $SCRIPT_NAME) -Force

$PwshCmd = Get-Command pwsh -ErrorAction SilentlyContinue
$PwshExe = if ($PwshCmd) { $PwshCmd.Source } else { (Get-Command powershell).Source }
$InstalledScript = Join-Path $INSTALL_DIR $SCRIPT_NAME

if (Get-ScheduledTask -TaskName $APP_NAME -ErrorAction SilentlyContinue) {
    Write-Host "Removing existing scheduled task..."
    Stop-ScheduledTask -TaskName $APP_NAME -ErrorAction SilentlyContinue
    Unregister-ScheduledTask -TaskName $APP_NAME -Confirm:$false
}

Write-Host "Registering scheduled task..."
$action    = New-ScheduledTaskAction -Execute $PwshExe `
                 -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$InstalledScript`" $API_URL" `
                 -WorkingDirectory $INSTALL_DIR
$trigger   = New-ScheduledTaskTrigger -AtStartup
$principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
$settings  = New-ScheduledTaskSettingsSet `
                 -ExecutionTimeLimit ([TimeSpan]::Zero) `
                 -RestartCount 10 `
                 -RestartInterval (New-TimeSpan -Minutes 1) `
                 -MultipleInstances IgnoreNew `
                 -StartWhenAvailable
Register-ScheduledTask -TaskName $APP_NAME -Action $action -Trigger $trigger `
    -Principal $principal -Settings $settings -Force | Out-Null

Write-Host "Starting task..."
Start-ScheduledTask -TaskName $APP_NAME

Write-Host ""
Write-Host "=== Deployment complete ==="
Write-Host "Task status:"
Get-ScheduledTask -TaskName $APP_NAME | Select-Object TaskName, State | Format-List
Write-Host ""
Write-Host "API URL: $API_URL"
Write-Host ""
Write-Host "Useful commands:"
Write-Host "  Get-ScheduledTask $APP_NAME"
Write-Host "  Stop-ScheduledTask $APP_NAME; Start-ScheduledTask $APP_NAME"
Write-Host "  schtasks /query /tn $APP_NAME /v"
