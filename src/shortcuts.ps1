# shortcuts — a customizable keyboard-shortcut reference
# https://github.com/Suhaas-code/shortcuts-cmd
[CmdletBinding()]
param(
    [Parameter(Position = 0)] [string] $Command = '',
    [Parameter(Position = 1, ValueFromRemainingArguments = $true)] [string[]] $Rest
)

$ErrorActionPreference = 'Stop'
$VERSION  = '1.5.1'
$REPO     = 'Suhaas-code/shortcuts-cmd'
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
$script:SpecCode   = 'bold yellow'

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
        # `// ansi = off` disables all color/styling (avoids ANSI leaking over SSH/WSL).
        if ($line -match '^\s*//\s*ansi\s*=?\s*(\w+)') {
            if ($Matches[1].ToLower() -in 'off','false','no','0','disable') {
                $script:UseColor = $false; $script:Rst = ''
            }
            continue
        }
        if ($line -match '^\s*//\s*color\s+(\w+)\s*=?\s*(.*)$') {
            $val = $Matches[2].Trim()
            switch ($Matches[1].ToLower()) {
                'header'      { $script:SpecHeader = $val }
                'key'         { $script:SpecKey = $val }
                'desc'        { $script:SpecDesc = $val }
                'description' { $script:SpecDesc = $val }
                'code'        { $script:SpecCode = $val }
            }
        }
    }
}

function Format-Colored([string] $code, [string] $text) {
    if ($code) { "$code$text$($script:Rst)" } else { $text }
}

# Converts one Markdown emphasis marker (e.g. `**`) into ANSI on/off codes.
# Codes accumulate over the surrounding color, so <off> (22/23) restores it
# without dropping the base color. Markers are always stripped, even with color off.
function Convert-Emphasis([string] $s, [string] $marker, [int] $on, [int] $off) {
    $out = ''
    $mlen = $marker.Length
    while (($p = $s.IndexOf($marker)) -ge 0) {
        $out += $s.Substring(0, $p)
        $s = $s.Substring($p + $mlen)
        $q = $s.IndexOf($marker)
        if ($q -lt 0) { return $out + $marker + $s }   # unmatched — keep literal
        $inner = $s.Substring(0, $q)
        $s = $s.Substring($q + $mlen)
        if ($inner -eq '') { $out += ($marker + $marker); continue }
        if ($script:UseColor) { $out += "$e[${on}m$inner$e[${off}m" } else { $out += $inner }
    }
    $out + $s
}

# Renders inline Markdown emphasis: **bold**, *italic*, _italic_ (bold first so
# ** is consumed before single *). Applied only to text outside `backticks`.
function Expand-Inline([string] $s) {
    if (-not $s) { return $s }
    $s = Convert-Emphasis $s '**' 1 22
    $s = Convert-Emphasis $s '*'  3 23
    $s = Convert-Emphasis $s '_'  3 23
    $s
}

# Splits text on `backticks`; even-index segments use $baseColor (with inline
# emphasis expanded), odd-index (inside backticks) use $codeColor verbatim.
# Backticks themselves are stripped from the output.
function Format-Field([string] $text, [string] $baseColor, [string] $codeColor) {
    $parts = $text -split '`'
    $sb = New-Object System.Text.StringBuilder
    for ($i = 0; $i -lt $parts.Count; $i++) {
        if ($parts[$i] -eq '') { continue }
        if ($i % 2 -eq 0) { [void]$sb.Append((Format-Colored $baseColor (Expand-Inline $parts[$i]))) }
        else              { [void]$sb.Append((Format-Colored $codeColor $parts[$i])) }
    }
    $sb.ToString()
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
        try { Get-File "$BASE_URL/windows.txt" $df }
        catch { Die "no shortcuts file at $df and default download failed. Run: shortcuts reset" }
    }
}

