# shellcheck shell=bash
# Module: zsh — zsh + Oh-My-Zsh + Powerlevel10k + plugins + linka ~/.zshrc, ~/.p10k.zsh.

mod_zsh_meta() {
  echo "Zsh + Oh-My-Zsh + Powerlevel10k + plugins (autosuggestions/syntax-highlighting)"
}

mod_zsh_cost() { printf '2\t80\t1\n'; }

_PN_OMZ_DIR="$HOME/.oh-my-zsh"
_PN_OMZ_CUSTOM="${ZSH_CUSTOM:-$_PN_OMZ_DIR/custom}"

mod_zsh_install() {
  require_supported_distro
  if ! has_cmd zsh; then
    apt_update_once
    apt_install zsh
  fi

  if [[ ! -d "$_PN_OMZ_DIR" ]]; then
    log_info "Instalando Oh-My-Zsh…"
    if [[ "$DRY_RUN" == "1" ]]; then
      log_dry "curl https://.../ohmyzsh/install.sh | sh (RUNZSH=no CHSH=no KEEP_ZSHRC=yes)"
    else
      RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
        sh -c "$(curl -fsSL --connect-timeout 15 --max-time 300 \
          https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
    fi
  else
    log_info "OK: Oh-My-Zsh já instalado"
  fi

  _PN_OMZ_CUSTOM="${ZSH_CUSTOM:-$_PN_OMZ_DIR/custom}"
  run mkdir -p "$_PN_OMZ_CUSTOM/themes" "$_PN_OMZ_CUSTOM/plugins"

  clone_or_pull \
    "https://github.com/romkatv/powerlevel10k.git" \
    "$_PN_OMZ_CUSTOM/themes/powerlevel10k" \
    "powerlevel10k"

  clone_or_pull \
    "https://github.com/zsh-users/zsh-autosuggestions" \
    "$_PN_OMZ_CUSTOM/plugins/zsh-autosuggestions" \
    "zsh-autosuggestions"

  clone_or_pull \
    "https://github.com/zsh-users/zsh-syntax-highlighting.git" \
    "$_PN_OMZ_CUSTOM/plugins/zsh-syntax-highlighting" \
    "zsh-syntax-highlighting"

  link_safe "$POWERTERMINAL_HOME/home/.zshrc"   "$HOME/.zshrc"
  link_safe "$POWERTERMINAL_HOME/home/.p10k.zsh" "$HOME/.p10k.zsh"

  _vf_set_default_shell
}

# O shell gravado pelo chsh só vale no próximo login: sem dizer isso, quem roda
# o comando conclui que ele não funcionou e volta a digitar `zsh` na mão.
_vf_nota_shell_padrao() {
  post_install_note "Definir zsh como shell padrão: chsh -s $1 — depois reinicie a máquina (ou saia da sessão e entre de novo), porque o shell novo só passa a valer no próximo login."
}

_vf_sudo_pronto() {
  [[ "$(id -u)" -eq 0 ]] || sudo -n true 2>/dev/null
}

# `chsh` direto pede a senha do usuário e trava sem TTY — no wizard, onde a
# saída dos módulos vai para o log, o prompt seria invisível. O install já
# autenticou o sudo, e `sudo chsh` grava em /etc/passwd sem pedir nada. Se o
# sudo não estiver válido, não insistimos: pendurar a instalação num prompt que
# ninguém vê é pior do que deixar uma tarefa manual.
_vf_set_default_shell() {
  local zsh_path usuario
  zsh_path="$(command -v zsh || true)"
  [[ -z "$zsh_path" ]] && return 0
  [[ "$(login_shell)" == "$zsh_path" ]] && return 0
  usuario="$(id -un)"

  if [[ "$DRY_RUN" == "1" ]]; then
    log_dry "chsh -s $zsh_path $usuario"
    return 0
  fi

  if ! _vf_sudo_pronto; then
    log_warn "sudo indisponível sem senha — shell padrão vai para as tarefas manuais."
    _vf_nota_shell_padrao "$zsh_path"
    return 0
  fi

  if as_sudo chsh -s "$zsh_path" "$usuario"; then
    log_success "zsh definido como shell padrão."
    post_install_note "Reinicie a máquina (ou saia da sessão e entre de novo) para o zsh assumir como shell padrão — a troca só vale no próximo login."
  else
    log_warn "chsh falhou — shell padrão vai para as tarefas manuais."
    _vf_nota_shell_padrao "$zsh_path"
  fi
}

mod_zsh_links() {
  printf '%s\t%s\n' "$POWERTERMINAL_HOME/home/.zshrc"   "$HOME/.zshrc"
  printf '%s\t%s\n' "$POWERTERMINAL_HOME/home/.p10k.zsh" "$HOME/.p10k.zsh"
}

mod_zsh_doctor() {
  has_cmd zsh && status_line 1 "zsh: $(zsh --version 2>/dev/null)" || status_line 0 "zsh: não instalado"
  [[ -d "$_PN_OMZ_DIR" ]] && status_line 1 "oh-my-zsh: presente" || status_line 0 "oh-my-zsh: ausente"
  [[ -d "$_PN_OMZ_CUSTOM/themes/powerlevel10k" ]] && status_line 1 "powerlevel10k: presente" || status_line 0 "powerlevel10k: ausente"
  [[ -L "$HOME/.zshrc" ]] && status_line 1 "~/.zshrc: linkado" || status_line 0 "~/.zshrc: não linkado por PowerTerminal"
  [[ -L "$HOME/.p10k.zsh" ]] && status_line 1 "~/.p10k.zsh: linkado" || status_line 0 "~/.p10k.zsh: não linkado"
}
