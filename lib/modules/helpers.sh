# shellcheck shell=bash
# Module: helpers — symlink dos seus utilitários myastro/mykitty/myyazi para ~/.local/bin.

mod_helpers_meta() {
  echo "Utilitários myastro, mykitty e myyazi (ajuda do AstroNvim, Kitty e Yazi)"
}

mod_helpers_cost() { printf '1\t1\t0\n'; }

_PN_HELPERS=(myastro mykitty myyazi)

mod_helpers_install() {
  ensure_local_bin
  for h in "${_PN_HELPERS[@]}"; do
    local src="$POWERTERMINAL_HOME/bin-helpers/$h"
    [[ -f "$src" ]] || { log_warn "helper ausente no repo: $h"; continue; }
    if [[ ! -x "$src" ]]; then
      if [[ "$DRY_RUN" == "1" ]]; then
        log_dry "chmod +x $src"
      else
        chmod +x "$src" 2>/dev/null \
          || log_warn "Não foi possível setar +x em $src (FS read-only?)"
      fi
    fi
    link_safe "$src" "$HOME/.local/bin/$h"
  done
}

mod_helpers_links() {
  for h in "${_PN_HELPERS[@]}"; do
    printf '%s\t%s\n' "$POWERTERMINAL_HOME/bin-helpers/$h" "$HOME/.local/bin/$h"
  done
}

mod_helpers_doctor() {
  for h in "${_PN_HELPERS[@]}"; do
    if [[ -L "$HOME/.local/bin/$h" ]]; then
      status_line 1 "$h: linkado"
    elif [[ -e "$HOME/.local/bin/$h" ]]; then
      status_line 0 "$h: existe mas não é symlink do PowerTerminal"
    else
      status_line 0 "$h: ausente"
    fi
  done
}
