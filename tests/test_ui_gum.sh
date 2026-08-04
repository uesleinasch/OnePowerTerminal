#!/usr/bin/env bash
set -euo pipefail
source "${POWERTERMINAL_HOME}/tests/lib.sh"
source "${POWERTERMINAL_HOME}/lib/core.sh"
source "${POWERTERMINAL_HOME}/lib/ui.sh"

it "o gum vendorizado existe e e executavel"
assert_ok test -x "${POWERTERMINAL_HOME}/vendor/gum"

it "o gum vendorizado responde --version"
assert_contains "$("${POWERTERMINAL_HOME}/vendor/gum" --version 2>&1)" "gum"

it "a licenca do gum acompanha o binario"
assert_ok test -s "${POWERTERMINAL_HOME}/vendor/LICENSE-gum"

it "_ui_gum_bin encontra o binario vendorizado em x86_64"
if [[ "$(uname -m)" == "x86_64" ]]; then
  assert_contains "$(_ui_gum_bin)" "vendor/gum"
else
  pass
fi

it "sem POWERTERMINAL_UI o backend padrao e gum em x86_64"
if [[ "$(uname -m)" == "x86_64" ]]; then
  assert_eq "gum" "$(unset POWERTERMINAL_UI; _PN_UI_BACKEND=""; ui_backend)"
else
  pass
fi

it "POWERTERMINAL_UI=text ainda sobrepoe o gum"
assert_eq "text" "$(_PN_UI_BACKEND=""; POWERTERMINAL_UI=text ui_backend)"

test_summary
