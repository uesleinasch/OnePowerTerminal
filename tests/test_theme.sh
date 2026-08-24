#!/usr/bin/env bash
set -euo pipefail
source "${POWERTERMINAL_HOME}/tests/lib.sh"

REPO="$POWERTERMINAL_HOME"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# theme.sh resolve os paths do estado a partir de $HOME em tempo de source.
export HOME="$tmp"

# shellcheck source=/dev/null
source "${REPO}/lib/core.sh"
# shellcheck source=/dev/null
source "${REPO}/lib/modules/theme.sh"

FLAVORS=(latte frappe macchiato mocha)

it "pn_theme_is_flavor aceita os quatro flavors"
ruim=""
for f in "${FLAVORS[@]}"; do pn_theme_is_flavor "$f" || ruim="$ruim $f"; done
assert_eq "" "$ruim"

it "pn_theme_is_flavor rejeita valor desconhecido"
assert_fail pn_theme_is_flavor dracula

it "sem estado gravado, o flavor em vigor e o default"
assert_eq "mocha" "$(_vf_theme_current)"

it "le o flavor gravado no estado"
mkdir -p "$HOME/.config/powerterminal"
printf 'latte\n' > "$HOME/.config/powerterminal/theme"
assert_eq "latte" "$(_vf_theme_current)"

it "estado invalido cai no default em vez de falhar"
printf 'dracula\n' > "$HOME/.config/powerterminal/theme"
assert_eq "mocha" "$(_vf_theme_current)"

it "estado vazio cai no default sem abortar sob set -e"
: > "$HOME/.config/powerterminal/theme"
assert_eq "mocha" "$(_vf_theme_current)"

it "apply grava o estado"
mkdir -p "$HOME/.config/kitty"
DRY_RUN=0 _vf_theme_apply frappe >/dev/null
assert_eq "frappe" "$(_vf_theme_current)"

it "apply aponta o include do kitty para o flavor"
assert_contains "$(cat "$HOME/.config/kitty/current-theme.conf")" "include themes/frappe.conf"

it "apply rejeita flavor desconhecido"
# subshell: _vf_theme_apply usa die, que faz exit e mataria o runner.
if ( DRY_RUN=0 _vf_theme_apply dracula ) >/dev/null 2>&1; then
  fail "deveria ter falhado com flavor desconhecido"
else
  pass
fi

it "dry-run nao altera o estado"
printf 'mocha\n' > "$HOME/.config/powerterminal/theme"
rm -f "$HOME/.config/kitty/current-theme.conf"
DRY_RUN=1 _vf_theme_apply latte >/dev/null
assert_eq "mocha" "$(_vf_theme_current)"

it "dry-run nao cria o include do kitty"
assert_fail test -e "$HOME/.config/kitty/current-theme.conf"

it "claude mode: latte e claro, os outros tres escuros"
ruim=""
[[ "$(_vf_theme_claude_mode latte)" == "light" ]] || ruim="$ruim latte"
for f in frappe macchiato mocha; do
  [[ "$(_vf_theme_claude_mode "$f")" == "dark" ]] || ruim="$ruim $f"
done
assert_eq "" "$ruim"

mkdir -p "$HOME/.claude"
cat > "$HOME/.claude/settings.json" <<'JSON'
{
    "permissions": { "allow": ["Bash(ls:*)"] },
    "theme": "dark",
    "hooks": { "PreToolUse": [] }
}
JSON

it "aplica o tema do Claude Code conforme o flavor"
DRY_RUN=0 _vf_theme_apply_claude latte >/dev/null
assert_contains "$(cat "$HOME/.claude/settings.json")" '"theme": "light"'

# O settings.json carrega hooks e permissions: um round-trip de JSON trocaria a
# formatação de tudo e tornaria o diff ilegível.
it "preserva a indentacao original das outras chaves"
assert_contains "$(cat "$HOME/.claude/settings.json")" '    "permissions": { "allow": ["Bash(ls:*)"] },'

it "o settings.json resultante continua sendo JSON valido"
assert_ok python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$HOME/.claude/settings.json"

it "reaplicar o mesmo modo nao altera o arquivo"
antes="$(cat "$HOME/.claude/settings.json")"
DRY_RUN=0 _vf_theme_apply_claude latte >/dev/null
assert_eq "$antes" "$(cat "$HOME/.claude/settings.json")"

it "flavor escuro volta o Claude Code para dark"
DRY_RUN=0 _vf_theme_apply_claude mocha >/dev/null
assert_contains "$(cat "$HOME/.claude/settings.json")" '"theme": "dark"'

