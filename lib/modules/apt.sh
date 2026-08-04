# shellcheck shell=bash
# Module: apt — base system packages (sem git/npm).

mod_apt_meta() {
  echo "Pacotes base do sistema (curl, ripgrep, fzf, jq, unzip…)"
}

mod_apt_cost() { printf '2\t150\t1\n'; }

# Pacotes considerados essenciais para o resto do toolchain.
# IMPORTANTE: git/npm/nodejs ficam de fora por decisão de design.
_PN_APT_PKGS=(
  ca-certificates
  curl
  wget
  unzip
  fontconfig
  build-essential
  whiptail
  ripgrep
  fd-find
  fzf
  jq
  tree
  bat
  htop
  xclip
)

mod_apt_install() {
  require_supported_distro
  apt_update_once
  log_info "Instalando pacotes base via apt-get…"
  apt_install "${_PN_APT_PKGS[@]}"
  # FiraCode é opcional — ignora se não estiver no repositório
  if ! dpkg -s fonts-firacode >/dev/null 2>&1; then
    if [[ "$DRY_RUN" == "1" ]]; then
      log_dry "apt-get install -y fonts-firacode (opcional)"
    else
      as_sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y fonts-firacode 2>/dev/null \
        || log_warn "fonts-firacode indisponível neste repositório (ok, segue sem)."
    fi
  fi
}

mod_apt_doctor() {
  local missing=()
  for p in "${_PN_APT_PKGS[@]}"; do
    dpkg -s "$p" >/dev/null 2>&1 || missing+=("$p")
  done
  if [[ ${#missing[@]} -eq 0 ]]; then
    status_line 1 "apt: todos os pacotes base instalados"
  else
    status_line 0 "apt: faltam ${#missing[@]} (${missing[*]})"
  fi
}
