#!/usr/bin/env bash
set -euo pipefail
source "${POWERTERMINAL_HOME}/tests/lib.sh"
source "${POWERTERMINAL_HOME}/lib/core.sh"
source "${POWERTERMINAL_HOME}/lib/receipt.sh"
source "${POWERTERMINAL_HOME}/lib/events.sh"

REPO="$POWERTERMINAL_HOME"
TMP="$(mktemp -d)"
trap 'command rm -rf "$TMP"' EXIT
SHIMS="$TMP/shims"
LOG="$TMP/calls.log"
mkdir -p "$SHIMS"

# O sudo falso nunca executa o comando: um `sudo rm -rf` errado vira só uma
# linha no log, nunca um rm de verdade fora do diretório temporário.
mkshim() {
  local nome="$1" corpo="${2:-exit 0}"
  cat >"$SHIMS/$nome" <<EOF
#!/usr/bin/env bash
printf '%s\n' "$nome \$*" >>"$LOG"
$corpo
EOF
  chmod +x "$SHIMS/$nome"
}
mkshim sudo 'case "${1:-}" in -n) exit 1 ;; esac; exit 0'
for c in apt-get dpkg chsh gpasswd usermod; do mkshim "$c"; done
mkshim pipx "[[ \"\${1:-}\" == list ]] && cat '$TMP/pipx-list' 2>/dev/null; exit 0"
mkshim systemctl "[[ \"\${2:-}\" == cat ]] && exit \"\$(cat '$TMP/unit-rc' 2>/dev/null || echo 0)\"; exit 0"

reset() {
  command rm -rf "$TMP/home" "$TMP/state" "$TMP/outside" "$LOG" "$TMP/pipx-list" "$TMP/unit-rc" "$TMP/tmpdir"
  mkdir -p "$TMP/home" "$TMP/state" "$TMP/outside"
  : >"$LOG"
}

pt() {
  PATH="$SHIMS:$PATH" HOME="$TMP/home" XDG_STATE_HOME="$TMP/state" \
    POWERTERMINAL_UI=text POWERTERMINAL_NONINTERACTIVE=0 "$REPO/bin/powerterminal" "$@"
}

recibo() {
  local mod="$1"; shift
  mkdir -p "$TMP/state/powerterminal/receipts"
  : >"$TMP/state/powerterminal/receipts/.migrated-v1"
  printf '%s\n' "$@" >"$TMP/state/powerterminal/receipts/$mod"
}

R="$TMP/state/powerterminal/receipts"
B="$TMP/home/.local/bin"

it "remove de helpers apaga os links e o recibo"
reset
pt install --module helpers --yes >/dev/null 2>&1 || true
[[ -L "$B/myastro" && -f "$R/helpers" ]] || fail "install não deixou links e recibo"
: >"$LOG"
pt remove --module helpers --yes >/dev/null 2>&1 || true
if [[ ! -e "$B/myastro" && ! -L "$B/myastro" && ! -L "$B/mykitty" && ! -L "$B/myyazi" && ! -e "$R/helpers" ]]; then pass; else fail "links ou recibo sobraram"; fi

it "remove de helpers não pede sudo"
assert_eq "" "$(grep '^sudo' "$LOG" || true)"

it "remove restaura o .pnbak mais recente"
reset
mkdir -p "$B"
printf 'velho\n' >"$B/myastro.pnbak.20000101000000"
printf 'meu\n' >"$B/myastro"
pt install --module helpers --yes >/dev/null 2>&1 || true
pt remove --module helpers --yes >/dev/null 2>&1 || true
if [[ ! -L "$B/myastro" && "$(cat "$B/myastro")" == meu && -f "$B/myastro.pnbak.20000101000000" ]]; then pass; else fail "backup mais recente não restaurado"; fi

it "arquivo real no lugar do link é mantido"
reset
pt install --module helpers --yes >/dev/null 2>&1 || true
command rm -f "$B/myastro"
printf 'do usuário\n' >"$B/myastro"
pt remove --module helpers --yes >/dev/null 2>&1 || true
assert_eq "do usuário" "$(cat "$B/myastro")"

