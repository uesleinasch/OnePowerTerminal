#!/usr/bin/env bash
# Roda todos os tests/test_*.sh. Sai 1 se qualquer um falhar.
set -euo pipefail

cd "$(dirname "$(readlink -f "$0")")/.."
POWERTERMINAL_HOME="$PWD"
export POWERTERMINAL_HOME

rc=0
for t in tests/test_*.sh; do
  printf '\n\033[1m%s\033[0m\n' "$t"
  bash "$t" || rc=1
done
exit "$rc"
