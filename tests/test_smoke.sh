#!/usr/bin/env bash
set -euo pipefail
source "${POWERTERMINAL_HOME}/tests/lib.sh"

it "assert_eq compara valores iguais"
assert_eq "a" "a"

it "o runner enxerga POWERTERMINAL_HOME apontando para a raiz do repo"
assert_ok test -x "$POWERTERMINAL_HOME/bin/powerterminal"

test_summary
