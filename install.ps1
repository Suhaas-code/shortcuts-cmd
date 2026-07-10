# Installer for `shortcuts` (Windows PowerShell / cmd).
#   irm https://github.com/Suhaas-code/Shortcuts-cmd/releases/latest/download/install.ps1 | iex
$ErrorActionPreference = 'Stop'

$REPO     = 'Suhaas-code/Shortcuts-cmd'
$BASE_URL = "https://github.com/$REPO/releases/latest/download"
$ProgDir  = Join-Path $env:LOCALAPPDATA 'Programs\shortcuts'
$CfgDir   = Join-Path $env:APPDATA 'shortcuts'
$DataFile = Join-Path $CfgDir 'shortcuts.txt'

function Info($m) { Write-Host "==> $m" -ForegroundColor Cyan }

function Get-File($url, $dest) {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -Uri $url -OutFile $dest -UseBasicParsing
}

Info 'Installing shortcuts...'
New-Item -ItemType Directory -Force -Path $ProgDir, $CfgDir | Out-Null

Info "Downloading script -> $ProgDir\shortcuts.ps1"
Get-File "$BASE_URL/shortcuts.ps1" (Join-Path $ProgDir 'shortcuts.ps1')

# CMD/PowerShell shim so `shortcuts` is callable from any native Windows shell.
$shim = '@powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0shortcuts.ps1" %*'
Set-Content -Path (Join-Path $ProgDir 'shortcuts.cmd') -Value $shim -Encoding Ascii

if (Test-Path $DataFile) {
    Info "Keeping existing shortcuts at $DataFile"
} else {
    Info "Installing default shortcuts -> $DataFile"
    Get-File "$BASE_URL/shortcuts.default.txt" $DataFile
}

# Add ProgDir to the User PATH if absent.
$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
if (-not $userPath) { $userPath = '' }
if (($userPath -split ';') -notcontains $ProgDir) {
    $newPath = if ($userPath.TrimEnd(';')) { "$($userPath.TrimEnd(';'));$ProgDir" } else { $ProgDir }
    [Environment]::SetEnvironmentVariable('Path', $newPath, 'User')
    $env:Path = "$env:Path;$ProgDir"
    Info "Added $ProgDir to your PATH"
}

Write-Host ''
Write-Host 'Done!' -ForegroundColor Green
Write-Host 'Open a NEW terminal, or use it right now in this shell by running:'
Write-Host "  `$env:Path += `";$ProgDir`"" -ForegroundColor Yellow
Write-Host ''
Write-Host 'Then try:'
Write-Host '  shortcuts'
Write-Host '  shortcuts edit'
