# Architecture

`shortcuts` is two dependency-free scripts that implement the **exact same
commands and the exact same rendering algorithm**:

- [`src/shortcuts.ps1`](https://github.com/Suhaas-code/shortcuts-cmd/blob/main/src/shortcuts.ps1) — PowerShell (Windows).
- [`src/shortcuts.sh`](https://github.com/Suhaas-code/shortcuts-cmd/blob/main/src/shortcuts.sh) — POSIX shell (Linux, macOS, WSL,
  Git Bash), rendering through `awk`.

Both read the same data-file format, so output is identical regardless of where
you run it. Any change to parsing or rendering must land in **both** scripts to
keep them in parity.

## Repository layout

```
install.ps1 / install.sh   one-line installers, run these (irm / curl)
src/shortcuts.ps1          PowerShell implementation
src/shortcuts.sh           POSIX shell implementation
src/shortcuts.txt          generic default (fallback / back-compat)
src/shortcuts/windows.txt  per-environment default cheat sheets
src/shortcuts/linux.txt      — the installer seeds the one that
src/shortcuts/macos.txt      matches your OS
docs/                      this documentation
```

## Rendering pipeline

Each script parses the data file line by line, in this order:

1. blank line → skipped
2. `//` comment → skipped (but `// color …` and `// ansi …` directives are read)
3. horizontal rule (`---` / `***` / `___`) → rule row
4. heading (`#` / `##` / `###`) → section header
5. otherwise → a `key<TAB>description` row (also splits on a run of 2+ spaces)

Fields are split on backticks: text outside gets the base color plus inline
emphasis (`**bold**`, `*italic*`, `_italic_`); text inside gets the code/key
color verbatim. Key column width ignores backticks and emphasis markers, so
columns align on visible width. Emphasis uses accumulating ANSI codes with
attribute-off codes (`22`/`23`) so styling never drops the surrounding color.

## Environment-matched defaults

The installers and the `reset` / first-run paths pick a seed file by OS:

| Environment | Seed asset |
|---|---|
| macOS (`uname -s` = `Darwin`) | `macos.txt` |
| Windows shell (MinGW / MSYS / Cygwin, and `install.ps1`) | `windows.txt` |
| Everything else (Linux, WSL) | `linux.txt` |

`shortcuts.txt` remains as a generic fallback and for backward compatibility
with older installs that fetch it by name.

## Pages

`shortcuts new <name>` creates additional pages as flat files,
`shortcuts-<name>.txt`, in the same config directory as `shortcuts.txt` — no
subdirectory. They're purely local: there's no remote seed for a page, so
`reset` and the auto-download-on-first-run path only ever touch
`shortcuts.txt`, never a named page. Because they live inside the config
directory, `uninstall`'s existing whole-directory removal deletes every page
along with the default sheet — no separate cleanup logic needed. See
[CLI Reference](reference.md#shortcuts-page) for the full command set.

## Distribution

Distribution is via GitHub Releases. The install one-liners and `shortcuts
update` fetch the `releases/latest` assets, **flattened to plain filenames**
(independent of this repo's folders): `install.ps1`, `install.sh`,
`shortcuts.ps1`, `shortcuts.sh`, `shortcuts.txt`, `windows.txt`, `linux.txt`,
`macos.txt`.

> Installed filenames differ slightly from source: the POSIX script installs as
> `shortcuts` (no extension) so it runs as a bare command, and the chosen seed
> installs as your personal `shortcuts.txt` in the config dir — separate from
> the templates in this repo.
