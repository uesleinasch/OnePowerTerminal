#!/usr/bin/env bash
set -euo pipefail
source "${POWERTERMINAL_HOME}/tests/lib.sh"

# `env -i` isola do ambiente do runner: uma POWERNEOVIM_* herdada tornaria
# verde um teste que deveria falhar.
_core_env() {
  env -i HOME="$HOME" PATH="$PATH" POWERTERMINAL_HOME="$POWERTERMINAL_HOME" "$@"
}

core_var() {
  local probe="$1"; shift
  _core_env PN_PROBE="$probe" "$@" \
    bash -c 'source "$POWERTERMINAL_HOME/lib/core.sh"; printf "%s" "${!PN_PROBE:-}"' 2>/dev/null
}

core_stderr() {
  { _core_env "$@" bash -c 'source "$POWERTERMINAL_HOME/lib/core.sh"' >/dev/null; } 2>&1
}

it "POWERNEOVIM_UI alimenta POWERTERMINAL_UI"
assert_eq "text" "$(core_var POWERTERMINAL_UI POWERNEOVIM_UI=text)"

it "POWERNEOVIM_NODE_MANAGER alimenta POWERTERMINAL_NODE_MANAGER"
assert_eq "n" "$(core_var POWERTERMINAL_NODE_MANAGER POWERNEOVIM_NODE_MANAGER=n)"

it "POWERNEOVIM_NONINTERACTIVE alimenta POWERTERMINAL_NONINTERACTIVE"
assert_eq "1" "$(core_var POWERTERMINAL_NONINTERACTIVE POWERNEOVIM_NONINTERACTIVE=1)"

it "o nome novo vence quando as duas estao definidas"
assert_eq "gum" "$(core_var POWERTERMINAL_UI POWERNEOVIM_UI=text POWERTERMINAL_UI=gum)"

it "a variavel legada emite aviso de depreciacao"
assert_contains "$(core_stderr POWERNEOVIM_UI=text)" "POWERNEOVIM_UI está depreciada"

it "sem variavel legada nao ha aviso"
assert_eq "" "$(core_stderr)"

it "o default de POWERTERMINAL_NONINTERACTIVE sobrevive a compat"
assert_eq "0" "$(core_var POWERTERMINAL_NONINTERACTIVE)"

it "bin/powerneovim e um symlink relativo para powerterminal"
assert_eq "powerterminal" "$(readlink "$POWERTERMINAL_HOME/bin/powerneovim")"

it "o symlink de compat responde igual ao binario novo"
assert_eq "$("$POWERTERMINAL_HOME/bin/powerterminal" version)" \
          "$("$POWERTERMINAL_HOME/bin/powerneovim" version)"

# Guard contra ocorrência esquecida na renomeação: o bloco de compat em
# lib/core.sh é o único lugar do código onde o nome antigo pode aparecer.
it "o nome antigo aparece apenas em lib/core.sh"
assert_eq "lib/core.sh" "$(
  cd "$POWERTERMINAL_HOME" &&
  { grep -rl POWERNEOVIM lib bin/powerterminal Makefile || true; } | sort | paste -sd' ' -
)"

test_summary
