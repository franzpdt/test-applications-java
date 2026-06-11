# restart.ps1
#
# Detects how project-api is running and restarts it:
#   k8s      -> kubectl rollout restart deployment/project-api (microk8s or minikube)
#   service  -> Restart-Service project-api (Windows service)
#   docker   -> docker restart project-api
#   podman   -> podman restart project-api
#   process  -> kills the java process and relaunches via start.ps1
#
# Usage:
#   .\restart.ps1                    # auto-detect
#   .\restart.ps1 -Namespace <ns>    # k8s: target a specific namespace
#   .\restart.ps1 -n <ns>            # short alias

param(
    [Parameter()]
    [Alias('n')]
    [string]$Namespace = 'default'
)

$ErrorActionPreference = 'Stop'
$APP_NAME   = 'project-api'
$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path

function Invoke-Kubectl {
    param([string[]]$Arguments)
    $cmdArgs = if ($script:KUBECTL.Count -gt 1) {
        @($script:KUBECTL[1..($script:KUBECTL.Count - 1)]) + $Arguments
    } else {
        $Arguments
    }
    & $script:KUBECTL[0] @cmdArgs
    return $LASTEXITCODE
}

$MODE   = $null
$KUBECTL = @()

# 1. Kubernetes — check for a live deployment before committing to this mode
$kc = $null
if (Get-Command microk8s -ErrorAction SilentlyContinue) {
    $kc = @('microk8s', 'kubectl')
} elseif (Get-Command kubectl -ErrorAction SilentlyContinue) {
    $kc = @('kubectl')
} elseif (Get-Command minikube -ErrorAction SilentlyContinue) {
    $kc = @('minikube', 'kubectl', '--')
}
if ($kc) {
    $script:KUBECTL = $kc
    $checkArgs = @('get', 'deployment', $APP_NAME, '-n', $Namespace)
    Invoke-Kubectl $checkArgs 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) { $MODE = 'k8s' }
}

# 2. Windows service
if (-not $MODE) {
    if (Get-Service -Name $APP_NAME -ErrorAction SilentlyContinue) {
        $MODE = 'service'
    }
}

# 3. Docker container
if (-not $MODE) {
    if (Get-Command docker -ErrorAction SilentlyContinue) {
        $containers = docker ps -a --filter "name=^/$APP_NAME$" --format '{{.Names}}' 2>$null
        if ($containers) { $MODE = 'docker' }
    }
}

# 4. Podman container
if (-not $MODE) {
    if (Get-Command podman -ErrorAction SilentlyContinue) {
        $containers = podman ps -a --filter "name=^$APP_NAME$" --format '{{.Names}}' 2>$null
        if ($containers) { $MODE = 'podman' }
    }
}

# 5. Bare process
if (-not $MODE) {
    $javaProcs = Get-CimInstance Win32_Process -Filter "Name='java.exe'" |
                 Where-Object { $_.CommandLine -like "*${APP_NAME}*.jar*" }
    if ($javaProcs) { $MODE = 'process' }
}

if (-not $MODE) {
    Write-Error "ERROR: no running $APP_NAME found (checked k8s, Windows service, docker, podman, process)."
    exit 1
}

Write-Host "Detected mode: $MODE"

switch ($MODE) {

    'k8s' {
        Write-Host "kubectl : $($KUBECTL -join ' ')"
        Write-Host "ns      : $Namespace"
        Write-Host ""
        Write-Host "Rolling out deployment/$APP_NAME ..."
        Invoke-Kubectl @('rollout', 'restart', "deployment/$APP_NAME", '-n', $Namespace)
        Write-Host ""
        Write-Host "Waiting for rollout to complete ..."
        Invoke-Kubectl @('rollout', 'status', "deployment/$APP_NAME", '-n', $Namespace)
    }

    'service' {
        Write-Host ""
        Write-Host "Restarting Windows service $APP_NAME ..."
        Restart-Service -Name $APP_NAME -Force
        Write-Host ""
        Get-Service -Name $APP_NAME | Format-List Name, Status, StartType
    }

    'docker' {
        Write-Host ""
        Write-Host "Restarting Docker container $APP_NAME ..."
        docker restart $APP_NAME
        Write-Host ""
        docker ps --filter "name=^/$APP_NAME$"
    }

    'podman' {
        Write-Host ""
        Write-Host "Restarting Podman container $APP_NAME ..."
        podman restart $APP_NAME
        Write-Host ""
        podman ps --filter "name=^$APP_NAME$"
    }

    'process' {
        $javaProcs = Get-CimInstance Win32_Process -Filter "Name='java.exe'" |
                     Where-Object { $_.CommandLine -like "*${APP_NAME}*.jar*" }
        $pids = ($javaProcs | ForEach-Object { $_.ProcessId }) -join ' '
        Write-Host ""
        Write-Host "Killing process(es): $pids"
        $javaProcs | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }

        for ($i = 0; $i -lt 10; $i++) {
            $still = Get-CimInstance Win32_Process -Filter "Name='java.exe'" |
                     Where-Object { $_.CommandLine -like "*${APP_NAME}*.jar*" }
            if (-not $still) { break }
            Start-Sleep -Seconds 1
        }
        $still = Get-CimInstance Win32_Process -Filter "Name='java.exe'" |
                 Where-Object { $_.CommandLine -like "*${APP_NAME}*.jar*" }
        if ($still) {
            Write-Host "Process did not exit cleanly, force-killing ..."
            $still | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
            Start-Sleep -Seconds 1
        }

        Write-Host ""
        Write-Host "Starting new process via start.ps1 ..."
        $logDir = if ($env:APP_LOG_PATH) { $env:APP_LOG_PATH } else { Join-Path $SCRIPT_DIR 'logs' }
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
        $logFile    = Join-Path $logDir 'restart.log'
        $errLogFile = Join-Path $logDir 'restart-err.log'
        $startScript = Join-Path $SCRIPT_DIR 'start.ps1'
        $PwshExe = if (Get-Command pwsh -ErrorAction SilentlyContinue) { 'pwsh' } else { 'powershell' }
        $proc = Start-Process $PwshExe `
            -ArgumentList "-NoProfile -File `"$startScript`"" `
            -RedirectStandardOutput $logFile `
            -RedirectStandardError $errLogFile `
            -WindowStyle Hidden -PassThru
        Write-Host "Started (PID $($proc.Id)) — logs: $logFile"
    }

}

Write-Host ""
Write-Host "Done."
