#Requires -RunAsAdministrator

$ErrorActionPreference = 'Stop'

$APP_NAME      = 'project-api'
$DEPLOY_DIR    = "C:\ProgramData\$APP_NAME"
$LOG_DIR       = "C:\ProgramData\$APP_NAME\logs"
$APP_PORT      = 5000
$SCRIPT_DIR    = Split-Path -Parent $MyInvocation.MyCommand.Path
$ENV_VARS_FILE = Join-Path $SCRIPT_DIR 'service.environment.variables.txt'

Write-Host "=== Deploying $APP_NAME as a Windows service ==="

if (-not (Get-Command nssm -ErrorAction SilentlyContinue)) {
    Write-Error "NSSM is required. Install it with: choco install nssm  (or download from https://nssm.cc)"
    exit 1
}

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

$svc = Get-Service -Name $APP_NAME -ErrorAction SilentlyContinue
if ($svc -and $svc.Status -eq 'Running') {
    Write-Host "Stopping running $APP_NAME service..."
    Stop-Service -Name $APP_NAME -Force
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

if (Get-Service -Name $APP_NAME -ErrorAction SilentlyContinue) {
    Write-Host "Removing existing service..."
    nssm stop $APP_NAME 2>$null
    nssm remove $APP_NAME confirm
}

Write-Host "Creating Windows service via NSSM..."
nssm install $APP_NAME $JavaPath
nssm set $APP_NAME AppParameters "-jar `"$JarDest`""
nssm set $APP_NAME AppDirectory $DEPLOY_DIR
nssm set $APP_NAME AppStdout (Join-Path $LOG_DIR 'stdout.log')
nssm set $APP_NAME AppStderr (Join-Path $LOG_DIR 'stderr.log')
nssm set $APP_NAME AppRotateFiles 1
nssm set $APP_NAME AppRestartDelay 5000
nssm set $APP_NAME Start SERVICE_AUTO_START

$envArgs = @("APP_PORT=$APP_PORT", "APP_LOG_PATH=$LOG_DIR")
foreach ($key in $ExtraEnvVars.Keys) { $envArgs += "$key=$($ExtraEnvVars[$key])" }
& nssm set $APP_NAME AppEnvironmentExtra @envArgs

Write-Host "Enabling and starting service..."
nssm start $APP_NAME

Write-Host ""
Write-Host "=== Deployment complete ==="
Write-Host "Service status:"
Get-Service -Name $APP_NAME | Format-List Name, Status, StartType
Write-Host ""
Write-Host "The API is listening on port $APP_PORT."
Write-Host "Logs are written to $LOG_DIR."
Write-Host ""
Write-Host "Useful commands:"
Write-Host "  Get-Service $APP_NAME"
Write-Host "  Restart-Service $APP_NAME"
Write-Host "  nssm edit $APP_NAME"
Write-Host "  Get-Content `"$LOG_DIR\stdout.log`" -Wait"
