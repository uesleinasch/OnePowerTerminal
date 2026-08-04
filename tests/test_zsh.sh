#!/usr/bin/env bash
set -euo pipefail
source "${POWERTERMINAL_HOME}/tests/lib.sh"
source "${POWERTERMINAL_HOME}/lib/core.sh"
source "${POWERTERMINAL_HOME}/lib/modules/zsh.sh"

# zsh falso à frente do PATH: o teste não pode depender de a máquina ter zsh,
# senão passaria por ausência de sonda em vez de por comportamento.
_zsh_falso="$(mktemp -d)"
printf '#!/bin/sh\n' > "$_zsh_falso/zsh"
chmod +x "$_zsh_falso/zsh"

_registro="$(mktemp)"
_notas=""

# Substitui as três dependências externas da função: o shell registrado, a
# disponibilidade do sudo e a execução privilegiada. Nada aqui toca /etc/passwd.
_configurar() {
  POWERTERMINAL_NOTES_FILE="$(mktemp)"
  export POWERTERMINAL_NOTES_FILE
  : > "$_registro"
  (
    login_shell() { printf '%s\n' "${FAKE_LOGIN_SHELL:-/bin/bash}"; }
    _vf_sudo_pronto() { [[ "${FAKE_SUDO_OK:-1}" == "1" ]]; }
    as_sudo() { printf 'as_sudo %s\n' "$*" >> "$_registro"; return "${FAKE_CHSH_RC:-0}"; }
    PATH="$_zsh_falso:$PATH" _vf_set_default_shell
  ) >/dev/null 2>&1
  _notas="$(cat "$POWERTERMINAL_NOTES_FILE")"
}

it "com sudo pronto, grava o shell padrao via sudo chsh"
_configurar
assert_contains "$(cat "$_registro")" "as_sudo chsh -s $_zsh_falso/zsh $(id -un)"

it "apos gravar, avisa que e preciso reiniciar"
assert_contains "$_notas" "Reinicie a máquina"

it "e explica que a troca so vale no proximo login"
assert_contains "$_notas" "próximo login"

it "apos gravar, nao pede o chsh manual"
assert_eq "nao" "$(printf '%s' "$_notas" | grep -q 'chsh -s' && echo sim || echo nao)"

it "sem sudo disponivel, nao chama chsh"
FAKE_SUDO_OK=0 _configurar
assert_eq "" "$(cat "$_registro")"

it "sem sudo disponivel, deixa o chsh como tarefa manual"
assert_contains "$_notas" "chsh -s $_zsh_falso/zsh"

it "a tarefa manual tambem avisa do reinicio"
assert_contains "$_notas" "reinicie a máquina"

it "se o chsh falhar, cai na tarefa manual"
FAKE_CHSH_RC=1 _configurar
assert_contains "$_notas" "chsh -s $_zsh_falso/zsh"

it "quando o zsh ja e o shell de login, nao faz nada"
FAKE_LOGIN_SHELL="$_zsh_falso/zsh" _configurar
assert_eq "" "$(cat "$_registro")$_notas"

# O defeito que isso previne: $SHELL é o shell da sessão, não o registrado.
# Quem rodou `zsh` na mão tem $SHELL=zsh e bash no passwd — antes, a função
# concluía "já está pronto" e não avisava nada.
it "decide pelo shell registrado, nao por \$SHELL"
SHELL="$_zsh_falso/zsh" FAKE_LOGIN_SHELL=/bin/bash _configurar
assert_contains "$(cat "$_registro")" "as_sudo chsh -s $_zsh_falso/zsh"

it "em dry-run nao chama chsh nem enfileira tarefa"
DRY_RUN=1 _configurar
assert_eq "" "$(cat "$_registro")$_notas"

it "mod_zsh_install chama _vf_set_default_shell"
assert_eq "sim" "$(declare -f mod_zsh_install | grep -q '_vf_set_default_shell' && echo sim || echo nao)"

test_summary
