# shellcheck shell=bash
# Module: uv — gerenciador de pacotes e ambientes Python (Astral).

mod_uv_meta() { echo "uv: gerenciador Python da Astral"; }

mod_uv_cost() { printf '1\t40\t0\n'; }

mod_uv_name() { echo "uv"; }

mod_uv_category() { echo dev; }

mod_uv_installed() { has_cmd uv; }

mod_uv_requires() { printf 'curl\tcurl\n'; }

mod_uv_install() {
  ensure_local_bin
  _vf_install_uv
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

_vf_update_uv() {
  log_info "Atualizando uv (uv self update)…"
  run "$HOME/.local/bin/uv" self update && return 0
  log_warn "uv self update falhou — reinstalando pelo instalador oficial."
  _vf_install_uv force
}

mod_uv_update() {
  ensure_local_bin
  if pn_receipt_has_entry uv file "$HOME/.local/bin/uv"; then
    _vf_update_uv
  else
    log_info "uv não foi instalado pelo PowerTerminal — pulado."
  fi
}

mod_uv_doctor() {
  if has_cmd uv; then
    status_line 1 "uv: $(command -v uv)"
  else
    status_line 0 "uv: não encontrado"
  fi
}

mod_uv_remove() { pn_receipt_undo uv; }
