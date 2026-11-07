#!/usr/bin/env bash
set -euo pipefail
source "${POWERTERMINAL_HOME}/tests/lib.sh"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
export HOME="$TMP/home" XDG_STATE_HOME="$TMP/state"
mkdir -p "$HOME"
TREE="$TMP/PowerTerminal"
mkdir -p "$TREE/home.local"
cp -r "$POWERTERMINAL_HOME/bin" "$POWERTERMINAL_HOME/lib" "$TREE/"
touch "$TREE/normal.txt" "$TREE/x.pnnew" \
  "$TREE/y.pnbak.20260101000000" "$TREE/home.local/segredo"

env -u POWERTERMINAL_HOME "$TREE/bin/powerterminal" share "$TMP/out.tar.gz" >/dev/null 2>&1
LISTA="$(tar -tzf "$TMP/out.tar.gz")"

it "share inclui arquivo normal"
assert_contains "$LISTA" "PowerTerminal/normal.txt"

it "share exclui *.pnnew"
case "$LISTA" in *pnnew*) fail "x.pnnew no tarball" ;; *) pass ;; esac

it "share exclui *.pnbak.*"
case "$LISTA" in *pnbak*) fail "pnbak no tarball" ;; *) pass ;; esac

it "share exclui home.local"
case "$LISTA" in *home.local*) fail "home.local no tarball" ;; *) pass ;; esac

it "share --dry-run menciona .pnnew nas exclusões"
SECO="$(env -u POWERTERMINAL_HOME "$TREE/bin/powerterminal" share --dry-run "$TMP/seco.tar.gz" 2>&1)"
assert_contains "$SECO" ".pnnew"

test_summary
