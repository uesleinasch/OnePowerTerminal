# shellcheck shell=bash
# Helpers de teste. Runner caseiro para manter o projeto sem dependências.

PN_TESTS_RUN=0
PN_TESTS_FAILED=0
PN_CURRENT_TEST=""

it() { PN_CURRENT_TEST="$1"; PN_TESTS_RUN=$((PN_TESTS_RUN + 1)); }

pass() { printf '  \033[32m✓\033[0m %s\n' "$PN_CURRENT_TEST"; }

fail() {
  PN_TESTS_FAILED=$((PN_TESTS_FAILED + 1))
  printf '  \033[31m✗\033[0m %s\n      %s\n' "$PN_CURRENT_TEST" "$1" >&2
}

assert_eq() {
  if [[ "$1" == "$2" ]]; then pass; else fail "esperado [$1], obtido [$2]"; fi
}

assert_contains() {
  if [[ "$1" == *"$2"* ]]; then pass; else fail "esperado conter [$2] em [$1]"; fi
}

assert_ok() {
  if "$@" >/dev/null 2>&1; then pass; else fail "deveria ter sucesso: $*"; fi
}

assert_fail() {
  if "$@" >/dev/null 2>&1; then fail "deveria falhar: $*"; else pass; fi
}

test_summary() {
  printf '  %d teste(s), %d falha(s)\n' "$PN_TESTS_RUN" "$PN_TESTS_FAILED"
  [[ "$PN_TESTS_FAILED" -eq 0 ]]
}
