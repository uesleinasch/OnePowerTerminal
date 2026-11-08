# shellcheck shell=bash
# Module: btop — monitor de recursos no terminal, com a config do repo.

mod_btop_meta() { echo "btop: monitor de recursos no terminal"; }

mod_btop_cost() { printf '1\t5\t1\n'; }

mod_btop_name() { echo "btop"; }

mod_btop_category() { echo extras; }

mod_btop_about() {
  echo "Instala o btop, um monitor de recursos de terminal, pelo apt, e liga ~/.config/btop à configuração do repositório. Altera o sistema e pede sudo. Remover purga o pacote, se foi o PowerTerminal quem o instalou, e desfaz o link."
}

mod_btop_provides() {
  printf 'apt\tbtop\n'
  printf 'config\t%s/.config/btop\n' "$HOME"
}

mod_btop_adopt() {
  _pn_adopt_apt btop btop
}

mod_btop_installed() { has_cmd btop; }

mod_btop_links() { pn_config_links btop; }

mod_btop_install() {
  apt_install btop
  pn_link_module_links btop
}

mod_btop_update() {
  if pn_receipt_has_entry btop apt btop; then
    apt_upgrade_instalados btop
  else
    log_info "btop não foi instalado pelo PowerTerminal — pulado."
  fi
}

mod_btop_doctor() {
  if has_cmd btop; then
    status_line 1 "btop: $(command -v btop)"
  else
    status_line 0 "btop: não encontrado"
  fi
  if [[ -L "$HOME/.config/btop" ]]; then
    status_line 1 "btop (config): linkada"
  else
    status_line 0 "btop (config): não linkada"
  fi
}

mod_btop_remove() { pn_receipt_undo btop; }
