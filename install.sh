#!/usr/bin/env bash
# Installer for `shortcuts` (Linux / macOS / WSL / Git Bash).
#   curl -fsSL https://github.com/Suhaas-code/Shortcuts-cmd/releases/latest/download/install.sh | bash
set -euo pipefail

REPO="Suhaas-code/Shortcuts-cmd"
BASE_URL="https://github.com/${REPO}/releases/latest/download"
BIN_DIR="$HOME/.local/bin"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/shortcuts"
DATA_FILE="$CONFIG_DIR/shortcuts.txt"

info() { printf '\033[1;36m==>\033[0m %s\n' "$1"; }
die()  { printf '\033[1;31merror:\033[0m %s\n' "$1" >&2; exit 1; }

fetch() { # url dest
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$1" -o "$2"
  elif command -v wget >/dev/null 2>&1; then
    wget -qO "$2" "$1"
  else
    die "need curl or wget"
  fi
}

info "Installing shortcuts..."
mkdir -p "$BIN_DIR" "$CONFIG_DIR"

info "Downloading script -> $BIN_DIR/shortcuts"
fetch "${BASE_URL}/shortcuts" "$BIN_DIR/shortcuts"
chmod +x "$BIN_DIR/shortcuts"

if [ -f "$DATA_FILE" ]; then
  info "Keeping existing shortcuts at $DATA_FILE"
else
  info "Installing default shortcuts -> $DATA_FILE"
  fetch "${BASE_URL}/shortcuts.default.txt" "$DATA_FILE"
fi

# Ensure ~/.local/bin is on PATH.
on_path=0
case ":$PATH:" in
  *":$BIN_DIR:"*) on_path=1 ;;
  *)
    line="export PATH=\"\$HOME/.local/bin:\$PATH\""
    rc=""
    for f in "$HOME/.zshrc" "$HOME/.bashrc" "$HOME/.profile"; do
      [ -f "$f" ] && { rc="$f"; break; }
    done
    [ -n "$rc" ] || rc="$HOME/.profile"
    if ! grep -qF "$BIN_DIR" "$rc" 2>/dev/null; then
      printf '\n# Added by shortcuts installer\n%s\n' "$line" >> "$rc"
      info "Added $BIN_DIR to PATH in $rc"
    fi
    ;;
esac

printf '\n\033[1;32mDone!\033[0m\n'
if [ "$on_path" -eq 0 ]; then
  printf 'Open a NEW terminal, or use it right now in this shell by running:\n'
  printf '  \033[1;33mexport PATH="%s:$PATH"\033[0m\n\n' "$BIN_DIR"
fi
printf 'Then try:\n  shortcuts\n  shortcuts edit\n'
