# shellcheck shell=bash
# Module: theme — flavor Catppuccin compartilhado por kitty, Neovim e prompt.
#
# A escolha vive num arquivo só (~/.config/powerterminal/theme). O kitty é o
# único que não sabe ler esse arquivo, então recebe um include derivado; o
# Neovim e o p10k leem o estado em runtime.

mod_theme_meta() {
  echo "Tema Catppuccin unificado (kitty + Neovim + prompt), 4 flavors"
}

mod_theme_cost() { printf '0\t0\t0\n'; }

_PN_THEME_FLAVORS=(latte frappe macchiato mocha)
_PN_THEME_DEFAULT="mocha"
_PN_THEME_STATE_DIR="$HOME/.config/powerterminal"
_PN_THEME_STATE="$_PN_THEME_STATE_DIR/theme"
_PN_THEME_KITTY_DIR="$HOME/.config/kitty"
_PN_THEME_KITTY_INCLUDE="$_PN_THEME_KITTY_DIR/current-theme.conf"
_PN_THEME_CLAUDE_SETTINGS="$HOME/.claude/settings.json"

# Só o latte é claro; os outros três são escuros.
_vf_theme_claude_mode() {
  case "$1" in
    latte) printf 'light\n' ;;
    *)     printf 'dark\n' ;;
  esac
}

mod_theme_install() {
  link_safe "$POWERTERMINAL_HOME/home/.config/powerterminal" "$_PN_THEME_STATE_DIR"
  _vf_theme_apply "$(_vf_theme_current)"
}

mod_theme_links() {
  printf '%s\t%s\n' "$POWERTERMINAL_HOME/home/.config/powerterminal" "$_PN_THEME_STATE_DIR"
}

pn_theme_is_flavor() {
  local f
  for f in "${_PN_THEME_FLAVORS[@]}"; do
    [[ "$f" == "$1" ]] && return 0
  done
  return 1
}

# Lê a escolha em vigor. Valor ausente ou inválido cai no default em vez de
# falhar: os três consumidores fazem o mesmo, então o ambiente nunca fica sem tema.
_vf_theme_current() {
  local valor=""
  # `|| true`: arquivo vazio faz o read retornar 1, o que abortaria sob set -e.
  if [[ -r "$_PN_THEME_STATE" ]]; then
    IFS= read -r valor < "$_PN_THEME_STATE" || true
  fi
  valor="${valor//[[:space:]]/}"
  if pn_theme_is_flavor "$valor"; then
    printf '%s\n' "$valor"
  else
    printf '%s\n' "$_PN_THEME_DEFAULT"
  fi
}

# Escreve o estado e o include do kitty. Escrevemos no $HOME (não no repo)
# porque é o $HOME que está em vigor; quando os dotfiles são symlinks o repo
# acompanha sozinho, e quando são arquivos reais o `make sync` reconcilia.
_vf_theme_apply() {
  local flavor="$1"
  pn_theme_is_flavor "$flavor" || die "Flavor desconhecido: $flavor (use: ${_PN_THEME_FLAVORS[*]})"

  run mkdir -p "$_PN_THEME_STATE_DIR"
  _vf_theme_write "$_PN_THEME_STATE" "$flavor"

  if [[ -d "$_PN_THEME_KITTY_DIR" ]]; then
    _vf_theme_write "$_PN_THEME_KITTY_INCLUDE" \
      "# Gerado por \`powerterminal theme <flavor>\` — a escolha canônica vive em" \
      "# ~/.config/powerterminal/theme." \
      "include themes/$flavor.conf"
  else
    log_warn "theme: $_PN_THEME_KITTY_DIR não existe — instale o módulo kitty para o terminal acompanhar"
  fi

  _vf_theme_apply_claude "$flavor"
  log_success "Tema: $flavor"
}

