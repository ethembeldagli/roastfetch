#!/bin/sh
# roastfetch installer
#
#   curl -fsSL https://raw.githubusercontent.com/ethembeldagli/roastfetch/main/install.sh | sh
#
# Options (when piping, pass them after `sh -s --`):
#   --bin-dir DIR   where the command goes (default ~/.local/bin, /usr/local/bin as root)
#   --uninstall     remove roastfetch
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
    if [ "$STEP_OPEN" = 1 ]; then printf '\n' >&2; fi
    printf '\n  %s✗ %s%s\n' "$RED$B" "$1" "$R" >&2
    shift
    for line in "$@"; do printf '    %s\n' "$line" >&2; done
    printf '\n' >&2
    exit 1
}
has() { command -v "$1" >/dev/null 2>&1; }
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

main() {
    BIN_DIR="${ROASTFETCH_BIN_DIR:-}"
    FROM=""
    ACTION="install"
    while [ $# -gt 0 ]; do
        case "$1" in
            --uninstall) ACTION="uninstall" ;;
            --bin-dir | --from)
                [ $# -ge 2 ] || die "$1 needs a value."
                if [ "$1" = "--bin-dir" ]; then BIN_DIR="$2"; else FROM="$2"; fi
                shift ;;
            --bin-dir=*) BIN_DIR="${1#*=}" ;;
            --from=*) FROM="${1#*=}" ;;
            -h | --help) sed -n '2,12p' "$0" 2>/dev/null || printf 'See https://github.com/%s\n' "$REPO"; exit 0 ;;
            *) die "Unknown option: $1" "Run with --help to see the options." ;;
        esac
        shift
    done
    : "${HOME:?HOME is not set}"
    if [ -z "$BIN_DIR" ]; then
        if [ "$(id -u)" = 0 ]; then BIN_DIR="/usr/local/bin"; else BIN_DIR="$HOME/.local/bin"; fi
    fi
    target="$BIN_DIR/roastfetch"

    printf '\n  %s%sroastfetch%s %sinstaller%s\n\n' "$B" "$ORG" "$R" "$D" "$R"

    if [ "$ACTION" = "uninstall" ]; then
        if [ -e "$target" ]; then rm -f "$target"; printf '  %s✓%s removed %s\n\n' "$GRN" "$R" "$(tilde "$target")"
        else printf '  Nothing to remove in %s.\n\n' "$(tilde "$BIN_DIR")"; fi
        return
    fi

    step "checking your system"
    [ "$(uname -s)" = "Linux" ] || die "roastfetch is made for Linux (this is $(uname -s))."
    find_python || die "Python 3.9 or newer is needed." "Install it with:  $(python_hint)"
    if [ -z "$FROM" ] && ! has curl && ! has wget; then
        die "Neither curl nor wget is installed." "Install one of them and run this again."
    fi
    ok "$(os_field PRETTY_NAME)"

    mkdir -p "$BIN_DIR" 2>/dev/null && [ -w "$BIN_DIR" ] || die "Can't write to $BIN_DIR." "Pick another place with --bin-dir."
    tmp="$target.tmp.$$"
    trap 'rm -f "$tmp"' EXIT
    trap 'exit 130' INT TERM

    if [ -n "$FROM" ]; then
        step "copying from $(tilde "$FROM")"
        cp "$FROM/roastfetch" "$tmp" || die "No roastfetch script in $FROM."
    else
        step "downloading"
        download "https://raw.githubusercontent.com/$REPO/main/roastfetch" "$tmp" 2>/dev/null \
            || die "Download failed." "Check your internet connection and try again."
    fi
    ok

    step "installing to $(tilde "$target")"
    if [ "$PY" != "python3" ]; then
        # No plain `python3` on PATH: point the script at the Python we found.
        py_path="$(command -v "$PY")"
        { printf '#!%s\n' "$py_path"; tail -n +2 "$tmp"; } >"$tmp.2" && mv -f "$tmp.2" "$tmp"
    fi
    chmod 755 "$tmp"
    mv -f "$tmp" "$target"
    ok

    step "checking it runs"
    version="$("$target" --version 2>/dev/null)" || die "Installed, but it doesn't run." "Please open an issue: https://github.com/$REPO/issues"
    ok "$version"

    printf '\n  %s%sDone!%s Get roasted:  %sroastfetch%s\n' "$B" "$GRN" "$R" "$B" "$R"
    case ":$PATH:" in
        *":$BIN_DIR:"*) ;;
        *) printf '  %s(%s is not on your PATH yet; run it as %s)%s\n' "$YEL" "$(tilde "$BIN_DIR")" "$(tilde "$target")" "$R" ;;
    esac
    printf '  %sWant a fresh roast in every new terminal? Add  roastfetch  to the end of your ~/.bashrc or ~/.zshrc.%s\n\n' "$D" "$R"
}

main "$@"
