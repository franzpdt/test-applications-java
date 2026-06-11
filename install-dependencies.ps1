#Requires -RunAsAdministrator

$ErrorActionPreference = 'Stop'

$MsiUrl  = 'https://aka.ms/download-jdk/microsoft-jdk-21-windows-x64.msi'
$MsiPath = Join-Path $env:TEMP 'microsoft-jdk-21.msi'

Write-Host "==> Downloading Microsoft OpenJDK 21"
Invoke-WebRequest -Uri $MsiUrl -OutFile $MsiPath -UseBasicParsing

Write-Host "==> Installing Microsoft OpenJDK 21"
Start-Process msiexec.exe -ArgumentList "/i `"$MsiPath`" /quiet /norestart" -Wait -NoNewWindow

Remove-Item $MsiPath -Force

Write-Host "==> Refreshing PATH"
$env:PATH = [System.Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
            [System.Environment]::GetEnvironmentVariable('Path', 'User')

Write-Host "==> Verifying Java installation"
java -version

Write-Host "==> All dependencies installed successfully"
