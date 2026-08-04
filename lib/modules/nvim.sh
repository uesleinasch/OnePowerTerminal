# shellcheck shell=bash
# Module: nvim — instala o binário do Neovim (release oficial) em /opt e symlink em /usr/local/bin.

mod_nvim_meta() {
  echo "Neovim (binário oficial mais recente, instalado em /opt)"
}

mod_nvim_cost() { printf '1\t60\t1\n'; }

_PN_NVIM_URL="https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz"
_PN_NVIM_PREFIX="/opt"

mod_nvim_install() {
  if has_cmd nvim; then
    log_info "OK: nvim já no PATH ($(nvim --version | head -1))"
    return 0
  fi
  if [[ "$DRY_RUN" == "1" ]]; then
    log_dry "download $_PN_NVIM_URL"
    log_dry "sudo rm -rf $_PN_NVIM_PREFIX/nvim $_PN_NVIM_PREFIX/nvim-linux-x86_64"
    log_dry "sudo tar -C $_PN_NVIM_PREFIX -xzf <tarball>"
    log_dry "sudo ln -sf $_PN_NVIM_PREFIX/nvim-linux-x86_64/bin/nvim /usr/local/bin/nvim"
    return 0
  fi
  local tmp; tmp="$(mktemp -d)"
  download_to "$_PN_NVIM_URL" "$tmp/nvim.tar.gz"
  log_info "Limpando instalações antigas em $_PN_NVIM_PREFIX/nvim*…"
  as_sudo rm -rf "$_PN_NVIM_PREFIX/nvim" "$_PN_NVIM_PREFIX/nvim-linux-x86_64"
  as_sudo tar -C "$_PN_NVIM_PREFIX" -xzf "$tmp/nvim.tar.gz"
  as_sudo ln -sf "$_PN_NVIM_PREFIX/nvim-linux-x86_64/bin/nvim" /usr/local/bin/nvim
  rm -rf "$tmp"
  log_success "Neovim instalado: $(nvim --version 2>/dev/null | head -1 || echo '(verifique o PATH)')"
}

mod_nvim_doctor() {
  if has_cmd nvim; then
    status_line 1 "nvim: $(nvim --version | head -1)"
  else
    status_line 0 "nvim: não encontrado no PATH"
  fi
}
