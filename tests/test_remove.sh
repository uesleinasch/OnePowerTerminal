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
# A purga via sudo marca os pacotes como ausentes para o dpkg falso, que passa a
# responder como um dpkg depois do apt-get purge.
mkshim sudo "case \"\${1:-}\" in
  -n) exit 1 ;;
  chsh) [[ -f '$TMP/chsh-falha' ]] && exit 1 ;;
  debconf-set-selections) cat >>'$TMP/debconf' ;;
  rm) [[ -f '$TMP/rm-falha' && \"\$*\" == */var/lib/* ]] && exit 1 ;;
  env) [[ \"\${4:-}\" == purge ]] && { shift 5; printf '%s\n' \"\$@\" >>'$TMP/dpkg-ausentes'; } ;;
esac
exit 0"
for c in chsh gpasswd usermod; do mkshim "$c"; done
# apt-get -s X responde com o conteúdo de $TMP/sim-X (simulação da purga, do autoremove).
mkshim apt-get "[[ \"\${1:-}\" == -s ]] && cat \"$TMP/sim-\${2:-}\" 2>/dev/null; exit 0"
mkshim dpkg "[[ \"\${1:-}\" == -s ]] && grep -qxF -- \"\${2:-}\" '$TMP/dpkg-ausentes' 2>/dev/null && exit 1; exit 0"
mkshim pipx "[[ \"\${1:-}\" == list ]] && cat '$TMP/pipx-list' 2>/dev/null; exit 0"
mkshim systemctl "[[ \"\${2:-}\" == cat ]] && exit \"\$(cat '$TMP/unit-rc' 2>/dev/null || echo 0)\"; exit 0"

# apt-get dos testes que sourceiam as funções: só simula, sem log (o LOG guarda o que o as_sudo faria).
APTSIM="$TMP/aptsim"
mkdir -p "$APTSIM"
cat >"$APTSIM/apt-get" <<EOF
#!/usr/bin/env bash
[[ "\${1:-}" == -s ]] && cat "$TMP/sim-\${2:-}" 2>/dev/null
exit 0
EOF
chmod +x "$APTSIM/apt-get"

# getent falso só para o shell de login (sem log: não polui as asserções do LOG).
GETENT_REAL="$(command -v getent)"
# Sem chave (enumeração) lista o usuário atual e as contas de $TMP/outros-passwd.
cat >"$SHIMS/getent" <<EOF
#!/usr/bin/env bash
if [[ "\${1:-}" == passwd && -z "\${2:-}" ]]; then
  printf '%s:x:1000:1000::%s:%s\n' "\$(id -un)" '$TMP/home' "\$(cat '$TMP/login-shell' 2>/dev/null || echo /bin/bash)"
  cat '$TMP/outros-passwd' 2>/dev/null
  exit 0
fi
if [[ "\${1:-}" == passwd && -f '$TMP/login-shell' ]]; then
  printf '%s:x:1000:1000::%s:%s\n' "\$(id -un)" '$TMP/home' "\$(cat '$TMP/login-shell')"
  exit 0
fi
exec '$GETENT_REAL' "\$@"
EOF
chmod +x "$SHIMS/getent"

reset() {
  command rm -rf "$TMP/home" "$TMP/state" "$TMP/outside" "$LOG" "$TMP/pipx-list" "$TMP/unit-rc" "$TMP/tmpdir" \
    "$TMP/login-shell" "$TMP/debconf" "$TMP/chsh-falha" "$SHIMS/code" "$SHIMS/podman" \
    "$TMP/rm-falha" "$TMP/dpkg-ausentes" "$TMP/docker-ativo-rc" "$TMP/sim-purge" "$TMP/sim-autoremove" \
    "$TMP/outros-passwd" "$TMP/out"
  mkdir -p "$TMP/home" "$TMP/state" "$TMP/outside"
  : >"$LOG"
}

NORUN="$TMP/norun"
mkdir -p "$NORUN"
for c in docker podman; do printf '#!/bin/sh\nexit 1\n' >"$NORUN/$c"; chmod +x "$NORUN/$c"; done

pt() {
  PATH="$SHIMS:$NORUN:$PATH" HOME="$TMP/home" XDG_STATE_HOME="$TMP/state" \
    POWERTERMINAL_UI=text POWERTERMINAL_NONINTERACTIVE="${PT_NONINT:-0}" "$REPO/bin/powerterminal" "$@"
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
assert_eq "" "$(find "$TMP/tmpdir" -mindepth 1 -maxdepth 1 ! -name 'powerterminal-notes*' ! -name 'powerterminal-answers*' -printf '%f\n')"

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
  export PATH="$APTSIM:$PATH"
  getent() {
    if [[ "${1:-}" == passwd && -z "${2:-}" ]]; then cat "$TMP/outros-passwd" 2>/dev/null; return 0; fi
    command getent "$@"
  }
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

it "depois da purga, órfãos geram aviso e nunca um autoremove de verdade"
(
  undo_env
  recibo m 'origin	installed' 'apt	podman'
  printf 'NOTE: This is only a simulation!\nRemv libpn-orfa [1.0]\n' >"$TMP/sim-autoremove"
  pn_receipt_undo m >"$TMP/out" 2>&1
  grep -q 'apt-get purge -y podman' "$LOG" && ! grep -q autoremove "$LOG"
) && pass || fail "$(cat "$LOG")"
it "o aviso nomeia os órfãos e sugere sudo apt autoremove"
out="$(cat "$TMP/out")"
[[ "$out" == *libpn-orfa* && "$out" == *"sudo apt autoremove"* ]] && pass || fail "$out"

it "sem órfãos não há aviso de autoremove"
( undo_env; recibo m 'origin	installed' 'apt	podman'; pn_receipt_undo m 2>&1 | grep -q autoremove && exit 1; exit 0 ) \
  && pass || fail "aviso sem órfãos"

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

recusa() { [[ -n "$(_pn_undo_path_motivo "$(_pn_norm_path "$1")" "/home/user")" ]]; }
for p in / /home/user /home/user/ /home/user/. /home/user/./x /home/user/a/../b /home/user/.. /opt /opt/ /usr/local \
  /usr/local/bin /usr/local/share /etc /etc/passwd /usr/bin/x relativo/x '' /home/user/.config \
  /home/user/.local /home/user/.local/bin /home/user/.local/share/ /home/user/.ssh /home/user/.cache /home/username/x \
  /home/user/.local/share/fonts /home/user/.local/share/applications/ /home/user/.config/systemd/user \
  ; do
  it "guard recusa '$p'"
  assert_ok recusa "$p"
done

it "guard recusa o repositório e o que o contém, mesmo sob o HOME"
(
  POWERTERMINAL_HOME=/home/user/src/PowerTerminal
  for p in /home/user/src/PowerTerminal /home/user/src/PowerTerminal/home /home/user/src; do
    [[ -n "$(_pn_undo_path_motivo "$p" "/home/user")" ]] || exit 1
  done
  [[ -z "$(_pn_undo_path_motivo /home/user/src2 /home/user)" ]]
) && pass || fail "repositório não protegido"
for p in /home/user/.nvm /home/user/n /home/user/.local/kitty.app /home/user/.local/bin/uv \
  /home/user/.local/share/fonts/x.ttf /opt/nvim-linux-x86_64 /usr/local/bin/nvim; do
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

# ---- zsh, vscode e container -------------------------------------------------

U="$(id -un)"
linha_de() { grep -nF -- "$1" "$LOG" | head -1 | cut -d: -f1; }

it "remove de vscode preexisting não chama apt-get"
reset
mkshim code 'echo 1.99.0'
out="$(pt remove --module vscode --yes 2>&1)" && rc=0 || rc=$?
[[ "$rc" -eq 0 ]] && ! grep -q apt-get "$LOG" && [[ ! -e "$TMP/debconf" ]] && pass || fail "rc=$rc $(cat "$LOG")"
it "e diz que não há nada do PowerTerminal"
assert_contains "$out" "Nada do PowerTerminal"

it "remove de vscode purga o code e apaga o repositório"
reset
recibo vscode 'origin	installed' 'apt_repo	vscode' 'apt	code'
pt remove --module vscode --yes >/dev/null 2>&1 || true
grep -qxF 'sudo env DEBIAN_FRONTEND=noninteractive apt-get purge -y code' "$LOG" \
  && grep -qxF 'sudo rm -f /etc/apt/keyrings/vscode.asc /etc/apt/sources.list.d/vscode.list' "$LOG" \
  && [[ ! -e "$R/vscode" ]] && pass || fail "$(cat "$LOG")"
it "e repõe a resposta padrão do debconf depois da purga"
assert_eq "code code/add-microsoft-repo boolean true" "$(cat "$TMP/debconf" 2>/dev/null)"
it "o debconf vem depois do apt-get purge"
[[ "$(linha_de 'apt-get purge')" -lt "$(linha_de 'sudo debconf-set-selections')" ]] && pass || fail "$(cat "$LOG")"

it "vscode sem apt code no recibo não mexe no debconf"
reset
recibo vscode 'origin	installed' 'apt_repo	vscode'
pt remove --module vscode --yes >/dev/null 2>&1 || true
[[ ! -e "$TMP/debconf" && ! -e "$R/vscode" ]] && pass || fail "$(cat "$LOG")"

it "purga que levaria junto um pacote fora do recibo não roda"
reset
recibo vscode 'origin	installed' 'apt	code'
printf 'NOTE: This is only a simulation!\nPurg code [1.99]\nRemv code-helper-pn [2.0]\n' >"$TMP/sim-purge"
out="$(pt remove --module vscode --yes 2>&1)" && rc=0 || rc=$?
[[ "$rc" -ne 0 ]] && ! grep -q 'apt-get purge -y' "$LOG" && grep -qxF $'apt\tcode' "$R/vscode" \
  && pass || fail "rc=$rc $(cat "$LOG")"
it "o aviso nomeia o pacote que sairia junto"
assert_contains "$out" "code-helper-pn"
it "a simulação da purga roda sem sudo"
grep -qxF 'apt-get -s purge code' "$LOG" && ! grep -q '^sudo.* -s purge' "$LOG" && pass || fail "$(cat "$LOG")"
it "purga cuja simulação só tira os pacotes do recibo roda"
reset
recibo vscode 'origin	installed' 'apt	code'
printf 'Purg code [1.99]\n' >"$TMP/sim-purge"
pt remove --module vscode --yes >/dev/null 2>&1 || true
grep -qxF 'sudo env DEBIAN_FRONTEND=noninteractive apt-get purge -y code' "$LOG" && [[ ! -e "$R/vscode" ]] \
  && pass || fail "$(cat "$LOG")"

it "remove de zsh volta o shell de login do recibo"
reset
echo /usr/bin/zsh >"$TMP/login-shell"
recibo zsh 'origin	installed' 'apt	zsh' 'login_shell	/bin/bash'
out="$(pt remove --module zsh --yes 2>&1)" || true
grep -qxF "sudo chsh -s /bin/bash $U" "$LOG" && pass || fail "$(cat "$LOG") $out"
it "o chsh vem antes da purga do zsh"
[[ "$(linha_de 'sudo chsh')" -lt "$(linha_de 'apt-get purge')" ]] && pass || fail "$(cat "$LOG")"
it "e pede um login novo"
assert_contains "$out" "próximo login"

it "zsh sem login_shell no recibo, com apt zsh e shell zsh, volta para /bin/bash"
reset
echo /usr/bin/zsh >"$TMP/login-shell"
recibo zsh 'origin	installed' 'apt	zsh'
out="$(pt remove --module zsh --yes 2>&1)" || true
grep -qxF "sudo chsh -s /bin/bash $U" "$LOG" && [[ "$(linha_de 'sudo chsh')" -lt "$(linha_de 'apt-get purge')" ]] \
  && [[ "$out" == *"login novo"* && ! -e "$R/zsh" ]] && pass || fail "$(cat "$LOG") $out"

it "zsh sem login_shell e sem apt zsh não troca o shell de login"
reset
echo /usr/bin/zsh >"$TMP/login-shell"
mkdir -p "$TMP/home/.oh-my-zsh"
recibo zsh 'origin	installed' "dir	$TMP/home/.oh-my-zsh"
pt remove --module zsh --yes >/dev/null 2>&1 || true
! grep -q chsh "$LOG" && [[ ! -e "$TMP/home/.oh-my-zsh" ]] && pass || fail "$(cat "$LOG")"

it "zsh com shell bash e sem login_shell não roda chsh"
reset
echo /bin/bash >"$TMP/login-shell"
recibo zsh 'origin	installed' 'apt	zsh'
pt remove --module zsh --yes >/dev/null 2>&1 || true
! grep -q chsh "$LOG" && grep -q 'apt-get purge -y zsh' "$LOG" && pass || fail "$(cat "$LOG")"

it "chsh de volta que falha não remove nada do zsh"
reset
echo /usr/bin/zsh >"$TMP/login-shell"
: >"$TMP/chsh-falha"
mkdir -p "$TMP/home/.oh-my-zsh"
recibo zsh 'origin	installed' 'apt	zsh' "dir	$TMP/home/.oh-my-zsh"
pt remove --module zsh --yes >/dev/null 2>&1 && rc=0 || rc=$?
[[ "$rc" -ne 0 && -d "$TMP/home/.oh-my-zsh" ]] && ! grep -q purge "$LOG" \
  && [[ "$(wc -l <"$R/zsh")" -eq 3 ]] && pass || fail "rc=$rc $(cat "$LOG")"

it "zsh não é purgado quando outra conta usa zsh como shell de login"
reset
echo /bin/bash >"$TMP/login-shell"
printf 'outra-pn:x:1001:1001::/home/dev/outra:/usr/bin/zsh\n' >"$TMP/outros-passwd"
recibo zsh 'origin	installed' 'apt	zsh'
out="$(pt remove --module zsh --yes 2>&1)" && rc=0 || rc=$?
[[ "$rc" -ne 0 ]] && ! grep -q 'apt-get purge' "$LOG" && grep -qxF $'apt\tzsh' "$R/zsh" && pass || fail "rc=$rc $(cat "$LOG")"
it "o aviso nomeia a conta que usa o zsh"
assert_contains "$out" "outra-pn"
it "e o shell do usuário atual não volta para o bash à toa"
reset
echo /usr/bin/zsh >"$TMP/login-shell"
printf 'outra-pn:x:1001:1001::/home/dev/outra:/bin/zsh\n' >"$TMP/outros-passwd"
recibo zsh 'origin	installed' 'apt	zsh'
pt remove --module zsh --yes >/dev/null 2>&1 || true
! grep -q chsh "$LOG" && ! grep -q 'apt-get purge' "$LOG" && pass || fail "$(cat "$LOG")"
it "conta com outro shell não segura o zsh"
reset
echo /bin/bash >"$TMP/login-shell"
printf 'outra-pn:x:1001:1001::/home/dev/outra:/bin/bash\n' >"$TMP/outros-passwd"
recibo zsh 'origin	installed' 'apt	zsh'
pt remove --module zsh --yes >/dev/null 2>&1 || true
grep -q 'apt-get purge -y zsh' "$LOG" && [[ ! -e "$R/zsh" ]] && pass || fail "$(cat "$LOG")"

it "remove do theme não cria current-theme.conf num ~/.config/kitty que não é do PowerTerminal"
reset
mkdir -p "$TMP/home/.config/kitty" "$TMP/home/.claude"
printf '{\n  "theme": "light"\n}\n' >"$TMP/home/.claude/settings.json"
recibo theme 'origin	installed' "link	$TMP/home/.config/powerterminal"
pt remove --module theme --yes >/dev/null 2>&1 || true
[[ ! -e "$TMP/home/.config/kitty/current-theme.conf" && ! -e "$R/theme" ]] && pass || fail "$(ls -la "$TMP/home/.config/kitty")"
it "nem cria o diretório de estado do tema"
[[ ! -e "$TMP/home/.config/powerterminal" ]] && pass || fail "$(ls -la "$TMP/home/.config")"
it "e não reescreve o ~/.claude/settings.json"
assert_eq $'{\n  "theme": "light"\n}' "$(cat "$TMP/home/.claude/settings.json")"

it "remove do theme repõe mocha no estado e no include que são do PowerTerminal"
(
  undo_env
  FAKE="$TMP/outside/repo"
  mkdir -p "$FAKE/home/.config/powerterminal" "$FAKE/home/.config/kitty" "$HOME/.config"
  echo latte >"$FAKE/home/.config/powerterminal/theme"
  ln -s "$FAKE/home/.config/powerterminal" "$HOME/.config/powerterminal"
  ln -s "$FAKE/home/.config/kitty" "$HOME/.config/kitty"
  POWERTERMINAL_HOME="$FAKE"
  source "$REPO/lib/modules/theme.sh"
  recibo theme 'origin	installed' "link	$HOME/.config/powerterminal"
  mod_theme_remove >/dev/null 2>&1
  [[ "$(cat "$FAKE/home/.config/powerterminal/theme")" == mocha && ! -L "$HOME/.config/powerterminal" ]] \
    && grep -qx 'include themes/mocha.conf' "$FAKE/home/.config/kitty/current-theme.conf"
) && pass || fail "estado ou include não voltaram ao mocha"

it "--purge-data só vale para container"
reset
recibo zsh 'origin	installed' "dir	$TMP/home/.oh-my-zsh"
out="$(pt remove --module zsh --purge-data --yes 2>&1)" && rc=0 || rc=$?
[[ "$rc" -ne 0 && "$out" == *"--purge-data só vale com --module container"* && ! -s "$LOG" && -f "$R/zsh" ]] \
  && pass || fail "rc=$rc $out"

DOCKER_RECIBO=('origin	installed' 'apt_repo	docker' 'apt	docker-ce' 'apt	containerd.io' 'group	docker')

it "container sem --purge-data não apaga /var/lib/docker"
reset
recibo container "${DOCKER_RECIBO[@]}"
pt remove --module container --yes >/dev/null 2>&1 || true
grep -q 'apt-get purge -y' "$LOG" && ! grep -q '/var/lib/docker\|/var/lib/containerd' "$LOG" \
  && [[ ! -e "$R/container" ]] && pass || fail "$(cat "$LOG")"

it "--purge-data com Docker apaga /var/lib/docker e /var/lib/containerd"
reset
recibo container "${DOCKER_RECIBO[@]}"
pt remove --module container --purge-data --yes >/dev/null 2>&1 || true
grep -qxF 'sudo rm -rf --one-file-system -- /var/lib/docker' "$LOG" \
  && grep -qxF 'sudo rm -rf --one-file-system -- /var/lib/containerd' "$LOG" && pass || fail "$(cat "$LOG")"
it "os dados do Docker saem depois dos pacotes (com o daemon parado)"
[[ "$(linha_de 'apt-get purge')" -lt "$(linha_de '/var/lib/docker')" ]] && pass || fail "$(cat "$LOG")"

it "recibo só com docker-ce não apaga /var/lib/containerd"
reset
recibo container 'origin	installed' 'apt	docker-ce'
pt remove --module container --purge-data --yes >/dev/null 2>&1 || true
grep -qxF 'sudo rm -rf --one-file-system -- /var/lib/docker' "$LOG" && ! grep -q '/var/lib/containerd' "$LOG" \
  && pass || fail "$(cat "$LOG")"

it "containerd.io mantido por outro recibo continua instalado e /var/lib/containerd fica"
reset
recibo outro 'origin	installed' 'apt	containerd.io'
recibo container "${DOCKER_RECIBO[@]}"
out="$(pt remove --module container --purge-data --yes 2>&1)" && rc=0 || rc=$?
grep -qxF 'sudo rm -rf --one-file-system -- /var/lib/docker' "$LOG" && ! grep -q '/var/lib/containerd' "$LOG" \
  && [[ "$out" == *"containerd.io continua instalado"* ]] && pass || fail "rc=$rc $(cat "$LOG") $out"

it "docker-ce que a purga não tirou mantém /var/lib/docker"
reset
recibo container 'origin	installed' 'apt	docker-ce'
cat >"$SHIMS/dpkg" <<EOF
#!/usr/bin/env bash
printf '%s\n' "dpkg \$*" >>"$LOG"
exit 0
EOF
out="$(pt remove --module container --purge-data --yes 2>&1)" && rc=0 || rc=$?
mkshim dpkg "[[ \"\${1:-}\" == -s ]] && grep -qxF -- \"\${2:-}\" '$TMP/dpkg-ausentes' 2>/dev/null && exit 1; exit 0"
[[ "$rc" -ne 0 && "$out" == *"docker-ce continua instalado"* ]] && ! grep -q '/var/lib/docker' "$LOG" \
  && pass || fail "rc=$rc $(cat "$LOG") $out"

it "dpkg com erro depois da purga mantém /var/lib/docker"
reset
recibo container 'origin	installed' 'apt	docker-ce'
mkshim dpkg "[[ \"\${1:-}\" == -s ]] && grep -qxF -- \"\${2:-}\" '$TMP/dpkg-ausentes' 2>/dev/null && exit 2; exit 0"
out="$(pt remove --module container --purge-data --yes 2>&1)" && rc=0 || rc=$?
mkshim dpkg "[[ \"\${1:-}\" == -s ]] && grep -qxF -- \"\${2:-}\" '$TMP/dpkg-ausentes' 2>/dev/null && exit 1; exit 0"
grep -q 'apt-get purge -y docker-ce' "$LOG" && ! grep -q '/var/lib/docker' "$LOG" && pass || fail "rc=$rc $(cat "$LOG")"

it "Status de outra linha do dpkg não engana a checagem de instalado"
reset
recibo container 'origin	installed' 'apt	docker-ce'
mkshim dpkg "printf 'Status: install ok installed\nDescription: x\n Status: deinstall ok config-files\n'; exit 0"
out="$(pt remove --module container --purge-data --yes 2>&1)" && rc=0 || rc=$?
mkshim dpkg "[[ \"\${1:-}\" == -s ]] && grep -qxF -- \"\${2:-}\" '$TMP/dpkg-ausentes' 2>/dev/null && exit 1; exit 0"
! grep -q '/var/lib/docker' "$LOG" && [[ "$out" == *"docker-ce continua instalado"* ]] && pass || fail "rc=$rc $(cat "$LOG")"

it "rm dos dados que falha deixa o comando manual nas tarefas"
reset
: >"$TMP/rm-falha"
recibo container "${DOCKER_RECIBO[@]}"
out="$(pt remove --module container --purge-data --yes 2>&1)" && rc=0 || rc=$?
[[ "$rc" -ne 0 && "$out" == *"sudo rm -rf --one-file-system -- /var/lib/docker /var/lib/containerd"* ]] \
  && pass || fail "rc=$rc $out"

it "POWERTERMINAL_NONINTERACTIVE=1 sem --yes não pula a confirmação do purge"
reset
recibo container "${DOCKER_RECIBO[@]}"
out="$(PT_NONINT=1 pt remove --module container --purge-data </dev/null 2>&1)" || true
[[ "$out" == *"Apagar imagens, containers e volumes? Não dá para desfazer."* && "$out" == *Cancelado* ]] \
  && ! grep -q '/var/lib\|purge' "$LOG" && [[ -f "$R/container" ]] && pass || fail "$(cat "$LOG") $out"

it "--purge-data sem --yes pede confirmação"
reset
recibo container "${DOCKER_RECIBO[@]}"
out="$(printf 'y\nn\n' | pt remove --module container --purge-data 2>&1)" || true
assert_contains "$out" "Apagar imagens, containers e volumes? Não dá para desfazer."
it "recusar a segunda confirmação cancela sem mexer em nada"
[[ "$out" == *Cancelado* && ! -s "$LOG" && -f "$R/container" ]] && pass || fail "$(cat "$LOG") $out"

it "--purge-data sem Docker nem Podman no recibo não apaga dados"
reset
recibo container 'origin	installed' 'group	docker'
out="$(pt remove --module container --purge-data --yes 2>&1)" || true
! grep -q '/var/lib/docker\|system reset' "$LOG" && [[ "$out" == *"os dados ficam"* ]] && pass || fail "$(cat "$LOG") $out"

it "--purge-data com Podman roda podman system reset antes da purga"
reset
mkshim podman 'exit 0'
recibo container 'origin	installed' 'apt	podman' 'apt	uidmap'
pt remove --module container --purge-data --yes >/dev/null 2>&1 || true
grep -qxF 'podman system reset -f' "$LOG" && [[ "$(linha_de 'podman system reset')" -lt "$(linha_de 'apt-get purge')" ]] \
  && ! grep -q '/var/lib/docker' "$LOG" && pass || fail "$(cat "$LOG")"

it "podman system reset que falha não remove nada"
reset
mkshim podman 'exit 1'
recibo container 'origin	installed' 'apt	podman'
pt remove --module container --purge-data --yes >/dev/null 2>&1 && rc=0 || rc=$?
[[ "$rc" -ne 0 && -f "$R/container" ]] && ! grep -q purge "$LOG" && pass || fail "rc=$rc $(cat "$LOG")"

it "--purge-data em dry-run mostra o rm sem executar nada"
reset
recibo container "${DOCKER_RECIBO[@]}"
out="$(pt remove --module container --purge-data --dry-run --yes 2>&1)" || true
[[ "$out" == *"rm -rf --one-file-system -- /var/lib/docker"* && "$out" == *"rm -rf --one-file-system -- /var/lib/containerd"* \
  && -f "$R/container" ]] \
  && ! grep -v '^dpkg -s \|^apt-get -s ' "$LOG" | grep -q . \
  && pass || fail "$(cat "$LOG") $out"

# ---- mod_container_data_mb ---------------------------------------------------

DSHIMS="$TMP/dshims"
mkdir -p "$DSHIMS"
fake_runtime() {
  local nome="$1" versao="$2" df="$3"
  cat >"$DSHIMS/$nome" <<EOF
#!/usr/bin/env bash
printf '%s\n' "$nome \$*" >>"$LOG"
[[ "\${1:-}" == --version ]] && { echo "$versao"; exit 0; }
[[ "\${1:-} \${2:-}" == "system df" ]] && { $df; }
exit 0
EOF
  chmod +x "$DSHIMS/$nome"
}
data_mb() {
  cat >"$DSHIMS/systemctl" <<EOF
#!/usr/bin/env bash
printf '%s\n' "systemctl \$*" >>"$LOG"
[[ "\${1:-}" == is-active ]] && exit "\$(cat '$TMP/docker-ativo-rc' 2>/dev/null || echo 0)"
exit 0
EOF
  chmod +x "$DSHIMS/systemctl"
  (
    export PATH="$DSHIMS:$SHIMS:$PATH"
    source "$REPO/lib/modules/container.sh"
    mod_container_data_mb
  )
}

it "data_mb soma o docker system df em MB, sem o build cache"
reset; command rm -f "$DSHIMS"/*
fake_runtime docker "Docker version 24.0.7" \
  "printf 'Images\t1.5GB\nContainers\t230.4MB\nLocal Volumes\t0B\nBuild Cache\t12GB\nX\t12kB\n'; exit 0"
assert_eq 1730 "$(data_mb)"
it "data_mb nunca usa sudo"
assert_eq "" "$(grep '^sudo' "$LOG" || true)"
it "data_mb pede o formato com o tipo e o tamanho"
assert_contains "$(cat "$LOG")" "docker system df --format {{.Type}}\t{{.Size}}"
it "data_mb confere se o daemon do Docker já está no ar"
assert_contains "$(cat "$LOG")" "systemctl is-active --quiet docker.service"

it "data_mb com o daemon parado não imprime nada nem chama o docker system df"
reset; command rm -f "$DSHIMS"/*
fake_runtime docker "Docker version 24.0.7" "printf 'Images\t1GB\n'; exit 0"
echo 3 >"$TMP/docker-ativo-rc"
v="$(data_mb)"
[[ -z "$v" ]] && ! grep -q 'docker system df' "$LOG" && pass || fail "v=$v $(cat "$LOG")"

it "data_mb com docker system df falhando não imprime nada"
reset; command rm -f "$DSHIMS"/*
fake_runtime docker "Docker version 24.0.7" "echo 'permission denied' >&2; exit 1"
assert_eq "" "$(data_mb)"

it "data_mb com saída que não é tamanho não imprime nada"
reset; command rm -f "$DSHIMS"/*
fake_runtime docker "Docker version 24.0.7" "printf 'Images\t1.5GB\nlixo\n'; exit 0"
assert_eq "" "$(data_mb)"

it "data_mb usa o podman quando o docker é o shim do podman"
reset; command rm -f "$DSHIMS"/*
fake_runtime docker "podman version 4.6.2" "exit 1"
fake_runtime podman "podman version 4.6.2" "printf 'Images\t2GB\nContainers\t500MB\nLocal Volumes\t1TB\n'; exit 0"
echo 3 >"$TMP/docker-ativo-rc"
assert_eq 1002500 "$(data_mb)"

# ---- Recibo só do que o módulo criou -----------------------------------------

mod_env() {
  undo_env
  PN_RECEIPT_MODULE="$1"
  source "$REPO/lib/modules/container.sh"
  sudo_ready() { return 0; }
  as_sudo() { [[ "$1" != tee ]] || cat >/dev/null; printf 'sudo %s\n' "$*" >>"$LOG"; }
}

repo_novo() {
  mod_env vscode
  download_to() { :; }
  dpkg() { echo amd64; }
  apt_update_once() { :; }
  EXISTE_RC="$1"
  _pn_apt_repo_existe() { return "$EXISTE_RC"; }
  apt_add_repo vscode https://k https://r stable main >/dev/null 2>&1
}

repo_etc() {
  mod_env vscode
  download_to() { :; }
  dpkg() { echo amd64; }
  apt_update_once() { :; }
  _PN_APT_ETC="$TMP/etc-apt"
  command rm -rf "$_PN_APT_ETC"
  mkdir -p "$_PN_APT_ETC/sources.list.d" "$_PN_APT_ETC/keyrings"
  [[ -z "$1" ]] || : >"$_PN_APT_ETC/$1"
  apt_add_repo docker https://k https://r stable main >/dev/null 2>&1
}

it "repositório deb822 (.sources) já configurado não entra no recibo nem é reescrito"
( repo_etc sources.list.d/docker.sources; [[ -z "$(pn_receipt_entries vscode apt_repo)" ]] && ! grep -q 'install -m 0644\|tee' "$LOG" ) \
  && pass || fail "$(cat "$LOG") $(cat "$R/vscode" 2>/dev/null)"
it "keyring já existente conta como repositório preexistente"
( repo_etc keyrings/docker.asc; [[ -z "$(pn_receipt_entries vscode apt_repo)" ]] && ! grep -q 'install -m 0644\|tee' "$LOG" ) \
  && pass || fail "$(cat "$LOG") $(cat "$R/vscode" 2>/dev/null)"
it "lista .list já existente conta como repositório preexistente"
( repo_etc sources.list.d/docker.list; [[ -z "$(pn_receipt_entries vscode apt_repo)" ]] && ! grep -q 'tee' "$LOG" ) \
  && pass || fail "$(cat "$LOG")"
it "sem nenhum dos três arquivos o repositório é escrito e gravado"
( repo_etc ""; [[ "$(pn_receipt_entries vscode apt_repo)" == $'apt_repo\tdocker' ]] && grep -q 'tee' "$LOG" ) \
  && pass || fail "$(cat "$LOG")"
it "repositório que já é do PowerTerminal é reescrito (rotação de chave) sem duplicar o recibo"
( mod_env vscode; recibo vscode 'origin	installed' 'apt_repo	docker'; PN_RECEIPT_MODULE=vscode
  download_to() { :; }; dpkg() { echo amd64; }; apt_update_once() { :; }
  _PN_APT_ETC="$TMP/etc-apt"; command rm -rf "$_PN_APT_ETC"; mkdir -p "$_PN_APT_ETC/sources.list.d"
  : >"$_PN_APT_ETC/sources.list.d/docker.list"
  apt_add_repo docker https://k https://r stable main >/dev/null 2>&1
  grep -q 'tee' "$LOG" && [[ "$(pn_receipt_entries vscode apt_repo)" == $'apt_repo\tdocker' ]] ) \
  && pass || fail "$(cat "$LOG")"

it "apt_add_repo com a lista já existente não grava apt_repo"
( repo_novo 0; [[ -z "$(pn_receipt_entries vscode apt_repo)" ]] ) && pass || fail "$(cat "$R/vscode" 2>/dev/null)"
it "apt_add_repo sem lista prévia grava apt_repo"
( repo_novo 1; [[ "$(pn_receipt_entries vscode apt_repo)" == $'apt_repo\tvscode' ]] ) && pass || fail "recibo sem apt_repo"

grupo() {
  mod_env container
  GRUPOS="$U"
  [[ "$1" == sim ]] && GRUPOS="$U docker"
  id() { [[ "${1:-}" == -nG ]] && { echo "$GRUPOS"; return 0; }; command id "$@"; }
  getent() { return 0; }
  _vf_add_docker_group >/dev/null 2>&1
}

it "grupo docker em que o usuário já estava não entra no recibo"
( grupo sim; [[ -z "$(pn_receipt_entries container group)" && ! -s "$LOG" ]] ) && pass || fail "$(cat "$LOG")"
it "grupo docker novo entra no recibo"
( grupo nao; [[ "$(pn_receipt_entries container group)" == $'group\tdocker' ]] && grep -qxF "sudo usermod -aG docker $U" "$LOG" ) \
  && pass || fail "$(cat "$LOG")"

subid() {
  mod_env container
  _vf_tem_subid() { [[ "$1" == subuid ]] && return "$UID_RC"; return "$GID_RC"; }
  _vf_ensure_subid >/dev/null 2>&1
}

it "subids já configurados não entram no recibo"
( UID_RC=0 GID_RC=0; subid; [[ -z "$(pn_receipt_entries container subids)" && ! -s "$LOG" ]] ) && pass || fail "$(cat "$LOG")"
it "subuid preexistente: só acrescenta o subgid e não grava recibo"
( UID_RC=0 GID_RC=1; subid; [[ -z "$(pn_receipt_entries container subids)" ]] \
  && [[ "$(cat "$LOG")" == "sudo usermod --add-subgids 100000-165535 $U" ]] ) && pass || fail "$(cat "$LOG")"
it "subids novos entram no recibo"
( UID_RC=1 GID_RC=1; subid; [[ "$(pn_receipt_entries container subids)" == $'subids\t'"$U" ]] \
  && [[ "$(cat "$LOG")" == "sudo usermod --add-subuids 100000-165535 --add-subgids 100000-165535 $U" ]] ) && pass || fail "$(cat "$LOG")"

socket() {
  mod_env container
  _vf_tem_systemd() { return 0; }
  systemctl() { printf 'systemctl %s\n' "$*" >>"$LOG"; [[ "$2" == is-enabled ]] && return "$ENABLED_RC"; return 0; }
  _vf_enable_podman_socket >/dev/null 2>&1
}

ZSH_MOD="${ZSH_MOD:-$REPO/lib/modules/zsh.sh}"
omz() {
  undo_env
  PN_RECEIPT_MODULE=zsh
  # shellcheck source=/dev/null
  source "$ZSH_MOD"
  has_cmd() { [[ "$1" == zsh ]] || command -v "$1" >/dev/null 2>&1; }
  curl() { printf '%s\n' 'mkdir -p "$HOME/.oh-my-zsh"; [ -e "$HOME/.zshrc" ] || echo template >"$HOME/.zshrc"'; }
  clone_or_pull() { :; }
  _vf_set_default_shell() { :; }
  mod_zsh_install >/dev/null 2>&1
}

it "o ~/.zshrc de template do instalador do OMZ não vira .pnbak"
( omz; [[ -L "$HOME/.zshrc" ]] && ! compgen -G "$HOME/.zshrc.pnbak.*" >/dev/null ) && pass || fail "$(ls -la "$TMP/home")"

it "o ~/.zshrc que o usuário já tinha vira .pnbak"
( undo_env; printf 'meu\n' >"$HOME/.zshrc"
  PN_RECEIPT_MODULE=zsh
  # shellcheck source=/dev/null
  source "$ZSH_MOD"
  has_cmd() { [[ "$1" == zsh ]] || command -v "$1" >/dev/null 2>&1; }
  curl() { printf '%s\n' 'mkdir -p "$HOME/.oh-my-zsh"'; }
  clone_or_pull() { :; }; _vf_set_default_shell() { :; }
  mod_zsh_install >/dev/null 2>&1
  [[ -L "$HOME/.zshrc" && "$(cat "$HOME"/.zshrc.pnbak.*)" == meu ]] ) && pass || fail "$(ls -la "$TMP/home")"

it "podman.socket já habilitado não entra no recibo"
( ENABLED_RC=0; socket; [[ -z "$(pn_receipt_entries container user_unit)" ]] ) && pass || fail "$(cat "$LOG")"
it "podman.socket novo entra no recibo"
( ENABLED_RC=1; socket; [[ "$(pn_receipt_entries container user_unit)" == $'user_unit\tpodman.socket' ]] ) && pass || fail "$(cat "$LOG")"

test_summary
