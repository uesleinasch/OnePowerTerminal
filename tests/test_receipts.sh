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

test_summary
