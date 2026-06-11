#Requires -RunAsAdministrator

$ErrorActionPreference = 'Stop'

$APP_NAME      = 'project-api'
$DEPLOY_DIR    = "C:\ProgramData\$APP_NAME"
$LOG_DIR       = "C:\ProgramData\$APP_NAME\logs"
$APP_PORT      = 5000
$SCRIPT_DIR    = Split-Path -Parent $MyInvocation.MyCommand.Path
$ENV_VARS_FILE = Join-Path $SCRIPT_DIR 'service.environment.variables.txt'

Write-Host "=== Deploying $APP_NAME as a scheduled task ==="

$JavaCmd = Get-Command java -ErrorAction SilentlyContinue
if (-not $JavaCmd) {
    Write-Error "'java' not found. Run install-dependencies.ps1 first."
    exit 1
}
$JavaPath = $JavaCmd.Source
Write-Host "Using java at: $JavaPath"

Write-Host "Creating directories..."
New-Item -ItemType Directory -Path $DEPLOY_DIR -Force | Out-Null
New-Item -ItemType Directory -Path $LOG_DIR    -Force | Out-Null

$existingTask = Get-ScheduledTask -TaskName $APP_NAME -ErrorAction SilentlyContinue
if ($existingTask -and $existingTask.State -eq 'Running') {
    Write-Host "Stopping running $APP_NAME task..."
    Stop-ScheduledTask -TaskName $APP_NAME
    Start-Sleep -Seconds 3
}

Write-Host "Building $APP_NAME..."
Push-Location (Join-Path $SCRIPT_DIR 'project-api')
try {
    & .\gradlew.bat bootJar --quiet
    if ($LASTEXITCODE -ne 0) { throw "Gradle build failed" }
    $JAR = Get-ChildItem 'build\libs\project-api-*.jar' | Select-Object -First 1
    if (-not $JAR) { throw "No jar found in build\libs\" }
} finally {
    Pop-Location
}

$JarDest = Join-Path $DEPLOY_DIR "$APP_NAME.jar"
Write-Host "Copying $($JAR.Name) to $DEPLOY_DIR..."
Copy-Item $JAR.FullName $JarDest -Force

$ExtraEnvVars = @{}
if (Test-Path $ENV_VARS_FILE) {
    Get-Content $ENV_VARS_FILE | Where-Object { $_ -and $_ -notmatch '^\s*#' } | ForEach-Object {
        if ($_ -match '^([^=]+)=(.*)$') { $ExtraEnvVars[$Matches[1].Trim()] = $Matches[2].Trim() }
    }
    Write-Host "Loaded environment variables from $ENV_VARS_FILE"
} else {
    Write-Host "Warning: $ENV_VARS_FILE not found, skipping extra environment variables."
}

# Create a launcher script so the task can set environment variables before starting java
$LauncherPath = Join-Path $DEPLOY_DIR 'run.ps1'
$launcherLines = @(
    "`$env:APP_PORT     = '$APP_PORT'",
    "`$env:APP_LOG_PATH = '$LOG_DIR'"
)
foreach ($key in $ExtraEnvVars.Keys) {
    $launcherLines += "`$env:$key = '$($ExtraEnvVars[$key])'"
}
$launcherLines += "& '$JavaPath' -jar '$JarDest'"
Set-Content -Path $LauncherPath -Value $launcherLines

$PwshCmd = Get-Command pwsh -ErrorAction SilentlyContinue
$PwshExe = if ($PwshCmd) { $PwshCmd.Source } else { (Get-Command powershell).Source }

if (Get-ScheduledTask -TaskName $APP_NAME -ErrorAction SilentlyContinue) {
    Write-Host "Removing existing scheduled task..."
    Unregister-ScheduledTask -TaskName $APP_NAME -Confirm:$false
}

Write-Host "Registering scheduled task..."
$action    = New-ScheduledTaskAction -Execute $PwshExe `
                 -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$LauncherPath`"" `
                 -WorkingDirectory $DEPLOY_DIR
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
Write-Host "The API is listening on port $APP_PORT."
Write-Host "Logs are written to $LOG_DIR."
Write-Host ""
Write-Host "Useful commands:"
Write-Host "  Get-ScheduledTask $APP_NAME"
Write-Host "  Stop-ScheduledTask $APP_NAME; Start-ScheduledTask $APP_NAME"
Write-Host "  Get-Content `"$LOG_DIR\project-api.log`" -Wait"
