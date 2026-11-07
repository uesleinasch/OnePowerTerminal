# shellcheck shell=bash
# Module: node — Node.js via nvm ou n (escolha do usuário) + Node LTS.

mod_node_meta() {
  echo "Node.js via nvm ou n (LTS) — pergunta interativamente; idempotente"
}

mod_node_cost() { printf '3\t120\t0\n'; }

mod_node_name() { echo "Node.js LTS"; }

mod_node_category() { echo dev; }

mod_node_about() {
  echo "Instala o Node.js LTS por um gerenciador de versões: o nvm, em ~/.nvm, ou o n, em ~/n, conforme a sua escolha. Nada é instalado no sistema e não pede sudo. Remover apaga o diretório do gerenciador que o PowerTerminal criou."
}

mod_node_provides() {
  local manager
  manager="$(pn_get_answer node.manager "")"
  [[ -n "$manager" ]] || manager="$(_vf_node_manager_decidido)"
  if [[ "$manager" == n ]]; then
    printf 'dir\t%s\n' "$_PN_N_PREFIX"
  else
    printf 'dir\t%s\n' "$_PN_NVM_DIR"
  fi
}

mod_node_installed() {
  [[ -s "$_PN_NVM_DIR/nvm.sh" ]] || [[ -x "$_PN_N_PREFIX/bin/n" ]] || _vf_is_real_n
}

mod_node_requires() { printf 'git\tgit\ncurl\tcurl\n'; }

_PN_NVM_DIR="$HOME/.nvm"
_PN_N_PREFIX="$HOME/n"
_PN_NVM_VERSION="v0.40.1"

# Decide qual gerenciador usar e grava a resposta ANTES do install começar.
# Precedência:
#   1) já instalado (nvm ganha se ambos existirem)
#   2) env POWERTERMINAL_NODE_MANAGER=nvm|n
#   3) não-interativo → nvm
#   4) pergunta
# `n` é um nome de comando de uma letra: um script pessoal ou utilitário
# qualquer no PATH satisfaz `has_cmd n` e desviaria a escolha em silêncio.
# O gerenciador responde `--version` com um número.
_vf_is_real_n() {
  has_cmd n || return 1
  n --version </dev/null 2>/dev/null | grep -qE '^[0-9]+\.[0-9]+'
}

# Resolve o gerenciador sem perguntar nada: já instalado, depois a env.
# Devolve vazio quando nada decidiu — só nesse caso vale perguntar/defaultar.
# Mesmo papel de _vf_runtime_decidido no módulo container: também é o que faz
# POWERTERMINAL_NODE_MANAGER valer no caminho --profile/--module, onde
# mod_node_configure nunca roda.
_vf_node_manager_decidido() {
  if [[ -s "$_PN_NVM_DIR/nvm.sh" ]]; then
    printf 'nvm\n'
  elif [[ -x "$_PN_N_PREFIX/bin/n" ]] || _vf_is_real_n; then
    printf 'n\n'
  elif [[ -n "${POWERTERMINAL_NODE_MANAGER:-}" ]]; then
    case "$POWERTERMINAL_NODE_MANAGER" in
      nvm|n) printf '%s\n' "$POWERTERMINAL_NODE_MANAGER" ;;
      *) log_warn "POWERTERMINAL_NODE_MANAGER inválido: '$POWERTERMINAL_NODE_MANAGER' (use nvm|n)" ;;
    esac
  fi
  return 0
}

mod_node_configure() {
  local escolha
  escolha="$(_vf_node_manager_decidido)"

  if [[ -z "$escolha" ]]; then
    if [[ "${POWERTERMINAL_NONINTERACTIVE:-0}" == "1" ]] || ! [[ -t 0 ]]; then
      escolha=nvm
    else
      escolha="$(ui_choose "Gerenciador de versões do Node" \
        nvm:"Node Version Manager (mais popular)" \
        n:"Tim Caswell n (mais simples)")"
    fi
  fi

  pn_set_answer node.manager "$escolha"
}

_vf_install_nvm() {
  if [[ -s "$_PN_NVM_DIR/nvm.sh" ]]; then
    log_info "OK: nvm presente em $_PN_NVM_DIR"
    return 0
  fi
  log_info "Instalando nvm ${_PN_NVM_VERSION}…"
  if [[ "$DRY_RUN" == "1" ]]; then
    log_dry "PROFILE=/dev/null curl https://raw.githubusercontent.com/nvm-sh/nvm/${_PN_NVM_VERSION}/install.sh | bash"
    return 0
  fi
  local existia=0
  _pn_existe "$_PN_NVM_DIR" && existia=1
  # PROFILE=/dev/null impede o instalador de tocar no rc — quem cuida disso é o módulo zsh.
  PROFILE=/dev/null bash -c \
    "$(curl -fsSL --connect-timeout 15 --max-time 300 \
      "https://raw.githubusercontent.com/nvm-sh/nvm/${_PN_NVM_VERSION}/install.sh")" \
    || die "Falha ao instalar nvm."
  _pn_receipt_criado "$existia" dir "$_PN_NVM_DIR"
}

