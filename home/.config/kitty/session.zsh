# Kitty — gerenciamento de sessão (salvar/restaurar abas, splits, cwd e programas).
# Versionado em PowerTerminal/home/.config/kitty/session.zsh
# Carregado pelo ~/.zshrc via `source`.

# ksave — salva a sessão atual do kitty (use antes de fechar/reiniciar).
#         Mesmo efeito do atalho ctrl+shift+s, porém pelo terminal.
ksave() {
  emulate -L zsh
  if [[ -z "$KITTY_WINDOW_ID" ]]; then
    print -u2 "ksave: rode dentro de uma janela do kitty."
    return 1
  fi
  "$HOME/.config/kitty/save-session.py" "$@"
}

# kload — abre uma NOVA janela do kitty restaurando a última sessão salva
#         (útil para testar sem mexer na janela atual).
kload() {
  emulate -L zsh
  local f="$HOME/.config/kitty/last-session.kitty"
  if [[ ! -s "$f" ]]; then
    print -u2 "kload: nenhuma sessão salva em $f (rode ksave primeiro)."
    return 1
  fi
  kitty --session "$f" & disown
}