it "remove --dry-run não apaga nada nem o recibo"
reset
pt install --module helpers --yes >/dev/null 2>&1 || true
pt remove --module helpers --dry-run --yes >/dev/null 2>&1 || true
if [[ -L "$B/myastro" && -L "$B/myyazi" && -f "$R/helpers" ]]; then pass; else fail "dry-run apagou algo"; fi

it "remove de módulo sem recibo sai 0 e avisa"
reset
out="$(pt remove --module helpers --yes 2>&1)" && rc=0 || rc=$?
assert_contains "rc=$rc $out" "rc=0"
it "o aviso diz que não há nada a desfazer"
assert_contains "$out" "Nada do PowerTerminal para desfazer em helpers."

it "remove pede confirmação quando há dependentes"
reset
recibo astronvim 'origin	installed' "link	$TMP/home/.config/nvim"
recibo nvim 'origin	installed' 'dir	/opt/nvim-linux-x86_64'
out="$(printf 'n\n' | pt remove --module nvim 2>&1)" || true
assert_contains "$out" "Cancelado"
it "a pergunta lista os módulos"
assert_contains "$out" "Remover nvim?"
it "o aviso de dependentes nomeia quem quebra"
assert_contains "$out" "astronvim dependem de nvim e vão parar de funcionar."
it "cancelar deixa o recibo do nvim intacto"
assert_eq $'origin\tinstalled\ndir\t/opt/nvim-linux-x86_64' "$(cat "$R/nvim")"
it "cancelar não pede sudo"
assert_eq "" "$(cat "$LOG")"

it "dependente removido junto não pede confirmação"
reset
recibo astronvim 'origin	installed' "link	$TMP/home/.config/nvim"
recibo nvim 'origin	installed' "dir	$TMP/home/.fake-nvim"
out="$(printf 'y\n' | pt remove --module nvim,astronvim 2>&1)" || true
[[ "$out" != *"dependem de"* && ! -e "$R/nvim" ]] && pass || fail "avisou dependentes ou não removeu: $out"

it "remove sem --yes pergunta mesmo sem dependentes"
reset
pt install --module helpers --yes >/dev/null 2>&1 || true
out="$(printf 'n\n' | pt remove --module helpers 2>&1)" || true
assert_contains "$out" "Remover helpers?"
it "responder não cancela sem mudar nada"
[[ "$out" == *"Cancelado"* && -L "$B/myastro" && -f "$R/helpers" ]] && pass || fail "mudou algo: $out"

nvm_proprio() {
  mkdir -p "$TMP/home/.nvm"
  printf 'nvm\n' >"$TMP/home/.nvm/nvm.sh"
}
evidencia() {
  mkdir -p "$B"
  ln -s "$REPO/bin-helpers/myastro" "$B/myastro"
}

it "nvm do próprio usuário, sem link do PowerTerminal, não é removido"
reset
nvm_proprio
out="$(pt remove --module node --yes 2>&1)" || true
[[ -f "$TMP/home/.nvm/nvm.sh" && ! -e "$R/node" ]] && pass || fail "apagou o ~/.nvm do usuário: $out"
it "e o remove diz que não há nada a desfazer"
assert_contains "$out" "Nada do PowerTerminal para desfazer em node."
it "e o catálogo mostra node como preexisting"
assert_eq preexisting "$(pt catalog --json 2>/dev/null | python3 -c 'import json,sys;print([m["state"] for m in json.load(sys.stdin)["modules"] if m["id"]=="node"][0])')"

it "com evidência de install do PowerTerminal, o ~/.nvm deduzido é removido"
reset
nvm_proprio; evidencia
pt remove --module node --yes >/dev/null 2>&1 || true
[[ ! -e "$TMP/home/.nvm" && ! -e "$R/node" ]] && pass || fail "~/.nvm deduzido não saiu"

