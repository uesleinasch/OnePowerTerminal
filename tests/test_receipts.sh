#!/usr/bin/env bash
set -euo pipefail
source "${POWERTERMINAL_HOME}/tests/lib.sh"
source "${POWERTERMINAL_HOME}/lib/core.sh"
source "${POWERTERMINAL_HOME}/lib/receipt.sh"

REPO_REAL="$POWERTERMINAL_HOME"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
export HOME="$TMP/home" XDG_STATE_HOME="$TMP/state"
mkdir -p "$HOME" "$TMP/repo/home"
: >"$TMP/repo/home/.zshrc"
export POWERTERMINAL_HOME="$TMP/repo"
DRY_RUN=0
require_supported_distro() { :; }
log_info() { :; }

reset() { rm -rf "$XDG_STATE_HOME" "$HOME/.zshrc"; DRY_RUN=0; }

it "fora de um módulo, pn_receipt_add não grava"
reset
PN_RECEIPT_MODULE= pn_receipt_add file /x
assert_fail pn_receipt_has zsh

it "a primeira entrada cria o recibo com origin installed"
reset
PN_RECEIPT_MODULE=zsh pn_receipt_add file /x
assert_eq installed "$(pn_receipt_origin zsh)"

it "entrada repetida não duplica"
reset
PN_RECEIPT_MODULE=zsh pn_receipt_add file /x
PN_RECEIPT_MODULE=zsh pn_receipt_add file /x
assert_eq 1 "$(pn_receipt_entries zsh file | wc -l)"

it "dry-run não grava recibo"
reset
DRY_RUN=1 PN_RECEIPT_MODULE=zsh pn_receipt_add file /x
assert_fail pn_receipt_has zsh

it "link_safe grava a entrada link"
reset
PN_RECEIPT_MODULE=zsh link_safe "$POWERTERMINAL_HOME/home/.zshrc" "$HOME/.zshrc"
assert_contains "$(pn_receipt_entries zsh link)" "$HOME/.zshrc"

it "link_safe sobre link já correto também grava"
reset
ln -s "$POWERTERMINAL_HOME/home/.zshrc" "$HOME/.zshrc"
PN_RECEIPT_MODULE=zsh link_safe "$POWERTERMINAL_HOME/home/.zshrc" "$HOME/.zshrc"
assert_contains "$(pn_receipt_entries zsh link)" "$HOME/.zshrc"

it "apt_install grava só o pacote que não estava instalado"
reset
(
  dpkg() { [[ "$2" == "jq" ]]; }
  as_sudo() { return 0; }
  PN_RECEIPT_MODULE=tools apt_install jq tree
  [[ "$(pn_receipt_entries tools apt)" == $'apt\ttree' ]]
) && pass || fail "recibo esperado apenas com tree"

it "apt_install que falha não grava nada"
reset
(
  dpkg() { return 1; }
  as_sudo() { return 1; }
  PN_RECEIPT_MODULE=tools apt_install tree || true
)
assert_fail pn_receipt_has tools

it "ensure_curl não grava curl no recibo do módulo"
reset
(
  has_cmd() { [[ "$1" != "curl" ]]; }
  dpkg() { return 1; }
  as_sudo() { return 0; }
  PN_RECEIPT_MODULE=tools ensure_curl
)
assert_fail pn_receipt_has tools

it "apt_add_repo grava apt_repo com o nome"
reset
(
  dpkg() { echo amd64; }
  download_to() { : >"$2"; }
  as_sudo() { cat >/dev/null 2>&1 || true; return 0; }
  apt_update_once() { :; }
  PN_RECEIPT_MODULE=vscode apt_add_repo vscode http://k http://r stable main </dev/null
  [[ "$(pn_receipt_entries vscode apt_repo)" == $'apt_repo\tvscode' ]]
) && pass || fail "apt_repo vscode ausente"

it "zsh grava o shell de login anterior antes do chsh"
reset
(
  source "$REPO_REAL/lib/modules/zsh.sh"
  has_cmd() { return 0; }
  login_shell() { echo /bin/bash; }
  sudo_ready() { return 0; }
  as_sudo() { return 0; }
  post_install_note() { :; }
  log_success() { :; }
  PN_RECEIPT_MODULE=zsh _vf_set_default_shell
  [[ "$(pn_receipt_entries zsh login_shell)" == $'login_shell\t/bin/bash' ]]
) && pass || fail "login_shell /bin/bash ausente"