# --- rendering -------------------------------------------------------------
# Parses the data file into sections and prints aligned/colored output.
# Markdown-lite supported: #/##/### headings, --- horizontal rule, **bold**,
# *italic* / _italic_. // comment lines and `key`<TAB>desc rows are unchanged.
function Show-Shortcuts([string] $Filter) {
    $lines = Get-Content -LiteralPath (Get-DataFile)
    Read-ColorDirectives $lines
    $cHdr = ConvertTo-Ansi $script:SpecHeader
    $cKey = ConvertTo-Ansi $script:SpecKey
    $cDesc = ConvertTo-Ansi $script:SpecDesc
    $cCode = ConvertTo-Ansi $script:SpecCode
    $cRule = if ($script:UseColor) { "$e[2m" } else { '' }
    $sections = New-Object System.Collections.ArrayList
    $cur = $null
    $maxk = 0

    function New-Section($name, $level) {
        $s = [ordered]@{ Name = $name; Level = $level; Rows = (New-Object System.Collections.ArrayList) }
        [void]$sections.Add($s)
        $s
    }

    foreach ($line in $lines) {
        if ($line -match '^\s*$') { continue }
        if ($line -match '^\s*//') { continue }                    # comment / color directive
        if ($line -match '^\s*(-{3,}|\*{3,}|_{3,})\s*$') {         # horizontal rule
            if ($null -eq $cur) { $cur = New-Section 'General' 1 }
            [void]$cur.Rows.Add(@{ Type = 'rule' })
            continue
        }
        if ($line -match '^\s*#') {                                # heading (any level)
            $m = [regex]::Match($line, '^\s*(#+)\s*(.*?)\s*#*\s*$')
            $cur = New-Section ($m.Groups[2].Value.Trim()) ($m.Groups[1].Value.Length)
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
        if ($null -eq $cur) { $cur = New-Section 'General' 1 }
        [void]$cur.Rows.Add(@{ Type = 'row'; Key = $k; Desc = $d })
        $kVisLen = ($k -replace '`', '').Length
        if ($kVisLen -gt $maxk) { $maxk = $kVisLen }
    }

    $pad = $maxk + 2
    $first = $true
    foreach ($s in $sections) {
        $rows = $s.Rows
        if ($Filter) {
            $f = $Filter.ToLower()
            # A term matching the section heading returns every row in that section;
            # otherwise fall back to matching the row's key/description.
            if ($s.Name.ToLower().Contains($f)) {
                $rows = @($s.Rows | Where-Object { $_.Type -eq 'row' })
            } else {
                $rows = @($s.Rows | Where-Object { $_.Type -eq 'row' -and ($_.Key.ToLower().Contains($f) -or $_.Desc.ToLower().Contains($f)) })
            }
        }
        if ($rows.Count -eq 0) { continue }
        if (-not $first) { Write-Host '' }
        $first = $false
        $deco = if ($s.Level -ge 2) { '---' } else { '===' }
        Write-Host (Format-Colored $cHdr "$deco $(Expand-Inline $s.Name) $deco")
        foreach ($r in $rows) {
            if ($r.Type -eq 'rule') {
                Write-Host (Format-Colored $cRule ('-' * 32))
            } elseif ($r.Desc -eq '') {
                Write-Host (Format-Field $r.Key $cKey $cCode)
            } else {
                $kVisLen = ($r.Key -replace '`', '').Length
                $padSpaces = ' ' * [Math]::Max(0, $pad - $kVisLen)
                Write-Host ((Format-Field $r.Key $cKey $cCode) + $padSpaces + (Format-Field $r.Desc $cDesc $cCode))
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

function Invoke-Reset([string[]] $Argv) {
    $df = Get-DataFile
    $yes = ($Argv -contains '-y') -or ($Argv -contains '--yes')
    if ((Test-Path $df) -and (-not $yes)) {
        $ans = Read-Host "Overwrite $df with defaults? [y/N]"
        if ($ans -notmatch '^(y|yes)$') { Die 'cancelled' }
    }
    New-Item -ItemType Directory -Force -Path (Get-ConfigDir) | Out-Null
    Get-File "$BASE_URL/windows.txt" $df
    Write-Host "Restored defaults to $df"
}

function Invoke-Update {
    $dest = $PSCommandPath
    if (-not $dest) { $dest = Join-Path $env:LOCALAPPDATA 'Programs\shortcuts\shortcuts.ps1' }
    Get-File "$BASE_URL/shortcuts.ps1" $dest
    Write-Host "Updated shortcuts at $dest"
}

# neofetch-style banner for `shortcuts version`.
function Show-Version {
    $df = Get-DataFile
    $nsec = 0; $nrow = 0
    if (Test-Path $df) {
        $lines = Get-Content -LiteralPath $df
        Read-ColorDirectives $lines
        foreach ($ln in $lines) {
            if ($ln -match '^\s*$' -or $ln -match '^\s*//') { continue }
            if ($ln -match '^\s*(-{3,}|\*{3,}|_{3,})\s*$') { continue }   # horizontal rule
            if ($ln -match '^\s*#') { $nsec++ } else { $nrow++ }
        }
    }
    $cH = ConvertTo-Ansi $script:SpecHeader
    $rst = $script:Rst

    $edition = $PSVersionTable.PSEdition
    $envName = if ($edition -eq 'Core') { 'PowerShell' } else { 'Windows PowerShell' }
    $osName = if ($PSVersionTable.PSVersion.Major -ge 6) {
        if ($IsLinux) { 'Linux' } elseif ($IsMacOS) { 'macOS' } else { 'Windows' }
    } else { 'Windows' }
    $shellName = "$envName $($PSVersionTable.PSVersion)"
    $host_ = $env:COMPUTERNAME; if (-not $host_) { $host_ = 'localhost' }
    $editor = if ($env:EDITOR) { $env:EDITOR } else { 'notepad' }
    $palette = (Format-Colored (ConvertTo-Ansi $script:SpecHeader) 'header') + ' ' +
               (Format-Colored (ConvertTo-Ansi $script:SpecKey) 'key') + ' ' +
               (Format-Colored (ConvertTo-Ansi $script:SpecDesc) 'desc') + ' ' +
               (Format-Colored (ConvertTo-Ansi $script:SpecCode) 'code')

    $logo = @(
        '   ___________________________'
        '  |  _______________________  |'
        '  | |                       | |'
        '  | |   >_ shortcuts        | |'
        '  | |_______________________| |'
        '  |   ___   ___   ___   ___   |'
        '  |  |Ctl| |Alt| |Sft| |Tab|  |'
        '  |  |___| |___| |___| |___|  |'
        '  |___________________________|'
        '      |_______________________|'
    )
    $info = @(
        (Format-Colored $cH 'shortcuts') + '@' + (Format-Colored $cH $host_)
        '-----------------------------'
        "Version      $VERSION"
        "Environment  $envName"
        "OS           $osName"
        "Shell        $shellName"
        "Shortcuts    $nrow in $nsec sections"
        "Editor       $editor"
        "Data         $df"
        "Palette      $palette"
        "GitHub       https://github.com/$REPO"
        '             ^ star & contribute to support!'
    )
    $w = ($logo | Measure-Object -Property Length -Maximum).Maximum
    $max = [Math]::Max($logo.Count, $info.Count)
    Write-Host ''
    for ($i = 0; $i -lt $max; $i++) {
        $l = if ($i -lt $logo.Count) { $logo[$i] } else { '' }
        $r = if ($i -lt $info.Count) { $info[$i] } else { '' }
        $padded = $l.PadRight($w)
        if ($l) { Write-Host ((Format-Colored $cH $padded) + '   ' + $r) }
        else    { Write-Host ($padded + '   ' + $r) }
    }
    Write-Host ''
}

# Removes every trace of shortcuts: program dir, config dir, and the User PATH entry.
# Touches ONLY shortcuts' own files.
function Invoke-Uninstall([string[]] $Argv) {
    $progDir = Join-Path $env:LOCALAPPDATA 'Programs\shortcuts'
    $cfgDir  = Get-ConfigDir
    $yes = ($Argv -contains '-y') -or ($Argv -contains '--yes')

    Write-Host 'This will remove shortcuts completely:'
    Write-Host "  program:  $progDir"
    Write-Host "  config:   $cfgDir (including your customized shortcuts)"
    Write-Host '  PATH:     the shortcuts entry in your User PATH'
    if (-not $yes) {
        $ans = Read-Host 'Proceed? [y/N]'
        if ($ans -notmatch '^(y|yes)$') { Die 'cancelled' }
    }

    # 1) User PATH — drop only the shortcuts program dir
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    if ($userPath) {
        $kept = @($userPath -split ';' | Where-Object { $_ -and $_ -ne $progDir })
        $new = ($kept -join ';')
        if ($new -ne $userPath) {
            [Environment]::SetEnvironmentVariable('Path', $new, 'User')
            Write-Host 'Removed shortcuts from your User PATH'
        }
    }

    # 2) config dir (namespaced to shortcuts)
    if ((Test-Path $cfgDir) -and ($cfgDir -match '[\\/]shortcuts$')) {
        Remove-Item -Recurse -Force $cfgDir
        Write-Host "Removed $cfgDir"
    }

    # 3) program dir — this holds the shortcuts.cmd/shortcuts.ps1 that is running
    #    right now. Deleting it inline would yank the file out from under the shell.
    #    Hand off to a detached cmd that waits for this process to exit, then removes it.
    if ((Test-Path $progDir) -and ($progDir -match '[\\/]shortcuts$')) {
        Start-Process cmd.exe -WindowStyle Hidden `
            -ArgumentList "/c ping 127.0.0.1 -n 3 >nul & rmdir /s /q `"$progDir`"" | Out-Null
        Write-Host "Removed $progDir"
    }

    Write-Host ''
    Write-Host 'shortcuts uninstalled. Open a new terminal to drop the PATH change.'
}

# --- autoadd ---------------------------------------------------------------
# Starter shortcut sets for popular CLI tools, keyed by the executable name we
# probe with Get-Command. Intentionally small — edit them after adding. The
# section text produced here is kept byte-identical with shortcuts.sh.
$script:ToolLibrary = @(
    @{ Exe = 'claude'; Name = 'Claude Code'; Rows = @(
        @('`/model`',        'Switch the active model'),
        @('`/clear`',        'Start a fresh conversation'),
        @('`/diff`',         'View uncommitted changes'),
        @('`Ctrl` + `C`',    'Cancel current operation'),
        @('`Esc`',           'Cancel input'),
        @('`Ctrl` + `J`',    'Insert a newline'),
        @('`Ctrl` + `D`',    'Exit Claude Code')
    )},
    @{ Exe = 'codex'; Name = 'Codex'; Rows = @(
        @('`/model`',            'Change model & reasoning effort'),
        @('`/approvals`',        'Set what Codex can do'),
        @('`/init`',             'Create an AGENTS.md file'),
        @('`/new`',              'Start a new chat'),
        @('`/diff`',             'Show the git diff'),
        @('`Esc`',               'Interrupt the current task'),
        @('`Ctrl` + `C` (twice)', 'Quit Codex')
    )},
    @{ Exe = 'opencode'; Name = 'opencode'; Rows = @(
        @('`/init`',       'Set up an AGENTS.md file'),
        @('`/new`',        'Start a new session'),
        @('`/models`',     'List and switch model'),
        @('`/sessions`',   'Switch sessions'),
        @('`/share`',      'Share the session'),
        @('`/undo`',       'Undo the last change'),
        @('`Esc`',         'Interrupt the agent'),
        @('`Ctrl` + `C`',  'Exit')
    )},
    @{ Exe = 'aider'; Name = 'Aider'; Rows = @(
        @('`/add`',        'Add files to the chat'),
        @('`/drop`',       'Remove files from the chat'),
        @('`/ask`',        'Ask without editing'),
        @('`/architect`',  'Plan, then edit'),
        @('`/diff`',       'Diff since the last message'),
        @('`/undo`',       "Undo aider's last commit"),
        @('`/run`',        'Run a shell command'),
        @('`/exit`',       'Quit aider')
    )},
    @{ Exe = 'gemini'; Name = 'Gemini'; Rows = @(
        @('`/help`',              'Show help and commands'),
        @('`/clear`',             'Clear screen and history'),
        @('`/chat`',              'Save or resume chat history'),
        @('`/tools`',             'List available tools'),
        @('`/mcp`',               'List MCP servers'),
        @('`/memory`',            'Manage GEMINI.md context'),
        @('`Ctrl` + `C` (twice)', 'Cancel, or exit')
    )},
    @{ Exe = 'vim'; Name = 'Vim'; Rows = @(
        @('`i`',    'Insert mode'),
        @('`Esc`',  'Normal mode'),
        @('`:w`',   'Save'),
        @('`:q`',   'Quit'),
        @('`:wq`',  'Save and quit'),
        @('`dd`',   'Delete the current line'),
        @('`/`',    'Search forward')
    )},
    @{ Exe = 'nvim'; Name = 'Neovim'; Rows = @(
        @('`i`',    'Insert mode'),
        @('`Esc`',  'Normal mode'),
        @('`:w`',   'Save'),
        @('`:q`',   'Quit'),
        @('`:wq`',  'Save and quit'),
        @('`gg`',   'Go to the top'),
        @('`G`',    'Go to the bottom')
    )},
    @{ Exe = 'git'; Name = 'Git'; Rows = @(
        @('`git status`',  'Show working tree status'),
        @('`git add`',     'Stage changes'),
        @('`git commit`',  'Record staged changes'),
        @('`git push`',    'Upload commits'),
        @('`git pull`',    'Fetch and merge'),
        @('`git log`',     'Show commit history')
    )},
    @{ Exe = 'tmux'; Name = 'tmux'; Rows = @(
        @('`Ctrl` + `b` `c`',  'New window'),
        @('`Ctrl` + `b` `n`',  'Next window'),
        @('`Ctrl` + `b` `%`',  'Split vertically'),
        @('`Ctrl` + `b` `"`',  'Split horizontally'),
        @('`Ctrl` + `b` `d`',  'Detach session'),
        @('`Ctrl` + `b` `x`',  'Kill the pane')
    )},
    @{ Exe = 'fzf'; Name = 'fzf'; Rows = @(
        @('`Ctrl` + `R`',  'Search command history'),
        @('`Ctrl` + `T`',  'Paste selected files'),
        @('`Alt` + `C`',   'cd into selected directory'),
        @('`Tab`',         'Toggle multi-select'),
        @('`Enter`',       'Confirm selection')
    )},
    @{ Exe = 'docker'; Name = 'Docker'; Rows = @(
        @('`docker ps`',      'List running containers'),
        @('`docker images`',  'List images'),
        @('`docker build`',   'Build an image'),
        @('`docker run`',     'Run a container'),
        @('`docker exec`',    'Run a command in a container'),
        @('`docker logs`',    'Show container logs')
    )},
    @{ Exe = 'kubectl'; Name = 'kubectl'; Rows = @(
        @('`kubectl get`',       'List resources'),
        @('`kubectl describe`',  'Show resource details'),
        @('`kubectl logs`',      'Print pod logs'),
        @('`kubectl apply`',     'Apply a manifest'),
        @('`kubectl exec`',      'Run a command in a pod'),
        @('`kubectl delete`',    'Delete resources')
    )}
)

function Test-HasCommand([string] $name) {
    [bool](Get-Command $name -ErrorAction SilentlyContinue)
}

# Detects installed CLI tools and appends a starter shortcut section for each,
# skipping any tool whose section heading is already in the data file.
function Invoke-AutoAdd([string[]] $Argv) {
    Confirm-Data
    $df = Get-DataFile
    $yes = ($Argv -contains '-y') -or ($Argv -contains '--yes')

    $existing = @{}
    foreach ($line in (Get-Content -LiteralPath $df)) {
        if ($line -match '^\s*#+\s*(.*?)\s*#*\s*$') { $existing[$Matches[1].Trim().ToLower()] = $true }
    }

    $toAdd = @(); $present = @()
    foreach ($t in $script:ToolLibrary) {
        if (-not (Test-HasCommand $t.Exe)) { continue }
        if ($existing.ContainsKey($t.Name.ToLower())) { $present += $t.Name; continue }
        $toAdd += $t
    }

    Write-Host 'autoadd — shortcuts for detected CLI tools'
    Write-Host ''
    if ($toAdd.Count) {
        Write-Host 'Will add sections:'
        foreach ($t in $toAdd) { Write-Host "  + $($t.Name)  ($($t.Exe))" }
    }
    if ($present.Count) {
        if ($toAdd.Count) { Write-Host '' }
        Write-Host "Already present (skipped): $($present -join ', ')"
    }
    if ($toAdd.Count -eq 0) {
        Write-Host ''
        Write-Host 'Nothing to add — no new detected tools.'
        return
    }
    Write-Host ''
    if (-not $yes) {
        $ans = Read-Host "Append $($toAdd.Count) section(s) to $df? [y/N]"
        if ($ans -notmatch '^(y|yes)$') { Die 'cancelled' }
    }
    foreach ($t in $toAdd) {
        $block = @('', "# $($t.Name)") + @($t.Rows | ForEach-Object { $_[0] + "`t" + $_[1] })
        Add-Content -LiteralPath $df -Value $block
    }
    Write-Host ''
    Write-Host "Added $($toAdd.Count) section(s) to $df"
}

function Show-Help {
    @"
shortcuts v$VERSION — keyboard-shortcut cheat sheet

Usage: shortcuts [command]
  (none)           Print shortcuts
  search <term>    Filter by keyword or section heading
  autoadd [-y]     Add shortcuts for detected CLI tools
  edit             Edit in `$env:EDITOR (else notepad)
  path             Print data file path
  reset [-y]       Restore defaults
  update           Update the script
  version          Version + environment
  uninstall [-y]   Remove everything
  help             This help

Data: $(Get-DataFile)
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
    'autoadd'   { Invoke-AutoAdd $Rest }
    { $_ -in 'path','where' } { Write-Host (Get-DataFile) }
    'reset'     { Invoke-Reset $Rest }
    { $_ -in 'update','upgrade' } { Invoke-Update }
    { $_ -in 'version','-v','--version' } { Show-Version }
    { $_ -in 'uninstall','remove' } { Invoke-Uninstall $Rest }
    { $_ -in 'help','-h','--help' } { Show-Help }
    default     { Write-Host "shortcuts: unknown command `"$Command`"`n"; Show-Help; exit 1 }
}
