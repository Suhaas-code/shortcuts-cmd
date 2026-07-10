# shortcuts — a customizable keyboard-shortcut reference
# https://github.com/Suhaas-code/Shortcuts-cmd
[CmdletBinding()]
param(
    [Parameter(Position = 0)] [string] $Command = '',
    [Parameter(Position = 1, ValueFromRemainingArguments = $true)] [string[]] $Rest
)

$ErrorActionPreference = 'Stop'
$VERSION  = '1.0.0'
$REPO     = 'Suhaas-code/Shortcuts-cmd'
$BASE_URL = "https://github.com/$REPO/releases/latest/download"

function Get-ConfigDir { Join-Path $env:APPDATA 'shortcuts' }
function Get-DataFile  { Join-Path (Get-ConfigDir) 'shortcuts.txt' }

# --- colors ----------------------------------------------------------------
$script:UseColor = (-not $env:NO_COLOR) -and (-not [Console]::IsOutputRedirected)
$e = [char]27
$script:Rst = if ($script:UseColor) { "$e[0m" } else { '' }

# Default color specs — overridable via `// color <target> = <spec>` in the data file.
$script:SpecHeader = 'bold cyan'
$script:SpecKey    = 'green'
$script:SpecDesc   = 'default'

$script:AnsiMap = @{
    'bold' = 1; 'dim' = 2; 'italic' = 3; 'underline' = 4
    'black' = 30; 'red' = 31; 'green' = 32; 'yellow' = 33
    'blue' = 34; 'magenta' = 35; 'cyan' = 36; 'white' = 37
    'gray' = 90; 'grey' = 90; 'bright-black' = 90; 'bright-red' = 91
    'bright-green' = 92; 'bright-yellow' = 93; 'bright-blue' = 94
    'bright-magenta' = 95; 'bright-cyan' = 96; 'bright-white' = 97
}

function ConvertTo-Ansi([string] $spec) {
    if (-not $script:UseColor) { return '' }
    $codes = @()
    foreach ($t in ($spec -split '\s+')) {
        if (-not $t -or $t -in 'default', 'none') { continue }
        if ($script:AnsiMap.ContainsKey($t)) { $codes += $script:AnsiMap[$t] }
    }
    if ($codes.Count -eq 0) { return '' }
    "$e[" + ($codes -join ';') + 'm'
}

function Read-ColorDirectives([string[]] $lines) {
    foreach ($line in $lines) {
        if ($line -notmatch '^\s*//') { continue }
        if ($line -match '^\s*//\s*color\s+(\w+)\s*=?\s*(.*)$') {
            $val = $Matches[2].Trim()
            switch ($Matches[1].ToLower()) {
                'header'      { $script:SpecHeader = $val }
                'key'         { $script:SpecKey = $val }
                'desc'        { $script:SpecDesc = $val }
                'description' { $script:SpecDesc = $val }
            }
        }
    }
}

function Format-Colored([string] $code, [string] $text) {
    if ($code) { "$code$text$($script:Rst)" } else { $text }
}

function Die($msg) { Write-Error "shortcuts: $msg"; exit 1 }

function Get-File($url, $dest) {
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri $url -OutFile $dest -UseBasicParsing
    } catch { Die "download failed: $url" }
}

function Confirm-Data {
    $df = Get-DataFile
    if (-not (Test-Path $df)) {
        New-Item -ItemType Directory -Force -Path (Get-ConfigDir) | Out-Null
        try { Get-File "$BASE_URL/shortcuts.default.txt" $df }
        catch { Die "no shortcuts file at $df and default download failed. Run: shortcuts reset" }
    }
}

