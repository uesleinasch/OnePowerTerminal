# shellcheck shell=bash
# precheck.sh — verificações de ambiente exibidas na abertura do wizard.
# Cada check imprime "status\trótulo\tdetalhe". Só distro não suportada é fatal.

_pn_check_distro() {
  if is_supported_distro; then
    # shellcheck disable=SC1091
    local nome; nome="$(. /etc/os-release 2>/dev/null && echo "${PRETTY_NAME:-?}")"
    printf 'ok\tDistro\t%s\n' "$nome"
  else
    printf 'fatal\tDistro\tsuportadas: Ubuntu, Debian, Pop!_OS\n'
  fi
}

_pn_check_sudo() {
  if ! has_cmd sudo; then
    printf 'warn\tsudo\tnão encontrado — módulos que exigem root vão falhar\n'
  elif sudo -n true 2>/dev/null; then
    printf 'ok\tsudo\tdisponível (sem senha agora)\n'
  else
    printf 'ok\tsudo\tvai pedir sua senha uma vez\n'
  fi
}

_pn_check_rede() {
  if ! has_cmd curl; then
    printf 'warn\tConectividade\tcurl ausente — não deu para testar (o módulo apt instala)\n'
    return 0
  fi
  if curl -fsS --connect-timeout 5 --max-time 8 -o /dev/null https://github.com 2>/dev/null; then
    printf 'ok\tConectividade\tgithub.com alcançável\n'
  else
    printf 'warn\tConectividade\tsem acesso: só módulos locais vão funcionar\n'
  fi
}

_pn_check_espaco() {
  local kb gb
  kb="$(df -Pk "$HOME" 2>/dev/null | awk 'NR==2 {print $4}')"
  if [[ -z "$kb" ]]; then
    printf 'warn\tEspaço\tnão foi possível medir %s\n' "$HOME"
    return 0
  fi
  gb=$((kb / 1024 / 1024))
  if (( gb >= 2 )); then
    printf 'ok\tEspaço\t%d GB livres em %s\n' "$gb" "$HOME"
  else
    printf 'warn\tEspaço\tsó %d GB livres (recomendado: 2 GB)\n' "$gb"
  fi
}

_pn_check_shell() {
  local zsh_path; zsh_path="$(command -v zsh || true)"
  if [[ -z "$zsh_path" ]]; then
    printf 'ok\tShell\tzsh será instalado\n'
  elif [[ "$(login_shell)" == "$zsh_path" ]]; then
    printf 'ok\tShell\tzsh já é o padrão\n'
  else
    printf 'warn\tShell\tzsh não é o padrão — o install resolve com chsh\n'
  fi
}

# pn_precheck_all — roda todos os checks. Retorna 1 se algum for fatal.
# Chame sempre com `|| true` (ou dentro de um `if`): sob `set -e`, capturar a
# saída de uma função que retorna 1 aborta o script antes de imprimir qualquer
# linha, e o usuário não veria nem o motivo da falha.
pn_precheck_all() {
  local saida
  saida="$(
    _pn_check_distro
    _pn_check_sudo
    _pn_check_rede
    _pn_check_espaco
    _pn_check_shell
  )"
  printf '%s\n' "$saida"
  ! printf '%s\n' "$saida" | grep -q '^fatal'
}
