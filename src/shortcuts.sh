#!/usr/bin/env bash
# shortcuts — a customizable keyboard-shortcut reference
# https://github.com/Suhaas-code/Shortcuts-cmd
set -euo pipefail

VERSION="1.2.0"
REPO="Suhaas-code/Shortcuts-cmd"
BASE_URL="https://github.com/${REPO}/releases/latest/download"

# --- paths -----------------------------------------------------------------
config_dir() {
  printf '%s/shortcuts' "${XDG_CONFIG_HOME:-$HOME/.config}"
}
data_file() {
  printf '%s/shortcuts.txt' "$(config_dir)"
}

# --- colors ----------------------------------------------------------------
# Disabled when NO_COLOR is set or stdout is not a terminal.
if [ -n "${NO_COLOR:-}" ] || [ ! -t 1 ]; then COLOR_ON=0; else COLOR_ON=1; fi

# Default color specs — overridable via `// color <target> = <spec>` in the data file.
SPEC_HDR="bold cyan"
SPEC_KEY="green"
SPEC_DESC="default"
SPEC_CODE="bold yellow"

ansi_code() { # color/style name -> SGR number ("" if unknown)
  case "$1" in
    bold) echo 1;; dim) echo 2;; italic) echo 3;; underline) echo 4;;
    black) echo 30;; red) echo 31;; green) echo 32;; yellow) echo 33;;
    blue) echo 34;; magenta) echo 35;; cyan) echo 36;; white) echo 37;;
    gray|grey|bright-black) echo 90;; bright-red) echo 91;; bright-green) echo 92;;
    bright-yellow) echo 93;; bright-blue) echo 94;; bright-magenta) echo 95;;
    bright-cyan) echo 96;; bright-white) echo 97;;
    *) echo "";;
  esac
}
ansi_seq() { # "tokens..." -> escape sequence ("" if color off / empty / default)
  [ "$COLOR_ON" = 1 ] || { printf ''; return; }
  local codes="" t c
  for t in $1; do
    case "$t" in default|none) continue;; esac
    c="$(ansi_code "$t")"
    [ -n "$c" ] && codes="${codes:+$codes;}$c"
  done
  [ -n "$codes" ] && printf '\033[%sm' "$codes"
}
ltrim() { printf '%s' "${1#"${1%%[![:space:]]*}"}"; }
rtrim() { printf '%s' "${1%"${1##*[![:space:]]}"}"; }

parse_color_directives() { # file  — read `// color <target> = <spec>` lines
  local ln rest target val
  while IFS= read -r ln; do
    rest="$(ltrim "$ln")"
    case "$rest" in //*) rest="$(ltrim "${rest#//}")" ;; *) continue ;; esac
    # require the 'color' keyword
    case "$rest" in
      color) continue ;;
      color[[:space:]]*) rest="$(ltrim "${rest#color}")" ;;
      *) continue ;;
    esac
    # split target/value on '=' if present, else on whitespace
    case "$rest" in
      *=*) target="${rest%%=*}"; val="${rest#*=}" ;;
      *)   target="${rest%%[[:space:]]*}"; val="${rest#"$target"}" ;;
    esac
    target="$(printf '%s' "$target" | tr -d '[:space:]')"
    val="$(rtrim "$(ltrim "$val")")"
    case "$target" in
      header) SPEC_HDR="$val";;
      key) SPEC_KEY="$val";;
      desc|description) SPEC_DESC="$val";;
      code) SPEC_CODE="$val";;
    esac
  done < "$1"
}

die() { printf 'shortcuts: %s\n' "$1" >&2; exit 1; }

have() { command -v "$1" >/dev/null 2>&1; }

fetch() { # url dest
  if have curl; then
    curl -fsSL "$1" -o "$2"
  elif have wget; then
    wget -qO "$2" "$1"
  else
    die "need curl or wget"
  fi
}

ensure_data() {
  local df; df="$(data_file)"
  if [ ! -f "$df" ]; then
    mkdir -p "$(config_dir)"
    if ! fetch "${BASE_URL}/shortcuts.txt" "$df" 2>/dev/null; then
      die "no shortcuts file at $df and default download failed. Run: shortcuts reset"
    fi
  fi
}

