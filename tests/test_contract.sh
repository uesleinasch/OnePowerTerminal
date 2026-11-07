#!/usr/bin/env bash
set -euo pipefail
source "${POWERTERMINAL_HOME}/tests/lib.sh"
TMP_HOME="$(mktemp -d)"
trap 'rm -rf "$TMP_HOME"' EXIT
export HOME="$TMP_HOME" XDG_STATE_HOME="$TMP_HOME/state"
source "${POWERTERMINAL_HOME}/lib/core.sh"
source "${POWERTERMINAL_HOME}/lib/receipt.sh"
for m in "${POWERTERMINAL_HOME}"/lib/modules/*.sh; do
  # shellcheck source=/dev/null
  source "$m"
done

MODULOS=(apt fonts zsh nvim astronvim vscode kitty eza starship lazygit lazydocker uv yazi node claude helpers btop ranger picom flameshot notiont container theme)

it "todo modulo declara mod_X_cost"
faltando=""
for m in "${MODULOS[@]}"; do
  declare -F "mod_${m}_cost" >/dev/null || faltando="$faltando $m"
done
assert_eq "" "$faltando"

it "todo modulo declara installed, name e category"
faltando=""
for m in "${MODULOS[@]}"; do
  for f in installed name category; do
    declare -F "mod_${m}_${f}" >/dev/null || faltando="$faltando ${m}:${f}"
  done
done
assert_eq "" "$faltando"

it "category e uma das seis"
ruim=""
for m in "${MODULOS[@]}"; do
  declare -F "mod_${m}_category" >/dev/null || { ruim="$ruim $m"; continue; }
  case "$("mod_${m}_category")" in
    base|shell|editor|terminal|dev|extras) ;;
    *) ruim="$ruim $m" ;;
  esac
done
assert_eq "" "$ruim"

it "name tem uma linha nao vazia"
ruim=""
for m in "${MODULOS[@]}"; do
  declare -F "mod_${m}_name" >/dev/null || { ruim="$ruim $m"; continue; }
  [[ "$("mod_${m}_name" | wc -l)" == "1" && -n "$("mod_${m}_name")" ]] || ruim="$ruim $m"
done
assert_eq "" "$ruim"

it "installed nao imprime nada"
ruim=""
for m in "${MODULOS[@]}"; do
  declare -F "mod_${m}_installed" >/dev/null || { ruim="$ruim $m"; continue; }
  saida="$("mod_${m}_installed" 2>&1 || true)"
  [[ -z "$saida" ]] || ruim="$ruim $m"
done
assert_eq "" "$ruim"

it "todo cost tem 3 campos separados por TAB"
ruim=""
for m in "${MODULOS[@]}"; do
  n="$("mod_${m}_cost" | awk -F'\t' '{print NF}')"
  [[ "$n" == "3" ]] || ruim="$ruim $m($n)"
done
assert_eq "" "$ruim"

it "minutos e MB sao numeros e sudo e 0 ou 1"
ruim=""
for m in "${MODULOS[@]}"; do
  IFS=$'\t' read -r min mb sudo < <("mod_${m}_cost")
  [[ "$min" =~ ^[0-9]+$ && "$mb" =~ ^[0-9]+$ && "$sudo" =~ ^[01]$ ]] || ruim="$ruim $m"
done
assert_eq "" "$ruim"

it "todo needs referencia um modulo existente"
ruim=""
for m in "${MODULOS[@]}"; do
  declare -F "mod_${m}_needs" >/dev/null || continue
  while read -r dep; do
    [[ -z "$dep" ]] && continue
    declare -F "mod_${dep}_install" >/dev/null || ruim="$ruim $m->$dep"
  done < <("mod_${m}_needs")
done
assert_eq "" "$ruim"

it "astronvim depende de nvim"
assert_contains "$(mod_astronvim_needs)" "nvim"

it "fonts depende de apt (precisa de fontconfig)"
assert_contains "$(mod_fonts_needs)" "apt"

it "nenhuma dependencia aponta para tras na ordem canonica"
ruim=""
for m in "${MODULOS[@]}"; do
  declare -F "mod_${m}_needs" >/dev/null || continue
  pos_m=-1; for i in "${!MODULOS[@]}"; do [[ "${MODULOS[$i]}" == "$m" ]] && pos_m=$i; done
  while read -r dep; do
    [[ -z "$dep" ]] && continue
    pos_d=-1; for i in "${!MODULOS[@]}"; do [[ "${MODULOS[$i]}" == "$dep" ]] && pos_d=$i; done
    (( pos_d < pos_m )) || ruim="$ruim $m->$dep"
  done < <("mod_${m}_needs")
done
assert_eq "" "$ruim"

it "ensure_curl existe e e idempotente quando o curl ja esta presente"
assert_ok ensure_curl

it "download_to e curl_pipe garantem o curl antes de usar"
faltando=""
for f in download_to curl_pipe; do
  declare -f "$f" | grep -q 'ensure_curl' || faltando="$faltando $f"
done
assert_eq "" "$faltando"

it "todo modulo declara about e provides"
faltando=""
for m in "${MODULOS[@]}"; do
  for f in about provides; do
    declare -F "mod_${m}_${f}" >/dev/null || faltando="$faltando ${m}:${f}"
  done
done
assert_eq "" "$faltando"

it "about tem entre 2 e 4 frases em uma linha"
ruim=""
for m in "${MODULOS[@]}"; do
  declare -F "mod_${m}_about" >/dev/null || { ruim="$ruim $m"; continue; }
  txt="$("mod_${m}_about")"
  n="$(grep -o '[.!?]\( \|$\)' <<<"$txt" | wc -l)"
  [[ "$(wc -l <<<"$txt")" == 1 && "$n" -ge 2 && "$n" -le 4 ]] || ruim="$ruim $m($n)"
done
assert_eq "" "$ruim"

it "provides emite so linhas kind<TAB>valor com kind permitido"
ruim=""
for m in "${MODULOS[@]}"; do
  declare -F "mod_${m}_provides" >/dev/null || { ruim="$ruim $m"; continue; }
  n=0
  while IFS=$'\t' read -r k v extra; do
    n=$((n+1))
    case "$k" in bin|apt|dir|config|repo|font|shell|group|service) ;; *) ruim="$ruim ${m}:kind=$k" ;; esac
    [[ -n "$v" && -z "$extra" ]] || ruim="$ruim ${m}:valor"
  done < <("mod_${m}_provides" 2>/dev/null)
  (( n > 0 )) || ruim="$ruim ${m}:vazio"
done
assert_eq "" "$ruim"

it "so-links e detectado pelo corpo de installed: astronvim sim, btop nunca"
assert_ok pn_installed_so_links astronvim
assert_ok pn_installed_so_links helpers
assert_fail pn_installed_so_links btop
assert_fail pn_installed_so_links kitty

test_summary
