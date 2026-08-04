#!/usr/bin/env bash
set -euo pipefail
source "${POWERTERMINAL_HOME}/tests/lib.sh"
source "${POWERTERMINAL_HOME}/lib/core.sh"
source "${POWERTERMINAL_HOME}/lib/ui.sh"
export POWERTERMINAL_UI=text
XDG_STATE_HOME="$(mktemp -d)"
export XDG_STATE_HOME

it "pn_log_file devolve um caminho dentro de powerterminal"
assert_contains "$(pn_log_file)" "powerterminal"

it "pn_log_file cria o diretorio"
assert_ok test -d "$(dirname "$(pn_log_file)")"

it "pn_log_file e estavel ao longo do tempo depois de resolvido"
XDG_STATE_HOME="$(mktemp -d)"
export XDG_STATE_HOME
_PN_LOG_FILE=""
_pn_resolve_log_file
a="$(pn_log_file)"
echo "teste" >> "$a"
sleep 1.1
b="$(pn_log_file)"
assert_eq "$a" "$b"

it "a execucao gera um unico arquivo de log"
assert_eq "1" "$(find "$XDG_STATE_HOME/powerterminal" -name 'install-*.log' | wc -l)"

it "ui_step_ok mostra o nome do modulo"
assert_contains "$(ui_step_ok apt 42 2>&1)" "apt"

it "ui_step_ok mostra a duracao"
assert_contains "$(ui_step_ok apt 42 2>&1)" "42s"

it "ui_step_fail sinaliza a falha"
assert_contains "$(ui_step_fail kitty 2>&1)" "kitty"

it "o modo nao-interativo nao regrediu"
assert_ok ./bin/powerterminal install --profile minimal --dry-run --yes

test_summary
