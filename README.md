<div align="center">
  <img src="shortcuts-logo.jpg" alt="shortcuts" width="160">
  <h1>Shortcuts</h1>
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

### Your shortcuts, always one command away.

You're in the middle of a task when your mind blanks on a shortcut. Split a pane. Jump to the end of a line. Search scrollback. Instead of doing what you were doing, you leave the terminal, search on google, ask your AI, dig through notes, or worst case, skim documentation. The interruption costs more than the ease the shortcut ever had.

**shortcuts** does what it says, it keeps what you need, where you work. The default command displays your personal cheat sheet in a clean, organized layout, one command instantly searches it, and another one opens it in your preferred editor. You can also keep personal notes, phone numbers, IP addresses, plaintext passwords, or anything else at a glance for your CLI.

Powered by a single plain-text file, **shortcuts** works consistently across PowerShell, Command Prompt, Linux, macOS, WSL, and Git Bash. It runs entirely offline, never connects to the internet, and only updates when you explicitly run the update command. No runtime. No dependencies. Just a lightweight script for each platform.


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
- **Highlights individual keys** — wrap a key in `` `backticks` `` and it renders
  in its own color, e.g. `` `Alt` + `Shift` + `+` ``, distinct from the `+` connectors.
- **Customizable colors** — set section/key/description/code colors right inside
  the data file with `// color` lines (see [Customizing](#customizing)).
- **Self-maintaining** — `shortcuts update` pulls the latest script; `shortcuts reset`
  restores the defaults; `shortcuts path` tells you where your file lives; and
  `shortcuts uninstall` cleanly removes everything it installed.
- **Neofetch-style `version`** — an ASCII banner showing the version, your current
  shell/OS environment, shortcut counts, color palette, and the project link.
- **Respects your terminal** — color turns off automatically when piped or when
  `NO_COLOR` is set.

## Get started (30 seconds)

**Windows** (PowerShell):

```powershell
irm https://github.com/Suhaas-code/shortcuts-cmd/releases/latest/download/install.ps1 | iex
```

**Linux · macOS · WSL · Git Bash**:

```bash
curl -fsSL https://github.com/Suhaas-code/shortcuts-cmd/releases/latest/download/install.sh | bash
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
| `shortcuts version` | Show a neofetch-style banner: version, environment, shortcut counts |
| `shortcuts uninstall [-y]` | Remove shortcuts completely (script, config, PATH entry) |
| `shortcuts help` | Show help |

`shortcuts help` starts with a one-line usage summary, then the full table above.

### Uninstalling

`shortcuts uninstall` removes **everything** it installed and nothing else — the
script, your `shortcuts` config directory, and the single PATH line/entry the
installer added. It never deletes shared directories like `~/.local/bin`. Add
`-y` to skip the confirmation prompt.

You can also uninstall straight from the installers, handy if the command isn't
on your `PATH`:

```powershell
# Windows
& ([scriptblock]::Create((irm https://github.com/Suhaas-code/shortcuts-cmd/releases/latest/download/install.ps1))) -Uninstall
```

```bash
# Linux · macOS · WSL · Git Bash
curl -fsSL https://github.com/Suhaas-code/shortcuts-cmd/releases/latest/download/install.sh | bash -s -- --uninstall
```

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
- **`` `key` ``** — wrap individual keys in backticks to highlight them in a
  distinct color, separate from connectors like `+` or `/` left outside the
  backticks.
- **`// ...`** — a comment. Ignored when printing.
- Blank lines are ignored.

Example:

```
# Git
git st      status
git co      checkout

# tmux
`Ctrl+b` `%`    split vertical
`Ctrl+b` `"`    split horizontal
```

### Colors

Colors are configured with `// color` lines in the same file — so your theme
travels with your shortcuts:

```
// color header = bold cyan
// color key    = green
// color desc   = default
// color code   = bold yellow
```

- **Targets:** `header`, `key`, `desc`, and `code` (text inside `` `backticks` ``).
- **Colors:** `black red green yellow blue magenta cyan white gray`, plus
  `bright-*` variants (e.g. `bright-magenta`).
- **Styles:** `bold dim italic underline`. Combine with spaces (`bold bright-cyan`).
- Use `default` for your terminal's normal color. Set `NO_COLOR=1` to disable
  color entirely.
- `shortcuts.txt` ships with these defaults already set, ready to tweak.

## Where things live

| | Unix (Linux/macOS/WSL/Git Bash) | Windows (PowerShell/cmd) |
|---|---|---|
| Data file | `~/.config/shortcuts/shortcuts.txt` | `%APPDATA%\shortcuts\shortcuts.txt` |
| Script | `~/.local/bin/shortcuts` | `%LOCALAPPDATA%\Programs\shortcuts\` |

> **Note:** On Windows, a native PowerShell/cmd install and a Git Bash/WSL install
> keep **separate** data files — each environment is self-contained. `shortcuts path`
> always tells you which file the current environment uses.

## How it works

Two dependency-free scripts — [`src/shortcuts.ps1`](src/shortcuts.ps1) for
PowerShell and [`src/shortcuts.sh`](src/shortcuts.sh) for everything POSIX —
implement the exact same commands and the exact same rendering algorithm. Both
read the same [`src/shortcuts.txt`](src/shortcuts.txt) format, so output is
identical regardless of where you run it. Distribution is via GitHub Releases;
the install one-liners and `shortcuts update` fetch the `releases/latest`
assets (flattened to plain filenames, independent of this repo's folders).

```
install.ps1 / install.sh   one-line installers, run these (irm / curl)
src/shortcuts.ps1          PowerShell implementation
src/shortcuts.sh           POSIX shell implementation
src/shortcuts.txt          the default cheat sheet + color config
```

> Installed filenames differ slightly from source: the POSIX script installs
> as `shortcuts` (no extension) so it runs as a bare command, and the data
> file installs as your personal `shortcuts.txt` in the config dir below —
> separate from the `src/shortcuts.txt` template in this repo.

## License

MIT — see [LICENSE](LICENSE).
