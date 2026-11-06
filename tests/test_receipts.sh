#!/usr/bin/env bash
set -euo pipefail
source "${POWERTERMINAL_HOME}/tests/lib.sh"
source "${POWERTERMINAL_HOME}/lib/core.sh"
source "${POWERTERMINAL_HOME}/lib/receipt.sh"

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

test_summary
