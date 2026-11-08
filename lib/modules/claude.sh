# shellcheck shell=bash
# Module: claude — Claude Code (CLI da Anthropic) pelo instalador nativo.

mod_claude_meta() {
  echo "Claude Code (CLI da Anthropic, instalador nativo em ~/.local/bin)"
}

mod_claude_cost() { printf '1\t200\t0\n'; }

mod_claude_requires() { printf 'curl\tcurl\n'; }

mod_claude_name() { echo "Claude Code"; }

mod_claude_category() { echo dev; }

mod_claude_about() {
  echo "Instala o Claude Code, a CLI da Anthropic, pelo instalador nativo: o binário fica em ~/.local/bin e os arquivos em ~/.local/share/claude. Não pede sudo. Remover apaga essa instalação, mas deixa ~/.claude e ~/.claude.json, que são dados seus."
}

mod_claude_provides() {
  printf 'bin\t%s/.local/bin/claude\n' "$HOME"
  printf 'dir\t%s/.local/share/claude\n' "$HOME"
}

mod_claude_adopt() {
  _pn_adopt_path file "$HOME/.local/bin/claude" claude
  _pn_adopt_path dir "$HOME/.local/share/claude"
}

mod_claude_installed() {
  has_cmd claude || [[ -x "$HOME/.local/bin/claude" ]]
}

_PN_CLAUDE_INSTALLER="https://claude.ai/install.sh"

mod_claude_install() {
  if has_cmd claude || [[ -x "$HOME/.local/bin/claude" ]]; then
    log_info "OK: Claude Code presente"
    return 0
  fi
  if [[ "$DRY_RUN" == "1" ]]; then
    log_dry "curl -fsSL $_PN_CLAUDE_INSTALLER | bash"
    return 0
  fi

  # O instalador é bash, não sh: curl_pipe não serve aqui.
  local tmp; tmp="$(mktemp)"
  pn_step 1 2 "Baixando o instalador do Claude Code…"
  if ! download_to "$_PN_CLAUDE_INSTALLER" "$tmp"; then
    rm -f "$tmp"
    die "Falha ao baixar o instalador do Claude Code."
  fi
  pn_step 2 2 "Rodando o instalador do Claude Code…"
  if ! bash "$tmp"; then
    rm -f "$tmp"
    die "O instalador do Claude Code falhou."
  fi
  rm -f "$tmp"
  _pn_receipt file "$HOME/.local/bin/claude"
  _pn_receipt dir "$HOME/.local/share/claude"
  post_install_note "Rode 'claude' para fazer login na sua conta Anthropic."
}

mod_claude_update() {
  log_info "Atualizando o Claude Code…"
  run claude update
}

mod_claude_doctor() {
  local bin=""
  if has_cmd claude; then
    bin="$(command -v claude)"
  elif [[ -x "$HOME/.local/bin/claude" ]]; then
    bin="$HOME/.local/bin/claude"
  fi
  if [[ -n "$bin" ]]; then
    status_line 1 "claude: $("$bin" --version 2>/dev/null | head -1) ($bin)"
  else
    status_line 0 "claude: ausente"
  fi
}

mod_claude_remove() { pn_receipt_undo claude; }
