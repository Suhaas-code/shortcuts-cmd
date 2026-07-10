<div align="center">
  <h1>⌨️ shortcuts</h1>
  <p><em>Your personal keyboard-shortcut cheat sheet, one command away — in every shell</em></p>
</div>

<p align="center"><strong>one-line install · edit in your own editor · consistent output everywhere · zero runtime deps</strong></p>

<p align="center">
  <img src="https://img.shields.io/badge/deps-none-10b981.svg" alt="Dependencies: none">
  <img src="https://img.shields.io/badge/Windows-PowerShell%20%2B%20cmd-5391FE?logo=powershell&logoColor=white" alt="Windows">
  <img src="https://img.shields.io/badge/Linux%20%2F%20macOS-Bash%20%2F%20zsh-4EAA25?logo=gnubash&logoColor=white" alt="Bash / zsh">
  <img src="https://img.shields.io/badge/also-WSL%20%2B%20Git%20Bash-333.svg" alt="WSL + Git Bash">
  <img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="MIT">
</p>

<p align="center">
  <a href="#what-it-does">What it does</a> ·
  <a href="#get-started-30-seconds">Get started</a> ·
  <a href="#commands">Commands</a> ·
  <a href="#customizing">Customizing</a> ·
  <a href="#where-things-live">Where things live</a>
</p>

---

`shortcuts` is a tiny terminal command that prints your own list of keyboard
shortcuts, grouped into sections and neatly aligned — then lets you edit that
list in your favorite editor. It behaves **identically** on Windows PowerShell,
cmd, Linux, macOS, WSL, and Git Bash because every environment reads the same
plain-text data file. No runtime, no dependencies, one script per platform.

```
> shortcuts

=== Panes ===
Alt + Shift + +           Split pane
Alt + Shift + -           Split pane horizontally
Alt + Arrow Keys          Move focus between panes
...

> shortcuts edit
Opening shortcuts in the default editor...
```

## What it does

- **Prints your cheat sheet** — section headers plus auto-aligned `key → description`
  rows, colored for readability.
- **Edits in your editor** — `shortcuts edit` opens the data file in `$EDITOR`
  (or Notepad on Windows). Add, remove, or reorganize anything.
- **Searches** — `shortcuts search <term>` filters rows by keyword across keys and
  descriptions, keeping only the sections that match.
- **Customizable colors** — set section/key/description colors right inside the
  data file with `// color` lines (see [Customizing](#customizing)).
- **Self-maintaining** — `shortcuts update` pulls the latest script; `shortcuts reset`
  restores the defaults; `shortcuts path` tells you where your file lives.
- **Respects your terminal** — color turns off automatically when piped or when
  `NO_COLOR` is set.

## Get started (30 seconds)

**Windows** (PowerShell):

```powershell
irm https://github.com/Suhaas-code/Shortcuts-cmd/releases/latest/download/install.ps1 | iex
```

**Linux · macOS · WSL · Git Bash**:

```bash
curl -fsSL https://github.com/Suhaas-code/Shortcuts-cmd/releases/latest/download/install.sh | bash
```

The installer drops the script somewhere on your `PATH` and seeds a default
shortcut list. Open a **new** terminal afterwards — or the installer prints a
one-line command to enable it in your **current** shell without restarting.

> Re-running an installer is safe: it upgrades the script but **never overwrites
> your edited shortcuts**.

## Commands

| Command | What it does |
|---|---|
| `shortcuts` | Print your shortcuts |
| `shortcuts search <term>` | Filter shortcuts by keyword |
| `shortcuts edit` | Open your shortcuts in your editor |
| `shortcuts path` | Print the data file path |
| `shortcuts reset [-y]` | Restore the default shortcuts |
| `shortcuts update` | Update the `shortcuts` script itself |
| `shortcuts version` | Print the version |
| `shortcuts help` | Show help |

## Customizing

Run `shortcuts edit` and make it yours. The format is plain text:

```
// a line starting with // is a comment (never shown)

# Section Name
key<TAB>description
```

- **`# Section`** — a section header.
- **`key<TAB>description`** — one shortcut. Separate the two with a **Tab**
  (a run of 2+ spaces also works). Columns are aligned automatically on print.
- **`// ...`** — a comment. Ignored when printing.
- Blank lines are ignored.

Example:

```
# Git
git st      status
git co      checkout

# tmux
Ctrl+b %    split vertical
Ctrl+b "    split horizontal
```

### Colors

Colors are configured with `// color` lines in the same file — so your theme
travels with your shortcuts:

```
// color header = bold cyan
// color key    = green
// color desc   = default
```

- **Targets:** `header`, `key`, `desc`.
- **Colors:** `black red green yellow blue magenta cyan white gray`, plus
  `bright-*` variants (e.g. `bright-magenta`).
- **Styles:** `bold dim italic underline`. Combine with spaces (`bold bright-cyan`).
- Use `default` for your terminal's normal color. Set `NO_COLOR=1` to disable
  color entirely.

## Where things live

| | Unix (Linux/macOS/WSL/Git Bash) | Windows (PowerShell/cmd) |
|---|---|---|
| Data file | `~/.config/shortcuts/shortcuts.txt` | `%APPDATA%\shortcuts\shortcuts.txt` |
| Script | `~/.local/bin/shortcuts` | `%LOCALAPPDATA%\Programs\shortcuts\` |

> **Note:** On Windows, a native PowerShell/cmd install and a Git Bash/WSL install
> keep **separate** data files — each environment is self-contained. `shortcuts path`
> always tells you which file the current environment uses.

## How it works

Two dependency-free scripts — [`shortcuts.ps1`](shortcuts.ps1) for PowerShell and
[`shortcuts`](shortcuts) (Bash) for everything POSIX — implement the exact same
commands and the exact same rendering algorithm. Both read the same
[`shortcuts.default.txt`](shortcuts.default.txt) format, so output is identical
regardless of where you run it. Distribution is via GitHub Releases; the install
one-liners and `shortcuts update` fetch the `releases/latest` assets.

```
install.ps1 / install.sh   one-line installers (irm / curl)
shortcuts.ps1              PowerShell implementation
shortcuts                  POSIX shell implementation
shortcuts.default.txt      the default cheat sheet + color config
```

## License

MIT — see [LICENSE](LICENSE).
