# shellcheck shell=bash
# Module: container — runtime de container: Docker (daemon + grupo) ou Podman (rootless).

mod_container_meta() {
  echo "Docker ou Podman (escolha do usuário) — grupo docker ou rootless; idempotente"
}

# Números do caminho Docker, que é o mais caro. O Podman pesa bem menos, mas o
# cost é consultado pelo teste de contrato antes de qualquer escolha existir:
# um valor dinâmico criaria um caminho que só serve para embelezar o resumo.
mod_container_cost() { printf '4\t520\t1\n'; }

mod_container_needs() { echo apt; }

_PN_DOCKER_PKGS=(docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin)
_PN_SUBID_RANGE_START=100000
_PN_SUBID_RANGE_END=165535

# `podman-docker` instala um /usr/bin/docker que é shim do podman, então
# `has_cmd docker` não distingue os dois — e escolher "docker" por causa do shim
# faria o módulo instalar o daemon por cima de um Podman que já funciona.
# O Docker real responde "Docker version X"; o shim responde com a do podman.
_vf_is_real_docker() {
  has_cmd docker || return 1
  docker --version </dev/null 2>/dev/null | grep -qi '^docker version'
}

# Instalar um runtime de container dentro de um container não produz ambiente
# utilizável (o daemon não sobe sem privilégio) e o docker/Dockerfile deste repo
# roda o instalador exatamente assim.
_vf_in_container() {
  [[ -f /.dockerenv ]] || [[ -f /run/.containerenv ]] \
    || grep -qa 'container=' /proc/1/environ 2>/dev/null
}

# Lê uma chave do /etc/os-release num subshell: sourcear no escopo do módulo
# faria ID/VERSION_CODENAME vazarem e colidirem com variáveis do chamador.
_vf_os_release_val() {
  [[ -r /etc/os-release ]] || return 0
  (
    # shellcheck disable=SC1091
    . /etc/os-release
    printf '%s' "${!1:-}"
  )
}

# O repo do Docker publica só linux/ubuntu e linux/debian. Derivados (Pop!_OS,
# Mint) têm ID próprio, então o que serve é a base declarada em ID_LIKE.
_vf_docker_repo_base() {
  local id id_like
  id="$(_vf_os_release_val ID)"
  id_like="$(_vf_os_release_val ID_LIKE)"
  case "$id" in
    ubuntu) printf 'ubuntu\n'; return 0 ;;
    debian) printf 'debian\n'; return 0 ;;
  esac
  if [[ "$id_like" =~ ubuntu ]]; then
    printf 'ubuntu\n'
  elif [[ "$id_like" =~ debian ]]; then
    printf 'debian\n'
  else
    return 1
  fi
}

# Pop!_OS 22.04 declara VERSION_CODENAME=jammy, mas derivados podem trazer um
# nome próprio que não existe no repo do Docker. UBUNTU_CODENAME, quando
# presente, é sempre o nome da base — por isso vem primeiro.
_vf_docker_repo_suite() {
  local ubuntu_codename version_codename
  ubuntu_codename="$(_vf_os_release_val UBUNTU_CODENAME)"
  version_codename="$(_vf_os_release_val VERSION_CODENAME)"
  printf '%s\n' "${ubuntu_codename:-$version_codename}"
}

# Resolve o runtime sem perguntar nada: pedido explícito, depois o que já está
# instalado. Devolve vazio quando nada decidiu — só nesse caso vale perguntar.
# Avisos vão para stderr de propósito: o stdout desta função é capturado.
_vf_runtime_decidido() {
  local pedido="${POWERTERMINAL_CONTAINER_RUNTIME:-}"

  case "$pedido" in
    docker|podman) ;;
    "") ;;
    *)
      log_warn "POWERTERMINAL_CONTAINER_RUNTIME inválido: '$pedido' (use docker|podman)"
      pedido=""
      ;;
  esac

  # O pedido explícito ganha da detecção. Deixar o que já está instalado vencer
  # tornaria a variável inerte justamente em quem já tem um runtime — que é a
  # maioria de quem quer trocar — e a troca ficaria impossível sem interação.
  if [[ -n "$pedido" ]]; then
    if [[ "$pedido" == podman ]] && _vf_is_real_docker; then
      log_warn "Docker já instalado, mas foi pedido Podman: os dois disputam /usr/bin/docker."
    elif [[ "$pedido" == docker ]] && has_cmd podman; then
      log_warn "Podman já instalado, mas foi pedido Docker: os dois disputam /usr/bin/docker."
    fi
    printf '%s\n' "$pedido"
    return 0
  fi

  if _vf_is_real_docker; then
    printf 'docker\n'
  elif has_cmd podman; then
    printf 'podman\n'
  fi
  return 0
}

