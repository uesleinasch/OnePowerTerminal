# shellcheck shell=bash
# Module: astronvim — linka ~/.config/nvim para a config do PowerTerminal.

mod_astronvim_meta() {
  echo "Linka ~/.config/nvim para a config customizada (AstroNvim v5)"
}

mod_astronvim_needs() { echo nvim; }

mod_astronvim_cost() { printf '1\t5\t0\n'; }

mod_astronvim_install() {
  local src="$POWERTERMINAL_HOME/home/.config/nvim"
  [[ -d "$src" ]] || die "PowerTerminal/home/.config/nvim não existe no repo."
  link_safe "$src" "$HOME/.config/nvim"
  for d in share state cache; do
    run mkdir -p "$HOME/.local/$d/nvim"
  done
  log_info "Pronto. Rode 'nvim' uma vez — Lazy.nvim instalará os plugins automaticamente."
}

mod_astronvim_links() {
  printf '%s\t%s\n' "$POWERTERMINAL_HOME/home/.config/nvim" "$HOME/.config/nvim"
}

mod_astronvim_doctor() {
  if [[ -L "$HOME/.config/nvim" ]]; then
    status_line 1 "nvim config: linkado → $(readlink "$HOME/.config/nvim")"
  elif [[ -d "$HOME/.config/nvim" ]]; then
    status_line 0 "nvim config: existe mas não é symlink do PowerTerminal"
  else
    status_line 0 "nvim config: ausente"
  fi
}
