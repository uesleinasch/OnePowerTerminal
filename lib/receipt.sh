# shellcheck shell=bash

pn_receipt_dir() {
  if [[ -n "${PN_RECEIPT_DIR:-}" ]]; then
    printf '%s\n' "$PN_RECEIPT_DIR"
  else
    printf '%s/powerterminal/receipts\n' "${XDG_STATE_HOME:-$HOME/.local/state}"
  fi
}

pn_receipt_path() { printf '%s/%s\n' "$(pn_receipt_dir)" "$1"; }

pn_receipt_has() { [[ -f "$(pn_receipt_path "$1")" ]]; }

pn_receipt_origin() {
  local f; f="$(pn_receipt_path "$1")"
  [[ -f "$f" ]] || return 0
  awk -F'\t' '$1 == "origin" {print $2; exit}' "$f"
}

pn_receipt_entries() {
  local f; f="$(pn_receipt_path "$1")"
  [[ -f "$f" ]] || return 0
  awk -F'\t' -v t="${2:-}" '$1 != "origin" && (t == "" || $1 == t)' "$f"
}

pn_receipt_add() {
  local mod="${PN_RECEIPT_MODULE:-}"
  [[ -n "$mod" && "${DRY_RUN:-0}" != "1" ]] || return 0
  local f linha
  f="$(pn_receipt_path "$mod")"
  linha="$(printf '%s\t%s' "$1" "$2")"
  if [[ ! -f "$f" ]]; then
    mkdir -p "$(dirname "$f")"
    printf 'origin\tinstalled\n' >"$f"
  fi
  grep -qxF -- "$linha" "$f" || printf '%s\n' "$linha" >>"$f"
}

# Sem nenhum link do PowerTerminal na máquina, ~/.nvm, kitty.app e afins são do
# próprio usuário: deduzir recibo deles faria o remove apagá-los.
_pn_tem_link_do_repo() {
  local m src dst
  for m in "${_PN_ALL_MODULES[@]}"; do
    declare -F "mod_${m}_links" >/dev/null || continue
    while IFS=$'\t' read -r src dst; do
      [[ -n "$dst" && -L "$dst" && "$(readlink "$dst")" == "$POWERTERMINAL_HOME"/* ]] && return 0
    done < <("mod_${m}_links")
  done
  return 1
}

pn_receipts_migrate() {
  [[ "${DRY_RUN:-0}" != "1" ]] || return 0
  local dir marker m f src dst alvo
  dir="$(pn_receipt_dir)"
  marker="$dir/.migrated-v1"
  [[ ! -e "$marker" ]] || return 0
  if ! _pn_tem_link_do_repo; then
    mkdir -p "$dir"
    : >"$marker"
    return 0
  fi
  for m in "${_PN_ALL_MODULES[@]}"; do
    declare -F "mod_${m}_installed" >/dev/null || continue
    pn_receipt_has "$m" && continue
    "mod_${m}_installed" || continue
    f="$(pn_receipt_path "$m")"
    mkdir -p "$dir"
    printf 'origin\tdeduced\n' >"$f"
    if declare -F "mod_${m}_links" >/dev/null; then
      while IFS=$'\t' read -r src dst; do
        [[ -n "$dst" && -L "$dst" ]] || continue
        alvo="$(readlink "$dst")"
        [[ "$alvo" == "$POWERTERMINAL_HOME"/* ]] && PN_RECEIPT_MODULE="$m" pn_receipt_add link "$dst"
      done < <("mod_${m}_links")
    fi
    if declare -F "mod_${m}_deduce" >/dev/null; then
      PN_RECEIPT_MODULE="$m" "mod_${m}_deduce"
    fi
    [[ -n "$(pn_receipt_entries "$m")" ]] || rm -f "$f"
  done
  mkdir -p "$dir"
  : >"$marker"
}

_pn_norm_path() {
  local p="$1" duas='//' uma='/'
  while [[ "$p" == *//* ]]; do p="${p//"$duas"/"$uma"}"; done
  while [[ "$p" == ?*/ ]]; do p="${p%/}"; done
  printf '%s' "$p"
}