it "remove --dry-run mostra o que a migração pendente faria remover"
reset
nvm_proprio; evidencia
mkdir -p "$TMP/tmpdir"
out="$(TMPDIR="$TMP/tmpdir" pt remove --module node --dry-run --yes 2>&1)" || true
assert_contains "$out" "rm -rf --one-file-system -- $TMP/home/.nvm"
it "o dry-run não grava recibo nem marcador reais e não apaga o ~/.nvm"
[[ ! -e "$R/node" && ! -e "$R/.migrated-v1" && -f "$TMP/home/.nvm/nvm.sh" ]] && pass || fail "dry-run mexeu no estado real"
it "o dry-run limpa o diretório temporário de prévia"
assert_eq "" "$(ls -A "$TMP/tmpdir" | grep -v '^powerterminal-\(notes\|answers\)' || true)"

it "pipx que já não lista o pacote conta como desfeito"
reset
recibo notiont 'origin	installed' 'pipx	notion-t'
out="$(pt remove --module notiont --yes 2>&1)" && rc=0 || rc=$?
[[ "$rc" -eq 0 && ! -e "$R/notiont" ]] && ! grep -q 'pipx uninstall' "$LOG" && pass || fail "rc=$rc $(cat "$LOG") $out"

it "pipx que lista o pacote desinstala"
reset
printf 'notion-t 0.1.0\n' >"$TMP/pipx-list"
recibo notiont 'origin	installed' 'pipx	notion-t'
pt remove --module notiont --yes >/dev/null 2>&1 || true
[[ ! -e "$R/notiont" ]] && grep -qx 'pipx uninstall notion-t' "$LOG" && pass || fail "$(cat "$LOG")"

it "recibo com caminho fora do HOME pede sudo upfront"
reset
recibo nvim 'origin	installed' 'dir	/opt/nvim-linux-x86_64'
pt remove --module nvim --yes >/dev/null 2>&1 || true
assert_contains "$(cat "$LOG")" "sudo -v"

it "remove --dry-run não pede sudo"
reset
recibo nvim 'origin	installed' 'dir	/opt/nvim-linux-x86_64'
pt remove --module nvim --dry-run --yes >/dev/null 2>&1 || true
assert_eq "" "$(cat "$LOG")"

it "remove --module apt é recusado"
reset
out="$(pt remove --module apt --yes 2>&1)" && rc=0 || rc=$?
assert_contains "rc=$rc $out" "O módulo apt não pode ser removido."
it "a recusa sai com erro"
[[ "$rc" -ne 0 ]] && pass || fail "rc=$rc"

it "remove de módulo desconhecido é recusado"
assert_fail pt remove --module naoexiste --yes

it "remove sem --module é recusado"
assert_fail pt remove --yes

it "remove emite module_end ok por --events-fd"
reset
pt install --module helpers --yes >/dev/null 2>&1 || true
EV="$TMP/ev"
pt remove --module helpers --yes --events-fd 3 3>"$EV" >/dev/null 2>&1 || true
assert_contains "$(cat "$EV")" '{"event":"module_end","module":"helpers","action":"remove","ok":true}'
it "os eventos do remove são JSON válido"
assert_ok python3 -c 'import json,sys;[json.loads(l) for l in sys.stdin]' <"$EV"

it "remove roda na ordem inversa da canônica"
reset
recibo helpers 'origin	installed' "dir	$TMP/home/.h"
recibo fonts 'origin	installed' "dir	$TMP/home/.f"
pt remove --module fonts,helpers --yes --events-fd 3 3>"$EV" >/dev/null 2>&1 || true
assert_eq "helpers fonts" "$(python3 -c 'import json,sys;print(" ".join(e["module"] for e in map(json.loads,sys.stdin) if e["event"]=="module_begin"))' <"$EV")"

# ---- pn_receipt_undo direto (funções sobrescritas no subshell) ---------------

