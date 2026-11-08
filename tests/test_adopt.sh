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

recibo() { cat "$XDG_STATE_HOME"/powerterminal/receipts/"$1" 2>/dev/null; }

it "adopt --module btop com dpkg dizendo instalado grava apt btop e o link da config"
mkdir -p "$TMP/dpkg" "$HOME/.config/btop"
printf '#!/bin/sh\necho "Status: install ok installed"\n' >"$TMP/dpkg/dpkg"
printf '#!/bin/sh\nexit 0\n' >"$TMP/dpkg/btop"
chmod +x "$TMP/dpkg/dpkg" "$TMP/dpkg/btop"
PATH="$TMP/dpkg:$PATH" "$CLI" adopt --module btop >"$TMP/b.log" 2>&1 || cat "$TMP/b.log"
rb="$(recibo btop)"
assert_contains "$rb" "$(printf 'apt\tbtop')"
assert_contains "$rb" "$(printf 'link\t%s/.config/btop' "$HOME")"

it "adopt --module lazygit com o binário em ~/.local/bin grava o file dele"
mkdir -p "$HOME/.local/bin" "$HOME/.config/lazygit"
printf '#!/bin/sh\nexit 0\n' >"$HOME/.local/bin/lazygit"; chmod +x "$HOME/.local/bin/lazygit"
"$CLI" adopt --module lazygit >"$TMP/l.log" 2>&1 || cat "$TMP/l.log"
assert_contains "$(recibo lazygit)" "$(printf 'file\t%s/.local/bin/lazygit' "$HOME")"

it "com o lazygit só em outro diretório do PATH o recibo não tem file e sai o aviso"
"$CLI" remove --module lazygit --yes >/dev/null 2>&1 || true
rm -f "$HOME/.local/bin/lazygit"
mkdir -p "$TMP/outro"; printf '#!/bin/sh\nexit 0\n' >"$TMP/outro/lazygit"; chmod +x "$TMP/outro/lazygit"
mkdir -p "$HOME/.config/lazygit"
out="$(PATH="$TMP/outro:$PATH" "$CLI" adopt --module lazygit 2>&1 || true)"
assert_contains "$out" "fica fora do recibo"
assert_eq "0" "$(recibo lazygit | grep -c '^file' || true)"
