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
for c in sudo apt-get chsh gpasswd usermod pipx git curl tar; do mkshim "$c"; done
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

it "update --module tools --dry-run reinstala mesmo com as seis ferramentas no PATH"
reset
for c in starship eza yazi ya lazygit lazydocker uv; do mkshim "$c"; done
out="$(pt update --module tools --dry-run --yes 2>&1)"
for c in starship eza yazi ya lazygit lazydocker uv; do command rm -f "$SHIMS/$c"; done
if grep -q 'OK: .* presente' <<<"$out"; then fail "atalho 'já presente' não foi ignorado"; else pass; fi
it "a reinstalação do starship roda o instalador"
assert_contains "$out" "starship.rs/install.sh"
it "a reinstalação do eza passa pelo apt"
assert_contains "$out" "apt-get install -y eza"
it "o uv usa uv self update"
assert_contains "$out" "uv self update"
it "a reinstalação do lazydocker roda o instalador"
assert_contains "$out" "install_update_linux.sh"
if [[ "$(uname -m)" == x86_64 ]]; then
  it "a reinstalação do yazi e do lazygit acontece"
  assert_contains "$out" "yazi-x86_64-unknown-linux-musl.zip"
  assert_contains "$out" "install lazygit"
fi

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

NVOPT="$TMP/opt"
NVLINK="$TMP/usrlocal/nvim"
pt_nvim() {
  POWERTERMINAL_NVIM_PREFIX="$NVOPT" POWERTERMINAL_NVIM_LINK="$NVLINK" pt "$@"
}
nvim_gerenciado() {
  command rm -rf "$NVOPT" "$SHIMS/nvim"
  mkdir -p "$NVOPT/nvim-linux-x86_64/bin"
  printf '#!/bin/sh\necho "NVIM v0.0"\n' >"$NVOPT/nvim-linux-x86_64/bin/nvim"
  chmod +x "$NVOPT/nvim-linux-x86_64/bin/nvim"
  ln -s "$NVOPT/nvim-linux-x86_64/bin/nvim" "$SHIMS/nvim"
}

if [[ "$(uname -m)" == x86_64 ]]; then
  it "update de nvim preexisting (sem recibo) não cria recibo, mesmo gravando"
  reset
  nvim_gerenciado
  out="$(pt_nvim update --module nvim --yes 2>&1)" && rc=0 || rc=$?
  assert_contains "rc=$rc $(cat "$LOG")" "sudo ln -sf $NVOPT/nvim-linux-x86_64/bin/nvim $NVLINK"
  it "e nenhum recibo aparece"
  assert_eq "" "$(ls "$R" 2>/dev/null)"

  it "update de nvim com recibo não muda o recibo"
  reset
  nvim_gerenciado
  recibo nvim 'origin	installed' "dir	$NVOPT/nvim-linux-x86_64"
  pt_nvim update --module nvim --yes >/dev/null 2>&1 || true
  assert_eq $'origin\tinstalled\ndir\t'"$NVOPT/nvim-linux-x86_64" "$(cat "$R/nvim")"
fi

it "update de nvim que não é do PowerTerminal não mexe em nada"
reset
command rm -rf "$NVOPT" "$SHIMS/nvim"
mkshim nvim 'echo "NVIM v9"'
out="$(pt_nvim update --module nvim --yes 2>&1)" && rc=0 || rc=$?
command rm -f "$SHIMS/nvim"
assert_contains "rc=$rc $out" "não é do PowerTerminal"
it "e não chama sudo nem curl"
assert_eq "" "$(grep -E '^(sudo [^-]|curl)' "$LOG" || true)"

it "update de kitty que o usuário já tinha não grava o kitty.app no recibo"
reset
K="$TMP/home/.local/kitty.app"
mkdir -p "$K/bin" "$TMP/home/.local/bin"
printf '#!/bin/sh\necho user-kitty\n' >"$K/bin/kitty"; cp "$K/bin/kitty" "$K/bin/kitten"; chmod +x "$K/bin/"*
ln -s "$K/bin/kitty" "$TMP/home/.local/bin/kitty"; ln -s "$K/bin/kitten" "$TMP/home/.local/bin/kitten"
pt install --module kitty --yes >/dev/null 2>&1 || true
pt update --module kitty --yes >/dev/null 2>&1 || true
[[ -f "$R/kitty" ]] && ! grep -q $'^dir\t' "$R/kitty" && pass || fail "recibo: $(cat "$R/kitty" 2>&1)"
it "e o remove depois do update preserva o kitty do usuário"
pt remove --module kitty --yes >/dev/null 2>&1 || true
[[ -x "$K/bin/kitty" && -x "$K/bin/kitten" ]] && pass || fail "kitty.app do usuário apagado: $(cat "$LOG")"

it "update de tools não grava binário que o usuário já tinha"
reset
mkdir -p "$TMP/home/.local/bin"
printf '#!/bin/sh\necho meu\n' >"$TMP/home/.local/bin/starship"; chmod +x "$TMP/home/.local/bin/starship"
for c in eza yazi ya lazygit lazydocker uv; do mkshim "$c"; done
recibo tools 'origin	installed' "file	$TMP/home/.local/bin/lazygit"
PATH="$TMP/home/.local/bin:$PATH" pt update --module tools --yes >/dev/null 2>&1 || true
assert_eq $'origin\tinstalled\nfile\t'"$TMP/home/.local/bin/lazygit" "$(cat "$R/tools")"
it "e o remove depois do update preserva o starship do usuário"
PATH="$TMP/home/.local/bin:$PATH" pt remove --module tools --yes >/dev/null 2>&1 || true
for c in eza yazi ya lazygit lazydocker uv; do command rm -f "$SHIMS/$c"; done
[[ "$(cat "$TMP/home/.local/bin/starship" 2>/dev/null)" == *"echo meu"* ]] && pass || fail "starship do usuário apagado"

it "update falha de um módulo sai 1 e o resto segue"
reset
mkshim claude "exit 3"
out="$(pt update --module claude,notiont --yes 2>&1)" && rc=0 || rc=$?
assert_contains "rc=$rc $out" "rc=1"

test_summary