undo_env() {
  reset
  export HOME="$TMP/home" XDG_STATE_HOME="$TMP/state"
  DRY_RUN=0
  POWERTERMINAL_NOTES_FILE="$TMP/notes"; : >"$POWERTERMINAL_NOTES_FILE"
  as_sudo() { printf 'sudo %s\n' "$*" >>"$LOG"; }
  dpkg() { return 0; }
  # Cinto de segurança: se o guard falhar, o rm de verdade só age dentro do TMP.
  rm() {
    local a
    for a in "$@"; do
      [[ "$a" == -* || "$a" == "$TMP"/?* ]] || { printf 'rm bloqueado: %s\n' "$a" >>"$LOG"; return 1; }
    done
    command rm "$@"
  }
}

it "pacote apt de outro recibo não é purgado"
(
  undo_env
  recibo apt 'origin	installed' 'apt	ca-certificates'
  recibo container 'origin	installed' 'apt	ca-certificates' 'apt	podman' 'apt	uidmap'
  _PN_SUBID_RANGE_START=100000 _PN_SUBID_RANGE_END=165535
  pn_receipt_undo container >/dev/null 2>&1
  grep -q 'apt-get purge' "$LOG" && ! grep 'apt-get purge' "$LOG" | grep -q ca-certificates
) && pass || fail "ca-certificates purgado ou purge ausente: $(cat "$LOG")"

it "a purga é uma chamada só com os pacotes exclusivos"
assert_eq "sudo env DEBIAN_FRONTEND=noninteractive apt-get purge -y uidmap podman" "$(grep 'apt-get' "$LOG")"

it "nunca roda autoremove"
assert_eq "" "$(grep autoremove "$LOG" || true)"

it "entrada dir perigosa é recusada"
(
  undo_env
  mkdir -p "$HOME/.legit/sub" "$HOME/.local/bin"
  : >"$HOME/legit.txt"
  recibo perigo 'origin	installed' 'dir	/' "dir	$HOME" "dir	$HOME/" 'file	' \
    "dir	$HOME/../outside" "dir	$HOME/./" "dir	$HOME/.local" "dir	$HOME/.local/bin" \
    'dir	/usr/local/bin' 'dir	/opt' 'dir	/etc' "dir	$REPO" 'dir	relativo/x' \
    "dir	$HOME/.legit" "file	$HOME/legit.txt"
  rc=0
  pn_receipt_undo perigo >"$TMP/out" 2>&1 || rc=$?
  [[ "$rc" -ne 0 && -d "$HOME/.local/bin" && -d "$TMP/outside" && -d "$REPO/lib" ]] \
    && [[ ! -e "$HOME/.legit" && ! -e "$HOME/legit.txt" ]] \
    && ! grep -q 'rm' "$LOG"
) && pass || fail "guard falhou: $(cat "$LOG") $(cat "$TMP/out")"

it "a recusa avisa o caminho"
assert_contains "$(cat "$TMP/out")" "Recusado"

it "o recibo mantém só as entradas recusadas"
H="$TMP/home"
assert_eq "$(printf '%s\n' $'origin\tinstalled' $'dir\t/' $'dir\t'"$H" $'dir\t'"$H/" $'file\t' \
  $'dir\t'"$H/../outside" $'dir\t'"$H/./" $'dir\t'"$H/.local" $'dir\t'"$H/.local/bin" \
  $'dir\t/usr/local/bin' $'dir\t/opt' $'dir\t/etc' $'dir\t'"$REPO" $'dir\trelativo/x')" "$(cat "$R/perigo")"

it "dir que é symlink remove só o link, não o alvo"
(
  undo_env
  mkdir -p "$TMP/outside/dados"
  ln -s "$TMP/outside/dados" "$HOME/.atalho"
  recibo m 'origin	installed' "dir	$HOME/.atalho"
  pn_receipt_undo m >/dev/null 2>&1
  [[ ! -L "$HOME/.atalho" && -d "$TMP/outside/dados" && ! -e "$R/m" ]]
) && pass || fail "seguiu o symlink"

