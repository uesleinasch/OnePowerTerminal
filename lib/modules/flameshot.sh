# shellcheck shell=bash
# Module: flameshot — captura de tela com anotações, com a config do repo.

mod_flameshot_meta() { echo "flameshot: captura de tela com anotações"; }

mod_flameshot_cost() { printf '1\t10\t1\n'; }

mod_flameshot_name() { echo "flameshot"; }

mod_flameshot_category() { echo extras; }

mod_flameshot_installed() { has_cmd flameshot; }

mod_flameshot_links() { pn_config_links flameshot; }

mod_flameshot_install() {
  apt_install flameshot
  pn_link_module_links flameshot
}

mod_flameshot_update() {
  if pn_receipt_has_entry flameshot apt flameshot; then
    apt_upgrade_instalados flameshot
  else
    log_info "flameshot não foi instalado pelo PowerTerminal — pulado."
  fi
}

mod_flameshot_doctor() {
  if has_cmd flameshot; then
    status_line 1 "flameshot: $(command -v flameshot)"
  else
    status_line 0 "flameshot: não encontrado"
  fi
  if [[ -L "$HOME/.config/flameshot" ]]; then
    status_line 1 "flameshot (config): linkada"
  else
    status_line 0 "flameshot (config): não linkada"
  fi
}

mod_flameshot_remove() { pn_receipt_undo flameshot; }
