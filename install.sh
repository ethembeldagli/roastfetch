#!/bin/sh
# roastfetch installer
#
#   curl -fsSL https://raw.githubusercontent.com/ethembeldagli/roastfetch/main/install.sh | sh
#
# Run it and pick: install, update or delete. For scripts, skip the menu with an
# option (when piping, pass them after `sh -s --`):
#   --install       install or reinstall
#   --update        install only if there's a newer version
#   --uninstall     remove roastfetch
#   --check         is there a newer version? (changes nothing)
#   --bin-dir DIR   where the command goes (default ~/.local/bin, /usr/local/bin as root)
#   --from DIR      install from a local checkout
#
# Needs only Python 3.9+ and curl or wget. Everything runs inside main(),
# called on the last line, so a half-downloaded script can never run.

set -eu

REPO="ethembeldagli/roastfetch"

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
    B="$(printf '\033[1m')"; D="$(printf '\033[2m')"; R="$(printf '\033[0m')"
    RED="$(printf '\033[31m')"; GRN="$(printf '\033[32m')"; YEL="$(printf '\033[33m')"; ORG="$(printf '\033[38;5;208m')"
else
    B=""; D=""; R=""; RED=""; GRN=""; YEL=""; ORG=""
fi

STEP_OPEN=0
step() { printf '  %s›%s %s… ' "$D" "$R" "$1"; STEP_OPEN=1; }
ok() { STEP_OPEN=0; if [ -n "${1:-}" ]; then printf '%s✓%s %s%s%s\n' "$GRN" "$R" "$D" "$1" "$R"; else printf '%s✓%s\n' "$GRN" "$R"; fi; }
die() {
    ui_stop
    if [ "$STEP_OPEN" = 1 ]; then printf '\n' >&2; fi
    printf '\n  %s✗ %s%s\n' "$RED$B" "$1" "$R" >&2
    shift
    for line in "$@"; do printf '    %s\n' "$line" >&2; done
    printf '\n' >&2
    exit 1
}
has() { command -v "$1" >/dev/null 2>&1; }

# >>> fullscreen ui >>>
# A full-screen, full-colour menu in the style of Terminal Wrapped's slides,
# shared by the ethembeldagli installers. When the terminal can't show it
# (too small, no colour, not interactive) the plain text menu is used instead.
# UI_THEME is "TOP|BOTTOM|ACCENT|ACCENT2", each colour as "R G B".

UI_ESC=$(printf '\033')
UI_CR=$(printf '\r')
UI_NL='
'
UI_ACTIVE=0
UI_CLEANUP=""
UI_LOG=""
UI_SEL=1
UI_TRUE=0 UI_STTY="" UI_PREPARED="" UI_KEY="" UI_CHOICE="" UI_TICK=0
UI_TITLE="" UI_RIGHT="" UI_SUB="" UI_LINES="" UI_OPTS="" UI_FOOT="" UI_BRAND=""

# ui_supported: can this terminal show the full-screen menu?
ui_supported() {
    [ -z "${NO_COLOR:-}" ] || return 1
    [ -z "${PLAIN_INSTALLER:-}" ] || return 1
    case "${TERM:-dumb}" in dumb | linux | vt*) return 1 ;; esac
    case "${COLORTERM:-}" in
        truecolor | 24bit) UI_TRUE=1 ;;
        *) case "${TERM:-}" in *256col* | xterm-kitty | alacritty | wezterm | foot*) UI_TRUE=0 ;; *) return 1 ;; esac ;;
    esac
    [ -t 1 ] || return 1
    ( : </dev/tty ) 2>/dev/null || return 1
    command -v stty >/dev/null 2>&1 && command -v dd >/dev/null 2>&1 || return 1
    ui_size || return 1
    [ "$UI_COLS" -ge 60 ] && [ "$UI_ROWS" -ge 20 ]
}

ui_size() {
    _ui_size=$(stty size </dev/tty 2>/dev/null) || return 1
    UI_ROWS=${_ui_size% *} UI_COLS=${_ui_size#* }
    case "$UI_ROWS$UI_COLS" in '' | *[!0-9]*) return 1 ;; esac
    [ "$UI_ROWS" -gt 0 ]
}

# ui_sgr 38|48 R G B -> UI_C, the escape for that foreground/background colour
ui_sgr() {
    if [ "$UI_TRUE" = 1 ]; then
        UI_C="${UI_ESC}[$1;2;$2;$3;$4m"
    else
        UI_C="${UI_ESC}[$1;5;$((16 + 36 * (($2 * 5 + 127) / 255) + 6 * (($3 * 5 + 127) / 255) + ($4 * 5 + 127) / 255))m"
    fi
}

