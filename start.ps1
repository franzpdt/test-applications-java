$ErrorActionPreference = 'Stop'

$APP_PORT      = if ($env:APP_PORT)      { $env:APP_PORT }      else { '5000' }
$APP_LOG_PATH  = if ($env:APP_LOG_PATH)  { $env:APP_LOG_PATH }  else { '.\logs' }
$JETTY_VERSION = if ($env:JETTY_VERSION) { $env:JETTY_VERSION } else { '12.0.21' }

$SCRIPT_DIR  = Split-Path -Parent $MyInvocation.MyCommand.Path
$JETTY_DIR   = Join-Path $SCRIPT_DIR '.jetty'
$JETTY_HOME  = Join-Path $JETTY_DIR "jetty-home-$JETTY_VERSION"
$JETTY_BASE  = Join-Path $JETTY_DIR 'base'
$DOWNLOAD_URL = "https://repo1.maven.org/maven2/org/eclipse/jetty/jetty-home/$JETTY_VERSION/jetty-home-$JETTY_VERSION.tar.gz"

New-Item -ItemType Directory -Path $APP_LOG_PATH -Force | Out-Null

# ── Build WAR ─────────────────────────────────────────────────────────────────
Write-Host "==> Building project-api"
Push-Location (Join-Path $SCRIPT_DIR 'project-api')
try {
    & .\gradlew.bat war --quiet
    if ($LASTEXITCODE -ne 0) { throw "Gradle build failed with exit code $LASTEXITCODE" }
    $WAR = Get-ChildItem 'build\libs\project-api-*.war' | Select-Object -First 1
    if (-not $WAR) { throw "No WAR found in build\libs\" }
} finally {
    Pop-Location
}
Write-Host "==> Built: $($WAR.Name)"

# ── Download Jetty if not already present ─────────────────────────────────────
$JettyStartJar = Join-Path $JETTY_HOME 'start.jar'
if (-not (Test-Path $JettyStartJar)) {
    if (Test-Path $JETTY_HOME) { Remove-Item -Recurse -Force $JETTY_HOME }
    Write-Host "==> Downloading Jetty $JETTY_VERSION ..."
    New-Item -ItemType Directory -Path $JETTY_DIR -Force | Out-Null
    $TMP = [System.IO.Path]::GetTempFileName() + '.tar.gz'
    Invoke-WebRequest -Uri $DOWNLOAD_URL -OutFile $TMP
    # Expand using tar (available on Windows 10 1803+ and Server 2019+)
    & tar -xzf $TMP -C $JETTY_DIR
    if ($LASTEXITCODE -ne 0) { throw "tar extraction failed" }
    Remove-Item $TMP
}

# ── Initialise JETTY_BASE once ────────────────────────────────────────────────
if (-not (Test-Path $JETTY_BASE)) {
    New-Item -ItemType Directory -Path (Join-Path $JETTY_BASE 'webapps') -Force | Out-Null
    & java -jar $JettyStartJar "--jetty.base=$JETTY_BASE" '--add-module=http,ee10-deploy' 2>&1 |
        Where-Object { $_ -notmatch '^NOTE:' }
}

# ── Deploy WAR ────────────────────────────────────────────────────────────────
New-Item -ItemType Directory -Path (Join-Path $JETTY_BASE 'webapps') -Force | Out-Null
Copy-Item $WAR.FullName (Join-Path $JETTY_BASE 'webapps\ROOT.war') -Force

Write-Host "==> Starting project-api on port $APP_PORT (logs: $APP_LOG_PATH)"

& java `
    "-DAPP_LOG_PATH=$APP_LOG_PATH" `
    -jar $JettyStartJar `
    "--jetty.base=$JETTY_BASE" `
    "jetty.http.port=$APP_PORT"
