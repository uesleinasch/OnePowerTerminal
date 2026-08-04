#!/usr/bin/env bash
set -euo pipefail
source "${POWERTERMINAL_HOME}/tests/lib.sh"
source "${POWERTERMINAL_HOME}/lib/core.sh"
source "${POWERTERMINAL_HOME}/lib/ui.sh"
source "${POWERTERMINAL_HOME}/lib/modules/container.sh"

export POWERTERMINAL_UI=text

_registro="$(mktemp)"
_notas=""

# ---- Contrato e registro -----------------------------------------------------

it "mod_container_configure existe"
assert_ok declare -F mod_container_configure

it "mod_container_doctor existe (cmd_doctor chama sem checar)"
assert_ok declare -F mod_container_doctor

# A lista canônica de bin/powerterminal e a de tests/test_contract.sh são
# duplicadas: registrar num lugar só faz o módulo sumir em silêncio.
it "container esta registrado em _PN_ALL_MODULES"
assert_ok grep -q '_PN_ALL_MODULES=(.*container' "${POWERTERMINAL_HOME}/bin/powerterminal"

it "o perfil dev inclui container"
assert_ok grep -qE 'dev\).*container' "${POWERTERMINAL_HOME}/bin/powerterminal"

it "o Compose v2 vem no conjunto de pacotes do Docker"
assert_contains "${_PN_DOCKER_PKGS[*]}" "docker-compose-plugin"

it "container depende de apt"
assert_contains "$(mod_container_needs)" "apt"

# ---- Sonda: Docker real vs shim do podman-docker ------------------------------
# Roda a sonda num subprocesso com um `docker` controlado à frente do PATH.

_probe_real_docker() {
  PATH="$1:$PATH" bash -c "
    source '$POWERTERMINAL_HOME/lib/core.sh'
    source '$POWERTERMINAL_HOME/lib/modules/container.sh'
    _vf_is_real_docker"
}

it "um docker de verdade e reconhecido"
_fake_docker="$(mktemp -d)"
printf '#!/bin/sh\necho "Docker version 27.0.3, build 7d4bcd8"\n' > "$_fake_docker/docker"
chmod +x "$_fake_docker/docker"
assert_ok _probe_real_docker "$_fake_docker"

it "o shim do podman-docker NAO passa por docker"
_fake_shim="$(mktemp -d)"
printf '#!/bin/sh\necho "podman version 4.9.3"\n' > "$_fake_shim/docker"
chmod +x "$_fake_shim/docker"
assert_fail _probe_real_docker "$_fake_shim"

# ---- Precedência da escolha --------------------------------------------------
# Neutraliza as duas sondas de ambiente: a máquina do CI pode ter docker ou
# podman de verdade, e deixar o ambiente decidir tornaria os testes inúteis.
# A sonda real acabou de ser exercitada nos dois casos acima.
_vf_is_real_docker() { return 1; }
has_cmd() { [[ "$1" == "podman" && "${FAKE_PODMAN:-0}" == "1" ]]; }

_escolher() {
  POWERTERMINAL_ANSWERS_FILE="$(mktemp)"
  export POWERTERMINAL_ANSWERS_FILE
  ( mod_container_configure >/dev/null 2>&1 )
  pn_get_answer container.runtime "<nenhuma>"
}

it "POWERTERMINAL_CONTAINER_RUNTIME=podman e respeitada"
assert_eq "podman" "$(POWERTERMINAL_CONTAINER_RUNTIME=podman _escolher)"

it "POWERTERMINAL_CONTAINER_RUNTIME=docker e respeitada"
assert_eq "docker" "$(POWERTERMINAL_CONTAINER_RUNTIME=docker _escolher)"

it "env invalida cai no default docker"
assert_eq "docker" "$(POWERTERMINAL_CONTAINER_RUNTIME=lxc POWERTERMINAL_NONINTERACTIVE=1 _escolher)"

it "modo nao-interativo usa docker por default"
assert_eq "docker" "$(POWERTERMINAL_NONINTERACTIVE=1 _escolher)"

it "podman ja instalado ganha da pergunta"
assert_eq "podman" "$(FAKE_PODMAN=1 POWERTERMINAL_NONINTERACTIVE=1 _escolher)"

_escolher_com_docker() {
  POWERTERMINAL_ANSWERS_FILE="$(mktemp)"
  export POWERTERMINAL_ANSWERS_FILE
  (
    _vf_is_real_docker() { return 0; }
    mod_container_configure >/dev/null 2>&1
  )
  pn_get_answer container.runtime "<nenhuma>"
}

it "docker instalado ganha o desempate quando nada foi pedido"
assert_eq "docker" "$(FAKE_PODMAN=1 POWERTERMINAL_NONINTERACTIVE=1 _escolher_com_docker)"

# Um pedido explícito nunca pode ser engolido pela detecção: quem tem Docker e
# pede Podman está justamente tentando trocar.
it "pedido explicito de podman ganha do docker instalado"
assert_eq "podman" "$(FAKE_PODMAN=0 POWERTERMINAL_CONTAINER_RUNTIME=podman _escolher_com_docker)"

