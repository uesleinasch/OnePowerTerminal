#!/usr/bin/env bash
set -euo pipefail
source "${POWERTERMINAL_HOME}/tests/lib.sh"
source "${POWERTERMINAL_HOME}/lib/core.sh"
for m in "${POWERTERMINAL_HOME}"/lib/modules/*.sh; do
  # shellcheck source=/dev/null
  source "$m"
done

# Mesma ordem canônica do bin/powerterminal.
_PN_ALL_MODULES=(apt fonts zsh nvim astronvim kitty tools node helpers extras notiont)

it "modulo sem dependencia devolve ele mesmo"
assert_eq "zsh" "$(pn_expand_deps zsh)"

it "astronvim puxa nvim"
assert_eq "nvim
astronvim" "$(pn_expand_deps astronvim)"

it "fonts puxa apt"
assert_eq "apt
fonts" "$(pn_expand_deps fonts)"

it "a saida sai na ordem canonica, nao na ordem do argumento"
assert_eq "apt
zsh" "$(pn_expand_deps zsh apt)"

it "nao duplica quando a dependencia ja foi pedida"
assert_eq "nvim
astronvim" "$(pn_expand_deps nvim astronvim)"

it "resolve varios modulos de uma vez"
assert_eq "apt
fonts
nvim
astronvim" "$(pn_expand_deps astronvim fonts)"

it "modulo nao registrado em _PN_ALL_MODULES falha com mensagem clara"
cat > "${POWERTERMINAL_HOME}/lib/modules/zztest.sh" <<'MOD'
# shellcheck shell=bash
mod_zztest_meta() { echo "modulo temporario de teste"; }
mod_zztest_install() { :; }
mod_zztest_doctor() { :; }
MOD
saida="$("${POWERTERMINAL_HOME}/bin/powerterminal" install --module zztest --dry-run --yes 2>&1 || true)"
rm -f "${POWERTERMINAL_HOME}/lib/modules/zztest.sh"
assert_contains "$saida" "_PN_ALL_MODULES"

test_summary
