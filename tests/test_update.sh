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
  local nome="$1" corpo="${2:-exit 0}"
  cat >"$SHIMS/$nome" <<EOF
#!/usr/bin/env bash
printf '%s\n' "$nome \$*" >>"$LOG"
$corpo
EOF
  chmod +x "$SHIMS/$nome"
}
for c in sudo apt-get chsh gpasswd usermod pipx git; do mkshim "$c"; done
mkshim dpkg
NORUN="$TMP/norun"
mkdir -p "$NORUN"
for c in docker podman; do printf '#!/bin/sh\nexit 1\n' >"$NORUN/$c"; chmod +x "$NORUN/$c"; done

pt() {
  PATH="$SHIMS:$NORUN:$PATH" HOME="$TMP/home" XDG_STATE_HOME="$TMP/state" \
    POWERTERMINAL_UI=text POWERTERMINAL_NONINTERACTIVE=0 "$REPO/bin/powerterminal" "$@"
}

reset() {
  command rm -rf "$TMP/home" "$TMP/state" "$LOG" "$TMP/ev"
  mkdir -p "$TMP/home" "$TMP/state"
  : >"$LOG"
}

R="$TMP/state/powerterminal/receipts"
recibo() {
  local mod="$1"; shift
  mkdir -p "$R"
  : >"$R/.migrated-v1"
  printf '%s\n' "$@" >"$R/$mod"
}

it "update --module helpers é recusado com a mensagem da release"
reset
out="$(pt update --module helpers --yes 2>&1)" && rc=0 || rc=$?
assert_contains "rc=$rc $out" "rc=1"
it "a recusa explica que o módulo muda com a release"
assert_contains "$out" "O módulo helpers não tem atualização própria; ele muda junto com a release do PowerTerminal."

it "update --module inexistente é recusado"
out="$(pt update --module naoexiste --yes 2>&1)" && rc=0 || rc=$?
assert_contains "rc=$rc $out" "Módulo desconhecido: naoexiste"

it "update --module claude --dry-run mostra claude update"
reset
out="$(pt update --module claude --dry-run --yes 2>&1)"
assert_contains "$out" "claude update"

it "update --module vscode --dry-run usa --only-upgrade code"
reset
out="$(pt update --module vscode --dry-run --yes 2>&1)"
assert_contains "$out" "apt-get install --only-upgrade -y code"

it "update --dry-run não executa sudo nem apt de verdade"
assert_eq "" "$(cat "$LOG")"

it "update --module zsh --dry-run faz pull --ff-only dos três clones"
reset
C="$TMP/home/.oh-my-zsh/custom"
mkdir -p "$C/themes/powerlevel10k/.git" "$C/plugins/zsh-autosuggestions/.git" "$C/plugins/zsh-syntax-highlighting/.git"
out="$(pt update --module zsh --dry-run --yes 2>&1)"
n="$(grep -c 'pull --ff-only' <<<"$out" || true)"
assert_eq "3" "$n"

it "update --module zsh pula clone ausente"
reset
mkdir -p "$TMP/home/.oh-my-zsh/custom/plugins/zsh-autosuggestions/.git"
out="$(pt update --module zsh --dry-run --yes 2>&1)"
assert_eq "1" "$(grep -c 'pull --ff-only' <<<"$out" || true)"

it "update --module notiont --dry-run mostra pipx upgrade notion-t"
reset
out="$(pt update --module notiont --dry-run --yes 2>&1)"
assert_contains "$out" "pipx upgrade notion-t"

it "update --module node --dry-run mostra a atualização do LTS"
reset
mkdir -p "$TMP/home/.nvm"
printf '# nvm\n' >"$TMP/home/.nvm/nvm.sh"
out="$(pt update --module node --dry-run --yes 2>&1)"
assert_contains "$out" "nvm install --lts"

it "update --module apt --dry-run faz upgrade dos pacotes base"
reset
out="$(pt update --module apt --dry-run --yes 2>&1)"
assert_contains "$out" "apt-get install --only-upgrade -y ca-certificates"

it "update --module kitty --dry-run roda o instalador oficial de novo"
reset
mkdir -p "$TMP/home/.local/kitty.app/bin"
printf '#!/bin/sh\n' >"$TMP/home/.local/kitty.app/bin/kitty"; chmod +x "$TMP/home/.local/kitty.app/bin/kitty"
out="$(pt update --module kitty --dry-run --yes 2>&1)"
assert_contains "$out" "sh /dev/stdin"

it "update --module tools --dry-run força a reinstalação mesmo com a ferramenta presente"
reset
out="$(pt update --module tools --dry-run --yes 2>&1)"
if grep -q 'OK: .* presente' <<<"$out"; then fail "atalho 'já presente' não foi ignorado"; else pass; fi

it "update sem --module não inclui módulos available"
reset
mkshim dpkg "exit 1"
pt install --module helpers --yes >/dev/null 2>&1 || true
pt update --dry-run --yes --events-fd 3 3>"$TMP/ev" >/dev/null 2>&1 || true
catalogo="$(pt catalog --json 2>/dev/null)"
ruim="$(python3 -I - "$catalogo" "$(cat "$TMP/ev")" <<'PY'
import json, sys
estado = {m["id"]: m["state"] for m in json.loads(sys.argv[1])["modules"]}
for linha in sys.argv[2].splitlines():
    ev = json.loads(linha)
    if ev.get("event") == "module_begin" and estado.get(ev["module"]) == "available":
        print(ev["module"])
PY
)"
mkshim dpkg
assert_eq "" "$ruim"

it "update sem --module inclui o módulo com recibo"
reset
recibo claude 'origin	installed'
pt update --dry-run --yes --events-fd 3 3>"$TMP/ev" >/dev/null 2>&1 || true
assert_contains "$(cat "$TMP/ev")" '"module":"claude"'

it "update emite module_begin com action update"
assert_contains "$(cat "$TMP/ev")" '"action":"update"'

it "update de módulo sem recibo (preexisting) não cria recibo"
reset
mkshim claude
out="$(pt update --module claude --yes 2>&1)" && rc=0 || rc=$?
if [[ "$rc" -eq 0 && ! -e "$R/claude" && -z "$(ls "$R" 2>/dev/null)" ]]; then pass; else fail "rc=$rc recibo criado: $(ls "$R" 2>&1)"; fi

it "update de módulo sem recibo chama o comando de update"
assert_contains "$(cat "$LOG")" "claude update"

it "update mantém o recibo existente"
reset
recibo claude 'origin	installed' "file	$TMP/home/.local/bin/claude"
pt update --module claude --yes >/dev/null 2>&1 || true
assert_eq $'origin\tinstalled\nfile\t'"$TMP/home/.local/bin/claude" "$(cat "$R/claude")"

it "update de módulo preexisting com sudo (vscode) não grava recibo de apt"
reset
pt update --module vscode --yes >/dev/null 2>&1 || true
assert_eq "" "$(ls "$R" 2>/dev/null)"

it "update falha de um módulo sai 1 e o resto segue"
reset
mkshim claude "exit 3"
out="$(pt update --module claude,notiont --yes 2>&1)" && rc=0 || rc=$?
assert_contains "rc=$rc $out" "rc=1"

test_summary
