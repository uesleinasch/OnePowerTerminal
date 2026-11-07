# shellcheck shell=bash
# Module: extras — configs auxiliares (btop, ranger, picom, flameshot).

mod_extras_meta() {
  echo "Configs auxiliares (btop, ranger, picom, flameshot)"
}

mod_extras_cost() { printf '1\t5\t0\n'; }

mod_extras_name() { echo "Configs extras"; }

mod_extras_category() { echo extras; }

mod_extras_installed() { pn_links_installed extras; }

_PN_EXTRA_DIRS=(btop ranger picom flameshot)

# Itera somente sobre os módulos cuja config existe no repo.
_vf_extras_present() {
  for d in "${_PN_EXTRA_DIRS[@]}"; do
    [[ -d "$POWERTERMINAL_HOME/home/.config/$d" ]] && echo "$d"
  done
}

mod_extras_install() {
  for d in $(_vf_extras_present); do
    link_safe "$POWERTERMINAL_HOME/home/.config/$d" "$HOME/.config/$d"
  done
}

mod_extras_links() {
  for d in $(_vf_extras_present); do
    printf '%s\t%s\n' "$POWERTERMINAL_HOME/home/.config/$d" "$HOME/.config/$d"
  done
}

mod_extras_doctor() {
  for d in $(_vf_extras_present); do
    if [[ -L "$HOME/.config/$d" ]]; then
      status_line 1 "$d: linkado"
    else
      status_line 0 "$d: não linkado"
    fi
  done
}

mod_extras_remove() { pn_receipt_undo extras; }
