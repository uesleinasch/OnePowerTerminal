# shellcheck shell=bash
# Module: kitty — instala o Kitty seguindo o método oficial em
# https://sw.kovidgoyal.net/kitty/binary/ e linka kitty.conf do PowerTerminal.

mod_kitty_meta() {
  echo "Terminal Kitty (~/.local/kitty.app, método oficial) + symlink da kitty.conf"
}

mod_kitty_cost() { printf '2\t100\t0\n'; }

mod_kitty_name() { echo "Kitty"; }

mod_kitty_category() { echo terminal; }

mod_kitty_about() {
  echo "Instala o terminal Kitty pelo instalador oficial em ~/.local/kitty.app, liga kitty e kitten em ~/.local/bin, copia os atalhos do menu e liga ~/.config/kitty à configuração do repositório. Tudo fica no seu HOME, sem sudo. Remover apaga a instalação, os links e os atalhos que o PowerTerminal criou."
}

mod_kitty_provides() {
  printf 'dir\t%s\n' "$_PN_KITTY_DIR"
  printf 'bin\t%s/.local/bin/kitty\n' "$HOME"
  printf 'bin\t%s/.local/bin/kitten\n' "$HOME"
  printf 'config\t%s/.config/kitty\n' "$HOME"
  printf 'config\t%s/.local/share/applications/kitty.desktop\n' "$HOME"
  printf 'config\t%s/.local/share/applications/kitty-open.desktop\n' "$HOME"
}

mod_kitty_installed() { [[ -x "$_PN_KITTY_DIR/bin/kitty" ]]; }

mod_kitty_requires() { printf 'curl\tcurl\nxz\txz-utils\n'; }

_PN_KITTY_DIR="$HOME/.local/kitty.app"
_PN_KITTY_INSTALLER="https://sw.kovidgoyal.net/kitty/installer.sh"

mod_kitty_install() {
  ensure_local_bin
  pn_step 1 4 "Instalando o Kitty…"
  _vf_install_kitty_binary
  pn_step 2 4 "Linkando kitty e kitten em ~/.local/bin…"
  _vf_link_kitty_binaries
  pn_step 3 4 "Instalando os atalhos do menu…"
  _vf_install_kitty_desktop
  pn_step 4 4 "Linkando a configuração do Kitty…"
  link_safe "$POWERTERMINAL_HOME/home/.config/kitty" "$HOME/.config/kitty"
}

mod_kitty_update() {
  if ! pn_receipt_has_entry kitty dir "$_PN_KITTY_DIR"; then
    log_info "O Kitty em $_PN_KITTY_DIR não foi instalado pelo PowerTerminal — nada a atualizar."
    return 0
  fi
  log_info "Atualizando o Kitty (instalador oficial)…"
  _vf_install_kitty_binary force
}

# Passo 1 do guia oficial: curl -L .../installer.sh | sh /dev/stdin
_vf_install_kitty_binary() {
  if [[ "${1:-}" != force && -x "$_PN_KITTY_DIR/bin/kitty" ]]; then
    log_info "OK: Kitty já instalado em $_PN_KITTY_DIR"
    return 0
  fi
  log_info "Método oficial: $_PN_KITTY_INSTALLER"
  if [[ "$DRY_RUN" == "1" ]]; then
    log_dry "curl -L $_PN_KITTY_INSTALLER | sh /dev/stdin"
    return 0
  fi
  local existia=0
  _pn_existe "$_PN_KITTY_DIR" && existia=1
  # -f: sem ele, uma página de erro HTTP seria canalizada para o sh.
  curl -fL --connect-timeout 15 --max-time 600 "$_PN_KITTY_INSTALLER" | sh /dev/stdin \
    || die "Kitty installer falhou."
  _pn_receipt_criado "$existia" dir "$_PN_KITTY_DIR"
}

# Passo 2 do guia oficial: symlinks dos binários para o PATH do usuário.
_vf_link_kitty_binaries() {
  link_safe "$_PN_KITTY_DIR/bin/kitty"  "$HOME/.local/bin/kitty"
  link_safe "$_PN_KITTY_DIR/bin/kitten" "$HOME/.local/bin/kitten"
}

# Passo 3 do guia oficial: copiar .desktop e atualizar Icon/Exec absolutos.
_vf_install_kitty_desktop() {
  local apps_src="$_PN_KITTY_DIR/share/applications"
  local apps_dst="$HOME/.local/share/applications"
  [[ -d "$apps_src" ]] || { log_warn "kitty: $apps_src não existe — pulando atalhos do menu"; return 0; }

  run mkdir -p "$apps_dst"
  if [[ "$DRY_RUN" == "1" ]]; then
    log_dry "cp $apps_src/kitty*.desktop $apps_dst/"
    log_dry "sed -i 's|Icon=kitty|Icon=$_PN_KITTY_DIR/share/icons/.../kitty.png|' $apps_dst/kitty*.desktop"
    log_dry "sed -i 's|Exec=kitty|Exec=$_PN_KITTY_DIR/bin/kitty|'  $apps_dst/kitty*.desktop"
    return 0
  fi

  for f in "$apps_src"/*.desktop; do
    [[ -f "$f" ]] || continue
    local dst existia=0
    dst="$apps_dst/$(basename "$f")"
    [[ -e "$dst" ]] && existia=1
    cp -f "$f" "$dst"
    [[ "$existia" == 1 ]] || _pn_receipt file "$dst"
  done

  # Substituições recomendadas pelo upstream para que o launcher use o caminho real.
  sed -i "s|Icon=kitty|Icon=$_PN_KITTY_DIR/share/icons/hicolor/256x256/apps/kitty.png|g" \
    "$apps_dst"/kitty*.desktop 2>/dev/null || true
  sed -i "s|Exec=kitty|Exec=$_PN_KITTY_DIR/bin/kitty|g" \
    "$apps_dst"/kitty*.desktop 2>/dev/null || true
}

mod_kitty_links() {
  printf '%s\t%s\n' "$_PN_KITTY_DIR/bin/kitty"  "$HOME/.local/bin/kitty"
  printf '%s\t%s\n' "$_PN_KITTY_DIR/bin/kitten" "$HOME/.local/bin/kitten"
  printf '%s\t%s\n' "$POWERTERMINAL_HOME/home/.config/kitty" "$HOME/.config/kitty"
}

mod_kitty_doctor() {
  if [[ -x "$_PN_KITTY_DIR/bin/kitty" ]]; then
    status_line 1 "kitty: $($_PN_KITTY_DIR/bin/kitty --version 2>/dev/null | head -1)"
  else
    status_line 0 "kitty: não instalado em $_PN_KITTY_DIR"
  fi
  [[ -L "$HOME/.config/kitty" ]] && status_line 1 "kitty config: linkado" || status_line 0 "kitty config: não linkado"
}

mod_kitty_deduce() {
  [[ -d "$_PN_KITTY_DIR" ]] || return 0
  pn_receipt_add dir "$_PN_KITTY_DIR"
  local b
  for b in kitty kitten; do
    [[ -L "$HOME/.local/bin/$b" ]] || continue
    [[ "$(readlink "$HOME/.local/bin/$b")" == "$_PN_KITTY_DIR/bin/"* ]] && pn_receipt_add link "$HOME/.local/bin/$b"
  done
  return 0
}

mod_kitty_remove() { pn_receipt_undo kitty; }
