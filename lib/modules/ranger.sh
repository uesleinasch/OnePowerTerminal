# shellcheck shell=bash
# Module: ranger — gerenciador de arquivos no terminal, com a config do repo.

mod_ranger_meta() { echo "ranger: gerenciador de arquivos no terminal"; }

mod_ranger_cost() { printf '1\t5\t1\n'; }

mod_ranger_name() { echo "ranger"; }

mod_ranger_category() { echo extras; }

mod_ranger_installed() { has_cmd ranger; }

mod_ranger_links() { pn_config_links ranger; }

mod_ranger_install() {
  apt_install ranger
  pn_link_module_links ranger
}

mod_ranger_update() {
  if pn_receipt_has_entry ranger apt ranger; then
    apt_upgrade_instalados ranger
  else
    log_info "ranger não foi instalado pelo PowerTerminal — pulado."
  fi
}

mod_ranger_doctor() {
  if has_cmd ranger; then
    status_line 1 "ranger: $(command -v ranger)"
  else
    status_line 0 "ranger: não encontrado"
  fi
  if [[ -L "$HOME/.config/ranger" ]]; then
    status_line 1 "ranger (config): linkada"
  else
    status_line 0 "ranger (config): não linkada"
  fi
}

mod_ranger_remove() { pn_receipt_undo ranger; }
