#!/usr/bin/env bash
set -euo pipefail
source "${POWERTERMINAL_HOME}/tests/lib.sh"
source "${POWERTERMINAL_HOME}/lib/core.sh"

it "pn_get_answer devolve o default quando a chave nao existe"
assert_eq "nvm" "$(pn_get_answer node.manager nvm)"

it "pn_get_answer devolve o valor gravado"
pn_set_answer node.manager n
assert_eq "n" "$(pn_get_answer node.manager nvm)"

it "a ultima gravacao vence"
pn_set_answer node.manager nvm
assert_eq "nvm" "$(pn_get_answer node.manager)"

it "valores com espaco sobrevivem"
pn_set_answer saudacao "bom dia"
assert_eq "bom dia" "$(pn_get_answer saudacao)"

it "valores com = sobrevivem"
pn_set_answer flags "a=1"
assert_eq "a=1" "$(pn_get_answer flags)"

it "chave ausente sem default devolve vazio"
assert_eq "" "$(pn_get_answer inexistente)"

it "a gravacao sobrevive a um subshell"
( pn_set_answer dentro.subshell sim )
assert_eq "sim" "$(pn_get_answer dentro.subshell)"

it "o ponto na chave nao funciona como coringa"
pn_set_answer node.manager valor_certo
pn_set_answer nodeXmanager valor_errado
assert_eq "valor_certo" "$(pn_get_answer node.manager)"

it "chave com metacaractere de regex e recuperavel"
pn_set_answer 'weird[key' valor_colchete
assert_eq "valor_colchete" "$(pn_get_answer 'weird[key')"

it "valor vazio e distinto de chave ausente"
pn_set_answer chave.vazia ""
assert_eq "" "$(pn_get_answer chave.vazia FALLBACK)"

pn_set_answer node valor_curto

it "chave curta nao rouba o valor da chave longa"
assert_eq "valor_certo" "$(pn_get_answer node.manager)"

it "chave longa nao rouba o valor da chave curta"
assert_eq "valor_curto" "$(pn_get_answer node)"

test_summary
