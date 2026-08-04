#!/usr/bin/env bash
set -euo pipefail
source "${POWERTERMINAL_HOME}/tests/lib.sh"
source "${POWERTERMINAL_HOME}/lib/core.sh"
source "${POWERTERMINAL_HOME}/lib/ui.sh"
source "${POWERTERMINAL_HOME}/lib/modules/node.sh"

export POWERTERMINAL_UI=text
# Aponta as sondas de "já instalado" para um diretório vazio.
_PN_NVM_DIR="$(mktemp -d)"
_PN_N_PREFIX="$(mktemp -d)"

it "mod_node_configure existe"
assert_ok declare -F mod_node_configure

# Roda _vf_is_real_n num subprocesso com um `n` controlado à frente do PATH.
_probe_real_n() {
  PATH="$1:$PATH" bash -c "
    source '$POWERTERMINAL_HOME/lib/core.sh'
    source '$POWERTERMINAL_HOME/lib/modules/node.sh'
    _vf_is_real_n"
}

it "um comando 'n' que nao e o gerenciador e rejeitado"
_fake_nao="$(mktemp -d)"
printf '#!/bin/sh\necho "uso: n <arquivo>"\n' > "$_fake_nao/n"
chmod +x "$_fake_nao/n"
assert_fail _probe_real_n "$_fake_nao"

it "o gerenciador n instalado fora do prefixo e reconhecido"
_fake_sim="$(mktemp -d)"
printf '#!/bin/sh\n[ "$1" = --version ] && echo 10.1.0\n' > "$_fake_sim/n"
chmod +x "$_fake_sim/n"
assert_ok _probe_real_n "$_fake_sim"

# Neutraliza a sonda do PATH para os testes de precedência abaixo: o runner do
# CI tem um `n` visível, e deixar o ambiente decidir o resultado tornaria os
# testes inúteis. A função real acabou de ser exercitada nos dois casos.
_vf_is_real_n() { return 1; }

it "a env POWERTERMINAL_NODE_MANAGER e respeitada"
POWERTERMINAL_ANSWERS_FILE="$(mktemp)"
export POWERTERMINAL_ANSWERS_FILE
( POWERTERMINAL_NODE_MANAGER=n mod_node_configure >/dev/null 2>&1 )
assert_eq "n" "$(pn_get_answer node.manager)"

it "modo nao-interativo usa nvm por default"
POWERTERMINAL_ANSWERS_FILE="$(mktemp)"
export POWERTERMINAL_ANSWERS_FILE
( unset POWERTERMINAL_NODE_MANAGER; POWERTERMINAL_NONINTERACTIVE=1 mod_node_configure >/dev/null 2>&1 )
assert_eq "nvm" "$(pn_get_answer node.manager)"

it "env invalida cai no default nvm"
POWERTERMINAL_ANSWERS_FILE="$(mktemp)"
export POWERTERMINAL_ANSWERS_FILE
( POWERTERMINAL_NODE_MANAGER=bun POWERTERMINAL_NONINTERACTIVE=1 mod_node_configure >/dev/null 2>&1 )
assert_eq "nvm" "$(pn_get_answer node.manager)"

it "node.sh nao chama mais whiptail direto"
assert_fail grep -q whiptail "${POWERTERMINAL_HOME}/lib/modules/node.sh"

it "com nvm e n instalados, nvm ganha o desempate"
POWERTERMINAL_ANSWERS_FILE="$(mktemp)"
export POWERTERMINAL_ANSWERS_FILE
_PN_NVM_DIR="$(mktemp -d)"
_PN_N_PREFIX="$(mktemp -d)"
printf '# nvm falso\n' > "$_PN_NVM_DIR/nvm.sh"
mkdir -p "$_PN_N_PREFIX/bin"
printf '#!/bin/sh\n' > "$_PN_N_PREFIX/bin/n"
chmod +x "$_PN_N_PREFIX/bin/n"
( unset POWERTERMINAL_NODE_MANAGER; POWERTERMINAL_NONINTERACTIVE=1 mod_node_configure >/dev/null 2>&1 )
assert_eq "nvm" "$(pn_get_answer node.manager)"

test_summary
