#!/usr/bin/env bash
set -euo pipefail
source "${POWERTERMINAL_HOME}/tests/lib.sh"
source "${POWERTERMINAL_HOME}/lib/core.sh"
for m in "${POWERTERMINAL_HOME}"/lib/modules/*.sh; do
  # shellcheck source=/dev/null
  source "$m"
done

MODULOS=(apt fonts zsh nvim astronvim kitty tools node helpers extras notiont container theme)

it "todo modulo declara mod_X_cost"
faltando=""
for m in "${MODULOS[@]}"; do
  declare -F "mod_${m}_cost" >/dev/null || faltando="$faltando $m"
done
assert_eq "" "$faltando"

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

test_summary