mod_container_configure() {
  local escolha
  escolha="$(_vf_runtime_decidido)"

  if [[ -z "$escolha" ]]; then
    if [[ "${POWERTERMINAL_NONINTERACTIVE:-0}" == "1" ]] || ! [[ -t 0 ]]; then
      escolha=docker
    else
      escolha="$(ui_choose "Runtime de container" \
        docker:"daemon + grupo docker (mais compatível)" \
        podman:"rootless, sem daemon nem grupo")"
    fi
  fi

  pn_set_answer container.runtime "$escolha"
}

# ---- Docker ------------------------------------------------------------------

_vf_nota_grupo_docker() {
  post_install_note "Adicione seu usuário ao grupo docker: sudo usermod -aG docker $1 — depois reinicie a máquina (ou saia da sessão e entre de novo), porque a mudança de grupo só vale no próximo login."
}

# Sem o grupo, todo comando docker exige sudo. A troca não se aplica à sessão
# corrente: os grupos são fixados no login, e nenhum comando muda isso de fora.
_vf_add_docker_group() {
  local usuario
  usuario="$(id -un)"

  if id -nG "$usuario" 2>/dev/null | tr ' ' '\n' | grep -qx docker; then
    log_info "OK: $usuario já está no grupo docker."
    return 0
  fi

  if [[ "$DRY_RUN" == "1" ]]; then
    log_dry "usermod -aG docker $usuario"
    return 0
  fi

  if ! getent group docker >/dev/null 2>&1; then
    log_warn "grupo 'docker' ausente (o pacote deveria criá-lo) — criando."
    as_sudo groupadd -f docker || log_warn "groupadd docker falhou."
  fi

  if ! sudo_ready; then
    log_warn "sudo indisponível sem senha — grupo docker vai para as tarefas manuais."
    _vf_nota_grupo_docker "$usuario"
    return 0
  fi

  if as_sudo usermod -aG docker "$usuario"; then
    log_success "$usuario adicionado ao grupo docker."
    post_install_note "Reinicie a máquina (ou saia da sessão e entre de novo) para o grupo docker valer — a mudança só se aplica num login novo. Para testar já nesta sessão: 'newgrp docker'."
  else
    log_warn "usermod falhou — grupo docker vai para as tarefas manuais."
    _vf_nota_grupo_docker "$usuario"
  fi
}

# O pacote já habilita o serviço, mas em ambiente sem systemd (WSL antigo, imagem
# enxuta) isso não acontece e o daemon fica fora do boot sem avisar.
_vf_enable_docker_service() {
  if [[ "$DRY_RUN" == "1" ]]; then
    log_dry "systemctl enable --now docker.service"
    return 0
  fi
  if ! has_cmd systemctl || [[ ! -d /run/systemd/system ]]; then
    log_warn "systemd não detectado — inicie o daemon do Docker manualmente."
    post_install_note "Sem systemd nesta máquina: inicie o daemon do Docker manualmente (ex.: sudo dockerd &) antes de usar."
    return 0
  fi
  as_sudo systemctl enable --now docker.service \
    || log_warn "não consegui habilitar docker.service."
}

_vf_install_docker() {
  local base suite

  base="$(_vf_docker_repo_base)" \
    || die "Não sei qual repositório do Docker usar nesta distro (ID/ID_LIKE de /etc/os-release não são ubuntu nem debian)."
  suite="$(_vf_docker_repo_suite)"
  [[ -n "$suite" ]] \
    || die "Não consegui descobrir o codename da distro em /etc/os-release."

  log_info "Repositório oficial do Docker: linux/$base suite=$suite"
  apt_add_repo docker \
    "https://download.docker.com/linux/${base}/gpg" \
    "https://download.docker.com/linux/${base}" \
    "$suite" \
    stable

  log_info "Instalando Docker Engine, Compose v2 e buildx…"
  apt_install "${_PN_DOCKER_PKGS[@]}"

  _vf_enable_docker_service
  _vf_add_docker_group
}

# ---- Podman ------------------------------------------------------------------

_vf_nota_subid() {
  post_install_note "Configure o mapeamento rootless do Podman: sudo usermod --add-subuids ${_PN_SUBID_RANGE_START}-${_PN_SUBID_RANGE_END} --add-subgids ${_PN_SUBID_RANGE_START}-${_PN_SUBID_RANGE_END} $1"
}

# Rootless depende de um range de UIDs/GIDs subordinados. O pacote costuma
# popular /etc/subuid, mas um usuário criado com `useradd` cru (o caso do
# container de teste deste repo) fica sem e o podman falha só ao rodar.
_vf_ensure_subid() {
  local usuario
  usuario="$(id -un)"

  if grep -q "^${usuario}:" /etc/subuid 2>/dev/null \
    && grep -q "^${usuario}:" /etc/subgid 2>/dev/null; then
    log_info "OK: subuid/subgid já configurados para $usuario."
    return 0
  fi

  if [[ "$DRY_RUN" == "1" ]]; then
    log_dry "usermod --add-subuids ${_PN_SUBID_RANGE_START}-${_PN_SUBID_RANGE_END} --add-subgids ${_PN_SUBID_RANGE_START}-${_PN_SUBID_RANGE_END} $usuario"
    return 0
  fi

  if ! sudo_ready; then
    log_warn "sudo indisponível sem senha — subuid/subgid vai para as tarefas manuais."
    _vf_nota_subid "$usuario"
    return 0
  fi

  if as_sudo usermod \
    --add-subuids "${_PN_SUBID_RANGE_START}-${_PN_SUBID_RANGE_END}" \
    --add-subgids "${_PN_SUBID_RANGE_START}-${_PN_SUBID_RANGE_END}" \
    "$usuario"; then
    log_success "subuid/subgid configurados para $usuario."
  else
    log_warn "usermod --add-subuids falhou — vai para as tarefas manuais."
    _vf_nota_subid "$usuario"
  fi
}

