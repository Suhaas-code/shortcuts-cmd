# Installer for `shortcuts` (Windows PowerShell / cmd).
#   Install:   irm https://github.com/Suhaas-code/shortcuts-cmd/releases/latest/download/install.ps1 | iex
#   Uninstall: & ([scriptblock]::Create((irm .../install.ps1))) -Uninstall
#              (or set $env:SHORTCUTS_UNINSTALL=1 before the install one-liner)
param(
    [switch] $Uninstall,
    [switch] $Yes
)
$ErrorActionPreference = 'Stop'

$REPO     = 'Suhaas-code/shortcuts-cmd'
$BASE_URL = "https://github.com/$REPO/releases/latest/download"
$ProgDir  = Join-Path $env:LOCALAPPDATA 'Programs\shortcuts'
$CfgDir   = Join-Path $env:APPDATA 'shortcuts'
$DataFile = Join-Path $CfgDir 'shortcuts.txt'

function Info($m) { Write-Host "==> $m" -ForegroundColor Cyan }

function Get-File($url, $dest) {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -Uri $url -OutFile $dest -UseBasicParsing
}

# Removes every trace of shortcuts. Touches ONLY shortcuts' own files.
function Invoke-Uninstall([bool] $skipConfirm) {
    Write-Host 'This will remove shortcuts completely:'
    Write-Host "  program:  $ProgDir"
    Write-Host "  config:   $CfgDir (including your customized shortcuts)"
    Write-Host '  PATH:     the shortcuts entry in your User PATH'
    if (-not $skipConfirm) {
        $ans = Read-Host 'Proceed? [y/N]'
        if ($ans -notmatch '^(y|yes)$') { Write-Host 'cancelled'; return }
    }
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    if ($userPath) {
        $new = (@($userPath -split ';' | Where-Object { $_ -and $_ -ne $ProgDir }) -join ';')
        if ($new -ne $userPath) {
            [Environment]::SetEnvironmentVariable('Path', $new, 'User')
            Info 'Removed shortcuts from your User PATH'
        }
    }
    if ((Test-Path $CfgDir) -and ($CfgDir -match '[\\/]shortcuts$')) {
        Remove-Item -Recurse -Force $CfgDir; Info "Removed $CfgDir"
    }
    if ((Test-Path $ProgDir) -and ($ProgDir -match '[\\/]shortcuts$')) {
        Remove-Item -Recurse -Force $ProgDir; Info "Removed $ProgDir"
    }
    Write-Host ''
    Write-Host 'shortcuts uninstalled.' -ForegroundColor Green
    Write-Host 'Open a new terminal to drop the PATH change.'
}

if ($Uninstall -or $env:SHORTCUTS_UNINSTALL) {
    Invoke-Uninstall ($Yes -or $env:SHORTCUTS_YES)
    return
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
    Get-File "$BASE_URL/shortcuts.txt" $DataFile
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