it "pedido explicito de docker ganha do podman instalado"
assert_eq "docker" "$(FAKE_PODMAN=1 POWERTERMINAL_CONTAINER_RUNTIME=docker _escolher)"

# ---- Grupo docker ------------------------------------------------------------
# Substitui as quatro dependências externas: identidade do usuário, existência
# do grupo, disponibilidade do sudo e execução privilegiada. Nada toca /etc.

_grupo() {
  POWERTERMINAL_NOTES_FILE="$(mktemp)"
  export POWERTERMINAL_NOTES_FILE
  : > "$_registro"
  (
    id() {
      case "$1" in
        -un) printf 'testuser\n' ;;
        -nG) printf '%s\n' "${FAKE_GRUPOS:-users audio}" ;;
        *) command id "$@" ;;
      esac
    }
    getent() { return "${FAKE_GETENT_RC:-0}"; }
    sudo_ready() { [[ "${FAKE_SUDO_OK:-1}" == "1" ]]; }
    as_sudo() { printf 'as_sudo %s\n' "$*" >> "$_registro"; return "${FAKE_SUDO_RC:-0}"; }
    _vf_add_docker_group
  ) >/dev/null 2>&1
  _notas="$(cat "$POWERTERMINAL_NOTES_FILE")"
}

it "fora do grupo e com sudo pronto, chama usermod -aG docker"
_grupo
assert_contains "$(cat "$_registro")" "as_sudo usermod -aG docker testuser"

it "apos adicionar, avisa que a mudanca so vale no proximo login"
assert_contains "$_notas" "login novo"

it "ja no grupo, nao chama usermod"
FAKE_GRUPOS="users docker" _grupo
assert_eq "" "$(cat "$_registro")"

it "ja no grupo, nao enfileira tarefa manual"
assert_eq "" "$_notas"

it "sem sudo disponivel, nao chama usermod"
FAKE_SUDO_OK=0 _grupo
assert_eq "" "$(cat "$_registro")"

it "sem sudo disponivel, deixa o grupo como tarefa manual"
assert_contains "$_notas" "usermod -aG docker testuser"

it "se o usermod falhar, cai na tarefa manual"
FAKE_SUDO_RC=1 _grupo
assert_contains "$_notas" "usermod -aG docker testuser"

it "grupo docker ausente e criado antes do usermod"
FAKE_GETENT_RC=1 _grupo
assert_contains "$(cat "$_registro")" "as_sudo groupadd -f docker"

it "em dry-run nao chama usermod nem enfileira tarefa"
_grupo_dry() {
  POWERTERMINAL_NOTES_FILE="$(mktemp)"
  export POWERTERMINAL_NOTES_FILE
  : > "$_registro"
  (
    DRY_RUN=1
    id() { case "$1" in -un) printf 'testuser\n' ;; -nG) printf 'users\n' ;; *) command id "$@" ;; esac; }
    as_sudo() { printf 'as_sudo %s\n' "$*" >> "$_registro"; }
    _vf_add_docker_group
  ) >/dev/null 2>&1
  _notas="$(cat "$POWERTERMINAL_NOTES_FILE")"
}
_grupo_dry
assert_eq "" "$(cat "$_registro")"

# ---- subuid/subgid do Podman rootless ----------------------------------------

_subid() {
  POWERTERMINAL_NOTES_FILE="$(mktemp)"
  export POWERTERMINAL_NOTES_FILE
  : > "$_registro"
  (
    id() { case "$1" in -un) printf 'testuser\n' ;; *) command id "$@" ;; esac; }
    # Intercepta só as consultas a /etc/subuid e /etc/subgid; o resto do grep
    # continua real para não afetar outras checagens.
    grep() {
      if [[ "$*" == */etc/subuid* || "$*" == */etc/subgid* ]]; then
        return "${FAKE_SUBID_RC:-1}"
      fi
      command grep "$@"
    }
    sudo_ready() { [[ "${FAKE_SUDO_OK:-1}" == "1" ]]; }
    as_sudo() { printf 'as_sudo %s\n' "$*" >> "$_registro"; return "${FAKE_SUDO_RC:-0}"; }
    _vf_ensure_subid
  ) >/dev/null 2>&1
  _notas="$(cat "$POWERTERMINAL_NOTES_FILE")"
}

it "subid ausente e configurado com o range esperado"
_subid
assert_contains "$(cat "$_registro")" "--add-subuids 100000-165535 --add-subgids 100000-165535 testuser"

it "subid ja configurado nao chama usermod"
FAKE_SUBID_RC=0 _subid
assert_eq "" "$(cat "$_registro")"

it "sem sudo, subid vira tarefa manual"
FAKE_SUDO_OK=0 _subid
assert_contains "$_notas" "--add-subuids"

