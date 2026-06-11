#Requires -RunAsAdministrator

$ErrorActionPreference = 'Stop'

Write-Host "==> Checking for winget"
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Error "winget is not available. Install 'App Installer' from the Microsoft Store or upgrade to Windows 10 1709+."
    exit 1
}

Write-Host "==> Installing Microsoft OpenJDK 21"
winget install --id Microsoft.OpenJDK.21 --source winget --accept-source-agreements --accept-package-agreements

Write-Host "==> Refreshing PATH"
$env:PATH = [System.Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
            [System.Environment]::GetEnvironmentVariable('Path', 'User')

Write-Host "==> Verifying Java installation"
java -version

Write-Host "==> All dependencies installed successfully"
Write-Host ""
Write-Host "Note: deploy-service.ps1 and deploy-api-caller.ps1 require NSSM."
Write-Host "Install it with:  choco install nssm  (or download from https://nssm.cc)"
