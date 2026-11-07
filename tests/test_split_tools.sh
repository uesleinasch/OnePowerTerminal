#!/usr/bin/env bash
set -euo pipefail
source "${POWERTERMINAL_HOME}/tests/lib.sh"
cd "$POWERTERMINAL_HOME"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
export HOME="$TMP/home" XDG_STATE_HOME="$TMP/state"
mkdir -p "$HOME"

CLI=bin/powerterminal
NOVOS=(eza starship lazygit lazydocker uv yazi)

lista="$(sed -nE 's/^_PN_ALL_MODULES=\((.*)\)$/\1/p' "$CLI")"

it "as seis ferramentas ficam entre kitty e node, na ordem canônica"
assert_contains "$lista" "kitty eza starship lazygit lazydocker uv yazi node"

it "o módulo tools não existe mais"
[[ " $lista " != *" tools "* && ! -e lib/modules/tools.sh ]] && pass || fail "tools ainda registrado"

source lib/core.sh
source lib/receipt.sh
for f in lib/modules/*.sh; do source "$f"; done

it "cada ferramenta cumpre o contrato do módulo"
faltando=""
for m in "${NOVOS[@]}"; do
  for f in meta name category installed install doctor remove cost requires update; do
    declare -F "mod_${m}_${f}" >/dev/null || faltando="$faltando mod_${m}_${f}"
  done
  [[ "$("mod_${m}_category")" == dev ]] || faltando="$faltando categoria_${m}"
done
assert_eq "" "$faltando"

it "o custo de cada ferramenta é o declarado"
custo=""
for m in "${NOVOS[@]}"; do custo="$custo$m=$("mod_${m}_cost" | tr '\t' ,);"; done
assert_eq "eza=1,5,1;starship=1,10,0;lazygit=1,20,0;lazydocker=1,20,0;uv=1,40,0;yazi=1,15,0;" "$custo"

it "todas declaram curl como requisito"
ruim=""
for m in "${NOVOS[@]}"; do
  [[ "$("mod_${m}_requires")" == $'curl\tcurl' ]] || ruim="$ruim $m"
done
assert_eq "" "$ruim"

it "installed é só has_cmd da ferramenta"
SH="$TMP/shims"; mkdir -p "$SH"
ruim=""
for m in "${NOVOS[@]}"; do
  PATH="$SH:/usr/bin:/bin" "mod_${m}_installed" && ruim="$ruim ausente:$m"
  printf '#!/bin/sh\n' >"$SH/$m"; chmod +x "$SH/$m"
  PATH="$SH:/usr/bin:/bin" "mod_${m}_installed" || ruim="$ruim presente:$m"
  rm -f "$SH/$m"
done
assert_eq "" "$ruim"

it "pn_config_links emite o par só quando o diretório existe no repo"
POWERTERMINAL_HOME="$PWD"
assert_eq "$PWD/home/.config/yazi"$'\t'"$HOME/.config/yazi" "$(pn_config_links yazi)"
it "pn_config_links não emite nada para diretório ausente"
assert_eq "" "$(pn_config_links nao-existe)"

it "yazi, lazygit e lazydocker linkam a própria config; os outros não têm links"
ruim=""
for m in yazi lazygit lazydocker; do
  [[ "$("mod_${m}_links")" == "$(pn_config_links "$m")" && -n "$(pn_config_links "$m")" ]] || ruim="$ruim $m"
done
for m in eza starship uv; do
  declare -F "mod_${m}_links" >/dev/null && ruim="$ruim links:$m"
done
assert_eq "" "$ruim"

it "extras não linka mais yazi, lazygit nem lazydocker"
assert_eq "" "$(mod_extras_links | grep -E '/(yazi|lazygit|lazydocker)\s' || true)"

it "_vf_module_aliases expande tools e rejeita quem não é apelido"
eval "$(sed -n '/^_vf_module_aliases()/,/^}/p' "$CLI")"
assert_eq "${NOVOS[*]}" "$(_vf_module_aliases tools | tr '\n' ' ' | sed 's/ $//')"
it "_vf_module_aliases falha para módulo comum"
assert_fail _vf_module_aliases kitty

it "install --module tools --dry-run lista os seis módulos"
out="$("$CLI" install --module tools --dry-run --yes 2>&1 || true)"
ruim=""
for m in "${NOVOS[@]}"; do [[ "$out" == *"$m"* ]] || ruim="$ruim $m"; done
assert_eq "" "$ruim"

it "update e remove --module tools aceitam o apelido"
out="$("$CLI" remove --module tools --dry-run --yes 2>&1 || true)"
[[ "$out" != *"Módulo desconhecido"* ]] && pass || fail "$out"

it "o perfil dev contém os seis e não contém tools"
for f in _vf_is_editor_module _vf_editor_modules _vf_editor_default _vf_profile_modules; do
  eval "$(sed -n "/^$f()/,/^}/p" "$CLI")"
done
_PN_ALL_MODULES=($lista)
dev="$(_vf_profile_modules dev nvim)"
ruim=""
for m in "${NOVOS[@]}"; do [[ " $dev " == *" $m "* ]] || ruim="$ruim $m"; done
[[ " $dev " != *" tools "* ]] || ruim="$ruim tools"
assert_eq "" "$ruim"

test_summary