it "dry-run nao toca no settings.json"
antes="$(cat "$HOME/.claude/settings.json")"
DRY_RUN=1 _vf_theme_apply_claude latte >/dev/null
assert_eq "$antes" "$(cat "$HOME/.claude/settings.json")"

it "sem a chave theme, avisa e deixa o arquivo intacto"
printf '{\n  "permissions": {}\n}\n' > "$HOME/.claude/settings.json"
antes="$(cat "$HOME/.claude/settings.json")"
DRY_RUN=0 _vf_theme_apply_claude latte >/dev/null 2>&1
assert_eq "$antes" "$(cat "$HOME/.claude/settings.json")"

it "sem settings.json, nao falha nem cria o arquivo"
rm -f "$HOME/.claude/settings.json"
DRY_RUN=0 _vf_theme_apply_claude latte >/dev/null
assert_fail test -e "$HOME/.claude/settings.json"

it "sem o diretorio do kitty, apply avisa mas nao falha"
rm -rf "$HOME/.config/kitty"
assert_ok env DRY_RUN=0 bash -c "source '${REPO}/lib/core.sh'; source '${REPO}/lib/modules/theme.sh'; _vf_theme_apply mocha"

it "doctor sai com zero mesmo sem nada instalado"
assert_ok mod_theme_doctor

it "mod_theme_links emite o par do diretorio de estado"
assert_contains "$(mod_theme_links)" "$REPO/home/.config/powerterminal"

it "os quatro arquivos de paleta existem no repo"
faltando=""
for f in "${FLAVORS[@]}"; do
  [[ -f "$REPO/home/.config/kitty/themes/$f.conf" ]] || faltando="$faltando $f"
done
assert_eq "" "$faltando"

it "cada paleta define as 16 cores ANSI"
ruim=""
for f in "${FLAVORS[@]}"; do
  n="$(grep -cE '^color[0-9]+ ' "$REPO/home/.config/kitty/themes/$f.conf")"
  [[ "$n" == "16" ]] || ruim="$ruim $f($n)"
done
assert_eq "" "$ruim"

# Acoplamento real: o tab_bar.py identifica o flavor pelo `background` do tema
# carregado. Se um valor divergir, a barra de abas cai no fallback sem avisar.
it "os backgrounds do tab_bar.py casam com os themes do kitty"
ruim=""
for f in "${FLAVORS[@]}"; do
  bg="$(awk '/^background[[:space:]]/{print tolower($2)}' "$REPO/home/.config/kitty/themes/$f.conf")"
  grep -qF "\"$bg\"" "$REPO/home/.config/kitty/tab_bar.py" || ruim="$ruim $f($bg)"
done
assert_eq "" "$ruim"

# O estado e o include do kitty são versionados separados: um commit onde eles
# discordam entrega ao colega um Neovim/prompt num flavor e um terminal noutro.
it "no repo, o estado e o include do kitty concordam"
estado="$(cat "$REPO/home/.config/powerterminal/theme")"
estado="${estado//[[:space:]]/}"
assert_contains "$(cat "$REPO/home/.config/kitty/current-theme.conf")" "include themes/$estado.conf"

it "kitty.conf inclui o current-theme.conf"
assert_contains "$(cat "$REPO/home/.config/kitty/kitty.conf")" "include current-theme.conf"

it "kitty.conf nao tem mais paleta inline"
assert_eq "" "$(grep -oE '^color[0-9]+' "$REPO/home/.config/kitty/kitty.conf" || true)"

it "theme esta registrado em _PN_ALL_MODULES"
assert_ok grep -q '_PN_ALL_MODULES=(.*theme' "$REPO/bin/powerterminal"

it "o spec do Neovim le o estado do tema"
assert_contains "$(cat "$REPO/home/.config/nvim/lua/plugins/catppuccin.lua")" ".config/powerterminal/theme"

it "community.lua importa o pack do catppuccin"
assert_contains "$(cat "$REPO/home/.config/nvim/lua/community.lua")" "astrocommunity.colorscheme.catppuccin"

it "o override do prompt e sourceado depois do .p10k.zsh"
l_p10k="$(grep -n 'source ~/.p10k.zsh' "$REPO/home/.zshrc" | head -1 | cut -d: -f1)"
l_tema="$(grep -n 'p10k-theme.zsh' "$REPO/home/.zshrc" | head -1 | cut -d: -f1)"
if [[ -n "$l_p10k" && -n "$l_tema" ]] && (( l_tema > l_p10k )); then
  pass
else
  fail "esperado p10k-theme depois do .p10k.zsh (linhas: $l_p10k / $l_tema)"
fi

test_summary
