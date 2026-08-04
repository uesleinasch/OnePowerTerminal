# shellcheck shell=bash
# Module: fonts — MesloLGS NF (Powerlevel10k) + atualiza cache.

mod_fonts_meta() {
  echo "Fontes MesloLGS NF (necessárias para Powerlevel10k e ícones)"
}

mod_fonts_needs() { echo apt; }

mod_fonts_cost() { printf '1\t30\t1\n'; }

_PN_FONTS_DIR="$HOME/.local/share/fonts"
_PN_FONTS=(
  "MesloLGS NF Regular.ttf|https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Regular.ttf"
  "MesloLGS NF Bold.ttf|https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Bold.ttf"
  "MesloLGS NF Italic.ttf|https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Italic.ttf"
  "MesloLGS NF Bold Italic.ttf|https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Bold%20Italic.ttf"
)

mod_fonts_install() {
  run mkdir -p "$_PN_FONTS_DIR"
  for entry in "${_PN_FONTS[@]}"; do
    local file="${entry%%|*}"
    local url="${entry#*|}"
    local dst="$_PN_FONTS_DIR/$file"
    if [[ -f "$dst" ]]; then
      log_info "OK: $file"
    else
      download_to "$url" "$dst"
    fi
  done
  log_info "Atualizando cache de fontes…"
  if has_cmd fc-cache; then
    run fc-cache -f "$_PN_FONTS_DIR" >/dev/null
  else
    log_warn "fc-cache não encontrado — instale 'fontconfig' ou rode o módulo apt antes."
  fi
}

mod_fonts_doctor() {
  if has_cmd fc-list && fc-list 2>/dev/null | grep -qi "MesloLGS NF"; then
    status_line 1 "fonts: MesloLGS NF instalada"
  else
    status_line 0 "fonts: MesloLGS NF NÃO instalada (P10k mostrará ícones quebrados)"
  fi
}
