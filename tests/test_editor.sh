#!/usr/bin/env bash
set -euo pipefail
source "${POWERTERMINAL_HOME}/tests/lib.sh"
cd "$POWERTERMINAL_HOME"
unset POWERTERMINAL_EDITOR

# Devolve a lista "Módulos:" do modo não-interativo cercada de espaços, para
# casar nome inteiro (" nvim " não pode bater em "astronvim").
modulos() {
  local linha
  linha="$(./bin/powerterminal install "$@" --dry-run --yes 2>/dev/null | grep 'Módulos:' | head -1)"
  printf ' %s ' "${linha#*Módulos: }"
}

assert_tem() {
  if [[ "$1" == *" $2 "* ]]; then pass; else fail "esperado [$2] em [$1]"; fi
}

assert_nao_tem() {
  if [[ "$1" == *" $2 "* ]]; then fail "não esperado [$2] em [$1]"; else pass; fi
}

wizard() { printf '%b' "$1" | POWERTERMINAL_UI=text ./bin/powerterminal install --dry-run 2>&1; }

it "dev sem POWERTERMINAL_EDITOR continua com o Neovim"
dev="$(modulos --profile dev)"
assert_tem "$dev" astronvim

it "dev sem POWERTERMINAL_EDITOR nao traz o VS Code"
assert_nao_tem "$dev" vscode

it "dev traz o Claude Code"
assert_tem "$dev" claude

it "POWERTERMINAL_EDITOR=vscode troca o Neovim pelo VS Code"
saida="$(POWERTERMINAL_EDITOR=vscode modulos --profile dev)"
assert_tem "$saida" vscode

it "POWERTERMINAL_EDITOR=vscode tira nvim e astronvim"
if [[ "$saida" == *" nvim "* || "$saida" == *" astronvim "* ]]; then
  fail "nvim/astronvim não deveriam estar em [$saida]"
else
  pass
fi

it "POWERTERMINAL_EDITOR=both traz os tres modulos de editor"
saida="$(POWERTERMINAL_EDITOR=both modulos --profile dev)"
if [[ "$saida" == *" nvim "* && "$saida" == *" astronvim "* && "$saida" == *" vscode "* ]]; then
  pass
else
  fail "esperado nvim, astronvim e vscode em [$saida]"
fi

it "full sem POWERTERMINAL_EDITOR traz os dois editores"
saida="$(modulos --profile full)"
if [[ "$saida" == *" nvim "* && "$saida" == *" vscode "* ]]; then pass; else fail "esperado nvim e vscode em [$saida]"; fi

it "full com POWERTERMINAL_EDITOR=nvim deixa o VS Code de fora"
assert_nao_tem "$(POWERTERMINAL_EDITOR=nvim modulos --profile full)" vscode

it "minimal ignora POWERTERMINAL_EDITOR"
assert_nao_tem "$(POWERTERMINAL_EDITOR=vscode modulos --profile minimal)" vscode

it "POWERTERMINAL_EDITOR invalida avisa"
assert_contains "$(POWERTERMINAL_EDITOR=emacs ./bin/powerterminal install --profile dev --dry-run --yes 2>&1)" "POWERTERMINAL_EDITOR inválido"

it "POWERTERMINAL_EDITOR invalida cai no default do perfil"
assert_tem "$(POWERTERMINAL_EDITOR=emacs modulos --profile dev)" astronvim

it "a lista do perfil segue a ordem canonica"
assert_contains "$(POWERTERMINAL_EDITOR=both modulos --profile dev)" " nvim astronvim vscode "

it "--module vscode instala so o VS Code"
assert_eq " vscode " "$(modulos --module vscode)"

it "--module claude instala so o Claude Code"
assert_eq " claude " "$(modulos --module claude)"

it "o wizard pergunta o editor no perfil dev"
assert_contains "$(wizard '1\n1\nn\n')" "Qual editor"

it "o wizard nao pergunta o editor no perfil minimal"
saida="$(wizard '2\nn\n')"
if [[ "$saida" == *"Qual editor"* ]]; then fail "minimal não tem editor para escolher"; else pass; fi

it "escolher VS Code no wizard leva o vscode ao resumo"
saida="$(wizard '1\n2\nn\n')"
assert_contains "$saida" "vscode"

it "escolher VS Code no wizard deixa o astronvim fora do resumo"
if [[ "$saida" == *"astronvim"* ]]; then fail "astronvim não deveria aparecer"; else pass; fi

it "com POWERTERMINAL_EDITOR definida o wizard nao pergunta"
saida="$(printf '1\nn\n' | POWERTERMINAL_EDITOR=vscode POWERTERMINAL_UI=text ./bin/powerterminal install --dry-run 2>&1)"
if [[ "$saida" == *"Qual editor"* ]]; then fail "a env já decidiu o editor"; else pass; fi

# Os módulos rodam com has_cmd negado para que o dry-run não dependa do que o
# host já tem instalado.
modulo_dry() {
  bash -c "
    source '$POWERTERMINAL_HOME/lib/core.sh'
    source '$POWERTERMINAL_HOME/lib/modules/$1.sh'
    has_cmd() { [[ \"\$1\" == curl ]]; }
    HOME=\$(mktemp -d)
    _PN_APT_ETC=\$HOME/etc-apt
    DRY_RUN=1
    mod_$1_install" 2>&1
}

it "vscode recusa o repositorio que o pacote code tenta adicionar"
assert_contains "$(modulo_dry vscode)" "code/add-microsoft-repo boolean false"

it "vscode usa o repositorio apt da Microsoft"
assert_contains "$(modulo_dry vscode)" "packages.microsoft.com/repos/code"

it "vscode instala o pacote code"
assert_contains "$(modulo_dry vscode)" "apt-get install -y code"

it "claude usa o instalador nativo da Anthropic"
assert_contains "$(modulo_dry claude)" "claude.ai/install.sh"

test_summary