it "se o usermod de subid falhar, cai na tarefa manual"
FAKE_SUDO_RC=1 _subid
assert_contains "$_notas" "--add-subuids"

# ---- Repositório do Docker por distro ----------------------------------------

_base_repo() {
  (
    _vf_os_release_val() {
      case "$1" in
        ID) printf '%s' "${FAKE_ID:-}" ;;
        ID_LIKE) printf '%s' "${FAKE_ID_LIKE:-}" ;;
      esac
    }
    _vf_docker_repo_base
  )
}

it "Ubuntu usa o repo linux/ubuntu"
assert_eq "ubuntu" "$(FAKE_ID=ubuntu _base_repo)"

it "Debian usa o repo linux/debian"
assert_eq "debian" "$(FAKE_ID=debian _base_repo)"

it "Pop!_OS cai no repo do Ubuntu via ID_LIKE"
assert_eq "ubuntu" "$(FAKE_ID=pop FAKE_ID_LIKE="ubuntu debian" _base_repo)"

it "derivado so-Debian cai no repo do Debian"
assert_eq "debian" "$(FAKE_ID=linuxmint FAKE_ID_LIKE=debian _base_repo)"

it "distro sem base conhecida e recusada"
_base_desconhecida() { FAKE_ID=arch FAKE_ID_LIKE="" _base_repo; }
assert_fail _base_desconhecida

_suite_repo() {
  (
    _vf_os_release_val() {
      case "$1" in
        UBUNTU_CODENAME) printf '%s' "${FAKE_UBUNTU_CODENAME:-}" ;;
        VERSION_CODENAME) printf '%s' "${FAKE_VERSION_CODENAME:-}" ;;
      esac
    }
    _vf_docker_repo_suite
  )
}

it "UBUNTU_CODENAME ganha de VERSION_CODENAME em derivado"
assert_eq "jammy" "$(FAKE_UBUNTU_CODENAME=jammy FAKE_VERSION_CODENAME=vera _suite_repo)"

it "sem UBUNTU_CODENAME usa VERSION_CODENAME"
assert_eq "bookworm" "$(FAKE_VERSION_CODENAME=bookworm _suite_repo)"

# ---- Despacho do install e guarda de container -------------------------------

_instalar() {
  POWERTERMINAL_NOTES_FILE="$(mktemp)"
  export POWERTERMINAL_NOTES_FILE
  POWERTERMINAL_ANSWERS_FILE="$(mktemp)"
  export POWERTERMINAL_ANSWERS_FILE
  : > "$_registro"
  [[ -n "${1:-}" ]] && pn_set_answer container.runtime "$1"
  (
    _vf_in_container() { [[ "${FAKE_IN_CONTAINER:-0}" == "1" ]]; }
    require_supported_distro() { :; }
    apt_update_once() { :; }
    _vf_install_docker() { printf 'docker\n' >> "$_registro"; }
    _vf_install_podman() { printf 'podman\n' >> "$_registro"; }
    mod_container_install
  ) >/dev/null 2>&1
  _notas="$(cat "$POWERTERMINAL_NOTES_FILE")"
}

it "runtime docker despacha para o instalador do Docker"
_instalar docker
assert_eq "docker" "$(cat "$_registro")"

it "runtime podman despacha para o instalador do Podman"
_instalar podman
assert_eq "podman" "$(cat "$_registro")"

it "sem resposta gravada, o default do getter e docker"
_instalar ""
assert_eq "docker" "$(cat "$_registro")"

# --profile e --module nao passam pelo wizard, entao mod_container_configure
# nunca roda e nenhuma resposta e gravada. Sem o fallback no install, a env var
# seria ignorada em silencio exatamente no modo onde ela e a unica via.
it "sem wizard, POWERTERMINAL_CONTAINER_RUNTIME ainda decide"
POWERTERMINAL_CONTAINER_RUNTIME=podman _instalar ""
assert_eq "podman" "$(cat "$_registro")"

it "sem wizard, um podman ja instalado decide"
FAKE_PODMAN=1 _instalar ""
assert_eq "podman" "$(cat "$_registro")"

it "a resposta gravada pelo wizard ganha da env var"
POWERTERMINAL_CONTAINER_RUNTIME=podman _instalar docker
assert_eq "docker" "$(cat "$_registro")"

it "dentro de um container, nenhum runtime e instalado"
FAKE_IN_CONTAINER=1 _instalar docker
assert_eq "" "$(cat "$_registro")"

it "dentro de um container, explica como instalar na maquina real"
assert_contains "$_notas" "--module container"

it "runtime desconhecido falha em vez de instalar silenciosamente"
_instalar_invalido() {
  POWERTERMINAL_ANSWERS_FILE="$(mktemp)"
  export POWERTERMINAL_ANSWERS_FILE
  pn_set_answer container.runtime lxc
  (
    _vf_in_container() { return 1; }
    require_supported_distro() { :; }
    apt_update_once() { :; }
    mod_container_install
  )
}
assert_fail _instalar_invalido

test_summary
