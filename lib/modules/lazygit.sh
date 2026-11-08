# shellcheck shell=bash
# Module: lazygit — TUI para git, com a config do repo.

mod_lazygit_meta() { echo "lazygit: TUI para git"; }

mod_lazygit_cost() { printf '1\t20\t0\n'; }

mod_lazygit_name() { echo "lazygit"; }

mod_lazygit_category() { echo dev; }

mod_lazygit_about() {
  echo "Instala o lazygit, uma interface de terminal para o git, baixando o binário da versão mais recente do GitHub para ~/.local/bin, e liga ~/.config/lazygit à configuração do repositório. Remover apaga o binário e o link que o PowerTerminal criou."
}

mod_lazygit_provides() {
  printf 'bin\t%s/.local/bin/lazygit\n' "$HOME"
  printf 'config\t%s/.config/lazygit\n' "$HOME"
}

mod_lazygit_adopt() {
  _pn_adopt_path file "$HOME/.local/bin/lazygit" lazygit
}

mod_lazygit_installed() { has_cmd lazygit; }

mod_lazygit_requires() { printf 'curl\tcurl\n'; }

mod_lazygit_links() { pn_config_links lazygit; }

mod_lazygit_install() {
  ensure_local_bin
  _vf_install_lazygit
  pn_link_module_links lazygit
}

_vf_install_lazygit() {
  if [[ "${1:-}" != force ]] && has_cmd lazygit; then log_info "OK: lazygit presente"; return 0; fi
  require_x86_64 lazygit || return 0
  if [[ "$DRY_RUN" == "1" ]]; then
    log_dry "install lazygit (resolveria a versão mais recente via API e baixaria o tarball)"
    return 0
  fi
  log_info "Instalando lazygit…"
  local ver
  ver="$(curl -fsSL --connect-timeout 15 --max-time 30 \
    https://api.github.com/repos/jesseduffield/lazygit/releases/latest \
    | grep -Po '"tag_name": "v\K[^"]+' || true)"
  [[ -z "$ver" ]] && ver="0.44.1"
  install_github_binary \
    "https://github.com/jesseduffield/lazygit/releases/download/v${ver}/lazygit_${ver}_Linux_x86_64.tar.gz" \
    lazygit
}

mod_lazygit_update() {
  ensure_local_bin
  if pn_receipt_has_entry lazygit file "$HOME/.local/bin/lazygit"; then
    _vf_install_lazygit force
  else
    log_info "lazygit não foi instalado pelo PowerTerminal — pulado."
  fi
}

mod_lazygit_doctor() {
  if has_cmd lazygit; then
    status_line 1 "lazygit: $(command -v lazygit)"
  else
    status_line 0 "lazygit: não encontrado"
  fi
  if [[ -L "$HOME/.config/lazygit" ]]; then
    status_line 1 "lazygit (config): linkada"
  else
    status_line 0 "lazygit (config): não linkada"
  fi
}

mod_lazygit_remove() { pn_receipt_undo lazygit; }
