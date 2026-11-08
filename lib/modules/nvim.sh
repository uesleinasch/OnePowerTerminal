# shellcheck shell=bash
# Module: nvim — instala o binário do Neovim (release oficial) em /opt e symlink em /usr/local/bin.

mod_nvim_meta() {
  echo "Neovim (binário oficial mais recente, instalado em /opt)"
}

mod_nvim_cost() { printf '1\t60\t1\n'; }

mod_nvim_name() { echo "Neovim"; }

mod_nvim_category() { echo editor; }

mod_nvim_about() {
  echo "Baixa o release oficial do Neovim, extrai em /opt e cria o link /usr/local/bin/nvim. Só funciona em x86_64 e pede sudo, porque grava fora do seu HOME. Remover apaga o diretório em /opt e o link que o PowerTerminal criou."
}

mod_nvim_provides() {
  printf 'dir\t%s/nvim-linux-x86_64\n' "$_PN_NVIM_PREFIX"
  printf 'bin\t%s\n' "$_PN_NVIM_LINK"
}

mod_nvim_adopt() {
  _pn_adopt_path dir "$_PN_NVIM_PREFIX/nvim-linux-x86_64" nvim
  if [[ -L "$_PN_NVIM_LINK" && "$(readlink "$_PN_NVIM_LINK")" == "$_PN_NVIM_PREFIX/nvim-linux-x86_64"/* ]]; then
    _pn_adopt_path file "$_PN_NVIM_LINK"
  fi
  return 0
}

mod_nvim_installed() { has_cmd nvim; }

_PN_NVIM_URL="https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz"
_PN_NVIM_PREFIX=/opt
_PN_NVIM_LINK=/usr/local/bin/nvim
# Os overrides apontam o sudo rm -rf/ln -sf para outro lugar: só valem nos testes.
if [[ "${POWERTERMINAL_TESTING:-0}" == 1 ]]; then
  _PN_NVIM_PREFIX="${POWERTERMINAL_NVIM_PREFIX:-$_PN_NVIM_PREFIX}"
  _PN_NVIM_LINK="${POWERTERMINAL_NVIM_LINK:-$_PN_NVIM_LINK}"
fi

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

_vf_nvim_gerenciado() {
  local bin; bin="$(command -v nvim)" || return 1
  [[ "$(readlink -f "$bin")" == "$_PN_NVIM_PREFIX/nvim-linux-x86_64/"* ]]
}

mod_nvim_update() {
  if has_cmd nvim && ! _vf_nvim_gerenciado; then
    log_info "O nvim em uso não é do PowerTerminal ($(command -v nvim)); nada a atualizar."
    return 0
  fi
  require_x86_64 nvim || return 0
  _vf_nvim_fetch
}

_vf_nvim_fetch() {
  if [[ "$DRY_RUN" == "1" ]]; then
    log_dry "download $_PN_NVIM_URL"
    log_dry "sudo rm -rf $_PN_NVIM_PREFIX/nvim $_PN_NVIM_PREFIX/nvim-linux-x86_64"
    log_dry "sudo tar -C $_PN_NVIM_PREFIX -xzf <tarball>"
    log_dry "sudo ln -sf $_PN_NVIM_PREFIX/nvim-linux-x86_64/bin/nvim $_PN_NVIM_LINK"
    return 0
  fi
  local tmp; tmp="$(mktemp -d)"
  pn_step 1 3 "Baixando o Neovim…"
  download_to "$_PN_NVIM_URL" "$tmp/nvim.tar.gz"
  pn_step 2 3 "Extraindo em $_PN_NVIM_PREFIX (removendo instalações antigas)…"
  as_sudo rm -rf "$_PN_NVIM_PREFIX/nvim" "$_PN_NVIM_PREFIX/nvim-linux-x86_64"
  as_sudo tar -C "$_PN_NVIM_PREFIX" -xzf "$tmp/nvim.tar.gz"
  pn_step 3 3 "Linkando nvim em $(dirname "$_PN_NVIM_LINK")…"
  as_sudo ln -sf "$_PN_NVIM_PREFIX/nvim-linux-x86_64/bin/nvim" "$_PN_NVIM_LINK"
  _pn_receipt dir "$_PN_NVIM_PREFIX/nvim-linux-x86_64"
  _pn_receipt file "$_PN_NVIM_LINK"
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