it "helpers instalado em HOME temporario fica installed"
reset
mkdir -p "$TMP/repo/bin-helpers"
for h in myastro mykitty myyazi; do : >"$TMP/repo/bin-helpers/$h"; chmod +x "$TMP/repo/bin-helpers/$h"; done
(
  source "$REPO_REAL/lib/modules/helpers.sh"
  PN_RECEIPT_MODULE=helpers mod_helpers_install
  mod_helpers_installed
) && pass || fail "helpers não ficou installed"

it "kitty não grava no recibo um .desktop que já existia"
reset
mkdir -p "$TMP/kapp/share/applications" "$HOME/.local/share/applications"
: >"$TMP/kapp/share/applications/kitty.desktop"
: >"$TMP/kapp/share/applications/kitty-open.desktop"
: >"$HOME/.local/share/applications/kitty.desktop"
(
  source "$REPO_REAL/lib/modules/kitty.sh"
  _PN_KITTY_DIR="$TMP/kapp"
  PN_RECEIPT_MODULE=kitty _vf_install_kitty_desktop
  [[ "$(pn_receipt_entries kitty file)" == $'file\t'"$HOME/.local/share/applications/kitty-open.desktop" ]]
) && pass || fail "recibo deveria conter só o .desktop novo"

mig_setup() {
  reset
  rm -rf "$TMP/outside" "$HOME/.oh-my-zsh" "$HOME/.local" "$HOME/.nvm" "$HOME/n"
  mkdir -p "$TMP/repo/home" "$TMP/outside"
  : >"$TMP/repo/home/.p10k.zsh"; : >"$TMP/outside/zshrc"
  _PN_ALL_MODULES=(zsh kitty node)
  source "$REPO_REAL/lib/modules/zsh.sh"
  source "$REPO_REAL/lib/modules/kitty.sh"
  source "$REPO_REAL/lib/modules/node.sh"
  mod_zsh_installed() { return 0; }
  mod_kitty_installed() { return 0; }
  mod_node_installed() { return 0; }
}

it "migração deduz links que apontam para o repo"
(
  mig_setup
  ln -s "$TMP/repo/home/.zshrc" "$HOME/.zshrc"
  pn_receipts_migrate
  [[ "$(pn_receipt_origin zsh)" == deduced ]] \
    && [[ "$(pn_receipt_entries zsh link)" == $'link\t'"$HOME/.zshrc" ]]
) && pass || fail "recibo deduzido ausente"

it "link que aponta para fora do repo não é deduzido"
(
  mig_setup
  ln -s "$TMP/outside/zshrc" "$HOME/.zshrc"
  pn_receipts_migrate
  ! pn_receipt_has zsh
) && pass || fail "link externo foi deduzido"

