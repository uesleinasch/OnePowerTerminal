# shellcheck shell=bash
# ui.sh — camada de UI com dois backends: gum (preferido) e texto (fallback).
# O backend é resolvido uma vez e cacheado.

_PN_UI_BACKEND=""

# _ui_gum_bin — caminho do gum utilizável, ou vazio.
# O binário vendorizado é x86_64; em outra arquitetura só serve um gum do PATH.
_ui_gum_bin() {
  local vend="${POWERTERMINAL_HOME:-}/vendor/gum"
  if [[ "$(uname -m)" == "x86_64" && -x "$vend" ]]; then
    printf '%s\n' "$vend"
    return 0
  fi
  command -v gum 2>/dev/null || true
}

# Resolve na global: ui_backend é sempre consumida via $(...), e uma atribuição
# feita lá dentro morreria com o subshell.
_ui_resolve_backend() {
  [[ -n "$_PN_UI_BACKEND" ]] && return 0
  if [[ -n "${POWERTERMINAL_UI:-}" ]]; then
    _PN_UI_BACKEND="$POWERTERMINAL_UI"
  elif [[ -n "$(_ui_gum_bin)" ]]; then
    _PN_UI_BACKEND="gum"
  else
    _PN_UI_BACKEND="text"
  fi
}

ui_backend() {
  _ui_resolve_backend
  printf '%s\n' "$_PN_UI_BACKEND"
}

