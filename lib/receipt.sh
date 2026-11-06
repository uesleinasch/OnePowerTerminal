# shellcheck shell=bash

pn_receipt_dir() { printf '%s/powerterminal/receipts\n' "${XDG_STATE_HOME:-$HOME/.local/state}"; }

pn_receipt_path() { printf '%s/%s\n' "$(pn_receipt_dir)" "$1"; }

pn_receipt_has() { [[ -f "$(pn_receipt_path "$1")" ]]; }

pn_receipt_origin() {
  local f; f="$(pn_receipt_path "$1")"
  [[ -f "$f" ]] || return 0
  awk -F'\t' '$1 == "origin" {print $2; exit}' "$f"
}

pn_receipt_entries() {
  local f; f="$(pn_receipt_path "$1")"
  [[ -f "$f" ]] || return 0
  awk -F'\t' -v t="${2:-}" '$1 != "origin" && (t == "" || $1 == t)' "$f"
}

pn_receipt_add() {
  local mod="${PN_RECEIPT_MODULE:-}"
  [[ -n "$mod" && "${DRY_RUN:-0}" != "1" ]] || return 0
  local f linha
  f="$(pn_receipt_path "$mod")"
  linha="$(printf '%s\t%s' "$1" "$2")"
  if [[ ! -f "$f" ]]; then
    mkdir -p "$(dirname "$f")"
    printf 'origin\tinstalled\n' >"$f"
  fi
  grep -qxF -- "$linha" "$f" || printf '%s\n' "$linha" >>"$f"
}
