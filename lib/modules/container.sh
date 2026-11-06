# shellcheck shell=bash
# Module: container — runtime de container: Docker (daemon + grupo) ou Podman (rootless).

mod_container_meta() {
  echo "Docker ou Podman (escolha do usuário) — grupo docker ou rootless; idempotente"
}

# Números do caminho Docker, que é o mais caro. O Podman pesa bem menos, mas o
# cost é consultado pelo teste de contrato antes de qualquer escolha existir:
# um valor dinâmico criaria um caminho que só serve para embelezar o resumo.
mod_container_cost() { printf '4\t520\t1\n'; }

mod_container_name() { echo "Docker ou Podman"; }

mod_container_category() { echo dev; }

mod_container_installed() { has_cmd docker || has_cmd podman; }

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
    _pn_receipt group docker
    log_success "$usuario adicionado ao grupo docker."
    pn_session_restart "o grupo docker valer"
    post_install_note "Para testar já nesta sessão: 'newgrp docker'."
  else
    log_warn "usermod falhou — grupo docker vai para as tarefas manuais."
    _vf_nota_grupo_docker "$usuario"
  fi
}

_vf_tem_systemd() { has_cmd systemctl && [[ -d /run/systemd/system ]]; }

# O pacote já habilita o serviço, mas em ambiente sem systemd (WSL antigo, imagem
# enxuta) isso não acontece e o daemon fica fora do boot sem avisar.
_vf_enable_docker_service() {
  if [[ "$DRY_RUN" == "1" ]]; then
    log_dry "systemctl enable --now docker.service"
    return 0
  fi
  if ! _vf_tem_systemd; then
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

  pn_step 1 3 "Adicionando o repositório oficial do Docker (linux/$base, $suite)…"
  apt_add_repo docker \
    "https://download.docker.com/linux/${base}/gpg" \
    "https://download.docker.com/linux/${base}" \
    "$suite" \
    stable

  pn_step 2 3 "Instalando Docker Engine, Compose v2 e buildx…"
  apt_install "${_PN_DOCKER_PKGS[@]}"

  _vf_enable_docker_service
  pn_step 3 3 "Adicionando o usuário ao grupo docker…"
  _vf_add_docker_group
}

# ---- Podman ------------------------------------------------------------------

_vf_nota_subid() {
  post_install_note "Configure o mapeamento rootless do Podman: sudo usermod --add-subuids ${_PN_SUBID_RANGE_START}-${_PN_SUBID_RANGE_END} --add-subgids ${_PN_SUBID_RANGE_START}-${_PN_SUBID_RANGE_END} $1"
}

# Rootless depende de um range de UIDs/GIDs subordinados. O pacote costuma
# popular /etc/subuid, mas um usuário criado com `useradd` cru (o caso do
# container de teste deste repo) fica sem e o podman falha só ao rodar.
_vf_tem_subid() { grep -q "^${2}:" "/etc/$1" 2>/dev/null; }

# Só o que falta é acrescentado, e o recibo só leva os subids quando os dois
# arquivos estavam sem o usuário: o undo apaga o intervalo dos dois de uma vez, e
# um intervalo que o usuário já tinha igual ao nosso iria junto.
_vf_ensure_subid() {
  local usuario faltam=0 intervalo
  local -a args=()
  usuario="$(id -un)"
  intervalo="${_PN_SUBID_RANGE_START}-${_PN_SUBID_RANGE_END}"

  _vf_tem_subid subuid "$usuario" || { args+=(--add-subuids "$intervalo"); faltam=$((faltam + 1)); }
  _vf_tem_subid subgid "$usuario" || { args+=(--add-subgids "$intervalo"); faltam=$((faltam + 1)); }

  if [[ "$faltam" -eq 0 ]]; then
    log_info "OK: subuid/subgid já configurados para $usuario."
    return 0
  fi

  if [[ "$DRY_RUN" == "1" ]]; then
    log_dry "usermod ${args[*]} $usuario"
    return 0
  fi

  if ! sudo_ready; then
    log_warn "sudo indisponível sem senha — subuid/subgid vai para as tarefas manuais."
    _vf_nota_subid "$usuario"
    return 0
  fi

  if as_sudo usermod "${args[@]}" "$usuario"; then
    [[ "$faltam" -eq 2 ]] && _pn_receipt subids "$usuario"
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
  if ! _vf_tem_systemd; then
    log_warn "systemd não detectado — socket do Podman não habilitado."
    post_install_note "Habilite o socket do Podman quando houver sessão systemd: systemctl --user enable --now podman.socket"
    return 0
  fi
  local ja_habilitado=0
  systemctl --user is-enabled --quiet podman.socket 2>/dev/null && ja_habilitado=1
  if systemctl --user enable --now podman.socket 2>/dev/null; then
    [[ "$ja_habilitado" == 1 ]] || _pn_receipt user_unit podman.socket
    log_success "podman.socket habilitado para o usuário."
  else
    log_warn "não consegui habilitar podman.socket (sessão systemd de usuário ausente?)."
    post_install_note "Habilite o socket do Podman: systemctl --user enable --now podman.socket"
  fi
}

mod_container_update() {
  if _vf_is_real_docker; then
    log_info "Atualizando Docker Engine via apt-get…"
    apt_upgrade "${_PN_DOCKER_PKGS[@]}"
  elif has_cmd podman; then
    log_info "Atualizando Podman via apt-get…"
    apt_upgrade podman
  else
    log_warn "Nenhum runtime de container encontrado para atualizar."
  fi
}