# Imprime por que o undo não pode apagar P (vazio = pode). Um recibo corrompido
# ou forjado nunca pode virar rm -rf de algo que não foi o PowerTerminal que
# criou: só valem caminhos sob $HOME, /opt e /usr/local, nunca as raízes que
# guardam coisas de outros programas, nem o próprio repositório.
_pn_undo_path_motivo() {
  local p="$1" home="$2" parte rel repo n=0
  local -a partes=()
  [[ -n "$p" ]] || { echo "caminho vazio"; return 0; }
  [[ "$p" == /* ]] || { echo "caminho não absoluto"; return 0; }
  IFS=/ read -ra partes <<<"${p#/}"
  for parte in "${partes[@]}"; do
    [[ "$parte" == . || "$parte" == .. ]] && { echo "componente . ou .."; return 0; }
    n=$((n + 1))
  done
  (( n >= 2 )) || { echo "menos de dois componentes"; return 0; }
  if [[ -n "$home" && "$home" != / && "$p" == "$home" ]]; then
    echo "é o próprio \$HOME"; return 0
  elif [[ -n "$home" && "$home" != / && "$p" == "$home"/* ]]; then
    for rel in .config .config/autostart .config/systemd .config/systemd/user .local .local/bin \
      .local/lib .local/share .local/share/applications .local/share/fonts .local/share/icons \
      .local/state .cache .ssh .gnupg; do
      [[ "$p" == "$home/$rel" ]] && { echo "diretório compartilhado do \$HOME"; return 0; }
    done
  elif [[ "$p" == /opt/* ]]; then
    :
  elif [[ "$p" == /usr/local/* ]]; then
    (( n >= 4 )) || { echo "diretório compartilhado de /usr/local"; return 0; }
  else
    echo "fora de \$HOME, /opt e /usr/local"; return 0
  fi
  [[ -n "${POWERTERMINAL_HOME:-}" ]] || return 0
  for repo in "$(_pn_norm_path "$POWERTERMINAL_HOME")" "$(readlink -f -- "$POWERTERMINAL_HOME" 2>/dev/null || true)"; do
    [[ -n "$repo" ]] || continue
    if [[ "$p" == "$repo" || "$p" == "$repo"/* || "$repo" == "$p"/* ]]; then
      echo "contém o repositório do PowerTerminal"; return 0
    fi
  done
  return 0
}

# Resolve só os diretórios-pai: o último componente, se for symlink, é o que se
# apaga (o link), nunca o alvo dele.
_pn_undo_real_path() {
  local pai
  pai="$(readlink -f -- "$(dirname -- "$1")")" || return 1
  [[ -n "$pai" ]] || return 1
  [[ "$pai" == / ]] && pai=""
  printf '%s/%s' "$pai" "$(basename -- "$1")"
}

_pn_undo_path() {
  local tipo="$1" valor="$2" p home real home_real motivo
  p="$(_pn_norm_path "$valor")"
  home="$(_pn_norm_path "${HOME:-}")"
  motivo="$(_pn_undo_path_motivo "$p" "$home")"
  if [[ -z "$motivo" && ( -e "$p" || -L "$p" ) ]]; then
    home_real="$(readlink -f -- "$home" 2>/dev/null || true)"
    if real="$(_pn_undo_real_path "$p")"; then
      motivo="$(_pn_undo_path_motivo "$real" "$home_real")"
      [[ -z "$motivo" ]] || motivo="resolve para $real: $motivo"
    else
      motivo="não deu para resolver o caminho"
    fi
  fi
  if [[ -z "$motivo" && "$tipo" == file && -d "$p" && ! -L "$p" ]]; then
    motivo="registrado como arquivo, mas é um diretório"
  fi
  if [[ -n "$motivo" ]]; then
    log_warn "Recusado: $tipo '$valor' ($motivo) — mantido no recibo."
    return 1
  fi
  if [[ ! -e "$p" && ! -L "$p" ]]; then
    log_info "Já ausente: $p"
    return 0
  fi
  local -a cmd=(rm -rf --one-file-system -- "$p")
  [[ -L "$p" ]] && cmd=(rm -f -- "$p")
  log_info "Removendo $p"
  if [[ "$p" == "$home"/* ]]; then
    run "${cmd[@]}"
  else
    as_sudo "${cmd[@]}"
  fi
}

_pn_undo_link() {
  local p
  p="$(_pn_norm_path "$1")"; shift
  if [[ "$p" != /?* || "/$p/" == */./* || "/$p/" == */../* ]]; then
    log_warn "Recusado: link '$p' (caminho inválido) — mantido no recibo."
    return 1
  fi
  unlink_safe "$p" "$@"
}

_pn_user_in_group() {
  getent group "$1" 2>/dev/null | cut -d: -f4 | tr ',' '\n' | grep -qxF -- "$2"
}

_pn_apt_em_outro_recibo() {
  local f linha
  linha="$(printf 'apt\t%s' "$2")"
  for f in "$(pn_receipt_dir)"/*; do
    [[ -f "$f" && "${f##*/}" != "$1" ]] || continue
    grep -qxF -- "$linha" "$f" && return 0
  done
  return 1
}

_pn_undo_login_shell() {
  local sh="$1" usuario
  if [[ "$sh" != /* ]] || ! grep -qxF -- "$sh" /etc/shells 2>/dev/null || [[ ! -x "$sh" ]]; then
    log_warn "Recusado: login_shell '$sh' (não está em /etc/shells) — mantido no recibo."
    return 1
  fi
  if [[ "$(login_shell)" == "$sh" ]]; then
    log_info "O shell padrão já é $sh."
    return 0
  fi
  usuario="$(id -un)"
  as_sudo chsh -s "$sh" "$usuario" || return 1
  [[ "$DRY_RUN" == "1" ]] || pn_session_restart "o shell padrão volta a ser $sh no próximo login"
}

_pn_undo_group() {
  local g="$1" usuario
  usuario="$(id -un)"
  case "$g" in
    root|sudo|wheel|admin|adm)
      log_warn "Recusado: group '$g' (grupo de administração) — mantido no recibo."
      return 1 ;;
  esac
  if ! _pn_user_in_group "$g" "$usuario"; then
    log_info "$usuario já não está no grupo $g."
    return 0
  fi
  as_sudo gpasswd -d "$usuario" "$g" || return 1
  [[ "$DRY_RUN" == "1" ]] || pn_session_restart "a saída do grupo $g valer"
}

_pn_undo_subids() {
  local u="$1" s="${_PN_SUBID_RANGE_START:-}" e="${_PN_SUBID_RANGE_END:-}"
  if [[ "$u" != "$(id -un)" ]]; then
    log_warn "Recusado: subids '$u' (não é o usuário atual) — mantido no recibo."
    return 1
  fi
  if [[ ! "$s" =~ ^[0-9]+$ || ! "$e" =~ ^[0-9]+$ ]]; then
    log_warn "Intervalo de subids desconhecido — subids de $u mantidos no recibo."
    return 1
  fi
  as_sudo usermod --del-subuids "$s-$e" --del-subgids "$s-$e" "$u"
}

_pn_undo_pipx() {
  local p="$1" lista=""
  has_cmd pipx && lista="$(pipx list --short 2>/dev/null || true)"
  if [[ $'\n'"$(awk '{print $1}' <<<"$lista")"$'\n' != *$'\n'"$p"$'\n'* ]]; then
    log_info "Já ausente: pacote pipx $p."
    return 0
  fi
  run pipx uninstall "$p"
}

_pn_undo_user_unit() {
  local u="$1"
  if ! systemctl --user cat "$u" >/dev/null 2>&1; then
    log_info "Já ausente: unidade de usuário $u."
    return 0
  fi
  run systemctl --user disable --now "$u"
}

_pn_undo_apt_repo() {
  local n="$1"
  as_sudo rm -f "/etc/apt/keyrings/$n.asc" "/etc/apt/sources.list.d/$n.list" || return 1
  _PN_APT_UPDATED=""
  apt_update_once || log_warn "apt-get update falhou depois de remover o repositório $n."
  return 0
}

# Valida VALOR para TIPO antes de virar argumento de comando: nada que comece
# com "-" (seria lido como opção) nem que carregue "/" onde se espera um nome.
_pn_undo_valor_ok() {
  case "$1" in
    apt)       [[ "$2" =~ ^[a-z0-9][a-z0-9+.-]+(:[a-z0-9-]+)?$ ]] ;;
    apt_repo)  [[ "$2" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] ;;
    group)     [[ "$2" =~ ^[a-z_][a-z0-9_-]*$ ]] ;;
    pipx)      [[ "$2" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] ;;
    subids)    [[ "$2" =~ ^[A-Za-z0-9._@][A-Za-z0-9._@-]*\$?$ ]] ;;
    user_unit) [[ "$2" =~ ^[A-Za-z0-9][A-Za-z0-9@._:-]*$ ]] ;;
    *) return 0 ;;
  esac
}

# pn_receipt_undo MOD — desfaz o recibo em ordem inversa. Entrada que falha ou é
# recusada fica no recibo (e o retorno é 1); o recibo só some quando tudo saiu.
# Os pacotes apt vão numa purga única no fim, depois de o shell de login ter
# voltado — purgar o zsh antes deixaria o usuário com um shell inexistente.
pn_receipt_undo() {
  local mod="$1" f origin linha tipo valor i shell_falhou=0
  f="$(pn_receipt_path "$mod")"
  if [[ ! -f "$f" ]]; then
    log_info "Nada do PowerTerminal para desfazer em $mod."
    return 0
  fi
  origin="$(pn_receipt_origin "$mod")"
  local -a linhas=() donos=() idx_apt=() purgar=() idx_purgar=()
  local -A falhou=()
  mapfile -t linhas < <(pn_receipt_entries "$mod")

  for linha in "${linhas[@]+"${linhas[@]}"}"; do
    [[ "$linha" == dir$'\t'* ]] || continue
    valor="$(_pn_norm_path "${linha#*$'\t'}")"
    [[ -z "$(_pn_undo_path_motivo "$valor" "$(_pn_norm_path "${HOME:-}")")" ]] && donos+=("$valor")
  done

  for (( i = ${#linhas[@]} - 1; i >= 0; i-- )); do
    linha="${linhas[i]}"
    tipo="${linha%%$'\t'*}"
    valor=""
    [[ "$linha" == *$'\t'* ]] && valor="${linha#*$'\t'}"
    if ! _pn_undo_valor_ok "$tipo" "$valor"; then
      log_warn "Recusado: $tipo '$valor' (valor inválido) — mantido no recibo."
      falhou[$i]=1
      continue
    fi
    case "$tipo" in
      "")          ;;
      apt)         idx_apt+=("$i") ;;
      link)        _pn_undo_link "$valor" "${donos[@]+"${donos[@]}"}" ;;
      dir|file)    _pn_undo_path "$tipo" "$valor" ;;
      apt_repo)    _pn_undo_apt_repo "$valor" ;;
      login_shell) _pn_undo_login_shell "$valor" || { shell_falhou=1; false; } ;;
      group)       _pn_undo_group "$valor" ;;
      pipx)        _pn_undo_pipx "$valor" ;;
      subids)      _pn_undo_subids "$valor" ;;
      user_unit)   _pn_undo_user_unit "$valor" ;;
      *)           log_warn "Recusado: tipo desconhecido '$tipo' — mantido no recibo."; false ;;
    esac || falhou[$i]=1
  done

  if (( ${#idx_apt[@]} > 0 && shell_falhou == 1 )); then
    log_warn "O shell padrão não voltou — os pacotes apt de $mod ficam instalados."
    for i in "${idx_apt[@]}"; do falhou[$i]=1; done
  elif (( ${#idx_apt[@]} > 0 )); then
    for i in "${idx_apt[@]}"; do
      valor="${linhas[i]#*$'\t'}"
      if _pn_apt_em_outro_recibo "$mod" "$valor"; then
        log_info "Mantido: $valor (outro módulo também o instalou)."
      elif ! dpkg -s "$valor" >/dev/null 2>&1; then
        log_info "Já ausente: pacote $valor."
      else
        purgar+=("$valor"); idx_purgar+=("$i")
      fi
    done
    if (( ${#purgar[@]} > 0 )); then
      log_info "Purgando: ${purgar[*]}"
      if ! as_sudo env DEBIAN_FRONTEND=noninteractive apt-get purge -y "${purgar[@]}"; then
        log_warn "apt-get purge falhou — ${purgar[*]} mantidos no recibo."
        for i in "${idx_purgar[@]}"; do falhou[$i]=1; done
      fi
    fi
  fi

  if (( ${#falhou[@]} == 0 )); then
    run rm -f "$f"
    return 0
  fi
  if [[ "${DRY_RUN:-0}" != "1" ]]; then
    {
      printf 'origin\t%s\n' "${origin:-installed}"
      for i in "${!linhas[@]}"; do
        if [[ -n "${falhou[$i]:-}" ]]; then printf '%s\n' "${linhas[i]}"; fi
      done
    } >"$f.tmp" && mv -f "$f.tmp" "$f"
  fi
  log_warn "$mod: ${#falhou[@]} entrada(s) não desfeita(s) — continuam no recibo."
  return 1
}
