#!/usr/bin/env bash
# shortcuts — a customizable keyboard-shortcut reference
# https://github.com/Suhaas-code/shortcuts-cmd
set -euo pipefail

VERSION="1.5.1"
REPO="Suhaas-code/shortcuts-cmd"
BASE_URL="https://github.com/${REPO}/releases/latest/download"

# Default data asset for this environment (macOS / Windows-shell / Linux).
default_asset() {
  case "$(uname -s 2>/dev/null)" in
    Darwin)               echo macos.txt ;;
    MINGW*|MSYS*|CYGWIN*) echo windows.txt ;;
    *)                    echo linux.txt ;;
  esac
}

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
    # `// ansi = off` disables all color/styling (avoids ANSI leaking over SSH/WSL).
    case "$rest" in
      ansi*)
        aval="$(printf '%s' "${rest#ansi}" | tr -d '[:space:]=' | tr 'A-Z' 'a-z')"
        case "$aval" in off|false|no|0|disable) COLOR_ON=0 ;; esac
        continue ;;
    esac
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
    if ! fetch "${BASE_URL}/$(default_asset)" "$df" 2>/dev/null; then
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
  awk -v HDR="$hdr" -v KEY="$key" -v DESC="$desc" -v CODE="$code" -v RST="$rst" -v filter="$filter" -v CO="$COLOR_ON" '
    function trim(s){ sub(/^[ \t]+/,"",s); sub(/[ \t]+$/,"",s); return s }
    function wrap(c,s){ return (c=="" || s=="") ? s : c s RST }
    # wrap a Markdown emphasis span in ANSI on/off codes (accumulate over base color)
    function wstyle(txt,on,off){ return (CO!=1||txt=="") ? txt : "\033[" on "m" txt "\033[" off "m" }
    # convert one emphasis marker (** or * or _); markers always stripped
    function empass(s,marker,mlen,on,off,   out,p,q,inner){
      out=""
      while((p=index(s,marker))>0){
        out=out substr(s,1,p-1); s=substr(s,p+mlen)
        q=index(s,marker)
        if(q==0){ return out marker s }          # unmatched — keep literal
        inner=substr(s,1,q-1); s=substr(s,q+mlen)
        if(inner==""){ out=out marker marker; continue }
        out=out wstyle(inner,on,off)
      }
      return out s
    }
    # inline Markdown: **bold** (first), *italic*, _italic_
    function inl(s){ s=empass(s,"**",2,1,22); s=empass(s,"*",1,3,23); s=empass(s,"_",1,3,23); return s }
    # colorize a field: text outside `backticks` gets basec (+inline emphasis), inside gets CODE
    function colorize(s, basec,   n,arr,i,out){
      n=split(s,arr,"`")
      out=""
      for(i=1;i<=n;i++) out = out ((i%2==1) ? wrap(basec, inl(arr[i])) : wrap(CODE, arr[i]))
      return out
    }
    {
      line=$0
      if (line ~ /^[[:space:]]*$/) next
      if (line ~ /^[[:space:]]*\/\//) next     # comment / directive line
      if (line ~ /^[[:space:]]*(-{3,}|\*{3,}|_{3,})[[:space:]]*$/) {   # horizontal rule
        if (n_sec==0){ n_sec=1; sec_name[1]="General"; sec_lvl[1]=1; sec_rows[1]=0 }
        r=++sec_rows[n_sec]; rtype[n_sec,r]="rule"
        next
      }
      if (line ~ /^[[:space:]]*#/) {            # heading (any level)
        h=line; sub(/^[[:space:]]*/,"",h)
        lvl=0; while(substr(h,1,1)=="#"){ lvl++; h=substr(h,2) }
        sub(/[[:space:]]*#*[[:space:]]*$/,"",h)
        n_sec++; sec_name[n_sec]=trim(h); sec_lvl[n_sec]=lvl; sec_rows[n_sec]=0
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
      if (n_sec==0){ n_sec=1; sec_name[1]="General"; sec_lvl[1]=1; sec_rows[1]=0 }
      r=++sec_rows[n_sec]
      rtype[n_sec,r]="row"; rk[n_sec,r]=k; rd[n_sec,r]=d
      kv=k; gsub(/`/,"",kv)                    # visible width ignores backticks
      if (length(kv)>maxk) maxk=length(kv)
    }
    END{
      pad=maxk+2
      rulecol=(CO==1)?"\033[2m":""
      first=1
      for(i=1;i<=n_sec;i++){
        # apply filter: collect matching rows (rules dropped while filtering).
        # A term matching the section heading keeps every row in the section.
        secmatch=(filter!="" && index(tolower(sec_name[i]),tolower(filter))>0)
        cnt=0
        for(j=1;j<=sec_rows[i];j++){
          if(rtype[i,j]=="rule"){ if(filter!="") continue; mrows[++cnt]=j; continue }
          kk=rk[i,j]; dd=rd[i,j]
          if(filter!="" && !secmatch){
            lk=tolower(kk); ld=tolower(dd); lf=tolower(filter)
            if(index(lk,lf)==0 && index(ld,lf)==0) continue
          }
          mrows[++cnt]=j
        }
        if(cnt==0) continue
        if(!first) print ""
        first=0
        deco=(sec_lvl[i]>=2)?"---":"==="
        print wrap(HDR, deco " " inl(sec_name[i]) " " deco)
        for(m=1;m<=cnt;m++){
          j=mrows[m]
          if(rtype[i,j]=="rule"){ print wrap(rulecol, "--------------------------------"); continue }
          kk=rk[i,j]; dd=rd[i,j]
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
  fetch "${BASE_URL}/$(default_asset)" "$df" || die "download failed"
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
    counts="$(awk '/^[[:space:]]*$/{next}/^[[:space:]]*\/\//{next}/^[[:space:]]*(-{3,}|\*{3,}|_{3,})[[:space:]]*$/{next}/^[[:space:]]*#/{s++;next}{r++}END{print (s+0)"|"(r+0)}' "$df")"
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

# --- autoadd ---------------------------------------------------------------
# Starter shortcut sets for popular CLI tools, probed by executable name with
# have(). Intentionally small — edit them after adding. The section text
# produced here is kept byte-identical with shortcuts.ps1.
AUTOADD_TOOLS="claude codex opencode aider gemini vim nvim git tmux fzf docker kubectl"

tool_name() { # exe -> section heading
  case "$1" in
    claude)   printf 'Claude Code' ;;
    codex)    printf 'Codex' ;;
    opencode) printf 'opencode' ;;
    aider)    printf 'Aider' ;;
    gemini)   printf 'Gemini' ;;
    vim)      printf 'Vim' ;;
    nvim)     printf 'Neovim' ;;
    git)      printf 'Git' ;;
    tmux)     printf 'tmux' ;;
    fzf)      printf 'fzf' ;;
    docker)   printf 'Docker' ;;
    kubectl)  printf 'kubectl' ;;
  esac
}

aa_row() { printf '%s\t%s\n' "$1" "$2"; }

tool_block() { # exe -> section text (heading + `key`<TAB>desc rows)
  printf '# %s\n' "$(tool_name "$1")"
  case "$1" in
    claude)
      aa_row '`/model`'        'Switch the active model'
      aa_row '`/clear`'        'Start a fresh conversation'
      aa_row '`/diff`'         'View uncommitted changes'
      aa_row '`Ctrl` + `C`'    'Cancel current operation'
      aa_row '`Esc`'           'Cancel input'
      aa_row '`Ctrl` + `J`'    'Insert a newline'
      aa_row '`Ctrl` + `D`'    'Exit Claude Code' ;;
    codex)
      aa_row '`/model`'             'Change model & reasoning effort'
      aa_row '`/approvals`'         'Set what Codex can do'
      aa_row '`/init`'             'Create an AGENTS.md file'
      aa_row '`/new`'              'Start a new chat'
      aa_row '`/diff`'             'Show the git diff'
      aa_row '`Esc`'               'Interrupt the current task'
      aa_row '`Ctrl` + `C` (twice)' 'Quit Codex' ;;
    opencode)
      aa_row '`/init`'       'Set up an AGENTS.md file'
      aa_row '`/new`'        'Start a new session'
      aa_row '`/models`'     'List and switch model'
      aa_row '`/sessions`'   'Switch sessions'
      aa_row '`/share`'      'Share the session'
      aa_row '`/undo`'       'Undo the last change'
      aa_row '`Esc`'         'Interrupt the agent'
      aa_row '`Ctrl` + `C`'  'Exit' ;;
    aider)
      aa_row '`/add`'        'Add files to the chat'
      aa_row '`/drop`'       'Remove files from the chat'
      aa_row '`/ask`'        'Ask without editing'
      aa_row '`/architect`'  'Plan, then edit'
      aa_row '`/diff`'       'Diff since the last message'
      aa_row '`/undo`'       "Undo aider's last commit"
      aa_row '`/run`'        'Run a shell command'
      aa_row '`/exit`'       'Quit aider' ;;
    gemini)
      aa_row '`/help`'              'Show help and commands'
      aa_row '`/clear`'             'Clear screen and history'
      aa_row '`/chat`'              'Save or resume chat history'
      aa_row '`/tools`'             'List available tools'
      aa_row '`/mcp`'               'List MCP servers'
      aa_row '`/memory`'            'Manage GEMINI.md context'
      aa_row '`Ctrl` + `C` (twice)' 'Cancel, or exit' ;;
    vim)
      aa_row '`i`'    'Insert mode'
      aa_row '`Esc`'  'Normal mode'
      aa_row '`:w`'   'Save'
      aa_row '`:q`'   'Quit'
      aa_row '`:wq`'  'Save and quit'
      aa_row '`dd`'   'Delete the current line'
      aa_row '`/`'    'Search forward' ;;
    nvim)
      aa_row '`i`'    'Insert mode'
      aa_row '`Esc`'  'Normal mode'
      aa_row '`:w`'   'Save'
      aa_row '`:q`'   'Quit'
      aa_row '`:wq`'  'Save and quit'
      aa_row '`gg`'   'Go to the top'
      aa_row '`G`'    'Go to the bottom' ;;
    git)
      aa_row '`git status`'  'Show working tree status'
      aa_row '`git add`'     'Stage changes'
      aa_row '`git commit`'  'Record staged changes'
      aa_row '`git push`'    'Upload commits'
      aa_row '`git pull`'    'Fetch and merge'
      aa_row '`git log`'     'Show commit history' ;;
    tmux)
      aa_row '`Ctrl` + `b` `c`'  'New window'
      aa_row '`Ctrl` + `b` `n`'  'Next window'
      aa_row '`Ctrl` + `b` `%`'  'Split vertically'
      aa_row '`Ctrl` + `b` `"`'  'Split horizontally'
      aa_row '`Ctrl` + `b` `d`'  'Detach session'
      aa_row '`Ctrl` + `b` `x`'  'Kill the pane' ;;
    fzf)
      aa_row '`Ctrl` + `R`'  'Search command history'
      aa_row '`Ctrl` + `T`'  'Paste selected files'
      aa_row '`Alt` + `C`'   'cd into selected directory'
      aa_row '`Tab`'         'Toggle multi-select'
      aa_row '`Enter`'       'Confirm selection' ;;
    docker)
      aa_row '`docker ps`'      'List running containers'
      aa_row '`docker images`'  'List images'
      aa_row '`docker build`'   'Build an image'
      aa_row '`docker run`'     'Run a container'
      aa_row '`docker exec`'    'Run a command in a container'
      aa_row '`docker logs`'    'Show container logs' ;;
    kubectl)
      aa_row '`kubectl get`'       'List resources'
      aa_row '`kubectl describe`'  'Show resource details'
      aa_row '`kubectl logs`'      'Print pod logs'
      aa_row '`kubectl apply`'     'Apply a manifest'
      aa_row '`kubectl exec`'      'Run a command in a pod'
      aa_row '`kubectl delete`'    'Delete resources' ;;
  esac
}

# Detects installed CLI tools and appends a starter shortcut section for each,
# skipping any tool whose section heading is already in the data file.
cmd_autoadd() {
  ensure_data
  local df yes="" t name lname ans sep existing
  local toadd=() present=()
  df="$(data_file)"
  case "${1:-}" in -y|--yes) yes=1 ;; esac

  # existing heading names, lowercased (mirrors the heading parse in render)
  existing="$(awk 'match($0,/^[[:space:]]*#+[[:space:]]*/){h=substr($0,RLENGTH+1); sub(/[[:space:]]*#*[[:space:]]*$/,"",h); print tolower(h)}' "$df")"

  for t in $AUTOADD_TOOLS; do
    have "$t" || continue
    name="$(tool_name "$t")"
    lname="$(printf '%s' "$name" | tr 'A-Z' 'a-z')"
    if printf '%s\n' "$existing" | grep -qxF "$lname"; then
      present+=("$name")
    else
      toadd+=("$t")
    fi
  done

  printf 'autoadd — shortcuts for detected CLI tools\n\n'
  if [ "${#toadd[@]}" -gt 0 ]; then
    printf 'Will add sections:\n'
    for t in "${toadd[@]}"; do printf '  + %s  (%s)\n' "$(tool_name "$t")" "$t"; done
  fi
  if [ "${#present[@]}" -gt 0 ]; then
    [ "${#toadd[@]}" -gt 0 ] && printf '\n'
    printf 'Already present (skipped): '
    sep=""
    for name in "${present[@]}"; do printf '%s%s' "$sep" "$name"; sep=", "; done
    printf '\n'
  fi
  if [ "${#toadd[@]}" -eq 0 ]; then
    printf '\nNothing to add — no new detected tools.\n'
    return 0
  fi
  printf '\n'
  if [ -z "$yes" ]; then
    printf 'Append %s section(s) to %s? [y/N] ' "${#toadd[@]}" "$df"
    read -r ans
    case "$ans" in y|Y|yes|YES) ;; *) die "cancelled" ;; esac
  fi
  for t in "${toadd[@]}"; do
    printf '\n' >> "$df"
    tool_block "$t" >> "$df"
  done
  printf '\nAdded %s section(s) to %s\n' "${#toadd[@]}" "$df"
}

cmd_help() {
  cat <<EOF
shortcuts v${VERSION} — keyboard-shortcut cheat sheet

Usage: shortcuts [command]
  (none)           Print shortcuts
  search <term>    Filter by keyword or section heading
  autoadd [-y]     Add shortcuts for detected CLI tools
  edit             Edit in \$EDITOR
  path             Print data file path
  reset [-y]       Restore defaults
  update           Update the script
  version          Version + environment
  uninstall [-y]   Remove everything
  help             This help

Data: $(data_file)
EOF
}

main() {
  case "${1:-}" in
    ""|list)            cmd_list ;;
    edit)               cmd_edit ;;
    search|find)        shift; cmd_search "${1:-}" ;;
    autoadd)            shift; cmd_autoadd "${1:-}" ;;
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
