# Kopierar Farseer till WoW: Forever. Kör: powershell -ExecutionPolicy Bypass -File tools\install.ps1
param([string]$WowDir = "C:\SPEL\World of Warcraft\_forever_")
$src = Join-Path $PSScriptRoot "..\Farseer"
$dst = Join-Path $WowDir "Interface\AddOns\Farseer"
if (-not (Test-Path (Join-Path $WowDir "Wow.exe"))) { Write-Error "Hittar inte Wow.exe i $WowDir"; exit 1 }
if (Test-Path $dst) { Remove-Item -Recurse -Force $dst }
New-Item -ItemType Directory -Force (Split-Path $dst) | Out-Null
Copy-Item -Recurse $src $dst
Write-Host "Farseer installerat i $dst. Skriv /reload i spelet (eller starta om)."
