# shellcheck shell=bash
# Module: vscode — Visual Studio Code pelo repositório apt oficial da Microsoft.

mod_vscode_meta() {
  echo "Visual Studio Code (repositório apt da Microsoft; só o editor)"
}

mod_vscode_cost() { printf '2\t400\t1\n'; }

mod_vscode_name() { echo "Visual Studio Code"; }

mod_vscode_category() { echo editor; }

mod_vscode_installed() { has_cmd code; }

_PN_VSCODE_KEY="https://packages.microsoft.com/keys/microsoft.asc"
_PN_VSCODE_REPO="https://packages.microsoft.com/repos/code"
_PN_VSCODE_DEBCONF="code code/add-microsoft-repo boolean false"
_PN_VSCODE_DEBCONF_PADRAO="code code/add-microsoft-repo boolean true"

mod_vscode_install() {
  if has_cmd code; then
    log_info "OK: VS Code presente ($(command -v code))"
    return 0
  fi

  # Com a resposta padrão, o postinst do pacote `code` grava a própria lista
  # com outro Signed-By; duas fontes do mesmo repo com Signed-By divergentes
  # fazem todo `apt-get update` falhar.
  if [[ "$DRY_RUN" == "1" ]]; then
    log_dry "echo '$_PN_VSCODE_DEBCONF' | sudo debconf-set-selections"
  else
    printf '%s\n' "$_PN_VSCODE_DEBCONF" | as_sudo debconf-set-selections
  fi

  pn_step 1 2 "Adicionando o repositório da Microsoft e atualizando o índice do apt…"
  apt_add_repo vscode "$_PN_VSCODE_KEY" "$_PN_VSCODE_REPO" stable main
  pn_step 2 2 "Instalando o VS Code…"
  apt_install code
  [[ "$DRY_RUN" == "1" ]] || log_success "VS Code instalado: $(code --version 2>/dev/null | head -1)"
}

mod_vscode_update() {
  log_info "Atualizando o VS Code via apt-get…"
  apt_upgrade_instalados code
}

_vf_vscode_recibo_tem_code() {
  [[ $'\n'"$(pn_receipt_entries vscode apt)"$'\n' == *$'\n'"apt"$'\t'"code"$'\n'* ]]
}

mod_vscode_remove() {
  local rc=0
  if ! _vf_vscode_recibo_tem_code; then
    pn_receipt_undo vscode
    return
  fi
  pn_receipt_undo vscode || rc=$?
  if [[ "$DRY_RUN" == "1" ]]; then
    log_dry "echo '$_PN_VSCODE_DEBCONF_PADRAO' | sudo debconf-set-selections"
  elif ! _vf_vscode_recibo_tem_code; then
    as_sudo debconf-set-selections <<<"$_PN_VSCODE_DEBCONF_PADRAO" \
      || log_warn "debconf-set-selections falhou — a pergunta do repositório da Microsoft continua respondida com false."
  fi
  return "$rc"
}

mod_vscode_doctor() {
  if has_cmd code; then
    status_line 1 "code: $(code --version 2>/dev/null | head -1) ($(command -v code))"
  else
    status_line 0 "code: não encontrado no PATH"
  fi
}