it "dir sob um pai que é symlink para fora é recusado"
(
  undo_env
  mkdir -p "$TMP/outside/dados"
  ln -s "$TMP/outside" "$HOME/.fuga"
  recibo m 'origin	installed' "dir	$HOME/.fuga/dados"
  rc=0; pn_receipt_undo m >/dev/null 2>&1 || rc=$?
  [[ "$rc" -ne 0 && -d "$TMP/outside/dados" ]]
) && pass || fail "apagou fora do HOME por um pai symlink"

it "dir symlink com barra no fim remove só o link"
(
  undo_env
  mkdir -p "$TMP/outside/dados/x"
  ln -s "$TMP/outside/dados" "$HOME/.atalho"
  recibo m 'origin	installed' "dir	$HOME/.atalho/"
  pn_receipt_undo m >/dev/null 2>&1
  [[ ! -L "$HOME/.atalho" && -d "$TMP/outside/dados/x" ]]
) && pass || fail "barra no fim seguiu o symlink"

recusa() { [[ -n "$(_pn_undo_path_motivo "$(_pn_norm_path "$1")" /home/u)" ]]; }
for p in / /home/u /home/u/ /home/u/. /home/u/./x /home/u/a/../b /home/u/.. /opt /opt/ /usr/local \
  /usr/local/bin /usr/local/share /etc /etc/passwd /usr/bin/x relativo/x '' /home/u/.config \
  /home/u/.local /home/u/.local/bin /home/u/.local/share/ /home/u/.ssh /home/u/.cache /home/uu/x \
  /home/u/.local/share/fonts /home/u/.local/share/applications/ /home/u/.config/systemd/user \
  ; do
  it "guard recusa '$p'"
  assert_ok recusa "$p"
done

it "guard recusa o repositório e o que o contém, mesmo sob o HOME"
(
  POWERTERMINAL_HOME=/home/u/src/PowerTerminal
  for p in /home/u/src/PowerTerminal /home/u/src/PowerTerminal/home /home/u/src; do
    [[ -n "$(_pn_undo_path_motivo "$p" /home/u)" ]] || exit 1
  done
  [[ -z "$(_pn_undo_path_motivo /home/u/src2 /home/u)" ]]
) && pass || fail "repositório não protegido"
for p in /home/u/.nvm /home/u/n /home/u/.local/kitty.app /home/u/.local/bin/uv \
  /home/u/.local/share/fonts/x.ttf /opt/nvim-linux-x86_64 /usr/local/bin/nvim; do
  it "guard aceita '$p'"
  assert_fail recusa "$p"
done

it "file que é diretório de verdade é recusado"
(
  undo_env
  mkdir -p "$HOME/.local/share/algo/x"
  recibo m 'origin	installed' "file	$HOME/.local/share/algo"
  rc=0; pn_receipt_undo m >/dev/null 2>&1 || rc=$?
  [[ "$rc" -ne 0 && -d "$HOME/.local/share/algo/x" ]]
) && pass || fail "file apagou um diretório"

it "caminho que já não existe conta como desfeito"
(
  undo_env
  recibo m 'origin	installed' "dir	$HOME/.sumiu" 'file	/opt/nao-existe-pn-teste'
  pn_receipt_undo m >/dev/null 2>&1 && [[ ! -e "$R/m" && ! -s "$LOG" ]]
) && pass || fail "entrada ausente não foi tratada como desfeita"

it "caminho fora do HOME usa sudo"
(
  undo_env
  [[ -e /usr/local/bin ]] || exit 0
  real="$(ls -1 /usr/local/bin | head -1)"
  [[ -n "$real" ]] || exit 0
  [[ -L "/usr/local/bin/$real" ]] && esperado="sudo rm -f -- /usr/local/bin/$real" || esperado="sudo rm -rf --one-file-system -- /usr/local/bin/$real"
  [[ -d "/usr/local/bin/$real" && ! -L "/usr/local/bin/$real" ]] && exit 0
  recibo m 'origin	installed' "dir	/usr/local/bin/$real"
  pn_receipt_undo m >/dev/null 2>&1
  [[ "$(cat "$LOG")" == "$esperado" ]]
) && pass || fail "não usou sudo: $(cat "$LOG")"

