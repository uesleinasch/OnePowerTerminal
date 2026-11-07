#!/usr/bin/env bash
set -euo pipefail
source "${POWERTERMINAL_HOME}/tests/lib.sh"

REPO="$POWERTERMINAL_HOME"
TMP="$(mktemp -d)"
trap 'command rm -rf "$TMP"' EXIT
SHIMS="$TMP/shims"
LOG="$TMP/calls.log"
mkdir -p "$SHIMS"

mkshim() {
  cat >"$SHIMS/$1" <<EOF
#!/usr/bin/env bash
printf '%s\n' "$1 \$*" >>"$LOG"
exit 0
EOF
  chmod +x "$SHIMS/$1"
}
for c in sudo apt-get dpkg chsh curl git tar nvim; do mkshim "$c"; done

pt() {
  PATH="$SHIMS:$PATH" HOME="$TMP/home" XDG_STATE_HOME="$TMP/state" \
    POWERTERMINAL_UI=text "$REPO/bin/powerterminal" "$@"
}

reset() {
  command rm -rf "$TMP/home" "$TMP/state"
  mkdir -p "$TMP/home" "$TMP/state"
  : >"$LOG"
}

it "install --module helpers --yes não chama sudo"
reset
pt install --module helpers --yes >/dev/null 2>&1 && rc=0 || rc=$?
assert_eq "rc=0 sudo=" "rc=$rc sudo=$(grep '^sudo' "$LOG" || true)"

it "install --module nvim --yes libera o sudo antes dos módulos"
reset
pt install --module nvim --yes >/dev/null 2>&1 && rc=0 || rc=$?
assert_contains "rc=$rc $(cat "$LOG")" "sudo -n true"

test_summary