_vf_install_podman() {
  pn_step 1 2 "Instalando Podman (rootless)…"
  apt_install podman

  # podman-docker e podman-compose não existem em toda suite suportada (o Ubuntu
  # 22.04 não empacota podman-compose). Faltar um não invalida o runtime, então
  # cada um é instalado à parte para que a ausência degrade em aviso.
  local opcional
  for opcional in podman-docker podman-compose; do
    apt_install "$opcional" \
      || log_warn "$opcional indisponível nesta distro (segue sem)."
  done

  pn_step 2 2 "Configurando o mapeamento rootless…"
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

# ---- Remoção -----------------------------------------------------------------

_vf_container_recibo_tem_apt() {
  [[ $'\n'"$(pn_receipt_entries container apt)"$'\n' == *$'\n'"apt"$'\t'"$1"$'\n'* ]]
}

# Pacote → diretório de dados que o --purge-data apaga. Estes caminhos fixos nunca
# estão no recibo e não passam pelo guard do pn_receipt_undo: cada um só sai se o
# pacote dele estava no recibo (foi o módulo que instalou) e já não está
# instalado — um containerd.io do próprio usuário (nerdctl, k8s) nunca é tocado.
_PN_DOCKER_DADOS=("docker-ce:/var/lib/docker" "containerd.io:/var/lib/containerd")

# Na dúvida conta como instalado: o rm dos dados só vale com o pacote fora.
_vf_pkg_instalado() {
  local st
  st="$(dpkg -s "$1" 2>/dev/null)" || return 1
  [[ "$st" != *"Status: "*" config-files"* && "$st" != *"Status: "*" not-installed"* ]]
}

# _vf_purge_docker_data PACOTE… — os pacotes que estavam no recibo antes do undo.
_vf_purge_docker_data() {
  local par pkg dir rc=0
  local -a falharam=()
  for par in "${_PN_DOCKER_DADOS[@]}"; do
    pkg="${par%%:*}" dir="${par#*:}"
    [[ " $* " == *" $pkg "* ]] || continue
    if [[ "$DRY_RUN" != "1" ]] && _vf_pkg_instalado "$pkg"; then
      log_warn "$pkg continua instalado — $dir fica (apagar com o serviço no ar corromperia os dados)."
      rc=1
      continue
    fi
    log_info "Apagando $dir…"
    as_sudo rm -rf --one-file-system -- "$dir" || falharam+=("$dir")
  done
  if (( ${#falharam[@]} > 0 )); then
    log_warn "Não consegui apagar ${falharam[*]}."
    post_install_note "Apague os dados do Docker que sobraram: sudo rm -rf --one-file-system -- ${falharam[*]}"
    rc=1
  fi
  return "$rc"
}

_vf_purge_podman_data() {
  if ! has_cmd podman; then
    log_info "podman ausente — não há dados do Podman para apagar."
    return 0
  fi
  log_info "Apagando imagens, containers e volumes do Podman…"
  run podman system reset -f
}

# O podman system reset precisa do podman, então roda antes da purga; o rm de
# /var/lib/docker só depois, com o daemon já parado pelo prerm do docker-ce.
mod_container_remove() {
  local podman=0 rc=0 par
  local -a docker_pkgs=()
  if [[ "${PN_PURGE_DATA:-0}" == "1" ]]; then
    for par in "${_PN_DOCKER_DADOS[@]}"; do
      _vf_container_recibo_tem_apt "${par%%:*}" && docker_pkgs+=("${par%%:*}")
    done
    _vf_container_recibo_tem_apt podman && podman=1
    [[ ${#docker_pkgs[@]} -gt 0 || "$podman" == 1 ]] \
      || log_warn "Nem Docker nem Podman foram instalados pelo PowerTerminal — os dados ficam."
  fi

  if [[ "$podman" == 1 ]] && ! _vf_purge_podman_data; then
    log_warn "podman system reset falhou — nada do container foi removido."
    return 1
  fi

  pn_receipt_undo container || rc=$?

  if [[ ${#docker_pkgs[@]} -gt 0 ]]; then
    _vf_purge_docker_data "${docker_pkgs[@]}" || rc=1
  fi
  return "$rc"
}

# MB (decimais, como o docker/podman os mostram) somados de imagens, containers
# e volumes — sem o build cache. Nunca usa sudo, e com o Docker só mede com o
# daemon já no ar: o catalog roda isto a cada chamada, e o `docker` cliente
# acordaria pelo docker.socket um daemon que o usuário parou.
mod_container_data_mb() {
  local -a cmd=()
  if _vf_is_real_docker; then
    has_cmd systemctl && systemctl is-active --quiet docker.service </dev/null 2>/dev/null || return 0
    cmd=(docker system df --format '{{.Type}}\t{{.Size}}')
  elif has_cmd podman; then
    cmd=(podman system df --format '{{.Type}}\t{{.Size}}')
  else
    return 0
  fi
  has_cmd timeout && cmd=(timeout 10 "${cmd[@]}")
  local saida
  saida="$("${cmd[@]}" </dev/null 2>/dev/null)" || return 0
  LC_ALL=C awk -F'\t' '
    BEGIN { f["B"] = 1e-6; f["kB"] = 1e-3; f["KB"] = 1e-3; f["MB"] = 1; f["GB"] = 1e3; f["TB"] = 1e6 }
    $0 ~ /^[[:space:]]*$/ { next }
    NF == 2 && $1 == "Build Cache" { next }
    NF == 2 && match($2, /^[0-9]+(\.[0-9]+)?/) {
      u = substr($2, RLENGTH + 1)
      if (u in f) { total += substr($2, 1, RLENGTH) * f[u]; n++; next }
    }
    { ruim = 1 }
    END { if (!ruim && n > 0) printf "%d\n", total + 0.5 }
  ' <<<"$saida"
}
