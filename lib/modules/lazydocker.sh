# shellcheck shell=bash
# Module: lazydocker — TUI para docker, com a config do repo.

mod_lazydocker_meta() { echo "lazydocker: TUI para docker"; }

mod_lazydocker_cost() { printf '1\t20\t0\n'; }

mod_lazydocker_name() { echo "lazydocker"; }

mod_lazydocker_category() { echo dev; }

mod_lazydocker_about() {
  echo "Instala o lazydocker, uma interface de terminal para o Docker, pelo script oficial em ~/.local/bin, e liga ~/.config/lazydocker à configuração do repositório. Ele só é útil com Docker ou Podman instalados. Remover apaga o binário e o link que o PowerTerminal criou."
}

mod_lazydocker_provides() {
  printf 'bin\t%s/.local/bin/lazydocker\n' "$HOME"
  printf 'config\t%s/.config/lazydocker\n' "$HOME"
}

mod_lazydocker_adopt() {
  _pn_adopt_path file "$HOME/.local/bin/lazydocker" lazydocker
}

mod_lazydocker_installed() { has_cmd lazydocker; }

mod_lazydocker_requires() { printf 'curl\tcurl\n'; }

mod_lazydocker_links() { pn_config_links lazydocker; }

mod_lazydocker_install() {
  ensure_local_bin
  _vf_install_lazydocker
  pn_link_module_links lazydocker
}

_vf_install_lazydocker() {
  if [[ "${1:-}" != force ]] && has_cmd lazydocker; then log_info "OK: lazydocker presente"; return 0; fi
  log_info "Instalando lazydocker…"
  if [[ "$DRY_RUN" == "1" ]]; then
    log_dry "DIR=~/.local/bin curl .../install_update_linux.sh | bash"
    return 0
  fi
  local existia=0
  _pn_existe "$HOME/.local/bin/lazydocker" && existia=1
  DIR="$HOME/.local/bin" curl -fsSL --connect-timeout 15 --max-time 300 \
    https://raw.githubusercontent.com/jesseduffield/lazydocker/master/scripts/install_update_linux.sh \
    | bash
  _pn_receipt_criado "$existia" file "$HOME/.local/bin/lazydocker"
}

mod_lazydocker_update() {
  ensure_local_bin
  if pn_receipt_has_entry lazydocker file "$HOME/.local/bin/lazydocker"; then
    _vf_install_lazydocker force
  else
    log_info "lazydocker não foi instalado pelo PowerTerminal — pulado."
  fi
}

mod_lazydocker_doctor() {
  if has_cmd lazydocker; then
    status_line 1 "lazydocker: $(command -v lazydocker)"
  else
    status_line 0 "lazydocker: não encontrado"
  fi
  if [[ -L "$HOME/.config/lazydocker" ]]; then
    status_line 1 "lazydocker (config): linkada"
  else
    status_line 0 "lazydocker (config): não linkada"
  fi
}

mod_lazydocker_remove() { pn_receipt_undo lazydocker; }