_vf_install_n() {
  if has_cmd n || [[ -x "$_PN_N_PREFIX/bin/n" ]]; then
    log_info "OK: n presente"
    return 0
  fi
  log_info "Instalando n via n-install (em $_PN_N_PREFIX)…"
  if [[ "$DRY_RUN" == "1" ]]; then
    log_dry "curl https://raw.githubusercontent.com/mklement0/n-install/master/bin/n-install | bash -s -- -y -n"
    return 0
  fi
  local existia=0
  _pn_existe "$_PN_N_PREFIX" && existia=1
  # -y não-interativo; -n não modifica shell rc (a gente faz isso pelo módulo zsh).
  curl -fsSL --connect-timeout 15 --max-time 300 \
    https://raw.githubusercontent.com/mklement0/n-install/master/bin/n-install \
    | env N_PREFIX="$_PN_N_PREFIX" bash -s -- -y -n \
    || die "Falha ao instalar n."
  _pn_receipt_criado "$existia" dir "$_PN_N_PREFIX"
}

_vf_install_node_via_nvm() {
  if [[ "$DRY_RUN" == "1" ]]; then
    log_dry "nvm install --lts && nvm alias default 'lts/*'"
    return 0
  fi
  [[ -s "$_PN_NVM_DIR/nvm.sh" ]] || { log_warn "nvm.sh ausente — pulando install do Node"; return 0; }
  # nvm é uma função shell — precisa ser carregada num bash dedicado.
  if bash -c "export NVM_DIR='$_PN_NVM_DIR'; \. '$_PN_NVM_DIR/nvm.sh'; nvm install --lts && nvm alias default 'lts/*'"; then
    log_info "Node LTS instalado via nvm."
  else
    log_warn "nvm install --lts falhou (verifique conectividade)."
  fi
}

# _vf_install_node_via_n [BINÁRIO] — sem argumento, cai no `n` do PATH.
_vf_install_node_via_n() {
  if [[ "$DRY_RUN" == "1" ]]; then
    log_dry "N_PREFIX=$_PN_N_PREFIX n lts"
    return 0
  fi
  local n_bin="${1:-$_PN_N_PREFIX/bin/n}"
  [[ -n "${1:-}" || -x "$n_bin" ]] || n_bin="$(command -v n || true)"
  [[ -x "$n_bin" ]] || { log_warn "binário 'n' ausente — pulando install do Node"; return 0; }
  if N_PREFIX="$_PN_N_PREFIX" "$n_bin" lts; then
    log_info "Node LTS instalado via n."
  else
    log_warn "'n lts' falhou (verifique conectividade)."
  fi
}

mod_node_install() {
  local manager
  # Com --profile/--module o configure nunca rodou e não há resposta gravada:
  # sem este fallback, POWERTERMINAL_NODE_MANAGER seria ignorada em silêncio.
  manager="$(pn_get_answer node.manager "")"
  [[ -n "$manager" ]] || manager="$(_vf_node_manager_decidido)"
  [[ -n "$manager" ]] || manager=nvm
  log_info "Gerenciador escolhido: $manager"

  case "$manager" in
    nvm) _vf_install_nvm; _vf_install_node_via_nvm ;;
    n)   _vf_install_n;   _vf_install_node_via_n   ;;
    *)   die "Manager Node desconhecido: $manager" ;;
  esac

  log_info "PATHs do Node são carregados automaticamente pelo ~/.zshrc deste repo."
  log_info "Reabra o terminal (ou rode 'exec zsh') para ativar 'node'/'npm'."
}

mod_node_update() {
  if pn_receipt_has_entry node dir "$_PN_NVM_DIR" && [[ -s "$_PN_NVM_DIR/nvm.sh" ]]; then
    _vf_install_node_via_nvm
  elif pn_receipt_has_entry node dir "$_PN_N_PREFIX" && [[ -x "$_PN_N_PREFIX/bin/n" ]]; then
    _vf_install_node_via_n "$_PN_N_PREFIX/bin/n"
  else
    log_info "O gerenciador do Node em uso não foi instalado pelo PowerTerminal — nada a atualizar."
  fi
}

mod_node_doctor() {
  if [[ -s "$_PN_NVM_DIR/nvm.sh" ]]; then
    status_line 1 "nvm: $_PN_NVM_DIR"
  else
    status_line 0 "nvm: ausente"
  fi
  if has_cmd n; then
    status_line 1 "n: $(command -v n)"
  elif [[ -x "$_PN_N_PREFIX/bin/n" ]]; then
    status_line 1 "n: $_PN_N_PREFIX/bin/n (não está no PATH atual)"
  else
    status_line 0 "n: ausente"
  fi
  if has_cmd node; then
    status_line 1 "node: $(node --version 2>/dev/null) ($(command -v node))"
  else
    status_line 0 "node: não está no PATH atual"
  fi
}

mod_node_deduce() {
  [[ -f "$_PN_NVM_DIR/nvm.sh" ]] && pn_receipt_add dir "$_PN_NVM_DIR"
  [[ -f "$_PN_N_PREFIX/bin/n" ]] && pn_receipt_add dir "$_PN_N_PREFIX"
  return 0
}

mod_node_remove() { pn_receipt_undo node; }
