# shellcheck shell=bash
# Module: tools — utilitários CLI extras (eza, starship, lazygit, lazydocker, uv, yazi).

mod_tools_meta() {
  echo "CLIs extras: eza, starship, lazygit, lazydocker, uv, yazi"
}

mod_tools_cost() { printf '3\t80\t0\n'; }

mod_tools_install() {
  ensure_local_bin
  _vf_install_starship
  _vf_install_eza
  _vf_install_yazi
  _vf_install_lazygit
  _vf_install_lazydocker
  _vf_install_uv
}

_vf_install_starship() {
  if has_cmd starship; then log_info "OK: starship presente"; return 0; fi
  log_info "Instalando starship…"
  curl_pipe https://starship.rs/install.sh -y -b "$HOME/.local/bin"
}

_vf_install_eza() {
  if has_cmd eza; then log_info "OK: eza presente"; return 0; fi
  if apt_install eza 2>/dev/null; then return 0; fi
  log_info "eza não está no apt — baixando binário do GitHub…"
  install_github_binary \
    "https://github.com/eza-community/eza/releases/latest/download/eza_x86_64-unknown-linux-gnu.tar.gz" \
    eza
}

_vf_install_yazi() {
  if has_cmd yazi; then log_info "OK: yazi presente"; return 0; fi
  log_info "Instalando yazi (file explorer no terminal)…"
  # Build musl (estática): independe da glibc do sistema (ex.: glibc < 2.39).
  # Traz dois binários: `yazi` (TUI) e `ya` (CLI/plugins).
  install_github_zip \
    "https://github.com/sxyazi/yazi/releases/latest/download/yazi-x86_64-unknown-linux-musl.zip" \
    yazi ya
}

_vf_install_lazygit() {
  if has_cmd lazygit; then log_info "OK: lazygit presente"; return 0; fi
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
  if has_cmd lazydocker; then log_info "OK: lazydocker presente"; return 0; fi
  log_info "Instalando lazydocker…"
  if [[ "$DRY_RUN" == "1" ]]; then
    log_dry "DIR=~/.local/bin curl .../install_update_linux.sh | bash"
    return 0
  fi
  DIR="$HOME/.local/bin" curl -fsSL --connect-timeout 15 --max-time 300 \
    https://raw.githubusercontent.com/jesseduffield/lazydocker/master/scripts/install_update_linux.sh \
    | bash
}

_vf_install_uv() {
  if has_cmd uv; then log_info "OK: uv presente"; return 0; fi
  log_info "Instalando uv (Astral)…"
  curl_pipe https://astral.sh/uv/install.sh
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
