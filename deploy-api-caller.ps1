#Requires -RunAsAdministrator

$ErrorActionPreference = 'Stop'

$APP_NAME    = 'project-api-caller'
$INSTALL_DIR = "$env:ProgramFiles\$APP_NAME"
$SCRIPT_NAME = 'call-apis.ps1'
$SCRIPT_DIR  = Split-Path -Parent $MyInvocation.MyCommand.Path
$SOURCE_SCRIPT = Join-Path $SCRIPT_DIR $SCRIPT_NAME
$API_URL     = if ($args.Count -gt 0) { $args[0] } else { 'http://localhost:5000' }

Write-Host "=== Deploying $APP_NAME as a Windows service ==="

if (-not (Get-Command nssm -ErrorAction SilentlyContinue)) {
    Write-Error "NSSM is required. Install it with: choco install nssm  (or download from https://nssm.cc)"
    exit 1
}

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
$LogDir = "$env:ProgramData\$APP_NAME\logs"
New-Item -ItemType Directory -Path $LogDir -Force | Out-Null

if (Get-Service -Name $APP_NAME -ErrorAction SilentlyContinue) {
    Write-Host "Removing existing service..."
    nssm stop $APP_NAME 2>$null
    nssm remove $APP_NAME confirm
}

Write-Host "Creating Windows service via NSSM..."
nssm install $APP_NAME $PwshExe
nssm set $APP_NAME AppParameters "-NoProfile -ExecutionPolicy Bypass -File `"$InstalledScript`" $API_URL"
nssm set $APP_NAME AppDirectory $INSTALL_DIR
nssm set $APP_NAME AppStdout (Join-Path $LogDir 'stdout.log')
nssm set $APP_NAME AppStderr (Join-Path $LogDir 'stderr.log')
nssm set $APP_NAME AppRotateFiles 1
nssm set $APP_NAME AppRestartDelay 5000
nssm set $APP_NAME Start SERVICE_AUTO_START

Write-Host "Enabling and starting service..."
nssm start $APP_NAME

Write-Host ""
Write-Host "=== Deployment complete ==="
Write-Host "Service status:"
Get-Service -Name $APP_NAME | Format-List Name, Status, StartType
Write-Host ""
Write-Host "API URL: $API_URL"
Write-Host ""
Write-Host "Useful commands:"
Write-Host "  Get-Service $APP_NAME"
Write-Host "  Restart-Service $APP_NAME"
Write-Host "  nssm edit $APP_NAME"
Write-Host "  Get-Content `"$LogDir\stdout.log`" -Wait"
