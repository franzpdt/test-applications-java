$ErrorActionPreference = 'Stop'

$APP_PORT     = if ($env:APP_PORT)     { $env:APP_PORT }     else { '5000' }
$APP_LOG_PATH = if ($env:APP_LOG_PATH) { $env:APP_LOG_PATH } else { '.\logs' }
$SCRIPT_DIR   = Split-Path -Parent $MyInvocation.MyCommand.Path

New-Item -ItemType Directory -Path $APP_LOG_PATH -Force | Out-Null

Write-Host "==> Building project-api"
Push-Location (Join-Path $SCRIPT_DIR 'project-api')
try {
    & .\gradlew.bat bootJar --quiet
    if ($LASTEXITCODE -ne 0) { throw "Gradle build failed with exit code $LASTEXITCODE" }
    $JAR = Get-ChildItem 'build\libs\project-api-*.jar' | Select-Object -First 1
    if (-not $JAR) { throw "No jar found in build\libs\" }
} finally {
    Pop-Location
}

Write-Host "==> Starting $($JAR.Name) on port $APP_PORT (logs: $APP_LOG_PATH)"

& java `
    "-DAPP_PORT=$APP_PORT" `
    "-DAPP_LOG_PATH=$APP_LOG_PATH" `
    -jar $JAR.FullName
