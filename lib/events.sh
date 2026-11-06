# shellcheck shell=bash

pn_events_open() {
  local fd="${1:-}"
  [[ "$fd" =~ ^[0-9]+$ ]] && { : >&"$fd"; } 2>/dev/null \
    || die "--events-fd $fd não está aberto."
  PN_EVENTS_FD="$fd"
  export PN_EVENTS_FD
}

pn_json_str() {
  local s="$1" out="" c i
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"
  s="${s//$'\t'/\\t}"
  s="${s//$'\r'/\\r}"
  if [[ "$s" =~ [[:cntrl:]] ]]; then
    for (( i = 0; i < ${#s}; i++ )); do
      c="${s:i:1}"
      if [[ "$c" =~ [[:cntrl:]] ]]; then
        printf -v c '\\u%04x' "'$c"
      fi
      out+="$c"
    done
    s="$out"
  fi
  printf '"%s"' "$s"
}

pn_json_array() {
  local out="" item
  for item in "$@"; do
    out+="${out:+,}$(pn_json_str "$item")"
  done
  printf '[%s]' "$out"
}

# chave=valor tipa o valor (número, booleano ou string); chave:=JSON insere JSON já pronto (ex.: pn_json_array).
pn_event() {
  [[ -n "${PN_EVENTS_FD:-}" ]] || return 0
  local line arg key val
  line="{\"event\":$(pn_json_str "$1")"
  shift
  for arg in "$@"; do
    key="${arg%%=*}"
    val="${arg#*=}"
    if [[ "$key" == *: ]]; then
      line+=",$(pn_json_str "${key%:}"):$val"
    elif [[ "$val" =~ ^-?[0-9]+$ || "$val" == true || "$val" == false ]]; then
      line+=",$(pn_json_str "$key"):$val"
    else
      line+=",$(pn_json_str "$key"):$(pn_json_str "$val")"
    fi
  done
  printf '%s}\n' "$line" >&"$PN_EVENTS_FD" 2>/dev/null || true
}

pn_step() {
  log_info "$3"
  pn_event step "module=${PN_EVENT_MODULE:-}" "text=$3" "n=$1" "m=$2"
}

pn_session_restart() {
  post_install_note "Reinicie a máquina (ou saia da sessão e entre de novo) para $1 — a mudança só vale num login novo."
  pn_event session_restart "module=${PN_EVENT_MODULE:-}" "reason=$1"
}
