# shellcheck shell=bash
# Module: picom — compositor X11 (transparência e sombras), com a config do repo.

mod_picom_meta() { echo "picom: compositor X11 (transparência e sombras)"; }

mod_picom_cost() { printf '1\t5\t1\n'; }

mod_picom_name() { echo "picom"; }

mod_picom_category() { echo extras; }

mod_picom_about() {
  echo "Instala o picom, um compositor X11 para transparência e sombras, pelo apt, e liga ~/.config/picom à configuração do repositório. Altera o sistema e pede sudo. Remover purga o pacote, se foi o PowerTerminal quem o instalou, e desfaz o link."
}

mod_picom_provides() {
  printf 'apt\tpicom\n'
  printf 'config\t%s/.config/picom\n' "$HOME"
}

mod_picom_adopt() {
  _pn_adopt_apt picom picom
}

mod_picom_installed() { has_cmd picom; }

mod_picom_links() { pn_config_links picom; }

mod_picom_install() {
  apt_install picom
  pn_link_module_links picom
}

mod_picom_update() {
  if pn_receipt_has_entry picom apt picom; then
    apt_upgrade_instalados picom
  else
    log_info "picom não foi instalado pelo PowerTerminal — pulado."
  fi
}

mod_picom_doctor() {
  if has_cmd picom; then
    status_line 1 "picom: $(command -v picom)"
  else
    status_line 0 "picom: não encontrado"
  fi
  if [[ -L "$HOME/.config/picom" ]]; then
    status_line 1 "picom (config): linkada"
  else
    status_line 0 "picom (config): não linkada"
  fi
}

mod_picom_remove() { pn_receipt_undo picom; }
