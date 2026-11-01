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

    if [ -z "$ACTION" ]; then
        if interactive; then menu; else ACTION="install"; fi
    fi

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
