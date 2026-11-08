#!/usr/bin/env bash
set -euo pipefail
source "${POWERTERMINAL_HOME}/tests/lib.sh"
cd "$POWERTERMINAL_HOME"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
export HOME="$TMP/home" XDG_STATE_HOME="$TMP/state"
mkdir -p "$HOME/.config" "$TMP/shims" "$TMP/norun"
for c in sudo apt-get dpkg; do printf '#!/bin/sh\nexit 0\n' >"$TMP/shims/$c"; chmod +x "$TMP/shims/$c"; done
for c in docker podman; do printf '#!/bin/sh\nexit 1\n' >"$TMP/norun/$c"; chmod +x "$TMP/norun/$c"; done
export PATH="$TMP/shims:$TMP/norun:$PATH"

CLI=bin/powerterminal
campo() { python3 -c 'import json,sys;d=json.load(sys.stdin);print(eval(sys.argv[1]))' "$1"; }
modulo() { "$CLI" catalog --json 2>/dev/null | campo "[m for m in d['modules'] if m['id']=='$1'][0]$2"; }

cp -r home/.config/nvim "$HOME/.config/nvim"

it "can_adopt é true para preexisting, false para apt e para available"
assert_eq "True False False" "$(modulo astronvim "['can_adopt']") $(modulo apt "['can_adopt']") $(modulo helpers "['can_adopt']")"

it "adopt --module astronvim vira link e guarda a cópia em .pnbak"
"$CLI" adopt --module astronvim >/dev/null 2>&1
assert_eq "yes yes" "$([[ -L "$HOME/.config/nvim" ]] && echo yes) $(compgen -G "$HOME/.config/nvim.pnbak.*" >/dev/null && echo yes)"

it "o recibo é adopted com link e o catálogo mostra installed, can_remove true"
assert_eq "installed adopted True True" "$(modulo astronvim "['state']") $(modulo astronvim "['origin']") $(modulo astronvim "['can_remove']") $(modulo astronvim "['receipt'][0]['kind']=='link'")"

it "remove de adotado sem --yes e com NONINTERACTIVE herdado pede confirmação e 'n' cancela"
out="$(printf 'n\n' | POWERTERMINAL_NONINTERACTIVE=1 POWERTERMINAL_UI=text "$CLI" remove --module astronvim 2>&1 || true)"
assert_contains "$out" "já existia antes do PowerTerminal"

it "o cancelamento deixa o link no lugar"
assert_eq yes "$([[ -L "$HOME/.config/nvim" ]] && echo yes)"

it "remove --yes restaura o diretório original"
"$CLI" remove --module astronvim --yes >"$TMP/r.log" 2>&1 || cat "$TMP/r.log"
assert_eq "yes no" "$([[ -d "$HOME/.config/nvim" && ! -L "$HOME/.config/nvim" ]] && echo yes) $(compgen -G "$HOME/.config/nvim.pnbak.*" >/dev/null && echo yes || echo no)"
