#!/usr/bin/env bash
set -euo pipefail
source "${POWERTERMINAL_HOME}/tests/lib.sh"

# O bootstrap é exercitado contra o próprio repositório: `git clone` aceita
# caminho local, então nenhum teste toca a rede. PT_SKIP_INSTALL evita que
# rodar a suíte num terminal interativo dispare uma instalação de verdade.
_bs_run() {
  local dest="$1"; shift
  # `repo` fixa o valor de fora: na linha do comando, POWERTERMINAL_HOME já
  # aponta para o destino do teste, não mais para o repositório de origem.
  local repo="$POWERTERMINAL_HOME"
  PT_REPO="$repo" \
  POWERTERMINAL_HOME="$dest" \
  PT_SKIP_INSTALL=1 \
    bash "$repo/install.sh" "$@" 2>&1
}

_destino="$(mktemp -d)/powerterminal"

it "clona quando o destino nao existe"
_saida="$(_bs_run "$_destino")"
assert_ok test -x "$_destino/bin/powerterminal"

it "a CLI obtida pelo clone responde a mesma versao do repo"
assert_eq "$(cat "$POWERTERMINAL_HOME/VERSION")" "$("$_destino/bin/powerterminal" version)"

it "o clone traz o symlink de compat intacto"
assert_eq "powerterminal" "$(readlink "$_destino/bin/powerneovim")"

it "aponta o proximo passo quando nao dispara o instalador"
assert_contains "$_saida" "Próximo passo"

it "reexecutar no mesmo destino atualiza em vez de duplicar"
_saida="$(_bs_run "$_destino")"
assert_contains "$_saida" "atualizando"

it "destino ocupado por diretorio que nao e clone aborta"
_ocupado="$(mktemp -d)"
printf 'conteudo preexistente\n' > "$_ocupado/arquivo.txt"
assert_fail _bs_run "$_ocupado"

it "o aborto nao apaga o que estava no destino"
assert_ok test -f "$_ocupado/arquivo.txt"

it "a mensagem de aborto diz como escolher outro destino"
_saida="$(_bs_run "$_ocupado" || true)"
assert_contains "$_saida" "POWERTERMINAL_HOME"

it "respeita POWERTERMINAL_HOME como destino"
_alt="$(mktemp -d)/alternativo"
_bs_run "$_alt" >/dev/null
assert_ok test -x "$_alt/bin/powerterminal"

test_summary
