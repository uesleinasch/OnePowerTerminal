# shellcheck shell=bash
# Module: eza — substituto moderno do ls.

mod_eza_meta() { echo "eza: ls moderno, com ícones e git"; }

mod_eza_cost() { printf '1\t5\t1\n'; }

mod_eza_name() { echo "eza"; }

mod_eza_category() { echo dev; }

mod_eza_installed() { has_cmd eza; }

mod_eza_requires() { printf 'curl\tcurl\n'; }

mod_eza_install() {
  ensure_local_bin
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

mod_eza_update() {
  ensure_local_bin
  if pn_receipt_has_entry eza file "$HOME/.local/bin/eza"; then
    _vf_install_eza_github
  elif pn_receipt_has_entry eza apt eza; then
    apt_upgrade_instalados eza
  else
    log_info "eza não foi instalado pelo PowerTerminal — pulado."
  fi
}

mod_eza_doctor() {
  if has_cmd eza; then
    status_line 1 "eza: $(command -v eza)"
  else
    status_line 0 "eza: não encontrado"
  fi
}

mod_eza_remove() { pn_receipt_undo eza; }