# ui_mix "R G B" "R G B" STEP STEPS -> _ui_r _ui_g _ui_b
ui_mix() {
    # shellcheck disable=SC2086 # split the colours into their parts
    set -- $1 $2 "$3" "$4"
    _ui_r=$(($1 + ($4 - $1) * $7 / $8))
    _ui_g=$(($2 + ($5 - $2) * $7 / $8))
    _ui_b=$(($3 + ($6 - $3) * $7 / $8))
}

# ui_prepare: colours for this theme and terminal size.
ui_prepare() {
    _ui_old_ifs=$IFS
    IFS='|'
    # shellcheck disable=SC2086 # split the theme into its four colours
    set -- $UI_THEME
    IFS=$_ui_old_ifs
    UI_TOP=$1 UI_BOTTOM=$2 UI_ACC=$3 UI_ACC2=$4
    _ui_y=1
    while [ "$_ui_y" -le "$UI_ROWS" ]; do
        ui_mix "$UI_TOP" "$UI_BOTTOM" "$((_ui_y - 1))" "$((UI_ROWS > 1 ? UI_ROWS - 1 : 1))"
        ui_sgr 48 "$_ui_r" "$_ui_g" "$_ui_b"
        eval "UI_BG_$_ui_y=\$UI_C"
        _ui_y=$((_ui_y + 1))
    done
    ui_sgr 38 240 240 255 && UI_FG_C=$UI_C
    ui_mix "240 240 255" "$UI_TOP" 45 100 && ui_sgr 38 "$_ui_r" "$_ui_g" "$_ui_b" && UI_DIM_C=$UI_C
    # shellcheck disable=SC2086
    ui_sgr 38 $UI_ACC && UI_ACC_C=$UI_C
    # shellcheck disable=SC2086
    ui_sgr 38 $UI_ACC2 && UI_ACC2_C=$UI_C
    ui_sgr 38 124 255 178 && UI_GOOD_C=$UI_C
    ui_sgr 38 255 206 92 && UI_WARN_C=$UI_C
    ui_sgr 38 255 112 120 && UI_BAD_C=$UI_C
    # shellcheck disable=SC2086
    ui_sgr 48 $UI_ACC && UI_BAR_BG=$UI_C
    # shellcheck disable=SC2086
    ui_sgr 38 $UI_BOTTOM && UI_BAR_FG=$UI_C
    UI_BLANK=""
    _ui_x=0
    while [ "$_ui_x" -lt "$UI_COLS" ]; do UI_BLANK="$UI_BLANK "; _ui_x=$((_ui_x + 1)); done
    UI_W=$((UI_COLS - 8))
    [ "$UI_W" -gt 66 ] && UI_W=66
    UI_X=$(((UI_COLS - UI_W) / 2 + 1))
    UI_PREPARED="$UI_ROWS:$UI_COLS"
    return 0
}

ui_start() {
    [ "$UI_ACTIVE" = 1 ] && return 0
    UI_STTY=$(stty -g </dev/tty)
    stty -echo -icanon min 0 time 5 </dev/tty
    printf '%s[?1049h%s[?25l%s[?7l' "$UI_ESC" "$UI_ESC" "$UI_ESC"
    UI_ACTIVE=1
    UI_PREPARED=""
    trap 'ui_stop; eval "${UI_CLEANUP:-:}"' EXIT
    trap 'ui_stop; exit 130' INT TERM HUP
    return 0
}

ui_stop() {
    [ "$UI_ACTIVE" = 1 ] || return 0
    printf '%s[0m%s[?7h%s[?25h%s[?1049l' "$UI_ESC" "$UI_ESC" "$UI_ESC" "$UI_ESC"
    stty "$UI_STTY" </dev/tty 2>/dev/null || true
    UI_ACTIVE=0
    return 0
}

# ui_put ROW COL TEXT: add TEXT at ROW, COL on top of that row's background.
ui_put() {
    [ "$1" -ge 1 ] && [ "$1" -le "$UI_ROWS" ] || return 0
    _ui_bg=""
    eval "_ui_bg=\$UI_BG_$1"
    UI_FRAME="$UI_FRAME${UI_ESC}[$1;$2H$_ui_bg$3"
}

