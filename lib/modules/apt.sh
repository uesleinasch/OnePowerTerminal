# shellcheck shell=bash
# Module: apt — base system packages (sem npm; git é pré-requisito dos módulos que clonam).

mod_apt_meta() {
  echo "Pacotes base do sistema (curl, ripgrep, fzf, jq, unzip…)"
}

mod_apt_cost() { printf '2\t150\t1\n'; }

mod_apt_name() { echo "Pacotes base"; }

mod_apt_category() { echo base; }

mod_apt_about() {
  echo "Instala pelo apt os pacotes base que o resto do ambiente usa: curl, wget, unzip, ripgrep, fd, fzf, jq, bat, htop, build-essential e afins, mais a fonte FiraCode quando o repositório a oferece. Altera o sistema inteiro e pede sudo. Remover purga do apt só os pacotes que o PowerTerminal instalou, sem tocar nos que já existiam."
}

mod_apt_provides() {
  local p
  for p in "${_PN_APT_PKGS[@]}" fonts-firacode; do
    printf 'apt\t%s\n' "$p"
  done
}

mod_apt_installed() {
  local p
  for p in "${_PN_APT_PKGS[@]}"; do
    dpkg -s "$p" >/dev/null 2>&1 || return 1
  done
}

# Pacotes considerados essenciais para o resto do toolchain.
# IMPORTANTE: npm/nodejs ficam de fora por decisão de design. git também não
# entra aqui: quem precisa dele declara em mod_X_requires, e o install o
# instala só quando falta — assim `--module nvim` não arrasta git.
_PN_APT_PKGS=(
  ca-certificates
  curl
  wget
  unzip
  fontconfig
  build-essential
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

mod_apt_update() {
  log_info "Atualizando pacotes base via apt-get…"
  apt_upgrade_instalados "${_PN_APT_PKGS[@]}"
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