# O tema do Claude Code é o quarto consumidor do flavor: o syntax highlighting
# dele tem cor própria, então um flavor claro com o harness em `dark` deixa
# string ilegível sobre o fundo.
#
# Substituição cirúrgica, nunca round-trip de JSON: o arquivo carrega hooks e
# permissions do usuário, e reescrevê-lo inteiro trocaria a formatação de tudo.
_vf_theme_apply_claude() {
  local alvo rc=0
  alvo="$(_vf_theme_claude_mode "$1")"

  [[ -f "$_PN_THEME_CLAUDE_SETTINGS" ]] || return 0
  if ! has_cmd python3; then
    log_warn "theme: sem python3 — ajuste o tema do Claude Code para $alvo em /config"
    return 0
  fi
  if [[ "$DRY_RUN" == "1" ]]; then
    log_dry "theme=$alvo em $_PN_THEME_CLAUDE_SETTINGS"
    return 0
  fi

  python3 - "$_PN_THEME_CLAUDE_SETTINGS" "$alvo" <<'PY' || rc=$?
import json, os, re, sys

path, alvo = sys.argv[1], sys.argv[2]
src = open(path, encoding="utf-8").read()
if json.loads(src).get("theme") == alvo:
    sys.exit(3)
novo, n = re.subn(r'(^[ \t]*"theme"[ \t]*:[ \t]*")[^"]*(")',
                  lambda m: m.group(1) + alvo + m.group(2), src, count=1, flags=re.M)
if n != 1:
    sys.exit(4)
if json.loads(novo).get("theme") != alvo:
    sys.exit(5)
tmp = path + ".pntmp"
with open(tmp, "w", encoding="utf-8") as f:
    f.write(novo)
os.replace(tmp, path)
PY

  case "$rc" in
    0) log_info "Claude Code: tema $alvo" ;;
    3) ;;
    4) log_warn "theme: chave \"theme\" ausente em $_PN_THEME_CLAUDE_SETTINGS — defina uma vez em /config" ;;
    *) log_warn "theme: não consegui ajustar o tema do Claude Code (rc=$rc)" ;;
  esac
}

_vf_theme_write() {
  local destino="$1"; shift
  if [[ "$DRY_RUN" == "1" ]]; then
    log_dry "escreve $destino ($# linha(s))"
    return 0
  fi
  printf '%s\n' "$@" > "$destino"
}

# Aplica nas janelas abertas. Sem isso o kitty só mostra o tema novo ao reiniciar.
_vf_theme_reload_kitty() {
  local sock achou=0
  if ! has_cmd kitten; then
    log_info "kitten não está no PATH — abra um kitty novo para ver o tema."
    return 0
  fi
  for sock in /tmp/kitty-*; do
    [[ -S "$sock" ]] || continue
    achou=1
    run kitten @ --to "unix:$sock" load-config \
      || log_warn "theme: $sock não aceitou load-config"
  done
  if [[ "$achou" == "0" ]]; then
    log_info "Nenhum kitty em execução para recarregar."
  else
    # O tab_bar.py já está importado no processo; load-config não o reimporta.
    log_info "Cores das abas: reinicie o kitty (ou Ctrl+Shift+F5 numa janela nova)."
  fi
}

mod_theme_doctor() {
  local atual esperado
  atual="$(_vf_theme_current)"
  if [[ -r "$_PN_THEME_STATE" ]]; then
    status_line 1 "theme: flavor $atual"
  else
    status_line 0 "theme: sem estado em $_PN_THEME_STATE (usando $_PN_THEME_DEFAULT)"
  fi

  esperado="include themes/$atual.conf"
  if [[ ! -r "$_PN_THEME_KITTY_INCLUDE" ]]; then
    status_line 0 "theme kitty: $_PN_THEME_KITTY_INCLUDE ausente"
  elif grep -qxF "$esperado" "$_PN_THEME_KITTY_INCLUDE"; then
    status_line 1 "theme kitty: coerente ($atual)"
  else
    status_line 0 "theme kitty: divergente — rode 'powerterminal theme $atual'"
  fi

  if [[ -r "$POWERTERMINAL_HOME/home/.config/kitty/themes/$atual.conf" ]]; then
    status_line 1 "theme paletas: themes/$atual.conf presente"
  else
    status_line 0 "theme paletas: themes/$atual.conf não encontrado no repo"
  fi

  if [[ -f "$_PN_THEME_CLAUDE_SETTINGS" ]] && has_cmd python3; then
    local claude_atual claude_esperado
    claude_esperado="$(_vf_theme_claude_mode "$atual")"
    claude_atual="$(python3 -c \
      'import json,sys; print(json.load(open(sys.argv[1])).get("theme","?"))' \
      "$_PN_THEME_CLAUDE_SETTINGS" 2>/dev/null || echo '?')"
    if [[ "$claude_atual" == "$claude_esperado" ]]; then
      status_line 1 "theme Claude Code: $claude_atual"
    else
      status_line 0 "theme Claude Code: $claude_atual (esperado $claude_esperado)"
    fi
  fi
  return 0
}
