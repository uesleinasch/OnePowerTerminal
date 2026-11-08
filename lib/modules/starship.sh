# shellcheck shell=bash
# Module: starship — prompt.

mod_starship_meta() { echo "starship: prompt minimalista e rápido"; }

mod_starship_cost() { printf '1\t10\t0\n'; }

mod_starship_name() { echo "starship"; }

mod_starship_category() { echo dev; }

mod_starship_about() {
  echo "Instala o starship, um prompt de shell rápido, pelo instalador oficial em ~/.local/bin. Não altera a configuração do shell. Remover apaga o binário se foi o PowerTerminal quem o criou."
}

mod_starship_provides() {
  printf 'bin\t%s/.local/bin/starship\n' "$HOME"
}

mod_starship_adopt() {
  _pn_adopt_path file "$HOME/.local/bin/starship" starship
}

mod_starship_installed() { has_cmd starship; }

mod_starship_requires() { printf 'curl\tcurl\n'; }

mod_starship_install() {
  ensure_local_bin
  _vf_install_starship
}

_vf_install_starship() {
  if [[ "${1:-}" != force ]] && has_cmd starship; then log_info "OK: starship presente"; return 0; fi
  log_info "Instalando starship…"
  local existia=0
  _pn_existe "$HOME/.local/bin/starship" && existia=1
  curl_pipe https://starship.rs/install.sh -y -b "$HOME/.local/bin"
  _pn_receipt_criado "$existia" file "$HOME/.local/bin/starship"
}

mod_starship_update() {
  ensure_local_bin
  if pn_receipt_has_entry starship file "$HOME/.local/bin/starship"; then
    _vf_install_starship force
  else
    log_info "starship não foi instalado pelo PowerTerminal — pulado."
  fi
}

mod_starship_doctor() {
  if has_cmd starship; then
    status_line 1 "starship: $(command -v starship)"
  else
    status_line 0 "starship: não encontrado"
  fi
}

mod_starship_remove() { pn_receipt_undo starship; }