# ui_draw: draw UI_TITLE, UI_SUB, UI_LINES, UI_OPTS and UI_FOOT, centred on the
# gradient. UI_LINES holds "info|label|value|tone", "text|tone|text",
# "log|text", "spin|text" or "blank" lines; UI_OPTS holds "key|label|hint".
ui_draw() {
    ui_size || return 0
    [ "$UI_PREPARED" = "$UI_ROWS:$UI_COLS" ] || ui_prepare
    UI_FRAME="${UI_ESC}[0m"
    _ui_y=1
    while [ "$_ui_y" -le "$UI_ROWS" ]; do
        ui_put "$_ui_y" 1 "$UI_BLANK"
        _ui_y=$((_ui_y + 1))
    done

    _ui_count=4
    [ -n "$UI_LINES" ] && _ui_count=$((_ui_count + $(printf '%s\n' "$UI_LINES" | grep -c '') + 1))
    [ -n "$UI_OPTS" ] && _ui_count=$((_ui_count + $(printf '%s\n' "$UI_OPTS" | grep -c '') + 1))
    [ -n "$UI_FOOT" ] && _ui_count=$((_ui_count + 2))
    _ui_y=$(((UI_ROWS - _ui_count) / 2 + 1))
    [ "$_ui_y" -lt 2 ] && _ui_y=2
    _ui_x=$UI_X

    # Title, version on the right, subtitle and a gradient rule.
    ui_put "$_ui_y" "$_ui_x" "$UI_ACC_C${UI_ESC}[1m◆ $UI_FG_C$UI_TITLE${UI_ESC}[22m"
    if [ -n "$UI_RIGHT" ]; then
        ui_put "$_ui_y" "$((_ui_x + UI_W - ${#UI_RIGHT}))" "$UI_DIM_C$UI_RIGHT"
    fi
    _ui_y=$((_ui_y + 1))
    ui_put "$_ui_y" "$_ui_x" "$UI_DIM_C$UI_SUB"
    _ui_y=$((_ui_y + 1))
    _ui_rule=""
    _ui_i=0
    while [ "$_ui_i" -lt "$UI_W" ]; do
        ui_mix "$UI_ACC" "$UI_ACC2" "$_ui_i" "$UI_W"
        ui_sgr 38 "$_ui_r" "$_ui_g" "$_ui_b"
        _ui_rule="$_ui_rule$UI_C━"
        _ui_i=$((_ui_i + 1))
    done
    ui_put "$_ui_y" "$_ui_x" "$_ui_rule"
    _ui_y=$((_ui_y + 2))

    if [ -n "$UI_LINES" ]; then
        while IFS='|' read -r _ui_kind _ui_a _ui_b _ui_c; do
            case "$_ui_kind" in
                info)
                    ui_tone "$_ui_c"
                    _ui_label=$(printf '%-12s' "$_ui_a")
                    ui_put "$_ui_y" "$_ui_x" "$UI_DIM_C$_ui_label $_ui_tone$_ui_b"
                    ;;
                text) ui_tone "$_ui_a" && ui_put "$_ui_y" "$_ui_x" "$_ui_tone$_ui_b" ;;
                big) ui_tone "$_ui_a" && ui_put "$_ui_y" "$_ui_x" "$_ui_tone${UI_ESC}[1m$_ui_b${UI_ESC}[22m" ;;
                log) ui_put "$_ui_y" "$((_ui_x + 2))" "$UI_DIM_C$_ui_a" ;;
                spin)
                    ui_spinner
                    ui_put "$_ui_y" "$_ui_x" "$UI_ACC2_C$_ui_spin $UI_FG_C${UI_ESC}[1m$_ui_a${UI_ESC}[22m"
                    ;;
            esac
            _ui_y=$((_ui_y + 1))
        done <<EOF
