#!/usr/bin/env bash
set -euo pipefail
source "${POWERTERMINAL_HOME}/tests/lib.sh"
source "${POWERTERMINAL_HOME}/lib/core.sh"
source "${POWERTERMINAL_HOME}/lib/ui.sh"

export POWERTERMINAL_UI=text

it "POWERTERMINAL_UI força o backend"
assert_eq "text" "$(ui_backend)"

it "ui_choose devolve o id da opcao escolhida pelo numero"
assert_eq "n" "$(printf '2\n' | ui_choose "Gerenciador" nvm:"mais popular" n:"mais simples" 2>/dev/null)"

it "ui_choose com ENTER usa a primeira opcao"
assert_eq "nvm" "$(printf '\n' | ui_choose "Gerenciador" nvm:"mais popular" n:"mais simples" 2>/dev/null)"

it "ui_choose rejeita numero fora da faixa e devolve a primeira"
assert_eq "nvm" "$(printf '99\n' | ui_choose "Gerenciador" nvm:"mais popular" n:"mais simples" 2>/dev/null)"

it "ui_select_modules com ENTER seleciona todos"
out="$(printf '\n' | ui_select_modules apt:"base" zsh:"shell" 2>/dev/null)"
assert_eq "apt zsh" "$(echo $out)"

it "ui_select_modules aceita subconjunto por numero"
out="$(printf '2\n' | ui_select_modules apt:"base" zsh:"shell" 2>/dev/null)"
assert_eq "zsh" "$(echo $out)"

it "ui_confirm aceita y"
assert_ok bash -c 'printf "y\n" | { source "$POWERTERMINAL_HOME/lib/core.sh"; source "$POWERTERMINAL_HOME/lib/ui.sh"; POWERTERMINAL_UI=text ui_confirm "ok?"; }'

it "ui_confirm recusa n"
assert_fail bash -c 'printf "n\n" | { source "$POWERTERMINAL_HOME/lib/core.sh"; source "$POWERTERMINAL_HOME/lib/ui.sh"; POWERTERMINAL_UI=text ui_confirm "ok?"; }'

it "ui_confirm em modo nao-interativo aceita sem perguntar"
assert_ok bash -c 'source "$POWERTERMINAL_HOME/lib/core.sh"; source "$POWERTERMINAL_HOME/lib/ui.sh"; POWERTERMINAL_NONINTERACTIVE=1 POWERTERMINAL_UI=text ui_confirm "ok?"'

test_summary