# --- rendering -------------------------------------------------------------
# Reads data on stdin, prints aligned/colored output. Optional $1 = filter term.
render() {
  local filter="${1:-}" hdr key desc code rst
  hdr="$(ansi_seq "$SPEC_HDR")"
  key="$(ansi_seq "$SPEC_KEY")"
  desc="$(ansi_seq "$SPEC_DESC")"
  code="$(ansi_seq "$SPEC_CODE")"
  [ "$COLOR_ON" = 1 ] && rst=$'\033[0m' || rst=""
  awk -v HDR="$hdr" -v KEY="$key" -v DESC="$desc" -v CODE="$code" -v RST="$rst" -v filter="$filter" '
    function trim(s){ sub(/^[ \t]+/,"",s); sub(/[ \t]+$/,"",s); return s }
    function wrap(c,s){ return (c=="" || s=="") ? s : c s RST }
    # colorize a field: text outside `backticks` gets basec, text inside gets CODE
    function colorize(s, basec,   n,arr,i,out){
      n=split(s,arr,"`")
      out=""
      for(i=1;i<=n;i++) out = out wrap((i%2==1)?basec:CODE, arr[i])
      return out
    }
    {
      line=$0
      if (line ~ /^[[:space:]]*$/) next
      if (line ~ /^[[:space:]]*\/\//) next     # comment / directive line
      if (line ~ /^#/) {                       # section header
        sec=trim(substr(line,2))
        n_sec++; sec_name[n_sec]=sec; sec_rows[n_sec]=0
        next
      }
      # row: split on first TAB, else on 2+ spaces
      k=""; d=""
      if (index(line,"\t")>0) {
        t=index(line,"\t"); k=substr(line,1,t-1); d=substr(line,t+1)
      } else if (match(line,/  +/)) {
        k=substr(line,1,RSTART-1); d=substr(line,RSTART+RLENGTH)
      } else { k=line; d="" }
      k=trim(k); d=trim(d)
      if (n_sec==0){ n_sec=1; sec_name[1]="General"; sec_rows[1]=0 }
      r=++sec_rows[n_sec]
      rk[n_sec,r]=k; rd[n_sec,r]=d
      kv=k; gsub(/`/,"",kv)                    # visible width ignores backticks
      if (length(kv)>maxk) maxk=length(kv)
    }
    END{
      pad=maxk+2
      first=1
      for(i=1;i<=n_sec;i++){
        # apply filter: collect matching rows
        cnt=0
        for(j=1;j<=sec_rows[i];j++){
          kk=rk[i,j]; dd=rd[i,j]
          if(filter!=""){
            lk=tolower(kk); ld=tolower(dd); lf=tolower(filter)
            if(index(lk,lf)==0 && index(ld,lf)==0) continue
          }
          mrows[++cnt]=j
        }
        if(cnt==0) continue
        if(!first) print ""
        first=0
        print wrap(HDR, "=== " sec_name[i] " ===")
        for(m=1;m<=cnt;m++){
          j=mrows[m]; kk=rk[i,j]; dd=rd[i,j]
          kv=kk; gsub(/`/,"",kv)
          if(dd==""){ print colorize(kk, KEY) }
          else {
            padn=pad-length(kv); if(padn<0) padn=0
            printf "%s%s%s\n", colorize(kk,KEY), sprintf("%" padn "s",""), colorize(dd,DESC)
          }
        }
      }
    }
  '
}

# --- environment detection -------------------------------------------------
# Sets ENV_NAME (current shell environment), OS_NAME, SHELL_NAME.
detect_env() {
  if [ -n "${WSL_DISTRO_NAME:-}" ] || grep -qiE 'microsoft|wsl' /proc/version 2>/dev/null; then
    OS_NAME="Linux (WSL)"; ENV_NAME="WSL"
  else
    case "$(uname -s 2>/dev/null)" in
      Darwin)        OS_NAME="macOS"; ENV_NAME="Terminal" ;;
      MINGW*|MSYS*)  OS_NAME="Windows"; ENV_NAME="Git Bash" ;;
      CYGWIN*)       OS_NAME="Windows"; ENV_NAME="Cygwin" ;;
      Linux)         OS_NAME="Linux"; ENV_NAME="Terminal" ;;
      *)             OS_NAME="$(uname -s 2>/dev/null || echo Unknown)"; ENV_NAME="shell" ;;
    esac
  fi
  if [ -n "${BASH_VERSION:-}" ]; then SHELL_NAME="bash ${BASH_VERSION%%[^0-9.]*}"
  elif [ -n "${ZSH_VERSION:-}" ]; then SHELL_NAME="zsh ${ZSH_VERSION}"
  else SHELL_NAME="$(basename "${SHELL:-sh}")"; fi
}