$UI_LINES
EOF
        _ui_y=$((_ui_y + 1))
    fi

    if [ -n "$UI_OPTS" ]; then
        _ui_i=1
        while IFS='|' read -r _ui_key _ui_label _ui_hint; do
            _ui_text="$_ui_label${_ui_hint:+  $_ui_hint}"
            _ui_pad=$((UI_W - ${#_ui_text} - 7))
            [ "$_ui_pad" -lt 1 ] && _ui_pad=1
            if [ "$_ui_i" = "$UI_SEL" ]; then
                ui_put "$_ui_y" "$_ui_x" "$UI_BAR_BG$UI_BAR_FG${UI_ESC}[1m ▸ $_ui_label${UI_ESC}[22m${_ui_hint:+  $_ui_hint}$(printf "%${_ui_pad}s" '')$_ui_key   "
            else
                ui_put "$_ui_y" "$_ui_x" "   $UI_FG_C$_ui_label$UI_DIM_C${_ui_hint:+  $_ui_hint}$(printf "%${_ui_pad}s" '')$_ui_key"
            fi
            _ui_i=$((_ui_i + 1))
            _ui_y=$((_ui_y + 1))
        done <<EOF
$UI_OPTS
EOF
        _ui_y=$((_ui_y + 1))
    fi

    if [ -n "$UI_FOOT" ]; then
        _ui_y=$((_ui_y + 1))
        ui_put "$_ui_y" "$_ui_x" "$UI_DIM_C$UI_FOOT"
    fi
    if [ -n "$UI_BRAND" ] && [ "$_ui_y" -lt "$((UI_ROWS - 1))" ]; then
        ui_put "$UI_ROWS" "$(((UI_COLS - ${#UI_BRAND}) / 2 + 1))" "$UI_DIM_C$UI_BRAND"
    fi
    printf '%s' "$UI_FRAME"
    return 0
}

ui_tone() {
    case "$1" in
        good) _ui_tone=$UI_GOOD_C ;;
        warn) _ui_tone=$UI_WARN_C ;;
        bad) _ui_tone=$UI_BAD_C ;;
        dim) _ui_tone=$UI_DIM_C ;;
        accent) _ui_tone=$UI_ACC_C ;;
        accent2) _ui_tone=$UI_ACC2_C ;;
        *) _ui_tone=$UI_FG_C ;;
    esac
    return 0
}

ui_spinner() {
    case $((${UI_TICK:-0} % 10)) in
        0) _ui_spin="⠋" ;; 1) _ui_spin="⠙" ;; 2) _ui_spin="⠹" ;; 3) _ui_spin="⠸" ;; 4) _ui_spin="⠼" ;;
        5) _ui_spin="⠴" ;; 6) _ui_spin="⠦" ;; 7) _ui_spin="⠧" ;; 8) _ui_spin="⠇" ;; *) _ui_spin="⠏" ;;
    esac
    return 0
}

# ui_key: wait up to half a second for a key; sets UI_KEY to up, down, enter,
# esc, char:X or "" when nothing was pressed.
ui_key() {
    _ui_k=$(dd bs=1 count=1 2>/dev/null </dev/tty; echo .)
    _ui_k=${_ui_k%.}
    case "$_ui_k" in
        "") UI_KEY="" ;;
        "$UI_ESC")
            stty min 0 time 1 </dev/tty
            _ui_seq=$(dd bs=8 count=1 2>/dev/null </dev/tty)
            stty min 0 time 5 </dev/tty
            case "$_ui_seq" in
                "[A" | OA) UI_KEY=up ;;
                "[B" | OB) UI_KEY=down ;;
                "") UI_KEY=esc ;;
                *) UI_KEY=other ;;
            esac
            ;;
        "$UI_NL" | "$UI_CR" | " ") UI_KEY=enter ;;
        *) UI_KEY="char:$(printf '%s' "$_ui_k" | tr '[:upper:]' '[:lower:]')" ;;
    esac
    return 0
}

# ui_choose: show the menu until something is picked; sets UI_CHOICE to the
# key of the option, or "esc".
ui_choose() {
    _ui_n=$(printf '%s\n' "$UI_OPTS" | grep -c '')
    [ "$UI_SEL" -ge 1 ] && [ "$UI_SEL" -le "$_ui_n" ] || UI_SEL=1
    UI_FOOT="↑↓ move · enter select · or press a key"
    ui_draw
    while :; do
        _ui_before="$UI_ROWS:$UI_COLS"
        ui_key
        case "$UI_KEY" in
            "") ui_size && [ "$UI_ROWS:$UI_COLS" != "$_ui_before" ] && ui_draw ;;
            up) UI_SEL=$((UI_SEL > 1 ? UI_SEL - 1 : _ui_n)) && ui_draw ;;
            down) UI_SEL=$((UI_SEL < _ui_n ? UI_SEL + 1 : 1)) && ui_draw ;;
            enter)
                UI_CHOICE=$(printf '%s\n' "$UI_OPTS" | sed -n "${UI_SEL}p" | cut -d'|' -f1)
                return 0
                ;;
            esc) UI_CHOICE=esc && return 0 ;;
            char:*)
                _ui_letter=${UI_KEY#char:}
                if printf '%s\n' "$UI_OPTS" | grep -q "^$_ui_letter|"; then
                    UI_CHOICE=$_ui_letter
                    return 0
                fi
                case "$_ui_letter" in
                    k) UI_SEL=$((UI_SEL > 1 ? UI_SEL - 1 : _ui_n)) && ui_draw ;;
                    j) UI_SEL=$((UI_SEL < _ui_n ? UI_SEL + 1 : 1)) && ui_draw ;;
                esac
                ;;
        esac
    done
}