it "link apontando para dentro de um dir do próprio recibo é removido"
(
  undo_env
  mkdir -p "$HOME/.local/kitty.app/bin" "$HOME/.local/bin"
  : >"$HOME/.local/kitty.app/bin/kitty"
  ln -s "$HOME/.local/kitty.app/bin/kitty" "$HOME/.local/bin/kitty"
  recibo kitty 'origin	installed' "dir	$HOME/.local/kitty.app" "link	$HOME/.local/bin/kitty"
  pn_receipt_undo kitty >/dev/null 2>&1
  [[ ! -L "$HOME/.local/bin/kitty" && ! -e "$HOME/.local/kitty.app" && ! -e "$R/kitty" ]]
) && pass || fail "link do kitty sobrou"

it "link de terceiros não é removido"
(
  undo_env
  mkdir -p "$HOME/.local/bin"
  ln -s /usr/bin/true "$HOME/.local/bin/x"
  recibo m 'origin	installed' "link	$HOME/.local/bin/x"
  pn_receipt_undo m >/dev/null 2>&1
  [[ -L "$HOME/.local/bin/x" ]]
) && pass || fail "removeu link de terceiros"

it "login_shell volta ao shell anterior e pede novo login"
(
  undo_env
  login_shell() { echo /usr/bin/zsh; }
  recibo zsh 'origin	installed' 'login_shell	/bin/bash'
  pn_receipt_undo zsh >/dev/null 2>&1
  [[ "$(cat "$LOG")" == "sudo chsh -s /bin/bash $(id -un)" ]] && grep -q 'próximo login' "$POWERTERMINAL_NOTES_FILE"
) && pass || fail "chsh errado: $(cat "$LOG")"

it "login_shell fora de /etc/shells é recusado"
(
  undo_env
  login_shell() { echo /usr/bin/zsh; }
  recibo zsh 'origin	installed' 'login_shell	/bin/false-pn'
  rc=0; pn_receipt_undo zsh >/dev/null 2>&1 || rc=$?
  [[ "$rc" -ne 0 && ! -s "$LOG" ]] && pn_receipt_has zsh
) && pass || fail "chsh para shell inválido"

it "login_shell que falhou impede a purga do apt"
(
  undo_env
  login_shell() { echo /usr/bin/zsh; }
  recibo zsh 'origin	installed' 'apt	zsh' 'login_shell	/bin/false-pn'
  pn_receipt_undo zsh >/dev/null 2>&1 || true
  ! grep -q purge "$LOG" && [[ "$(pn_receipt_entries zsh apt)" == $'apt\tzsh' ]]
) && pass || fail "purgou o shell de login"

