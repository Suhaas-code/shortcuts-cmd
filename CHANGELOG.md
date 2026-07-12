# Changelog

All notable changes to this project are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.5.1]

### Fixed
- Corrected the `autoadd` starter shortcuts for the AI CLIs (Claude Code, Codex,
  opencode, Aider, Gemini) against their official docs. Notably `Ctrl`+`C` is
  interrupt/cancel — not quit — across all of them, plus command-name and
  wording fixes (e.g. opencode `/models` and `/new`, Codex `/approvals`, Aider
  `/ask` / `/architect`, Gemini `Ctrl`+`C` twice to exit).

## [1.5.0]

### Added
- `autoadd` command: detects installed CLI tools (Claude Code, Codex, opencode,
  Aider, Gemini, Vim, Neovim, git, tmux, fzf, Docker, kubectl) and appends a
  starter shortcut section for each. Previews what it will add, prompts for
  confirmation (`-y`/`--yes` to skip), and skips any section already present.
- `search` now also matches section headings — a term that matches a heading
  returns every shortcut in that section.

## [1.4.0]

### Added
- Per-environment default cheat sheets: the installer seeds `windows.txt`,
  `linux.txt`, or `macos.txt` based on the detected OS.
- `// ansi = off` directive to strip all styling (useful over SSH/WSL).

## [1.3.0]

### Added
- Markdown-lite rendering in the TUI: `#`/`##`/`###` headings, `---` horizontal
  rules, `**bold**`, and `*italic*` / `_italic_` emphasis.

## [1.2.0]

### Added
- `uninstall` command/flag that removes the program, config, and PATH entry.
- neofetch-style banner for `shortcuts version`.

### Fixed
- Self-delete error when uninstalling via the Windows shim.

## [1.1.1]

### Changed
- Colors refresh.

## [1.1.0]

### Added
- Key highlighting and configurable colors via `// color <target> = <spec>`.

### Changed
- Reorganized the repository layout.

## [1.0.0]

### Added
- Initial release: offline, dependency-free keyboard-shortcut cheat sheet with
  `list`, `search`, `edit`, `path`, `reset`, `update`, `version`, and `help`.

[Unreleased]: https://github.com/Suhaas-code/shortcuts-cmd/compare/v1.5.1...HEAD
[1.5.1]: https://github.com/Suhaas-code/shortcuts-cmd/compare/v1.5.0...v1.5.1
[1.5.0]: https://github.com/Suhaas-code/shortcuts-cmd/compare/v1.4.0...v1.5.0
[1.4.0]: https://github.com/Suhaas-code/shortcuts-cmd/compare/v1.3.0...v1.4.0
[1.3.0]: https://github.com/Suhaas-code/shortcuts-cmd/compare/v1.2.0...v1.3.0
[1.2.0]: https://github.com/Suhaas-code/shortcuts-cmd/compare/v1.1.1...v1.2.0
[1.1.1]: https://github.com/Suhaas-code/shortcuts-cmd/compare/v1.1.0...v1.1.1
[1.1.0]: https://github.com/Suhaas-code/shortcuts-cmd/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/Suhaas-code/shortcuts-cmd/releases/tag/v1.0.0
