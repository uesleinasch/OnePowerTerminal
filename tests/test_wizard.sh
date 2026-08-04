#!/usr/bin/env bash
set -euo pipefail
source "${POWERTERMINAL_HOME}/tests/lib.sh"
cd "$POWERTERMINAL_HOME"

# O backend de texto lê de stdin, então o wizard inteiro é dirigível por pipe.
wizard() { printf '%b' "$1" | POWERTERMINAL_UI=text ./bin/powerterminal install --dry-run 2>&1; }

it "o wizard abre com as boas-vindas"
assert_contains "$(wizard '1\nn\n')" "PowerTerminal"

it "o wizard mostra os prechecks"
assert_contains "$(wizard '1\nn\n')" "Distro"

it "o wizard oferece os perfis"
assert_contains "$(wizard '1\nn\n')" "minimal"

it "o wizard mostra o resumo antes de confirmar"
assert_contains "$(wizard '2\nn\n')" "Vai ser instalado"

it "perfil minimal resolve os quatro modulos"
assert_contains "$(wizard '2\nn\n')" "4 módulos"

it "recusar na confirmacao cancela"
assert_contains "$(wizard '1\nn\n')" "Cancelado"

it "aceitar executa em dry-run ate a tela final"
assert_contains "$(wizard '1\ny\n')" "Pronto"

it "a tela final aponta o proximo passo"
assert_contains "$(wizard '1\ny\n')" "doctor"

it "a quarta opcao abre o ajuste fino modulo a modulo"
assert_contains "$(wizard '4\n\nn\n')" "Módulos"

it "o ajuste fino respeita o subconjunto escolhido"
assert_contains "$(wizard '4\n3\nn\n')" "1 módulo"

it "o ajuste fino puxa as dependencias do que foi marcado"
assert_contains "$(wizard '4\n5\nn\n')" "nvim"

it "--profile ainda pula o wizard"
assert_ok ./bin/powerterminal install --profile full --dry-run --yes

it "--module ainda pula o wizard"
assert_ok ./bin/powerterminal install --module zsh --dry-run --yes

it "o dry-run nao cria diretorio de log no disco"
tmp_state="$(mktemp -d)"
printf '2\ny\n' | XDG_STATE_HOME="$tmp_state" POWERTERMINAL_UI=text ./bin/powerterminal install --dry-run >/dev/null 2>&1 || true
assert_fail test -d "$tmp_state/powerterminal"

it "o dry-run nao anuncia caminho de log"
saida="$(printf '2\ny\n' | POWERTERMINAL_UI=text ./bin/powerterminal install --dry-run 2>&1)"
if [[ "$saida" == *"Log completo"* ]]; then
  fail "dry-run não deveria anunciar log: aponta para /dev/null"
else
  pass
fi

it "--yes nao abre o wizard nem espera stdin"
saida="$(./bin/powerterminal install --profile minimal --dry-run --yes 2>&1)"
if [[ "$saida" == *"Como quer configurar"* ]]; then
  fail "o modo nao-interativo nao pode abrir o menu de perfis"
else
  pass
fi

test_summary