# --- rendering -------------------------------------------------------------
# Parses the data file into sections and prints aligned/colored output.
function Show-Shortcuts([string] $Filter) {
    $lines = Get-Content -LiteralPath (Get-DataFile)
    Read-ColorDirectives $lines
    $cHdr = ConvertTo-Ansi $script:SpecHeader
    $cKey = ConvertTo-Ansi $script:SpecKey
    $cDesc = ConvertTo-Ansi $script:SpecDesc
    $sections = New-Object System.Collections.ArrayList
    $cur = $null
    $maxk = 0

    foreach ($line in $lines) {
        if ($line -match '^\s*$') { continue }
        if ($line -match '^\s*//') { continue }
        if ($line -match '^#') {
            $cur = [ordered]@{ Name = ($line.Substring(1)).Trim(); Rows = (New-Object System.Collections.ArrayList) }
            [void]$sections.Add($cur)
            continue
        }
        $k = ''; $d = ''
        $tab = $line.IndexOf("`t")
        if ($tab -ge 0) {
            $k = $line.Substring(0, $tab); $d = $line.Substring($tab + 1)
        } elseif ($line -match '  +') {
            $idx = $line.IndexOf($Matches[0])
            $k = $line.Substring(0, $idx); $d = $line.Substring($idx + $Matches[0].Length)
        } else { $k = $line; $d = '' }
        $k = $k.Trim(); $d = $d.Trim()
        if ($null -eq $cur) {
            $cur = [ordered]@{ Name = 'General'; Rows = (New-Object System.Collections.ArrayList) }
            [void]$sections.Add($cur)
        }
        [void]$cur.Rows.Add(@{ Key = $k; Desc = $d })
        if ($k.Length -gt $maxk) { $maxk = $k.Length }
    }

    $pad = $maxk + 2
    $first = $true
    foreach ($s in $sections) {
        $rows = $s.Rows
        if ($Filter) {
            $f = $Filter.ToLower()
            $rows = @($s.Rows | Where-Object { $_.Key.ToLower().Contains($f) -or $_.Desc.ToLower().Contains($f) })
        }
        if ($rows.Count -eq 0) { continue }
        if (-not $first) { Write-Host '' }
        $first = $false
        Write-Host (Format-Colored $cHdr "=== $($s.Name) ===")
        foreach ($r in $rows) {
            if ($r.Desc -eq '') {
                Write-Host (Format-Colored $cKey $r.Key)
            } else {
                Write-Host ((Format-Colored $cKey $r.Key.PadRight($pad)) + (Format-Colored $cDesc $r.Desc))
            }
        }
    }
}

# --- commands --------------------------------------------------------------
function Invoke-Edit {
    Confirm-Data
    $df = Get-DataFile
    $ed = $env:EDITOR
    if (-not $ed) { $ed = 'notepad' }
    Write-Host 'Opening shortcuts in the default editor...'
    & $ed $df
}

function Invoke-Reset([string[]] $args) {
    $df = Get-DataFile
    $yes = ($args -contains '-y') -or ($args -contains '--yes')
    if ((Test-Path $df) -and (-not $yes)) {
        $ans = Read-Host "Overwrite $df with defaults? [y/N]"
        if ($ans -notmatch '^(y|yes)$') { Die 'cancelled' }
    }
    New-Item -ItemType Directory -Force -Path (Get-ConfigDir) | Out-Null
    Get-File "$BASE_URL/shortcuts.default.txt" $df
    Write-Host "Restored defaults to $df"
}

function Invoke-Update {
    $dest = $PSCommandPath
    if (-not $dest) { $dest = Join-Path $env:LOCALAPPDATA 'Programs\shortcuts\shortcuts.ps1' }
    Get-File "$BASE_URL/shortcuts.ps1" $dest
    Write-Host "Updated shortcuts at $dest"
}

function Show-Help {
    @"
shortcuts — customizable keyboard-shortcut reference (v$VERSION)

Usage:
  shortcuts                 Print your shortcuts
  shortcuts search <term>   Filter shortcuts by keyword
  shortcuts edit            Open your shortcuts in `$env:EDITOR (else notepad)
  shortcuts path            Print the data file path
  shortcuts reset [-y]      Restore the default shortcuts
  shortcuts update          Update the shortcuts script itself
  shortcuts version         Print version
  shortcuts help            Show this help

Data file: $(Get-DataFile)
"@ | Write-Host
}

switch ($Command.ToLower()) {
    ''          { Confirm-Data; Show-Shortcuts '' }
    'list'      { Confirm-Data; Show-Shortcuts '' }
    'edit'      { Invoke-Edit }
    { $_ -in 'search','find' } {
        if (-not $Rest -or -not $Rest[0]) { Die 'usage: shortcuts search <term>' }
        Confirm-Data; Show-Shortcuts $Rest[0]
    }
    { $_ -in 'path','where' } { Write-Host (Get-DataFile) }
    'reset'     { Invoke-Reset $Rest }
    { $_ -in 'update','upgrade' } { Invoke-Update }
    { $_ -in 'version','-v','--version' } { Write-Host "shortcuts $VERSION" }
    { $_ -in 'help','-h','--help' } { Show-Help }
    default     { Write-Host "shortcuts: unknown command `"$Command`"`n"; Show-Help; exit 1 }
}