# --- commands --------------------------------------------------------------
cmd_list()   { ensure_data; parse_color_directives "$(data_file)"; render "" < "$(data_file)"; }
cmd_search() {
  [ -n "${1:-}" ] || die "usage: shortcuts search <term>"
  ensure_data; parse_color_directives "$(data_file)"; render "$1" < "$(data_file)"
}
cmd_path()   { printf '%s\n' "$(data_file)"; }

cmd_edit() {
  ensure_data
  local ed df; df="$(data_file)"
  ed="${VISUAL:-${EDITOR:-}}"
  if [ -z "$ed" ]; then
    for c in nano vim vi; do have "$c" && { ed="$c"; break; }; done
  fi
  [ -n "$ed" ] || die "no editor found. Set \$EDITOR."
  printf 'Opening shortcuts in the default editor...\n'
  # shellcheck disable=SC2086
  $ed "$df"
}

cmd_reset() {
  local df yes=""; df="$(data_file)"
  case "${1:-}" in -y|--yes) yes=1 ;; esac
  if [ -f "$df" ] && [ -z "$yes" ]; then
    printf 'Overwrite %s with defaults? [y/N] ' "$df"
    read -r ans
    case "$ans" in y|Y|yes|YES) ;; *) die "cancelled" ;; esac
  fi
  mkdir -p "$(config_dir)"
  fetch "${BASE_URL}/shortcuts.txt" "$df" || die "download failed"
  printf 'Restored defaults to %s\n' "$df"
}

cmd_update() {
  local dest; dest="$(command -v shortcuts || true)"
  [ -n "$dest" ] || dest="$HOME/.local/bin/shortcuts"
  local tmp; tmp="$(mktemp)"
  fetch "${BASE_URL}/shortcuts.sh" "$tmp" || die "download failed"
  chmod +x "$tmp"
  mv "$tmp" "$dest"
  printf 'Updated shortcuts at %s\n' "$dest"
}

