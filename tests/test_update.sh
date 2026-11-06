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
# dpkg -s responde "instalado", salvo para os pacotes listados em $TMP/dpkg-nao ("*" = todos).
mkshim dpkg "if [[ \"\${1:-}\" == -s ]]; then grep -qxF -e \"\${2:-}\" -e '*' '$TMP/dpkg-nao' 2>/dev/null && exit 1; echo 'Status: install ok installed'; fi; exit 0"
NORUN="$TMP/norun"
mkdir -p "$NORUN"
for c in docker podman; do printf '#!/bin/sh\nexit 1\n' >"$NORUN/$c"; chmod +x "$NORUN/$c"; done

pt() {
  PATH="$SHIMS:$NORUN:$PATH" HOME="$TMP/home" XDG_STATE_HOME="$TMP/state" \
    POWERTERMINAL_UI=text POWERTERMINAL_NONINTERACTIVE=0 "$REPO/bin/powerterminal" "$@"
}

reset() {
  command rm -rf "$TMP/home" "$TMP/state" "$LOG" "$TMP/ev" "$TMP/dpkg-nao" "$TMP/out"
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
mkshim claude
out="$(pt update --module claude --dry-run --yes 2>&1)"
assert_contains "$out" "claude update"

it "update --module vscode --dry-run usa --only-upgrade code"
reset
out="$(pt update --module vscode --dry-run --yes 2>&1)"
assert_contains "$out" "apt-get install --only-upgrade -y code"

it "update --dry-run não executa sudo nem apt de verdade"
assert_eq "" "$(grep -v '^dpkg -s ' "$LOG" || true)"

it "update --module zsh --dry-run faz pull --ff-only dos três clones"
reset
mkshim zsh
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
command rm -f "$SHIMS/zsh"

it "update --module notiont --dry-run mostra pipx upgrade notion-t"
reset
mkshim notion-t
out="$(pt update --module notiont --dry-run --yes 2>&1)"
command rm -f "$SHIMS/notion-t"
assert_contains "$out" "pipx upgrade notion-t"

it "update --module de módulo que não está instalado não instala nada"
reset
PATH="/usr/bin:/bin" pt update --module notiont --yes >"$TMP/out" 2>&1 && rc=0 || rc=$?
[[ "$rc" -eq 0 ]] && ! grep -q pipx "$LOG" && pass || fail "rc=$rc $(cat "$LOG")"
it "e diz que o módulo não está instalado"
assert_contains "$(cat "$TMP/out")" "notiont não está instalado"

it "update --module node --dry-run mostra a atualização do LTS"
reset
mkdir -p "$TMP/home/.nvm"
printf '# nvm\n' >"$TMP/home/.nvm/nvm.sh"
recibo node 'origin	installed' "dir	$TMP/home/.nvm"
out="$(pt update --module node --dry-run --yes 2>&1)"
assert_contains "$out" "nvm install --lts"

it "update de node com o nvm do usuário (sem recibo) não mexe nele"
reset
mkdir -p "$TMP/home/.nvm"
printf '# nvm\n' >"$TMP/home/.nvm/nvm.sh"
out="$(pt update --module node --dry-run --yes 2>&1)"
[[ "$out" != *"nvm install"* && "$out" == *"não foi instalado pelo PowerTerminal"* ]] && pass || fail "$out"

it "update de node com o n do sistema (sem recibo) não roda n lts"
reset
mkshim n 'echo 9.0.0'
pt update --module node --yes >"$TMP/out" 2>&1 && rc=0 || rc=$?
command rm -f "$SHIMS/n"
[[ "$rc" -eq 0 ]] && ! grep -q '^n lts' "$LOG" && pass || fail "rc=$rc $(cat "$LOG")"

it "update --module apt --dry-run faz upgrade dos pacotes base"
reset
out="$(pt update --module apt --dry-run --yes 2>&1)"
assert_contains "$out" "apt-get install --only-upgrade -y ca-certificates"

it "update --module apt só atualiza os pacotes que o dpkg diz instalados"
reset
echo htop >"$TMP/dpkg-nao"
recibo apt 'origin	installed' 'apt	jq'
out="$(pt update --module apt --dry-run --yes 2>&1)"
up="$(grep -- '--only-upgrade' <<<"$out" || true)"
[[ "$up" == *ca-certificates* && "$up" != *htop* && "$out" == *htop* ]] && pass || fail "$out"

it "update --module vscode com o code fora do dpkg (snap) sai 0 sem chamar o apt"
reset
mkshim code
echo code >"$TMP/dpkg-nao"
pt update --module vscode --yes >"$TMP/out" 2>&1 && rc=0 || rc=$?
[[ "$rc" -eq 0 ]] && ! grep -q 'apt-get' "$LOG" && pass || fail "rc=$rc $(cat "$LOG")"
it "e diz que não é gerenciado pelo apt do módulo"
assert_contains "$(cat "$TMP/out")" "não gerenciado pelo apt deste módulo"

it "update de container com docker.io (sem docker-ce) não chama o apt"
reset
mkshim docker 'echo "Docker version 24.0.7"'
printf '%s\n' docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin >"$TMP/dpkg-nao"
pt update --module container --yes >"$TMP/out" 2>&1 && rc=0 || rc=$?
command rm -f "$SHIMS/docker"
[[ "$rc" -eq 0 ]] && ! grep -q 'apt-get' "$LOG" && grep -q 'não gerenciado pelo apt deste módulo' "$TMP/out" \
  && pass || fail "rc=$rc $(cat "$LOG") $(cat "$TMP/out")"

it "update sem --module com VS Code snap sai 0 sem chamar o apt"
reset
echo '*' >"$TMP/dpkg-nao"
PATH="/usr/bin:/bin" pt update --yes >"$TMP/out" 2>&1 && rc=0 || rc=$?
command rm -f "$SHIMS/code"
[[ "$rc" -eq 0 ]] && ! grep -q 'apt-get' "$LOG" && pass || fail "rc=$rc $(cat "$LOG") $(cat "$TMP/out")"

it "update --module kitty --dry-run roda o instalador oficial de novo"
reset
mkdir -p "$TMP/home/.local/kitty.app/bin"
printf '#!/bin/sh\n' >"$TMP/home/.local/kitty.app/bin/kitty"; chmod +x "$TMP/home/.local/kitty.app/bin/kitty"
recibo kitty 'origin	installed' "dir	$TMP/home/.local/kitty.app"
out="$(pt update --module kitty --dry-run --yes 2>&1)"
assert_contains "$out" "sh /dev/stdin"

it "update de kitty sem o kitty.app no recibo não roda o instalador"
reset
mkdir -p "$TMP/home/.local/kitty.app/bin"
printf '#!/bin/sh\n' >"$TMP/home/.local/kitty.app/bin/kitty"; chmod +x "$TMP/home/.local/kitty.app/bin/kitty"
pt update --module kitty --yes >"$TMP/out" 2>&1 && rc=0 || rc=$?
[[ "$rc" -eq 0 ]] && ! grep -q '^curl' "$LOG" && grep -q 'não foi instalado pelo PowerTerminal' "$TMP/out" \
  && pass || fail "rc=$rc $(cat "$LOG") $(cat "$TMP/out")"

it "update --module tools --dry-run reinstala mesmo com as seis ferramentas no PATH"
reset
for c in starship eza yazi ya lazygit lazydocker uv; do mkshim "$c"; done
B="$TMP/home/.local/bin"
recibo tools 'origin	installed' "file	$B/starship" 'apt	eza' "file	$B/yazi" "file	$B/ya" \
  "file	$B/lazygit" "file	$B/lazydocker" "file	$B/uv" "file	$B/uvx"
out="$(pt update --module tools --dry-run --yes 2>&1)"
for c in starship eza yazi ya lazygit lazydocker uv; do command rm -f "$SHIMS/$c"; done
if grep -q 'OK: .* presente' <<<"$out"; then fail "atalho 'já presente' não foi ignorado"; else pass; fi
it "a reinstalação do starship roda o instalador"
assert_contains "$out" "starship.rs/install.sh"
it "o eza instalado pelo apt é atualizado pelo apt"
assert_contains "$out" "apt-get install --only-upgrade -y eza"
it "o uv usa uv self update"
assert_contains "$out" "uv self update"
it "a reinstalação do lazydocker roda o instalador"
assert_contains "$out" "install_update_linux.sh"
if [[ "$(uname -m)" == x86_64 ]]; then
  it "a reinstalação do yazi e do lazygit acontece"
  assert_contains "$out" "yazi-x86_64-unknown-linux-musl.zip"
  assert_contains "$out" "install lazygit"
fi

it "update de tools sem recibo não reinstala nada"
reset
for c in starship eza yazi ya lazygit lazydocker uv; do mkshim "$c"; done
pt update --module tools --yes >"$TMP/out" 2>&1 && rc=0 || rc=$?
[[ "$rc" -eq 0 ]] && ! grep -q '^curl\|^uv \|^sudo env' "$LOG" && grep -q 'não foram instaladas pelo PowerTerminal' "$TMP/out" \
  && pass || fail "rc=$rc $(cat "$LOG") $(cat "$TMP/out")"

it "update de tools só reinstala o que está no recibo"
reset
recibo tools 'origin	installed' "file	$TMP/home/.local/bin/starship"
out="$(pt update --module tools --dry-run --yes 2>&1)"
[[ "$out" == *starship.rs/install.sh* && "$out" != *install_update_linux.sh* && "$out" != *"self update"* \
  && "$out" != *"only-upgrade -y eza"* ]] && pass || fail "$out"

it "uv do PowerTerminal cujo self update falha é reinstalado"
reset
mkdir -p "$TMP/home/.local/bin"
printf '#!/usr/bin/env bash\nprintf "pt-uv %%s\\n" "$*" >>"%s"\nexit 1\n' "$LOG" >"$TMP/home/.local/bin/uv"
chmod +x "$TMP/home/.local/bin/uv"
recibo tools 'origin	installed' "file	$TMP/home/.local/bin/uv"
pt update --module tools --yes >"$TMP/out" 2>&1 || true
grep -qx 'pt-uv self update' "$LOG" && grep -q 'astral.sh/uv/install.sh' "$LOG" && ! grep -q '^uv ' "$LOG" \
  && pass || fail "$(cat "$LOG")"

it "uv que não está no recibo não é tocado"
reset
recibo tools 'origin	installed' "file	$TMP/home/.local/bin/starship"
pt update --module tools --yes >"$TMP/out" 2>&1 || true
! grep -q '^uv \|astral.sh' "$LOG" && pass || fail "$(cat "$LOG")"
for c in starship eza yazi ya lazygit lazydocker uv; do command rm -f "$SHIMS/$c"; done

it "update sem --module não inclui módulos available"
reset
echo '*' >"$TMP/dpkg-nao"
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
  POWERTERMINAL_TESTING=1 POWERTERMINAL_NVIM_PREFIX="$NVOPT" POWERTERMINAL_NVIM_LINK="$NVLINK" pt "$@"
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

it "PN_RECEIPT_DIR herdado do ambiente não desvia os recibos de uma execução real"
reset
PN_RECEIPT_DIR="$TMP/desvio" pt install --module helpers --yes >/dev/null 2>&1 || true
[[ -f "$R/helpers" && ! -e "$TMP/desvio" ]] && pass || fail "recibo desviado: $(ls -R "$TMP/desvio" 2>&1)"

it "PN_RECEIPT_MODULE herdado não faz o update gravar recibo"
reset
mkshim claude
PN_RECEIPT_MODULE=claude pt update --module claude --yes >/dev/null 2>&1 || true
assert_eq "" "$(ls "$R" 2>/dev/null)"

it "PN_EVENTS_FD herdado não manda eventos para a saída"
reset
out="$(PN_EVENTS_FD=1 pt install --module helpers --dry-run --yes 2>/dev/null)" || true
[[ "$out" != *'"event"'* ]] && pass || fail "$out"

nvim_vars() {
  env -u POWERTERMINAL_TESTING POWERTERMINAL_NVIM_PREFIX=/x/opt POWERTERMINAL_NVIM_LINK=/x/nvim HOME="$TMP/home" "$@" \
    bash -c 'source "$1/lib/core.sh"; source "$1/lib/modules/nvim.sh"; printf "%s %s" "$_PN_NVIM_PREFIX" "$_PN_NVIM_LINK"' _ "$REPO"
}
it "POWERTERMINAL_NVIM_PREFIX/LINK são ignorados sem POWERTERMINAL_TESTING=1"
assert_eq "/opt /usr/local/bin/nvim" "$(nvim_vars)"
it "com POWERTERMINAL_TESTING=1 valem"
assert_eq "/x/opt /x/nvim" "$(nvim_vars POWERTERMINAL_TESTING=1)"

it "update falha de um módulo sai 1 e o resto segue"
reset
mkshim claude "exit 3"
out="$(pt update --module claude,notiont --yes 2>&1)" && rc=0 || rc=$?
assert_contains "rc=$rc $out" "rc=1"

test_summary
