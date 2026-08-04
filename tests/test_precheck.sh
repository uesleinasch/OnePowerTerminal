#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=/dev/null
source "${POWERTERMINAL_HOME}/tests/lib.sh"
# shellcheck source=/dev/null
source "${POWERTERMINAL_HOME}/lib/core.sh"
# shellcheck source=/dev/null
source "${POWERTERMINAL_HOME}/lib/precheck.sh"

saida="$(pn_precheck_all || true)"

it "todo check emite 3 campos separados por TAB"
ruim="$(printf '%s\n' "$saida" | awk -F'\t' 'NF != 3 {print NR}')"
assert_eq "" "$ruim"

it "todo status e ok, warn ou fatal"
ruim="$(printf '%s\n' "$saida" | awk -F'\t' '$1 !~ /^(ok|warn|fatal)$/ {print $1}')"
assert_eq "" "$ruim"

it "checa a distro"
assert_contains "$saida" "Distro"

it "checa o sudo"
assert_contains "$saida" "sudo"

it "checa a conectividade"
assert_contains "$saida" "Conectividade"

it "checa o espaco em disco"
assert_contains "$saida" "Espaço"

it "checa o shell padrao"
assert_contains "$saida" "Shell"

it "numa distro suportada nao ha fatal"
if is_supported_distro; then
  assert_eq "" "$(printf '%s\n' "$saida" | awk -F'\t' '$1 == "fatal"')"
else
  pass
fi

it "_pn_check_espaco devolve warn quando nao consegue medir"
assert_eq "warn" "$(HOME=/caminho/que/nao/existe _pn_check_espaco | cut -f1)"

it "_pn_check_shell devolve warn quando zsh nao e o shell padrao"
assert_eq "warn" "$( ( login_shell() { echo /bin/bash; }; _pn_check_shell ) | cut -f1)"

# $SHELL é o shell da sessão, não o registrado: um não pode mascarar o outro.
it "_pn_check_shell olha o shell registrado, nao \$SHELL"
assert_eq "warn" "$( ( login_shell() { echo /bin/bash; }; SHELL="$(command -v zsh)" _pn_check_shell ) | cut -f1)"

it "_pn_check_distro devolve fatal em distro nao suportada"
assert_eq "fatal" "$( ( is_supported_distro() { return 1; }; _pn_check_distro ) | cut -f1)"

it "_pn_check_distro devolve ok em distro suportada"
assert_eq "ok" "$( ( is_supported_distro() { return 0; }; _pn_check_distro ) | cut -f1)"

it "pn_precheck_all retorna 1 quando ha fatal"
assert_fail bash -c 'source "'"$POWERTERMINAL_HOME"'/lib/core.sh"; source "'"$POWERTERMINAL_HOME"'/lib/precheck.sh"; is_supported_distro() { return 1; }; pn_precheck_all >/dev/null'

it "pn_precheck_all imprime todas as linhas mesmo com fatal"
saida="$( ( is_supported_distro() { return 1; }; pn_precheck_all ) || true)"
assert_eq "5" "$(printf '%s\n' "$saida" | grep -c .)"

test_summary