# ui_choose TÍTULO id:desc… — ecoa o id escolhido. Default: a primeira opção.
ui_choose() {
  local titulo="$1"; shift
  local pares=("$@")
  [[ ${#pares[@]} -gt 0 ]] || return 1

  _ui_resolve_backend
  if [[ "$_PN_UI_BACKEND" == "gum" ]]; then
    _ui_choose_gum "$titulo" "${pares[@]}"
  else
    _ui_choose_text "$titulo" "${pares[@]}"
  fi
}

_ui_choose_text() {
  local titulo="$1"; shift
  local pares=("$@") i=1 p
  printf '\n%s%s%s\n' "$C_B" "$titulo" "$C_R" >&2
  for p in "${pares[@]}"; do
    printf '  %d) %-12s %s\n' "$i" "${p%%:*}" "${p#*:}" >&2
    i=$((i + 1))
  done
  printf 'Escolha [1-%d, ENTER=1]: ' "${#pares[@]}" >&2
  local ans=""
  read -r ans || true
  if [[ "$ans" =~ ^[0-9]+$ ]] && (( ans >= 1 && ans <= ${#pares[@]} )); then
    printf '%s\n' "${pares[$((ans - 1))]%%:*}"
  else
    printf '%s\n' "${pares[0]%%:*}"
  fi
}

_ui_choose_gum() {
  local titulo="$1"; shift
  local pares=("$@") rotulos=() p escolha
  for p in "${pares[@]}"; do rotulos+=("${p%%:*} — ${p#*:}"); done
  escolha="$("$(_ui_gum_bin)" choose --header "$titulo" "${rotulos[@]}")" || {
    printf '%s\n' "${pares[0]%%:*}"
    return 0
  }
  printf '%s\n' "${escolha%% —*}"
}

# ui_select_modules id:desc… — ecoa os ids escolhidos, um por linha.
ui_select_modules() {
  local pares=("$@")
  _ui_resolve_backend
  if [[ "$_PN_UI_BACKEND" == "gum" ]]; then
    _ui_select_gum "${pares[@]}"
  else
    _ui_select_text "${pares[@]}"
  fi
}

_ui_select_text() {
  local pares=("$@") i=1 p n
  printf '\n%sMódulos%s (ENTER = todos):\n' "$C_B" "$C_R" >&2
  for p in "${pares[@]}"; do
    printf '  %d) %-12s %s\n' "$i" "${p%%:*}" "${p#*:}" >&2
    i=$((i + 1))
  done
  printf 'Números separados por espaço: ' >&2
  local input=""
  read -r input || true
  if [[ -z "$input" ]]; then
    for p in "${pares[@]}"; do printf '%s\n' "${p%%:*}"; done
    return 0
  fi
  for n in $input; do
    if [[ "$n" =~ ^[0-9]+$ ]] && (( n >= 1 && n <= ${#pares[@]} )); then
      printf '%s\n' "${pares[$((n - 1))]%%:*}"
    fi
  done
}

_ui_select_gum() {
  local pares=("$@") rotulos=() p saida linha
  for p in "${pares[@]}"; do rotulos+=("${p%%:*} — ${p#*:}"); done
  # Cancelar devolve lista vazia de propósito: o chamador já trata isso com
  # "Nenhum módulo selecionado". Devolver tudo instalaria o que ninguém pediu.
  saida="$("$(_ui_gum_bin)" choose --no-limit --selected="*" \
    --header "Espaço alterna, Enter confirma" "${rotulos[@]}")" || return 0
  while IFS= read -r linha; do
    [[ -n "$linha" ]] && printf '%s\n' "${linha%% —*}"
  done <<< "$saida"
}

ui_confirm() {
  local msg="$1"
  [[ "${POWERTERMINAL_NONINTERACTIVE:-0}" == "1" ]] && return 0
  _ui_resolve_backend
  if [[ "$_PN_UI_BACKEND" == "gum" ]]; then
    "$(_ui_gum_bin)" confirm "$msg"
    return $?
  fi
  local ans=""
  printf '%s [y/N] ' "$msg" >&2
  read -r ans || true
  [[ "$ans" =~ ^[yY]$ ]]
}

# ---- Telas de apresentação ---------------------------------------------------
# Renderizadas em ANSI nos dois backends: são texto para ler, não interação.

ui_welcome() {
  local versao status rotulo detalhe
  versao="$(cat "${POWERTERMINAL_HOME}/VERSION" 2>/dev/null || echo '?')"
  printf '\n%s%sPowerTerminal%s %s\n' "$C_PURPLE" "$C_B" "$C_R" "$versao"
  printf '%sAmbiente Neovim/AstroNvim, Zsh, Kitty e CLIs.%s\n\n' "$C_GRAY" "$C_R"
  while IFS=$'\t' read -r status rotulo detalhe; do
    [[ -z "$status" ]] && continue
    case "$status" in
      ok)    printf '  %s✓%s %-16s %s%s%s\n' "$C_GREEN" "$C_R" "$rotulo" "$C_GRAY" "$detalhe" "$C_R" ;;
      warn)  printf '  %s!%s %-16s %s\n' "$C_YELLOW" "$C_R" "$rotulo" "$detalhe" ;;
      fatal) printf '  %s✗%s %-16s %s\n' "$C_RED" "$C_R" "$rotulo" "$detalhe" ;;
    esac
  done < <(pn_precheck_all || true)
  printf '\n'
}

# ui_summary MÓDULOS… — o que vai acontecer, antes de qualquer mudança.
ui_summary() {
  local modulos=("$@") m min mb sudo tot_min=0 tot_mb=0 precisa_sudo=0
  printf '\n%s%s▸ Vai ser instalado%s\n' "$C_PURPLE" "$C_B" "$C_R"
  for m in "${modulos[@]}"; do
    # `read` retorna 1 em EOF (saída vazia/sem newline final de um mod_X_cost
    # malformado); sem o `|| true` isso derrubaria o wizard inteiro sob set -e.
    IFS=$'\t' read -r min mb sudo < <("mod_${m}_cost") || true
    # Um cost malformado não pode derrubar a tela: sob `set -u`, um valor não
    # numérico em $(( )) aborta com "variável não associada".
    if ! [[ "$min" =~ ^[0-9]+$ && "$mb" =~ ^[0-9]+$ ]]; then
      log_warn "mod_${m}_cost devolveu valor inesperado — somando como zero"
      min=0
      mb=0
    fi
    [[ "$sudo" == "1" ]] || sudo=0
    tot_min=$((tot_min + min))
    tot_mb=$((tot_mb + mb))
    [[ "$sudo" == "1" ]] && precisa_sudo=1
    printf '  %s✓%s %-11s %s%s%s\n' "$C_GREEN" "$C_R" "$m" "$C_GRAY" "$("mod_${m}_meta")" "$C_R"
  done
  local plural="módulos"
  [[ "${#modulos[@]}" -eq 1 ]] && plural="módulo"
  printf '\n  %d %s · ~%d min · %d MB\n' "${#modulos[@]}" "$plural" "$tot_min" "$tot_mb"
  [[ "$precisa_sudo" == "1" ]] && printf '  %sPede sua senha uma vez, agora.%s\n' "$C_YELLOW" "$C_R"
  printf '  %sNão toca em: git, ~/.gitconfig, ~/.npmrc, GNOME.%s\n\n' "$C_GRAY" "$C_R"
  return 0
}

# ui_final SUCESSOS FALHAS — duas strings com nomes separados por espaço.
ui_final() {
  local sucessos="$1" falhas="$2" m
  printf '\n%s%s▸ Pronto%s\n' "$C_PURPLE" "$C_B" "$C_R"
  local n_ok plural_ok
  n_ok="$(printf '%s' "$sucessos" | wc -w)"
  plural_ok="módulos instalados"
  [[ "$n_ok" -eq 1 ]] && plural_ok="módulo instalado"
  printf '  %s✓%s %d %s\n' "$C_GREEN" "$C_R" "$n_ok" "$plural_ok"
  if [[ -n "$falhas" ]]; then
    printf '\n'
    for m in $falhas; do
      printf '  %s✗%s %-11s → powerterminal install --module %s\n' "$C_RED" "$C_R" "$m" "$m"
    done
  fi
  print_post_install_notes
  printf '\n  %sAgora:%s\n' "$C_B" "$C_R"
  printf '    1. exec zsh\n'
  printf '    2. abra o nvim (o Lazy instala os plugins sozinho)\n'
  printf '    3. powerterminal doctor\n\n'
  return 0
}

# ---- Execução observável -----------------------------------------------------
_PN_LOG_FILE=""

# Resolve na global e precisa ser chamada SEM $(...), uma vez, antes do laço de
# módulos: pn_log_file é consumida via $(...), e a atribuição feita dentro desse
# subshell morreria com ele — o nome mudaria a cada virada de segundo, espalhando
# o log da execução por vários arquivos.
_pn_resolve_log_file() {
  [[ -n "$_PN_LOG_FILE" ]] && return 0
  # Em dry-run nada pode tocar o disco — nem o diretório de log, nem o arquivo.
  if [[ "${DRY_RUN:-0}" == "1" ]]; then
    _PN_LOG_FILE="/dev/null"
    return 0
  fi
  local dir="${XDG_STATE_HOME:-$HOME/.local/state}/powerterminal"
  mkdir -p "$dir"
  _PN_LOG_FILE="$dir/install-$(date +%Y%m%d%H%M%S).log"
}

pn_log_file() {
  _pn_resolve_log_file
  printf '%s\n' "$_PN_LOG_FILE"
}

ui_step_begin() { printf '  %s⠿%s %-11s %sinstalando…%s\n' "$C_BLUE" "$C_R" "$1" "$C_GRAY" "$C_R"; }
ui_step_ok()    { printf '  %s✓%s %-11s %s%ss%s\n' "$C_GREEN" "$C_R" "$1" "$C_GRAY" "$2" "$C_R"; }
ui_step_fail()  { printf '  %s✗%s %-11s %sfalhou — veja o log%s\n' "$C_RED" "$C_R" "$1" "$C_RED" "$C_R"; }
