#!/usr/bin/env bash
set -euo pipefail
source "${POWERTERMINAL_HOME}/tests/lib.sh"
source "${POWERTERMINAL_HOME}/lib/core.sh"
source "${POWERTERMINAL_HOME}/lib/ui.sh"
source "${POWERTERMINAL_HOME}/lib/precheck.sh"
for m in "${POWERTERMINAL_HOME}"/lib/modules/*.sh; do
  # shellcheck source=/dev/null
  source "$m"
done
export POWERTERMINAL_UI=text

it "ui_welcome mostra a versao"
assert_contains "$(ui_welcome 2>&1)" "$(cat "${POWERTERMINAL_HOME}/VERSION")"

it "ui_welcome lista os prechecks"
assert_contains "$(ui_welcome 2>&1)" "Distro"

it "ui_summary usa singular com um modulo so"
assert_contains "$(ui_summary helpers 2>&1)" "1 módulo ·"

it "ui_summary usa plural com mais de um modulo"
assert_contains "$(ui_summary apt zsh 2>&1)" "2 módulos ·"

it "ui_final usa singular com um sucesso so"
assert_contains "$(ui_final "apt" "" 2>&1)" "1 módulo instalado"

it "ui_final usa plural com mais de um sucesso"
assert_contains "$(ui_final "apt zsh" "" 2>&1)" "2 módulos instalados"

it "ui_summary soma o tempo dos modulos"
# apt=2 + zsh=2 = 4 minutos
assert_contains "$(ui_summary apt zsh 2>&1)" "4 min"

it "ui_summary soma o espaco"
# apt=150 + zsh=80 = 230 MB
assert_contains "$(ui_summary apt zsh 2>&1)" "230 MB"

it "ui_summary avisa que pede sudo quando algum modulo exige"
assert_contains "$(ui_summary apt 2>&1)" "senha"

it "ui_summary nao fala em senha quando nenhum modulo exige"
saida="$(ui_summary helpers 2>&1)"
if [[ "$saida" == *senha* ]]; then fail "não deveria mencionar senha: $saida"; else pass; fi

it "ui_summary lista cada modulo pedido"
assert_contains "$(ui_summary apt zsh 2>&1)" "zsh"

it "ui_final mostra o comando de reexecucao das falhas"
assert_contains "$(ui_final "apt zsh" "kitty" 2>&1)" "--module kitty"

it "ui_final sem falhas nao sugere reexecucao"
saida="$(ui_final "apt zsh" "" 2>&1)"
if [[ "$saida" == *"--module"* ]]; then fail "não deveria sugerir: $saida"; else pass; fi

it "ui_final lista os proximos passos"
assert_contains "$(ui_final "apt" "" 2>&1)" "doctor"

it "ui_summary sobrevive a cost com campo nao numerico"
mod_zzruim_meta() { echo "modulo de teste"; }
mod_zzruim_cost() { printf 'abc\t10\t0\n'; }
saida="$(ui_summary zzruim 2>&1)"
assert_contains "$saida" "zzruim"

it "ui_summary avisa quando o cost e malformado"
assert_contains "$(ui_summary zzruim 2>&1)" "valor inesperado"

it "ui_summary sobrevive a cost vazio"
mod_zzvazio_meta() { echo "modulo de teste"; }
mod_zzvazio_cost() { :; }
assert_contains "$(ui_summary zzvazio 2>&1)" "zzvazio"

it "ui_summary continua somando certo os modulos validos"
assert_contains "$(ui_summary apt zsh 2>&1)" "4 min"

test_summary
