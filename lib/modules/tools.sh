# shellcheck shell=bash
# Module: tools — utilitários CLI extras (eza, starship, lazygit, lazydocker, uv, yazi).

mod_tools_meta() {
  echo "CLIs extras: eza, starship, lazygit, lazydocker, uv, yazi"
}

mod_tools_cost() { printf '3\t80\t0\n'; }

mod_tools_name() { echo "CLIs modernas"; }

mod_tools_category() { echo dev; }

mod_tools_installed() {
  local c
  for c in starship eza yazi lazygit lazydocker uv; do
    has_cmd "$c" || return 1
  done
}

mod_tools_requires() { printf 'curl\tcurl\n'; }

mod_tools_install() {
  ensure_local_bin
  _vf_install_starship
  _vf_install_eza
  _vf_install_yazi
  _vf_install_lazygit
  _vf_install_lazydocker
  _vf_install_uv
}

_vf_tools_nosso() { pn_receipt_has_entry tools file "$HOME/.local/bin/$1"; }

_vf_tools_pula() { log_info "$1 não foi instalado pelo PowerTerminal — pulado."; }

mod_tools_update() {
  if ! pn_receipt_has tools; then
    log_info "As CLIs extras não foram instaladas pelo PowerTerminal — nada a atualizar."
    return 0
  fi
  ensure_local_bin
  if _vf_tools_nosso starship; then _vf_install_starship force; else _vf_tools_pula starship; fi
  if _vf_tools_nosso eza; then
    _vf_install_eza_github
  elif pn_receipt_has_entry tools apt eza; then
    apt_upgrade_instalados eza
  else
    _vf_tools_pula eza
  fi
  if _vf_tools_nosso yazi; then _vf_install_yazi force; else _vf_tools_pula yazi; fi
  if _vf_tools_nosso lazygit; then _vf_install_lazygit force; else _vf_tools_pula lazygit; fi
  if _vf_tools_nosso lazydocker; then _vf_install_lazydocker force; else _vf_tools_pula lazydocker; fi
  if _vf_tools_nosso uv; then _vf_update_uv; else _vf_tools_pula uv; fi
}

_vf_update_uv() {
  log_info "Atualizando uv (uv self update)…"
  run "$HOME/.local/bin/uv" self update && return 0
  log_warn "uv self update falhou — reinstalando pelo instalador oficial."
  _vf_install_uv force
}

_vf_install_starship() {
  if [[ "${1:-}" != force ]] && has_cmd starship; then log_info "OK: starship presente"; return 0; fi
  log_info "Instalando starship…"
  local existia=0
  _pn_existe "$HOME/.local/bin/starship" && existia=1
  curl_pipe https://starship.rs/install.sh -y -b "$HOME/.local/bin"
  _pn_receipt_criado "$existia" file "$HOME/.local/bin/starship"
}

_vf_install_eza() {
  if has_cmd eza; then log_info "OK: eza presente"; return 0; fi
  if apt_install eza 2>/dev/null; then return 0; fi
  log_info "eza não está no apt — baixando binário do GitHub…"
  _vf_install_eza_github
}

_vf_install_eza_github() {
  require_x86_64 eza || return 0
  # Build musl (estática): a build -gnu recente exige glibc ≥ 2.39 e quebraria
  # no Ubuntu 22.04 (glibc 2.35) — mesma razão do yazi usar musl.
  install_github_binary \
    "https://github.com/eza-community/eza/releases/latest/download/eza_x86_64-unknown-linux-musl.tar.gz" \
    eza
}

_vf_install_yazi() {
  if [[ "${1:-}" != force ]] && has_cmd yazi; then log_info "OK: yazi presente"; return 0; fi
  require_x86_64 yazi || return 0
  log_info "Instalando yazi (file explorer no terminal)…"
  # Build musl (estática): independe da glibc do sistema (ex.: glibc < 2.39).
  # Traz dois binários: `yazi` (TUI) e `ya` (CLI/plugins).
  install_github_zip \
    "https://github.com/sxyazi/yazi/releases/latest/download/yazi-x86_64-unknown-linux-musl.zip" \
    yazi ya
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

_vf_install_uv() {
  if [[ "${1:-}" != force ]] && has_cmd uv; then log_info "OK: uv presente"; return 0; fi
  log_info "Instalando uv (Astral)…"
  local uv=0 uvx=0
  _pn_existe "$HOME/.local/bin/uv" && uv=1
  _pn_existe "$HOME/.local/bin/uvx" && uvx=1
  curl_pipe https://astral.sh/uv/install.sh
  _pn_receipt_criado "$uv" file "$HOME/.local/bin/uv"
  _pn_receipt_criado "$uvx" file "$HOME/.local/bin/uvx"
}

mod_tools_doctor() {
  for c in starship eza yazi ya lazygit lazydocker uv; do
    if has_cmd "$c"; then
      status_line 1 "$c: $(command -v "$c")"
    else
      status_line 0 "$c: não encontrado"
    fi
  done
}

mod_tools_remove() { pn_receipt_undo tools; }