# neofetch-style banner for `shortcuts version`.
cmd_version() {
  local df rst hdr nsec=0 nrow=0 counts
  df="$(data_file)"
  [ "$COLOR_ON" = 1 ] && rst=$'\033[0m' || rst=""
  if [ -f "$df" ]; then
    parse_color_directives "$df"
    counts="$(awk '/^[[:space:]]*$/{next}/^[[:space:]]*\/\//{next}/^[[:space:]]*#/{s++;next}{r++}END{print (s+0)"|"(r+0)}' "$df")"
    nsec="${counts%%|*}"; nrow="${counts##*|}"
  fi
  hdr="$(ansi_seq "$SPEC_HDR")"

  local ENV_NAME OS_NAME SHELL_NAME
  detect_env

  local host editor palette
  host="$(hostname 2>/dev/null || echo localhost)"
  editor="${VISUAL:-${EDITOR:-}}"; [ -n "$editor" ] || editor="nano/vim/vi (auto)"
  palette="$(ansi_seq "$SPEC_HDR")header${rst} $(ansi_seq "$SPEC_KEY")key${rst} $(ansi_seq "$SPEC_DESC")desc${rst} $(ansi_seq "$SPEC_CODE")code${rst}"

  local LOGO INFO
  LOGO=(
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
  INFO=(
"${hdr}shortcuts${rst}@${hdr}${host}${rst}"
"-----------------------------"
"Version      ${VERSION}"
"Environment  ${ENV_NAME}"
"OS           ${OS_NAME}"
"Shell        ${SHELL_NAME}"
"Shortcuts    ${nrow} in ${nsec} sections"
"Editor       ${editor}"
"Data         ${df}"
"Palette      ${palette}"
"GitHub       https://github.com/${REPO}"
"             ^ star & contribute to support!"
  )

  local w=0 l
  for l in "${LOGO[@]}"; do [ "${#l}" -gt "$w" ] && w=${#l}; done

  local n=${#INFO[@]} m=${#LOGO[@]} max i logo info padded
  max=$n; [ "$m" -gt "$max" ] && max=$m
  echo
  for ((i=0; i<max; i++)); do
    logo="${LOGO[i]:-}"; info="${INFO[i]:-}"
    printf -v padded '%-*s' "$w" "$logo"
    if [ -n "$logo" ] && [ "$COLOR_ON" = 1 ]; then
      printf '%s%s%s   %s\n' "$hdr" "$padded" "$rst" "$info"
    else
      printf '%s   %s\n' "$padded" "$info"
    fi
  done
  echo
}

# Removes every trace of shortcuts: the installed script, the config dir, and the
# PATH line the installer added. Touches ONLY shortcuts' own files.
cmd_uninstall() {
  local yes="" cfg bin ans
  case "${1:-}" in -y|--yes) yes=1 ;; esac
  cfg="$(config_dir)"
  bin="$(command -v shortcuts 2>/dev/null || true)"
  [ -n "$bin" ] || bin="$HOME/.local/bin/shortcuts"

  printf 'This will remove shortcuts completely:\n'
  printf '  script:  %s\n' "$bin"
  printf '  config:  %s (including your customized shortcuts)\n' "$cfg"
  printf '  PATH:    the line added to your shell profile\n'
  if [ -z "$yes" ]; then
    printf 'Proceed? [y/N] '
    read -r ans
    case "$ans" in y|Y|yes|YES) ;; *) die "cancelled" ;; esac
  fi

  # 1) config dir — namespaced to shortcuts, safe to remove wholesale
  case "$cfg" in */shortcuts) [ -d "$cfg" ] && rm -rf "$cfg" && printf 'Removed %s\n' "$cfg" ;; esac

  # 2) installed script (a single file)
  [ -f "$bin" ] && rm -f "$bin" && printf 'Removed %s\n' "$bin"

  # 3) PATH line added by the installer (marker + the following .local/bin line)
  local f tmp
  for f in "$HOME/.zshrc" "$HOME/.bashrc" "$HOME/.profile"; do
    [ -f "$f" ] || continue
    grep -q 'Added by shortcuts installer' "$f" 2>/dev/null || continue
    tmp="$(mktemp)"
    awk '
      /# Added by shortcuts installer/ { mark=1; next }
      mark==1 { mark=0; if ($0 ~ /\.local\/bin/) next }
      { print }
    ' "$f" > "$tmp" && cat "$tmp" > "$f" && rm -f "$tmp"
    printf 'Cleaned PATH entry from %s\n' "$f"
  done

  printf '\nshortcuts uninstalled. Open a new shell to drop the PATH change.\n'
}

cmd_help() {
  cat <<EOF
Usage: shortcuts [search <term>|edit|path|reset [-y]|update|version|uninstall|help]

shortcuts — customizable keyboard-shortcut reference (v${VERSION})

  shortcuts                 Print your shortcuts
  shortcuts search <term>   Filter shortcuts by keyword
  shortcuts edit            Open your shortcuts in \$EDITOR
  shortcuts path            Print the data file path
  shortcuts reset [-y]      Restore the default shortcuts
  shortcuts update          Update the shortcuts script itself
  shortcuts version         Show version + environment info
  shortcuts uninstall [-y]  Remove shortcuts completely
  shortcuts help            Show this help

Data file: $(data_file)
EOF
}

main() {
  case "${1:-}" in
    ""|list)            cmd_list ;;
    edit)               cmd_edit ;;
    search|find)        shift; cmd_search "${1:-}" ;;
    path|where)         cmd_path ;;
    reset)              shift; cmd_reset "${1:-}" ;;
    update|upgrade)     cmd_update ;;
    version|-v|--version) cmd_version ;;
    uninstall|remove)   shift; cmd_uninstall "${1:-}" ;;
    help|-h|--help)     cmd_help ;;
    *)                  printf 'shortcuts: unknown command "%s"\n\n' "$1" >&2; cmd_help >&2; exit 1 ;;
  esac
}

main "$@"
