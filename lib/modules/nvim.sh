# shellcheck shell=bash
# Module: nvim — instala o binário do Neovim (release oficial) em /opt e symlink em /usr/local/bin.

mod_nvim_meta() {
  echo "Neovim (binário oficial mais recente, instalado em /opt)"
}

mod_nvim_cost() { printf '1\t60\t1\n'; }

mod_nvim_name() { echo "Neovim"; }

mod_nvim_category() { echo editor; }

mod_nvim_installed() { has_cmd nvim; }

_PN_NVIM_URL="https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz"
_PN_NVIM_PREFIX="/opt"

mod_nvim_install() {
  if has_cmd nvim; then
    log_info "OK: nvim já no PATH ($(nvim --version | head -1))"
    return 0
  fi
  if ! require_x86_64 nvim; then
    post_install_note "Instale o Neovim manualmente para $(uname -m) — o release oficial usado pelo módulo nvim é só x86_64."
    return 0
  fi
  _vf_nvim_fetch
}

mod_nvim_update() {
  require_x86_64 nvim || return 0
  _vf_nvim_fetch
}

_vf_nvim_fetch() {
  if [[ "$DRY_RUN" == "1" ]]; then
    log_dry "download $_PN_NVIM_URL"
    log_dry "sudo rm -rf $_PN_NVIM_PREFIX/nvim $_PN_NVIM_PREFIX/nvim-linux-x86_64"
    log_dry "sudo tar -C $_PN_NVIM_PREFIX -xzf <tarball>"
    log_dry "sudo ln -sf $_PN_NVIM_PREFIX/nvim-linux-x86_64/bin/nvim /usr/local/bin/nvim"
    return 0
  fi
  local tmp; tmp="$(mktemp -d)"
  pn_step 1 3 "Baixando o Neovim…"
  download_to "$_PN_NVIM_URL" "$tmp/nvim.tar.gz"
  pn_step 2 3 "Extraindo em $_PN_NVIM_PREFIX (removendo instalações antigas)…"
  as_sudo rm -rf "$_PN_NVIM_PREFIX/nvim" "$_PN_NVIM_PREFIX/nvim-linux-x86_64"
  as_sudo tar -C "$_PN_NVIM_PREFIX" -xzf "$tmp/nvim.tar.gz"
  pn_step 3 3 "Linkando nvim em /usr/local/bin…"
  as_sudo ln -sf "$_PN_NVIM_PREFIX/nvim-linux-x86_64/bin/nvim" /usr/local/bin/nvim
  _pn_receipt dir "$_PN_NVIM_PREFIX/nvim-linux-x86_64"
  _pn_receipt file /usr/local/bin/nvim
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

mod_nvim_remove() { pn_receipt_undo nvim; }