# ui_ask QUESTION DETAIL DEFAULT(y|n): a full-screen yes/no question.
ui_ask() {
    _ui_saved_lines=$UI_LINES _ui_saved_opts=$UI_OPTS _ui_saved_sel=$UI_SEL
    UI_LINES="big|accent2|$1"
    [ -n "$2" ] && UI_LINES="$UI_LINES${UI_NL}text||$2"
    UI_OPTS="y|Yes|${UI_NL}n|No|"
    if [ "$3" = y ]; then UI_SEL=1; else UI_SEL=2; fi
    ui_choose
    UI_LINES=$_ui_saved_lines UI_OPTS=$_ui_saved_opts UI_SEL=$_ui_saved_sel
    [ "$UI_CHOICE" = y ]
}

# ui_busy TEXT: a full-screen "please wait" while something quick runs.
ui_busy() {
    UI_LINES="spin|$1" UI_OPTS="" UI_FOOT=""
    ui_draw
    return 0
}

# ui_run TITLE COMMAND...: run COMMAND with its output going to a log, showing
# the latest lines on a progress screen, then the result. Returns its status.
ui_run() {
    _ui_title=$1
    shift
    UI_LOG=$(mktemp "${TMPDIR:-/tmp}/installer.XXXXXX") || return 1
    # The job can't touch the screen: it runs with the full-screen view marked
    # inactive and its questions answered by their defaults.
    # shellcheck disable=SC2030,SC2034 # UI_IN_JOB is only for the job, read by the installers' own functions
    (UI_ACTIVE=0 UI_IN_JOB=1 && "$@") </dev/null >"$UI_LOG" 2>&1 &
    _ui_pid=$!
    UI_TICK=0
    UI_OPTS="" UI_FOOT=""
    while kill -0 "$_ui_pid" 2>/dev/null; do
        UI_LINES="spin|$_ui_title$(ui_log_lines)"
        ui_draw
        UI_TICK=$((UI_TICK + 1))
        sleep 0.12 2>/dev/null || sleep 1
    done
    _ui_status=0
    wait "$_ui_pid" || _ui_status=$?
    if [ "$_ui_status" = 0 ]; then
        UI_LINES="big|good|✓ Done$(ui_log_lines)"
    else
        UI_LINES="big|bad|✗ That didn't work$(ui_log_lines)"
    fi
    UI_FOOT="Press any key to close"
    ui_draw
    UI_KEY=""
    while [ -z "$UI_KEY" ]; do ui_key; done
    return "$_ui_status"
}

# The last lines of the log, without colours, as "log|..." lines.
ui_log_lines() {
    _ui_max=$((UI_ROWS - 16))
    [ "$_ui_max" -gt 10 ] && _ui_max=10
    [ "$_ui_max" -lt 3 ] && _ui_max=3
    printf '\nblank'
    tail -n 40 "$UI_LOG" 2>/dev/null | tr "$UI_CR" '\n' \
        | sed -e "s/$UI_ESC\[[0-9;?]*[A-Za-z]//g" -e 's/^ *//' -e '/^$/d' -e 's/|/¦/g' \
        | fold -s -w "$((UI_W - 4))" | sed -e 's/^ *//' -e '/^$/d' \
        | tail -n "$_ui_max" | sed -e 's/^/log|/' \
        | while IFS= read -r _ui_line; do printf '\n%s' "$_ui_line"; done
    return 0
}

# ui_finish: leave the full-screen view and print what the last ui_run did,
# so it stays in the terminal's scrollback.
ui_finish() {
    ui_stop
    if [ -n "$UI_LOG" ] && [ -f "$UI_LOG" ]; then
        printf '\n'
        cat "$UI_LOG"
        rm -f "$UI_LOG"
        UI_LOG=""
    fi
    return 0
}
# <<< fullscreen ui <<<