it "group, pipx, subids, user_unit e apt_repo chamam o comando certo"
(
  undo_env
  run() { printf '%s\n' "$*" >>"$LOG"; }
  apt_update_once() { printf 'apt-get update\n' >>"$LOG"; }
  _pn_user_in_group() { return 0; }
  pipx() { [[ "$1" == list ]] && echo "notion-t 0.1.0"; return 0; }
  systemctl() { return 0; }
  _PN_SUBID_RANGE_START=100000 _PN_SUBID_RANGE_END=165535
  u="$(id -un)"
  recibo container 'origin	installed' 'apt_repo	docker' 'group	docker' "subids	$u" 'user_unit	podman.socket' 'pipx	notion-t'
  pn_receipt_undo container >/dev/null 2>&1
  [[ "$(cat "$LOG")" == "pipx uninstall notion-t
systemctl --user disable --now podman.socket
sudo usermod --del-subuids 100000-165535 --del-subgids 100000-165535 $u
sudo gpasswd -d $u docker
sudo rm -f /etc/apt/keyrings/docker.asc /etc/apt/sources.list.d/docker.list
apt-get update
rm -f $R/container" ]]
) && pass || fail "comandos: $(cat "$LOG")"

it "pipx fora do PATH conta como desfeito"
(
  undo_env
  has_cmd() { [[ "$1" != pipx ]] && command -v "$1" >/dev/null 2>&1; }
  run() { printf '%s\n' "$*" >>"$LOG"; }
  recibo m 'origin	installed' 'pipx	notion-t'
  pn_receipt_undo m >/dev/null 2>&1 && ! grep -q pipx "$LOG"
) && pass || fail "$(cat "$LOG")"

it "user_unit sem unidade conta como desfeito"
(
  undo_env
  export PATH="$SHIMS:$PATH"
  echo 1 >"$TMP/unit-rc"
  recibo m 'origin	installed' 'user_unit	podman.socket'
  pn_receipt_undo m >/dev/null 2>&1 && [[ ! -e "$R/m" ]] && ! grep -q disable "$LOG"
) && pass || fail "$(cat "$LOG")"

it "user_unit existente é desabilitada"
(
  undo_env
  export PATH="$SHIMS:$PATH"
  echo 0 >"$TMP/unit-rc"
  recibo m 'origin	installed' 'user_unit	podman.socket'
  pn_receipt_undo m >/dev/null 2>&1 && grep -qx 'systemctl --user disable --now podman.socket' "$LOG"
) && pass || fail "$(cat "$LOG")"

it "valores com cara de opção ou caminho são recusados"
(
  undo_env
  run() { printf '%s\n' "$*" >>"$LOG"; }
  recibo m 'origin	installed' 'apt_repo	../../etc/passwd' 'apt	--allow-remove-essential' 'pipx	-v' 'user_unit	--all' 'group	-x'
  rc=0; pn_receipt_undo m >/dev/null 2>&1 || rc=$?
  [[ "$rc" -ne 0 && ! -s "$LOG" ]] && [[ "$(pn_receipt_entries m | wc -l)" -eq 5 ]]
) && pass || fail "valor perigoso executado: $(cat "$LOG")"

it "grupo de administração e subids de outro usuário são recusados"
(
  undo_env
  _pn_user_in_group() { return 0; }
  _PN_SUBID_RANGE_START=100000 _PN_SUBID_RANGE_END=165535
  recibo m 'origin	installed' 'group	sudo' 'group	adm' 'subids	outro-usuario-pn'
  rc=0; pn_receipt_undo m >/dev/null 2>&1 || rc=$?
  [[ "$rc" -ne 0 && ! -s "$LOG" && "$(pn_receipt_entries m | wc -l)" -eq 3 ]]
) && pass || fail "mexeu em grupo de admin ou em outro usuário: $(cat "$LOG")"

it "subids sem o intervalo definido fica no recibo"
(
  undo_env
  unset _PN_SUBID_RANGE_START _PN_SUBID_RANGE_END
  recibo m 'origin	installed' "subids	$(id -un)"
  rc=0; pn_receipt_undo m >/dev/null 2>&1 || rc=$?
  [[ "$rc" -ne 0 && ! -s "$LOG" ]] && pn_receipt_has m
) && pass || fail "usermod sem intervalo"

it "dry-run do undo não apaga nem reescreve o recibo"
(
  undo_env
  DRY_RUN=1
  mkdir -p "$HOME/.legit"
  recibo m 'origin	installed' "dir	$HOME/.legit" 'dir	/'
  pn_receipt_undo m >/dev/null 2>&1 || true
  [[ -d "$HOME/.legit" && "$(pn_receipt_entries m | wc -l)" -eq 2 ]]
) && pass || fail "dry-run mexeu em algo"

it "sem recibo, pn_receipt_undo avisa e retorna 0"
(
  undo_env
  out="$(pn_receipt_undo nada 2>&1)" && [[ "$out" == *"Nada do PowerTerminal para desfazer em nada."* ]]
) && pass || fail "sem recibo deveria ser no-op"

test_summary
