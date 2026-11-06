#!/usr/bin/env bash
set -euo pipefail
source "${POWERTERMINAL_HOME}/tests/lib.sh"
cd "$POWERTERMINAL_HOME"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
export HOME="$TMP/home" XDG_STATE_HOME="$TMP/state"
mkdir -p "$HOME" "$TMP/bin"
printf '#!/bin/sh\nexit 0\n' >"$TMP/bin/code"; chmod +x "$TMP/bin/code"
mkdir -p "$TMP/shims"
for c in sudo apt-get dpkg; do printf '#!/bin/sh\nexit 0\n' >"$TMP/shims/$c"; chmod +x "$TMP/shims/$c"; done

CLI=bin/powerterminal
campo() { python3 -c 'import json,sys;d=json.load(sys.stdin);print(eval(sys.argv[1]))' "$1"; }

it "catalog --json é JSON válido"
"$CLI" catalog --json >"$TMP/c.json" 2>/dev/null || true
assert_ok python3 -c 'import json,sys;json.load(sys.stdin)' <"$TMP/c.json"

it "stdout não tem nada além do JSON mesmo com POWERTERMINAL_EDITOR inválido"
POWERTERMINAL_EDITOR=emacs "$CLI" catalog --json >"$TMP/e.json" 2>/dev/null || true
assert_ok python3 -c 'import json,sys;json.loads(sys.stdin.read())' <"$TMP/e.json"

it "contract_version é 1"
assert_eq 1 "$(campo 'd["contract_version"]' <"$TMP/c.json")"

it "lista todos os módulos de _PN_ALL_MODULES na ordem"
esperado="$(sed -nE 's/^_PN_ALL_MODULES=\((.*)\)$/\1/p' "$CLI")"
assert_eq "$esperado" "$(campo '" ".join(m["id"] for m in d["modules"])' <"$TMP/c.json")"

it "dev inclui os três editores no catálogo"
assert_eq True "$(campo 'all(x in d["profiles"]["dev"] for x in ("nvim","astronvim","vscode"))' <"$TMP/c.json")"

it "cada módulo traz os campos do contrato"
assert_eq True "$(campo 'all(set(m)=={"id","name","category","description","minutes","mb","sudo","needs","editor","state","origin","can_update","can_remove","data_mb"} for m in d["modules"])' <"$TMP/c.json")"

it "módulo sem recibo e com ferramenta presente é preexisting"
PATH="$TMP/bin:$PATH" "$CLI" catalog --json >"$TMP/p.json" 2>/dev/null || true
assert_eq preexisting "$(campo '[m for m in d["modules"] if m["id"]=="vscode"][0]["state"]' <"$TMP/p.json")"

it "helpers instalado pela CLI vira installed com origin installed"
PATH="$TMP/shims:$PATH" "$CLI" install --module helpers --yes >/dev/null 2>&1 || true
"$CLI" catalog --json >"$TMP/h.json" 2>/dev/null || true
assert_eq "installed installed" "$(campo '[(m["state"]+" "+m["origin"]) for m in d["modules"] if m["id"]=="helpers"][0]' <"$TMP/h.json")"

it "catalog sem --json falha"
assert_fail "$CLI" catalog

test_summary
