# shellcheck shell=bash
# Module: zsh — zsh + Oh-My-Zsh + Powerlevel10k + plugins + linka ~/.zshrc, ~/.p10k.zsh.

mod_zsh_meta() {
  echo "Zsh + Oh-My-Zsh + Powerlevel10k + plugins (autosuggestions/syntax-highlighting)"
}

mod_zsh_cost() { printf '2\t80\t1\n'; }

mod_zsh_name() { echo "Zsh + Powerlevel10k"; }

mod_zsh_category() { echo shell; }

mod_zsh_about() {
  echo "Instala o zsh pelo apt, o Oh-My-Zsh, o tema Powerlevel10k e os plugins autosuggestions e syntax-highlighting, e liga ~/.zshrc e ~/.p10k.zsh à configuração do repositório. Também troca o shell de login para o zsh, o que só vale no próximo login. Remover desfaz o que o recibo registra e, se o zsh sair, devolve o shell de login ao bash."
}

mod_zsh_provides() {
  printf 'apt\tzsh\n'
  printf 'dir\t%s\n' "$_PN_OMZ_DIR"
  printf 'dir\t%s/themes/powerlevel10k\n' "$_PN_OMZ_CUSTOM"
  printf 'dir\t%s/plugins/zsh-autosuggestions\n' "$_PN_OMZ_CUSTOM"
  printf 'dir\t%s/plugins/zsh-syntax-highlighting\n' "$_PN_OMZ_CUSTOM"
  printf 'config\t%s/.zshrc\n' "$HOME"
  printf 'config\t%s/.p10k.zsh\n' "$HOME"
  printf 'shell\tzsh\n'
}

mod_zsh_installed() {
  has_cmd zsh && [[ -d "$_PN_OMZ_DIR" ]]
}

mod_zsh_requires() { printf 'git\tgit\ncurl\tcurl\n'; }

_PN_OMZ_DIR="$HOME/.oh-my-zsh"
_PN_OMZ_CUSTOM="${ZSH_CUSTOM:-$_PN_OMZ_DIR/custom}"

mod_zsh_update() {
  local omz_custom="${ZSH_CUSTOM:-$_PN_OMZ_DIR/custom}" d
  for d in \
    "$omz_custom/themes/powerlevel10k" \
    "$omz_custom/plugins/zsh-autosuggestions" \
    "$omz_custom/plugins/zsh-syntax-highlighting"; do
    [[ -d "$d/.git" ]] || continue
    log_info "Atualizando $(basename "$d")…"
    run git -C "$d" pull --ff-only || log_warn "$(basename "$d"): pull falhou"
  done
}

mod_zsh_install() {
  require_supported_distro
  pn_step 1 5 "Instalando o pacote zsh…"
  if ! has_cmd zsh; then
    apt_update_once
    apt_install zsh
  fi

  pn_step 2 5 "Instalando Oh-My-Zsh…"
  if [[ ! -d "$_PN_OMZ_DIR" ]]; then
    if [[ "$DRY_RUN" == "1" ]]; then
      log_dry "curl https://.../ohmyzsh/install.sh | sh (RUNZSH=no CHSH=no KEEP_ZSHRC=yes)"
    else
      local tinha_zshrc=0
      [[ -e "$HOME/.zshrc" || -L "$HOME/.zshrc" ]] && tinha_zshrc=1
      RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
        sh -c "$(curl -fsSL --connect-timeout 15 --max-time 300 \
          https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
      _pn_receipt dir "$_PN_OMZ_DIR"
      # Sem ~/.zshrc prévio o instalador do OMZ grava um de template; o link_safe
      # o guardaria como .pnbak e o remove o "restauraria" como se fosse do usuário.
      if [[ "$tinha_zshrc" == 0 && -f "$HOME/.zshrc" && ! -L "$HOME/.zshrc" ]]; then
        run rm -f "$HOME/.zshrc"
      fi
    fi
  else
    log_info "OK: Oh-My-Zsh já instalado"
  fi

  _PN_OMZ_CUSTOM="${ZSH_CUSTOM:-$_PN_OMZ_DIR/custom}"
  run mkdir -p "$_PN_OMZ_CUSTOM/themes" "$_PN_OMZ_CUSTOM/plugins"

  pn_step 3 5 "Instalando Powerlevel10k e plugins…"
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

  pn_step 4 5 "Linkando .zshrc e .p10k.zsh…"
  link_safe "$POWERTERMINAL_HOME/home/.zshrc"   "$HOME/.zshrc"
  link_safe "$POWERTERMINAL_HOME/home/.p10k.zsh" "$HOME/.p10k.zsh"

  pn_step 5 5 "Definindo zsh como shell padrão…"
  _vf_set_default_shell
}

# O shell gravado pelo chsh só vale no próximo login: sem dizer isso, quem roda
# o comando conclui que ele não funcionou e volta a digitar `zsh` na mão.
_vf_nota_shell_padrao() {
  post_install_note "Definir zsh como shell padrão: chsh -s $1 — depois reinicie a máquina (ou saia da sessão e entre de novo), porque o shell novo só passa a valer no próximo login."
}

_vf_sudo_pronto() { sudo_ready; }

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

  _pn_receipt login_shell "$(login_shell)"
  if as_sudo chsh -s "$zsh_path" "$usuario"; then
    log_success "zsh definido como shell padrão."
    pn_session_restart "o zsh assumir como shell padrão"
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

_vf_zsh_recibo_tem() {
  [[ $'\n'"$(pn_receipt_entries zsh "$1")"$'\n' == *$'\n'"$1"$'\t'"$2"$'\n'* ]]
}

# Sem login_shell no recibo o shell anterior é desconhecido. Só voltamos para o
# bash quando o pacote zsh vai ser purgado (o login quebraria); com o zsh
# ficando, o shell de login pode ser escolha do próprio usuário e não é tocado.
_vf_zsh_precisa_voltar_bash() {
  pn_receipt_has zsh || return 1
  [[ -z "$(pn_receipt_entries zsh login_shell)" ]] || return 1
  _vf_zsh_recibo_tem apt zsh || return 1
  [[ -z "$(_pn_contas_com_shell zsh)" ]] || return 1
  [[ "$(basename -- "$(login_shell)")" == zsh ]]
}

_vf_zsh_volta_bash() {
  local usuario
  if ! grep -qxF /bin/bash /etc/shells 2>/dev/null; then
    log_warn "/bin/bash não está em /etc/shells — o shell padrão continua o zsh e nada do zsh foi removido."
    return 1
  fi
  usuario="$(id -un)"
  log_info "Voltando o shell padrão para /bin/bash…"
  if ! as_sudo chsh -s /bin/bash "$usuario"; then
    log_warn "chsh falhou — o shell padrão continua o zsh e nada do zsh foi removido."
    return 1
  fi
  [[ "$DRY_RUN" == "1" ]] || pn_session_restart "o shell padrão voltar a ser /bin/bash"
}

mod_zsh_remove() {
  if _vf_zsh_precisa_voltar_bash; then
    _vf_zsh_volta_bash || return 1
  fi
  pn_receipt_undo zsh
}

mod_zsh_deduce() {
  [[ -d "$_PN_OMZ_CUSTOM/themes/powerlevel10k/.git" ]] && pn_receipt_add dir "$_PN_OMZ_DIR"
  return 0
}