# O socket de usuário é o que faz DOCKER_HOST e ferramentas que falam a API do
# Docker (testcontainers, compose) funcionarem sem daemon root. Sem sessão
# systemd de usuário o enable falha, e isso não é motivo para o módulo falhar.
_vf_enable_podman_socket() {
  if [[ "$DRY_RUN" == "1" ]]; then
    log_dry "systemctl --user enable --now podman.socket"
    return 0
  fi
  if ! has_cmd systemctl || [[ ! -d /run/systemd/system ]]; then
    log_warn "systemd não detectado — socket do Podman não habilitado."
    post_install_note "Habilite o socket do Podman quando houver sessão systemd: systemctl --user enable --now podman.socket"
    return 0
  fi
  if systemctl --user enable --now podman.socket 2>/dev/null; then
    log_success "podman.socket habilitado para o usuário."
  else
    log_warn "não consegui habilitar podman.socket (sessão systemd de usuário ausente?)."
    post_install_note "Habilite o socket do Podman: systemctl --user enable --now podman.socket"
  fi
}

_vf_install_podman() {
  log_info "Instalando Podman (rootless)…"
  apt_install podman

  # podman-docker e podman-compose não existem em toda suite suportada (o Ubuntu
  # 22.04 não empacota podman-compose). Faltar um não invalida o runtime, então
  # cada um é instalado à parte para que a ausência degrade em aviso.
  local opcional
  for opcional in podman-docker podman-compose; do
    apt_install "$opcional" \
      || log_warn "$opcional indisponível nesta distro (segue sem)."
  done

  _vf_ensure_subid
  _vf_enable_podman_socket

  log_info "DOCKER_HOST é exportado automaticamente pelo ~/.zshrc deste repo quando o socket existe."
}

# ---- Contrato ----------------------------------------------------------------

mod_container_install() {
  local runtime
  # mod_X_configure só roda no caminho do wizard: com --profile ou --module a
  # resposta nunca foi gravada. Sem este fallback, POWERTERMINAL_CONTAINER_RUNTIME
  # seria ignorada em silêncio justamente no modo em que ela é a única via de
  # escolha — o módulo node usa o mesmo padrão (_vf_node_manager_decidido).
  runtime="$(pn_get_answer container.runtime "")"
  [[ -n "$runtime" ]] || runtime="$(_vf_runtime_decidido)"
  [[ -n "$runtime" ]] || runtime=docker

  if _vf_in_container; then
    log_warn "Detectado ambiente containerizado — um runtime de container aqui não sobe daemon nem rootless utilizável."
    log_warn "Módulo container pulado de propósito."
    post_install_note "O módulo container foi pulado porque a instalação rodou dentro de um container. Rode 'powerterminal install --module container' na máquina real."
    return 0
  fi

  log_info "Runtime escolhido: $runtime"
  require_supported_distro
  apt_update_once

  case "$runtime" in
    docker) _vf_install_docker ;;
    podman) _vf_install_podman ;;
    *) die "Runtime de container desconhecido: $runtime (use docker|podman)" ;;
  esac
}

mod_container_doctor() {
  local usuario achou=0
  usuario="$(id -un)"

  if _vf_is_real_docker; then
    achou=1
    status_line 1 "docker: $(docker --version 2>/dev/null)"
    if id -nG "$usuario" 2>/dev/null | tr ' ' '\n' | grep -qx docker; then
      status_line 1 "grupo docker: $usuario é membro"
    else
      status_line 0 "grupo docker: $usuario fora do grupo (docker exigirá sudo)"
    fi
    if docker compose version >/dev/null 2>&1; then
      status_line 1 "docker compose: $(docker compose version --short 2>/dev/null)"
    else
      status_line 0 "docker compose: plugin ausente"
    fi
  fi

  if has_cmd podman; then
    achou=1
    status_line 1 "podman: $(podman --version 2>/dev/null)"
    if grep -q "^${usuario}:" /etc/subuid 2>/dev/null; then
      status_line 1 "podman rootless: subuid configurado"
    else
      status_line 0 "podman rootless: subuid ausente para $usuario"
    fi
  fi

  [[ "$achou" == "1" ]] \
    || status_line 0 "container: nenhum runtime instalado (docker/podman)"
}