# Colours from Terminal Wrapped's themes.
UI_THEME="77 18 7|22 4 3|255 176 0|255 77 109"
UI_BRAND="github.com/ethembeldagli/roastfetch"
tilde() { case "$1" in "$HOME"/*) printf '~%s' "${1#"$HOME"}" ;; *) printf '%s' "$1" ;; esac; }

os_field() {
    [ -r /etc/os-release ] || return 0
    while IFS='=' read -r key value; do
        if [ "$key" = "$1" ]; then value="${value#\"}"; printf '%s' "${value%\"}"; return 0; fi
    done </etc/os-release
}

python_hint() {
    case " $(os_field ID) $(os_field ID_LIKE) " in
        *" arch "*) echo "sudo pacman -S python" ;;
        *" alpine "*) echo "sudo apk add python3" ;;
        *" opensuse"* | *" suse "*) echo "sudo zypper install python3" ;;
        *" fedora "* | *" rhel "*) echo "sudo dnf install python3" ;;
        *" debian "* | *" ubuntu "*) echo "sudo apt install python3" ;;
        *" nixos "*) echo "nix-shell -p python3" ;;
        *) echo "install Python 3.9 or newer with your package manager" ;;
    esac
}

find_python() {
    for candidate in python3 python3.14 python3.13 python3.12 python3.11 python3.10 python3.9 python; do
        if has "$candidate" && "$candidate" -c 'import sys; sys.exit(sys.version_info < (3, 9))' >/dev/null 2>&1; then
            PY="$candidate"
            return 0
        fi
    done
    return 1
}

download() {
    if has curl; then curl -fsSL --retry 3 --connect-timeout 20 -o "$2" "$1" </dev/null; else wget -q -O "$2" "$1" </dev/null; fi
}

usage() {
    cat <<EOF
roastfetch installer

  curl -fsSL https://raw.githubusercontent.com/$REPO/main/install.sh | sh

Run it and choose: install, update or delete.

To skip the menu (scripts, CI), add an option after  sh -s --
  --install       install or reinstall
  --update        install only if there's a newer version
  --uninstall     remove roastfetch
  --check         is there a newer version? (changes nothing)
  --bin-dir DIR   where the command goes (default ~/.local/bin, /usr/local/bin as root)
  --from DIR      install from a local checkout
EOF
}

# Version of a roastfetch script file, e.g. 0.2.0
script_version() {
    "$PY" -c 'import re, sys
m = re.search(r"^__version__ = \"([^\"]+)\"", open(sys.argv[1], encoding="utf-8").read(), re.M)
print(m.group(1) if m else "")' "$1" 2>/dev/null
}

installed_version() {
    if [ -x "$target" ]; then
        v="$("$target" --version 2>/dev/null)" || return 0
        printf '%s' "${v#roastfetch }"
    fi
}

# Succeeds if version $1 is older than $2.
older() {
    "$PY" -c 'import sys
f = lambda v: tuple(int(p) for p in v.lstrip("v").split(".") if p.isdigit())
sys.exit(0 if f(sys.argv[1]) < f(sys.argv[2]) else 1)' "$1" "$2"
}

# Can we ask the person a question? (Works even when this script is piped from curl.)
interactive() {
    [ -t 1 ] && ( : </dev/tty ) 2>/dev/null
}

ask() { # prompt -> $answer, read from the keyboard
    printf '%s' "$1"
    read -r answer </dev/tty || answer=""
}

menu() { # sets ACTION from the person's choice
    printf '\n'
    if [ -z "$current" ]; then
        printf '  roastfetch is not installed yet.\n\n'
        printf '    %s[i]%s Install roastfetch %s\n' "$B" "$R" "$latest"
        printf '    %s[q]%s Quit\n\n' "$B" "$R"
        default="i"
    else
        if [ -n "$latest" ] && older "$current" "$latest"; then
            printf '  You have roastfetch %s. Version %s%s%s is available.\n\n' "$current" "$B" "$latest" "$R"
            printf '    %s[u]%s Update to %s\n' "$B" "$R" "$latest"
            default="u"
        else
            printf '  You have roastfetch %s, the latest version.\n\n' "$current"
            default="q"
        fi
        printf '    %s[i]%s Reinstall\n' "$B" "$R"
        printf '    %s[d]%s Delete roastfetch\n' "$B" "$R"
        printf '    %s[q]%s Quit\n\n' "$B" "$R"
    fi
    while :; do
        ask "  Choose [$default]: "
        case "${answer:-$default}" in
            i | I | install | reinstall) ACTION="install"; break ;;
            u | U | update) if [ -n "$current" ]; then ACTION="update"; break; fi ;;
            d | D | delete | uninstall | remove) if [ -n "$current" ]; then ACTION="uninstall"; break; fi ;;
            q | Q | quit | exit | n | N) ACTION="quit"; break ;;
        esac
        printf '  Please type one of the letters in brackets.\n'
    done
    printf '\n'
}

uninstall() {
    if [ -e "$target" ]; then
        rm -f "$target"
        printf '  %s✓%s removed %s. Sorry to see you go!\n\n' "$GRN" "$R" "$(tilde "$target")"
    else
        printf '  roastfetch is not installed in %s.\n\n' "$(tilde "$BIN_DIR")"
    fi
}

# The menu, full screen and in colour, when the terminal can show it. Sets
# ACTION, then runs it on a progress screen.
fullscreen_menu() {
    # shellcheck disable=SC2016 # expanded when the script exits
    UI_CLEANUP='rm -rf "$TMP"'
    ui_start
    UI_TITLE="roastfetch" UI_RIGHT="installer"
    UI_SUB="Your fastfetch, plus a roast of your setup"
    if [ -z "$current" ]; then
        UI_LINES="info|Installed|not yet|dim${UI_NL}info|Latest|${latest:-unknown (offline?)}|"
        UI_OPTS="i|Install roastfetch${latest:+ $latest}|${UI_NL}q|Quit|"
        UI_SEL=1
    else
        newer=0
        if [ -n "$latest" ] && older "$current" "$latest"; then newer=1; fi
        if [ -z "$latest" ]; then
            UI_LINES="info|Installed|$current  (couldn't check for updates)|"
        elif [ "$newer" = 1 ]; then
            UI_LINES="info|Installed|$current  → $latest available|warn"
        else
            UI_LINES="info|Installed|$current  ✓ up to date|good"
        fi
        UI_LINES="$UI_LINES${UI_NL}info|Command|$(tilde "$BIN_DIR")/roastfetch|"
        UI_OPTS=""
        if [ "$newer" = 1 ]; then UI_OPTS="u|Update to $latest|$UI_NL"; fi
        UI_OPTS="${UI_OPTS}i|Reinstall|${UI_NL}d|Delete roastfetch|${UI_NL}q|Quit|"
        if [ "$newer" = 1 ]; then UI_SEL=1; else UI_SEL=$(printf '%s\n' "$UI_OPTS" | grep -c ''); fi
    fi
    ui_choose
    case "$UI_CHOICE" in
        i)
            ACTION="install"
            if [ -z "$current" ]; then title="Installing roastfetch${latest:+ $latest}"; else title="Reinstalling roastfetch"; fi
            ;;
        u) ACTION="update" title="Updating roastfetch to $latest" ;;
        d)
            if ui_ask "Delete roastfetch?" "Your fetch goes back to being nice to you." n; then
                ACTION="uninstall" title="Removing roastfetch"
            else
                ACTION="quit"
            fi
            ;;
        *) ACTION="quit" ;;
    esac
    if [ "$ACTION" = "quit" ]; then
        ui_stop
        printf '  Nothing changed.\n\n'
        return 0
    fi
    if ui_run "$title" perform; then
        ui_finish
    else
        status=$?
        ui_finish
        exit "$status"
    fi
    return 0
}

main() {
    BIN_DIR="${ROASTFETCH_BIN_DIR:-}"
    FROM=""
    ACTION=""
    while [ $# -gt 0 ]; do
        case "$1" in
            --install) ACTION="install" ;;
            --uninstall) ACTION="uninstall" ;;
            --check) ACTION="check" ;;
            --update) ACTION="update" ;;
            --bin-dir | --from)
                [ $# -ge 2 ] || die "$1 needs a value."
                if [ "$1" = "--bin-dir" ]; then BIN_DIR="$2"; else FROM="$2"; fi
                shift ;;
            --bin-dir=*) BIN_DIR="${1#*=}" ;;
            --from=*) FROM="${1#*=}" ;;
            -h | --help) usage; exit 0 ;;
            *) die "Unknown option: $1" "Run with --help to see the options." ;;
        esac
        shift
    done
    : "${HOME:?HOME is not set}"
    if [ -z "$BIN_DIR" ]; then
        if [ "$(id -u)" = 0 ]; then BIN_DIR="/usr/local/bin"; else BIN_DIR="$HOME/.local/bin"; fi
    fi
    target="$BIN_DIR/roastfetch"
    one_liner="curl -fsSL https://raw.githubusercontent.com/$REPO/main/install.sh | sh"

    printf '\n  %s%sroastfetch%s %sinstaller%s\n\n' "$B" "$ORG" "$R" "$D" "$R"

    if [ "$ACTION" = "uninstall" ]; then
        uninstall
        return
    fi

    step "checking your system"
    [ "$(uname -s)" = "Linux" ] || die "roastfetch is made for Linux (this is $(uname -s))."
    find_python || die "Python 3.9 or newer is needed." "Install it with:  $(python_hint)"
    if [ -z "$FROM" ] && ! has curl && ! has wget; then
        die "Neither curl nor wget is installed." "Install one of them and run this again."
    fi
    ok "$(os_field PRETTY_NAME)"

    TMP="$(mktemp -d 2>/dev/null || mktemp -d -t roastfetch.XXXXXX)"
    trap 'rm -rf "$TMP"' EXIT
    trap 'exit 130' INT TERM
    new="$TMP/roastfetch"
    current="$(installed_version)"

    latest=""
    if [ -n "$FROM" ]; then
        step "copying from $(tilde "$FROM")"
        cp "$FROM/roastfetch" "$new" 2>/dev/null && latest="$(script_version "$new")"
    else
        step "fetching the latest version"
        download "https://raw.githubusercontent.com/$REPO/main/roastfetch" "$new" 2>/dev/null && latest="$(script_version "$new")"
    fi
    if [ -n "$latest" ]; then
        ok "roastfetch $latest"
    else
        printf '%s!%s couldn'"'"'t get it\n' "$YEL" "$R"
        STEP_OPEN=0
    fi

    if [ -z "$ACTION" ] && interactive && ui_supported; then
        fullscreen_menu
        return
    fi
    if [ -z "$ACTION" ]; then
        if interactive; then menu; else ACTION="install"; fi
    fi
    perform
}

# Everything after the choice: install, update, check or remove.
perform() {
    case "$ACTION" in
        quit)
            printf '  Nothing changed.\n\n'
            return ;;
        uninstall)
            uninstall
            return ;;
    esac
    [ -n "$latest" ] || die "Couldn't download roastfetch." "Check your internet connection and try again."

    if [ "$ACTION" = "check" ]; then
        if [ -z "$current" ]; then
            printf '\n  roastfetch is not installed yet. Latest is %s%s%s. Install it with:\n    %s\n\n' "$B" "$latest" "$R" "$one_liner"
        elif older "$current" "$latest"; then
            printf '\n  %s%sUpdate available:%s %s → %s%s%s. Run the installer again to update:\n    %s\n\n' \
                "$B" "$YEL" "$R" "$current" "$B" "$latest" "$R" "$one_liner"
        else
            printf '\n  %s%sUp to date.%s You have roastfetch %s.\n\n' "$B" "$GRN" "$R" "$current"
        fi
        return
    fi
    if [ "$ACTION" = "update" ] && [ -n "$current" ] && ! older "$current" "$latest"; then
        printf '  %s%sAlready up to date%s (roastfetch %s). Nothing to do.\n\n' "$B" "$GRN" "$R" "$current"
        return
    fi

    mkdir -p "$BIN_DIR" 2>/dev/null && [ -w "$BIN_DIR" ] || die "Can't write to $BIN_DIR." "Pick another place with --bin-dir."
    step "installing to $(tilde "$target")"
    if [ "$PY" != "python3" ]; then
        # No plain `python3` on PATH: point the script at the Python we found.
        py_path="$(command -v "$PY")"
        { printf '#!%s\n' "$py_path"; tail -n +2 "$new"; } >"$new.2" && mv -f "$new.2" "$new"
    fi
    chmod 755 "$new"
    cp "$new" "$target.tmp.$$" && mv -f "$target.tmp.$$" "$target"
    ok

    step "checking it runs"
    version="$("$target" --version 2>/dev/null)" || die "Installed, but it doesn't run." "Please open an issue: https://github.com/$REPO/issues"
    version="${version#roastfetch }"
    if [ -n "$current" ] && [ "$current" != "$version" ]; then ok "updated $current → $version"; else ok "roastfetch $version"; fi

    printf '\n  %s%sDone!%s Get roasted:  %sroastfetch%s\n' "$B" "$GRN" "$R" "$B" "$R"
    case ":$PATH:" in
        *":$BIN_DIR:"*) ;;
        *) printf '  %s(%s is not on your PATH yet; run it as %s)%s\n' "$YEL" "$(tilde "$BIN_DIR")" "$(tilde "$target")" "$R" ;;
    esac
    printf '  %sTo update or remove it later, run the same command again.%s\n\n' "$D" "$R"
}

main "$@"
