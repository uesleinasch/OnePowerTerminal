# shellcheck shell=bash
# Module: yazi — gerenciador de arquivos no terminal, com a config do repo.

mod_yazi_meta() { echo "yazi: gerenciador de arquivos no terminal"; }

mod_yazi_cost() { printf '1\t15\t0\n'; }

mod_yazi_name() { echo "yazi"; }

mod_yazi_category() { echo dev; }

mod_yazi_about() {
  echo "Instala o yazi, um gerenciador de arquivos de terminal, baixando a build estática (musl) do GitHub: os binários yazi e ya vão para ~/.local/bin. Liga também ~/.config/yazi à configuração do repositório. Remover apaga os binários e o link que o PowerTerminal criou."
}

mod_yazi_provides() {
  printf 'bin\t%s/.local/bin/yazi\n' "$HOME"
  printf 'bin\t%s/.local/bin/ya\n' "$HOME"
  printf 'config\t%s/.config/yazi\n' "$HOME"
}

mod_yazi_installed() { has_cmd yazi; }

mod_yazi_requires() { printf 'curl\tcurl\n'; }

mod_yazi_links() { pn_config_links yazi; }

mod_yazi_install() {
  ensure_local_bin
  _vf_install_yazi
  pn_link_module_links yazi
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

mod_yazi_update() {
  ensure_local_bin
  if pn_receipt_has_entry yazi file "$HOME/.local/bin/yazi"; then
    _vf_install_yazi force
  else
    log_info "yazi não foi instalado pelo PowerTerminal — pulado."
  fi
}

mod_yazi_doctor() {
  local c
  for c in yazi ya; do
    if has_cmd "$c"; then
      status_line 1 "$c: $(command -v "$c")"
    else
      status_line 0 "$c: não encontrado"
    fi
  done
  if [[ -L "$HOME/.config/yazi" ]]; then
    status_line 1 "yazi (config): linkada"
  else
    status_line 0 "yazi (config): não linkada"
  fi
}

mod_yazi_remove() { pn_receipt_undo yazi; }
