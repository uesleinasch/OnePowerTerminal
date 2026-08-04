#!/usr/bin/env bash
# install.sh — bootstrap do PowerTerminal: obtém o repositório e chama a CLI.
#
#   curl -fsSL https://raw.githubusercontent.com/uesleinasch/OnePowerTerminal/main/install.sh | bash
#   curl -fsSL .../install.sh | bash -s -- --profile full --yes
#
# PT_SKIP_INSTALL=1 pára depois de obter o repositório, sem chamar o instalador.
# PT_REPO aponta outra origem — os testes usam um caminho local para não ir à rede.
set -euo pipefail

PT_REPO="${PT_REPO:-https://github.com/uesleinasch/OnePowerTerminal.git}"
PT_TARBALL="${PT_TARBALL:-https://github.com/uesleinasch/OnePowerTerminal/archive/refs/heads/main.tar.gz}"
PT_DEST="${POWERTERMINAL_HOME:-$HOME/PowerTerminal}"

# Roda antes de o repositório existir, então não há lib/core.sh para sourcear:
# os helpers de log e de predicado precisam ser próprios.
if [[ -t 1 ]]; then
  _BS_R=$'\033[0m'
  _BS_BLUE=$'\033[38;5;110m'
  _BS_YELLOW=$'\033[38;5;215m'
  _BS_RED=$'\033[38;5;203m'
else
  _BS_R=""; _BS_BLUE=""; _BS_YELLOW=""; _BS_RED=""
fi

_bs_info() { printf '%s[powerterminal]%s %s\n' "$_BS_BLUE" "$_BS_R" "$*"; }
_bs_warn() { printf '%s[powerterminal]%s %s%s%s\n' "$_BS_YELLOW" "$_BS_R" "$_BS_YELLOW" "$*" "$_BS_R" >&2; }
_bs_die() {
  printf '%s[powerterminal]%s %s%s%s\n' "$_BS_RED" "$_BS_R" "$_BS_RED" "$*" "$_BS_R" >&2
  exit 1
}

_bs_has() { command -v "$1" >/dev/null 2>&1; }

_bs_baixar_tarball() {
  mkdir -p "$PT_DEST"
  if _bs_has curl; then
    curl -fsSL "$PT_TARBALL" | tar -xz --strip-components=1 -C "$PT_DEST"
  elif _bs_has wget; then
    wget -qO- "$PT_TARBALL" | tar -xz --strip-components=1 -C "$PT_DEST"
  else
    _bs_die "preciso de git, curl ou wget para obter o PowerTerminal."
  fi
}

_bs_obter() {
  if _bs_has git; then
    _bs_info "Clonando o PowerTerminal em $PT_DEST…"
    git clone --depth 1 "$PT_REPO" "$PT_DEST"
  else
    _bs_info "git não encontrado; baixando o pacote em $PT_DEST…"
    _bs_baixar_tarball
  fi
}

_bs_atualizar() {
  _bs_has git || _bs_die "$PT_DEST é um clone git, mas o git não está instalado."
  [[ -e "$PT_DEST/bin/powerterminal" ]] \
    || _bs_die "$PT_DEST é um clone git, mas não parece ser o PowerTerminal (bin/powerterminal ausente). Mova ou remova o diretório, ou escolha outro destino com POWERTERMINAL_HOME=/outro/caminho"
  _bs_info "Já existe um clone em $PT_DEST; atualizando…"
  git -C "$PT_DEST" pull --ff-only
}

_bs_proximo_passo() {
  _bs_info "PowerTerminal disponível em $PT_DEST"
  _bs_info "Próximo passo: $PT_DEST/bin/powerterminal install"
}

if [[ -e "$PT_DEST" ]]; then
  if [[ -d "$PT_DEST/.git" ]]; then
    _bs_atualizar
  else
    _bs_die "$PT_DEST já existe e não é um clone do PowerTerminal. Mova ou remova o diretório, ou escolha outro destino com POWERTERMINAL_HOME=/outro/caminho"
  fi
else
  _bs_obter
fi

[[ -x "$PT_DEST/bin/powerterminal" ]] ||
  _bs_die "obtenção incompleta: $PT_DEST/bin/powerterminal não existe ou não é executável."

# `curl … | bash` deixa o stdin do script preso ao pipe, e o wizard lê as
# respostas de stdin: reabrir /dev/tty é o que lhe devolve a entrada do usuário.
if [[ "${PT_SKIP_INSTALL:-0}" == "1" ]]; then
  _bs_proximo_passo
elif [[ -e /dev/tty ]] && (: >/dev/tty) 2>/dev/null; then
  _bs_info "Iniciando o instalador…"
  "$PT_DEST/bin/powerterminal" install "$@" </dev/tty
else
  _bs_warn "Sem terminal interativo disponível para o assistente."
  _bs_proximo_passo
fi