it "migração nunca deduz pacote apt"
(
  mig_setup
  ln -s "$TMP/repo/home/.zshrc" "$HOME/.zshrc"
  mkdir -p "$HOME/.oh-my-zsh/custom/themes/powerlevel10k/.git" "$HOME/.local/kitty.app/bin" "$HOME/.nvm"
  : >"$HOME/.nvm/nvm.sh"
  pn_receipts_migrate
  ! cat "$(pn_receipt_dir)"/* | grep -q $'^apt\t' && pn_receipt_has node && pn_receipt_has kitty
) && pass || fail "apt deduzido ou módulos sem recibo"

it "módulo sem nada deduzível continua sem recibo"
(
  mig_setup
  mkdir -p "$HOME/.oh-my-zsh/custom/themes"
  pn_receipts_migrate
  ! pn_receipt_has zsh && ! pn_receipt_has kitty && ! pn_receipt_has node
) && pass || fail "recibo vazio criado"

it "migração roda uma vez só"
(
  mig_setup
  ln -s "$TMP/repo/home/.zshrc" "$HOME/.zshrc"
  pn_receipts_migrate
  printf 'file\t/x\n' >>"$(pn_receipt_path zsh)"
  pn_receipts_migrate
  rm "$(pn_receipt_path zsh)"
  pn_receipts_migrate
  ! pn_receipt_has zsh
) && pass || fail "migração rodou duas vezes"

it "dry-run não migra"
(
  mig_setup
  ln -s "$TMP/repo/home/.zshrc" "$HOME/.zshrc"
  DRY_RUN=1 pn_receipts_migrate
  ! pn_receipt_has zsh && [[ ! -e "$(pn_receipt_dir)/.migrated-v1" ]]
) && pass || fail "dry-run migrou"

it "migração não toca módulo que já tem recibo"
(
  mig_setup
  ln -s "$TMP/repo/home/.zshrc" "$HOME/.zshrc"
  PN_RECEIPT_MODULE=zsh pn_receipt_add apt zsh
  pn_receipts_migrate
  [[ "$(pn_receipt_origin zsh)" == installed ]]
) && pass || fail "recibo existente alterado"

it "zsh só deduz oh-my-zsh com powerlevel10k clonado"
(
  mig_setup
  ln -s "$TMP/repo/home/.zshrc" "$HOME/.zshrc"
  mkdir -p "$HOME/.oh-my-zsh/custom/themes/powerlevel10k/.git"
  pn_receipts_migrate
  [[ "$(pn_receipt_entries zsh dir)" == $'dir\t'"$HOME/.oh-my-zsh" ]]
) && pass || fail "dir oh-my-zsh não deduzido"

it "kitty só deduz link cujo alvo literal está em kitty.app/bin"
(
  mig_setup
  ln -s "$TMP/repo/home/.zshrc" "$HOME/.zshrc"
  mkdir -p "$HOME/.local/kitty.app/bin" "$HOME/.local/bin"
  ln -s "$HOME/.local/kitty.app/bin/kitty" "$HOME/.local/bin/kitty"
  ln -s /usr/bin/true "$HOME/.local/bin/kitten"
  pn_receipts_migrate
  [[ "$(pn_receipt_entries kitty link)" == $'link\t'"$HOME/.local/bin/kitty" ]]
) && pass || fail "links do kitty errados"

it "node deduz ~/.nvm e ~/n pelos binários"
(
  mig_setup
  ln -s "$TMP/repo/home/.zshrc" "$HOME/.zshrc"
  mkdir -p "$HOME/.nvm" "$HOME/n/bin"
  : >"$HOME/.nvm/nvm.sh"; : >"$HOME/n/bin/n"
  pn_receipts_migrate
  [[ "$(pn_receipt_entries node dir)" == $'dir\t'"$HOME/.nvm"$'\ndir\t'"$HOME/n" ]]
) && pass || fail "dirs do node errados"

it "sem link do PowerTerminal na máquina a migração não deduz nada"
(
  mig_setup
  mkdir -p "$HOME/.nvm" "$HOME/.local/kitty.app/bin" "$HOME/.oh-my-zsh/custom/themes/powerlevel10k/.git"
  printf 'nvm\n' >"$HOME/.nvm/nvm.sh"
  pn_receipts_migrate
  ! pn_receipt_has node && ! pn_receipt_has kitty && ! pn_receipt_has zsh
) && pass || fail "deduziu sem evidência de install do PowerTerminal"

it "sem evidência a migração ainda grava o marcador"
(
  mig_setup
  pn_receipts_migrate
  [[ -e "$(pn_receipt_dir)/.migrated-v1" ]]
) && pass || fail "marcador ausente"

it "um link do PowerTerminal basta como evidência para deduzir os outros módulos"
(
  mig_setup
  mkdir -p "$HOME/.nvm"
  printf 'nvm\n' >"$HOME/.nvm/nvm.sh"
  ln -s "$TMP/repo/home/.zshrc" "$HOME/.zshrc"
  pn_receipts_migrate
  [[ "$(pn_receipt_origin node)" == deduced && "$(pn_receipt_entries node dir)" == $'dir\t'"$HOME/.nvm" ]]
) && pass || fail "node não deduzido com evidência"

it "link de fora do repo não conta como evidência"
(
  mig_setup
  mkdir -p "$HOME/.nvm"
  printf 'nvm\n' >"$HOME/.nvm/nvm.sh"
  ln -s "$TMP/outside/zshrc" "$HOME/.zshrc"
  pn_receipts_migrate
  ! pn_receipt_has node
) && pass || fail "link externo serviu de evidência"

it "PN_RECEIPT_DIR redireciona os recibos"
(
  reset
  PN_RECEIPT_DIR="$TMP/outro" PN_RECEIPT_MODULE=zsh pn_receipt_add file /x
  [[ -f "$TMP/outro/zsh" ]] && ! pn_receipt_has zsh
) && pass || fail "PN_RECEIPT_DIR ignorado"

test_summary
