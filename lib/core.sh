# shellcheck shell=bash
# core.sh — utilities shared by all PowerTerminal modules.

if [[ -t 1 ]]; then
  C_R=$'\033[0m'
  C_B=$'\033[1m'
  C_RED=$'\033[38;5;203m'
  C_GREEN=$'\033[38;5;114m'
  C_YELLOW=$'\033[38;5;215m'
  C_BLUE=$'\033[38;5;110m'
  C_PURPLE=$'\033[38;5;141m'
  C_GRAY=$'\033[38;5;245m'
else
  C_R=""; C_B=""; C_RED=""; C_GREEN=""; C_YELLOW=""; C_BLUE=""; C_PURPLE=""; C_GRAY=""
fi

# ---- Logging -----------------------------------------------------------------
log_info()    { printf "%s[powerterminal]%s %s\n" "$C_BLUE" "$C_R" "$*"; }
log_warn()    { printf "%s[powerterminal]%s %s%s%s\n" "$C_YELLOW" "$C_R" "$C_YELLOW" "$*" "$C_R" >&2; }
log_error()   { printf "%s[powerterminal]%s %s%s%s\n" "$C_RED" "$C_R" "$C_RED" "$*" "$C_R" >&2; }
log_success() { printf "%s[powerterminal]%s %s%s%s\n" "$C_GREEN" "$C_R" "$C_GREEN" "$*" "$C_R"; }
log_section() { printf "\n%s%s▸ %s%s\n" "$C_PURPLE" "$C_B" "$*" "$C_R"; }
log_dry()     { printf "%s[dry-run]%s %s\n" "$C_GRAY" "$C_R" "$*"; }

die() { log_error "$*"; exit 1; }

# ---- Compat: nomes POWERNEOVIM_* de antes da renomeação ----------------------
# Precisa rodar antes dos defaults abaixo: depois que `: "${POWERTERMINAL_HOME:=…}"`
# executa, a variável já está definida e o valor legado nunca seria consultado.
_pn_compat_env() {
  local new="POWERTERMINAL_$1" old="POWERNEOVIM_$1"
  [[ -n "${!new:-}" || -z "${!old:-}" ]] && return 0
  export "$new=${!old}"
  log_warn "$old está depreciada; use $new (a compat sai na 1.0)."
}

for _pn_legacy in HOME NONINTERACTIVE UI NODE_MANAGER; do
  _pn_compat_env "$_pn_legacy"
done
unset _pn_legacy

: "${DRY_RUN:=0}"
: "${POWERTERMINAL_NONINTERACTIVE:=0}"
: "${POWERTERMINAL_HOME:=$HOME/PowerTerminal}"

# ---- Predicates --------------------------------------------------------------
has_cmd() { command -v "$1" >/dev/null 2>&1; }

# O shell padrão do usuário vive em /etc/passwd. $SHELL é só o da sessão
# corrente e diverge de propósito no caso que interessa detectar: quem digita
# `zsh` na mão continua com o bash registrado.
login_shell() {
  getent passwd "$(id -un)" 2>/dev/null | awk -F: '{print $7}'
}

is_supported_distro() {
  [[ -r /etc/os-release ]] || return 1
  # shellcheck disable=SC1091
  . /etc/os-release
  case "${ID:-}" in
    ubuntu|debian|pop) return 0 ;;
    *) [[ "${ID_LIKE:-}" =~ (ubuntu|debian) ]] ;;
  esac
}

require_supported_distro() {
  is_supported_distro || die "Distro não suportada. Suporte: Ubuntu, Debian, Pop!_OS."
}

require_not_root() {
  [[ "$(id -u)" -ne 0 ]] || die "Não rode como root. Use seu usuário (sudo é chamado quando necessário)."
}

# ---- Execution wrappers ------------------------------------------------------
# run CMD ARGS… — executes unless DRY_RUN=1, in which case logs the action.
run() {
  if [[ "$DRY_RUN" == "1" ]]; then
    log_dry "$*"
  else
    "$@"
  fi
}

# as_sudo CMD — runs CMD as root when needed, dry-run aware.
as_sudo() {
  if [[ "$DRY_RUN" == "1" ]]; then
    log_dry "sudo $*"
    return 0
  fi
  if [[ "$(id -u)" -eq 0 ]]; then
    "$@"
  else
    sudo "$@"
  fi
}

# sudo_ready — sucesso quando dá para escalar sem prompt: já somos root, ou o
# timestamp do sudo está válido. Dentro do wizard a saída dos módulos vai para o
# log, então um prompt de senha ficaria invisível e travaria a instalação; quem
# chama usa isto para degradar para tarefa manual em vez de pendurar.
sudo_ready() {
  [[ "$(id -u)" -eq 0 ]] || sudo -n true 2>/dev/null
}

# ---- Apt ---------------------------------------------------------------------
apt_install() {
  require_supported_distro
  if [[ "$DRY_RUN" == "1" ]]; then
    log_dry "apt-get install -y $*"
    return 0
  fi
  sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "$@"
}

apt_update_once() {
  [[ "${_PN_APT_UPDATED:-}" == "1" ]] && return 0
  if [[ "$DRY_RUN" == "1" ]]; then
    log_dry "apt-get update"
  else
    sudo env DEBIAN_FRONTEND=noninteractive apt-get update -y
  fi
  _PN_APT_UPDATED=1
}

# apt_add_repo NOME CHAVE_URL REPO_URL SUITE COMPONENTE — registra um repositório
# apt externo com keyring próprio em /etc/apt/keyrings/NOME.asc e lista em
# /etc/apt/sources.list.d/NOME.list. Usa o padrão signed-by porque `apt-key` está
# depreciado e uma chave no chaveiro global assinaria por qualquer repositório.
# Reescreve keyring e lista a cada chamada: é barato e é o que mantém a coisa
# correta quando a chave upstream rotaciona.
apt_add_repo() {
  local nome="$1" chave_url="$2" repo_url="$3" suite="$4" componente="$5"
  local keyring="/etc/apt/keyrings/${nome}.asc"
  local lista="/etc/apt/sources.list.d/${nome}.list"
  local arch linha tmp

  arch="$(dpkg --print-architecture)"
  linha="deb [arch=${arch} signed-by=${keyring}] ${repo_url} ${suite} ${componente}"

  if [[ "$DRY_RUN" == "1" ]]; then
    log_dry "install -m 0755 -d /etc/apt/keyrings"
    log_dry "curl -fsSL $chave_url → $keyring (modo 0644)"
    log_dry "echo '$linha' > $lista"
    log_dry "apt-get update"
    return 0
  fi

  as_sudo install -m 0755 -d /etc/apt/keyrings

  # A chave tem de terminar legível por _apt (0644). Rodar o curl como root para
  # escrever direto em /etc daria a um download remoto privilégio que ele não
  # precisa: baixa como usuário, instala com o modo certo.
  tmp="$(mktemp)"
  if ! download_to "$chave_url" "$tmp"; then
    rm -f "$tmp"
    die "Falha ao baixar a chave GPG de '$nome' ($chave_url)."
  fi
  as_sudo install -m 0644 "$tmp" "$keyring"
  rm -f "$tmp"

  printf '%s\n' "$linha" | as_sudo tee "$lista" >/dev/null

  # A lista de fontes mudou: o cache do apt_update_once ficou obsoleto.
  _PN_APT_UPDATED=""
  apt_update_once
}

# ---- Sudo keepalive ----------------------------------------------------------
# Acquires a sudo timestamp now and refreshes it in the background. Required for
# unattended (--yes) runs that take longer than the sudo timestamp_timeout.
setup_sudo_keepalive() {
  [[ "$DRY_RUN" == "1" ]] && return 0
  if ! sudo -n true 2>/dev/null; then
    log_info "sudo: solicitando senha agora (mantida durante todo o install)"
    sudo -v || die "sudo não disponível — abortando."
  fi
  ( while sudo -n true 2>/dev/null && kill -0 "$$" 2>/dev/null; do sleep 50; done ) &
  pn_register_cleanup_pid "$!"
}

# ---- Symlink management ------------------------------------------------------
backup_path() {
  local path="$1"
  [[ -L "$path" ]] && return 0
  if [[ -e "$path" ]]; then
    local bak
    bak="${path}.pnbak.$(date +%Y%m%d%H%M%S)"
    log_info "Backup: $path → $bak"
    run mv "$path" "$bak"
  fi
}

# link_safe SRC DST — replace DST with a symlink to SRC, backing up real files.
# Compares the literal symlink target (NOT readlink -f) so dangling links are detected.
link_safe() {
  local src="$1" dst="$2"
  if [[ ! -e "$src" ]]; then
    if [[ "$DRY_RUN" == "1" ]]; then
      log_dry "ln -s $src $dst  (source ainda não existe — seria criado por passo anterior)"
      return 0
    fi
    die "link_safe: source não existe: $src"
  fi
  run mkdir -p "$(dirname "$dst")"
  if [[ -L "$dst" ]]; then
    local cur; cur="$(readlink "$dst" 2>/dev/null || true)"
    if [[ "$cur" == "$src" ]]; then
      log_info "OK (symlink já correto): $dst"
      return 0
    fi
    run rm -f "$dst"
  elif [[ -e "$dst" ]]; then
    backup_path "$dst"
  fi
  log_info "Link: $dst → $src"
  run ln -s "$src" "$dst"
}

# unlink_safe DST — remove DST only if it's a symlink owned by PowerTerminal, then
# restore the most recent backup if one exists.
unlink_safe() {
  local dst="$1"
  if [[ -L "$dst" ]]; then
    local target; target="$(readlink "$dst" 2>/dev/null || true)"
    if [[ "$target" != "$POWERTERMINAL_HOME"/* ]]; then
      log_warn "Symlink $dst não pertence ao PowerTerminal ($target). Ignorado."
      return 0
    fi
    log_info "Removendo symlink: $dst"
    run rm -f "$dst"
  fi
  # Pega o backup mais recente. Sort lexicográfico em sufixo YYYYMMDDHHMMSS é
  # locale-independente e monotônico (resolve ties melhor que `ls -1t`).
  local last_bak
  last_bak="$(ls -1 "${dst}".pnbak.* 2>/dev/null | LC_ALL=C sort -r | head -1 || true)"
  if [[ -n "$last_bak" ]]; then
    log_info "Restaurando backup: $last_bak → $dst"
    run mv "$last_bak" "$dst"
  fi
}

# ---- Filesystem helpers ------------------------------------------------------
ensure_local_bin() { run mkdir -p "$HOME/.local/bin"; }

# Garante o curl antes de qualquer download. Mesmo padrão que install_github_zip
# já usa para o unzip: o binário vem do módulo apt, mas um módulo isolado
# (--module nvim) precisa funcionar sem arrastar o apt inteiro como dependência.
ensure_curl() {
  has_cmd curl && return 0
  log_info "curl ausente — instalando…"
  apt_install curl
}

# download_to URL DST — robust download with retries and timeouts.
download_to() {
  local url="$1" dst="$2"
  ensure_curl
  log_info "Baixando $url"
  run curl -fL --retry 3 --retry-delay 2 \
    --connect-timeout 15 --max-time 300 \
    -o "$dst" "$url"
}

# install_github_binary URL BIN_NAME — baixa um tar.gz do GitHub que contém um
# binário com o nome BIN_NAME e o instala em ~/.local/bin/BIN_NAME.
# IMPORTANTE: NÃO usa `trap RETURN` porque o trap dispara depois que `local`
# vars saem de escopo, e sob `set -u` isso quebra com "tmp: unbound variable".
install_github_binary() {
  local url="$1" bin="$2"
  if [[ "$DRY_RUN" == "1" ]]; then
    log_dry "install_github_binary $url → ~/.local/bin/$bin"
    return 0
  fi
  local tmp; tmp="$(mktemp -d)"
  download_to "$url" "$tmp/pkg.tar.gz"
  tar -xzf "$tmp/pkg.tar.gz" -C "$tmp"
  # -print -quit evita SIGPIPE no pipe `find | head` sob pipefail (GNU find).
  local found
  found="$(find "$tmp" -maxdepth 3 -type f -name "$bin" -print -quit 2>/dev/null)"
  if [[ -z "$found" ]]; then
    rm -rf "$tmp"
    die "install_github_binary: '$bin' não encontrado em $url"
  fi
  install -m 0755 "$found" "$HOME/.local/bin/$bin"
  rm -rf "$tmp"
}

# install_github_zip URL BIN_NAME [BIN_NAME…] — baixa um .zip do GitHub e instala
# um ou mais binários (por nome) em ~/.local/bin. Útil para releases zipados cujo
# binário vem dentro de uma subpasta (ex.: yazi → yazi + ya). Garante `unzip`.
install_github_zip() {
  local url="$1"; shift
  if [[ "$DRY_RUN" == "1" ]]; then
    log_dry "install_github_zip $url → ~/.local/bin/{$*}"
    return 0
  fi
  has_cmd unzip || apt_install unzip
  local tmp; tmp="$(mktemp -d)"
  download_to "$url" "$tmp/pkg.zip"
  unzip -qo "$tmp/pkg.zip" -d "$tmp"
  local bin found
  for bin in "$@"; do
    found="$(find "$tmp" -maxdepth 3 -type f -name "$bin" -print -quit 2>/dev/null)"
    if [[ -z "$found" ]]; then
      rm -rf "$tmp"
      die "install_github_zip: '$bin' não encontrado em $url"
    fi
    install -m 0755 "$found" "$HOME/.local/bin/$bin"
  done
  rm -rf "$tmp"
}

# clone_or_pull REPO DST [LABEL]
clone_or_pull() {
  # Locais separados: dentro de um mesmo `local`, "$dst" ainda não teria sido
  # atribuído quando o default de name é expandido (resultaria em name vazio).
  local repo="$1" dst="$2"
  local name="${3:-$(basename "$dst")}"
  if [[ -d "$dst/.git" ]]; then
    log_info "Atualizando $name…"
    run git -C "$dst" pull --ff-only \
      || log_warn "$name: pull falhou (mantendo o que existe)"
  elif [[ -d "$dst" ]]; then
    log_warn "$name: diretório existe mas não é git — mantendo."
  else
    log_info "Clonando $name…"
    run git clone --depth=1 "$repo" "$dst"
  fi
}

# curl_pipe URL [ARGS…] — pipes a remote install script through sh, dry-run aware.
curl_pipe() {
  local url="$1"; shift
  if [[ "$DRY_RUN" == "1" ]]; then
    log_dry "curl $url | sh -s -- $*"
    return 0
  fi
  ensure_curl
  curl -fsSL --connect-timeout 15 --max-time 300 "$url" | sh -s -- "$@"
}

# ---- Post-install notes ------------------------------------------------------
# Permite que módulos enfileirem tarefas manuais (ex.: chsh) que não conseguiram
# completar sozinhos. Usamos arquivo (não array) porque os módulos rodam em
# subshell — array em pai não receberia as escritas do filho.
: "${POWERTERMINAL_NOTES_FILE:=}"
if [[ -z "$POWERTERMINAL_NOTES_FILE" ]]; then
  POWERTERMINAL_NOTES_FILE="$(mktemp -t powerterminal-notes.XXXXXX 2>/dev/null || mktemp)"
  export POWERTERMINAL_NOTES_FILE
fi

post_install_note() {
  printf '%s\n' "$*" >> "$POWERTERMINAL_NOTES_FILE"
}

print_post_install_notes() {
  [[ -f "$POWERTERMINAL_NOTES_FILE" && -s "$POWERTERMINAL_NOTES_FILE" ]] || return 0
  log_section "Tarefas manuais necessárias"
  local i=1
  while IFS= read -r note; do
    [[ -z "$note" ]] && continue
    printf "  %s%d)%s %s\n" "$C_YELLOW" "$i" "$C_R" "$note"
    i=$((i+1))
  done < "$POWERTERMINAL_NOTES_FILE"
}

# ---- Respostas do wizard ------------------------------------------------------
# Arquivo (não array) pelo mesmo motivo das notas: os módulos rodam em subshell
# no cmd_install, e escrita de filho não voltaria ao pai.
: "${POWERTERMINAL_ANSWERS_FILE:=}"
if [[ -z "$POWERTERMINAL_ANSWERS_FILE" ]]; then
  POWERTERMINAL_ANSWERS_FILE="$(mktemp -t powerterminal-answers.XXXXXX 2>/dev/null || mktemp)"
  export POWERTERMINAL_ANSWERS_FILE
fi

pn_set_answer() {
  printf '%s=%s\n' "$1" "$2" >> "$POWERTERMINAL_ANSWERS_FILE"
}

pn_get_answer() {
  local key="$1" default="${2:-}" line valor="" achou=0
  if [[ -f "${POWERTERMINAL_ANSWERS_FILE:-}" ]]; then
    while IFS= read -r line; do
      if [[ "${line%%=*}" == "$key" ]]; then
        valor="${line#*=}"
        achou=1
      fi
    done < "$POWERTERMINAL_ANSWERS_FILE"
  fi
  if [[ "$achou" == "1" ]]; then
    printf '%s\n' "$valor"
  else
    printf '%s\n' "$default"
  fi
}

# pn_expand_deps MÓDULOS… — imprime os módulos pedidos mais o fecho transitivo
# de mod_X_needs, sem duplicatas, na ordem canônica de _PN_ALL_MODULES.
# Percorre a fila por índice (em vez de fazer shift) porque `set -u` reclama de
# expandir array vazio.
pn_expand_deps() {
  local -A want=()
  local -a queue=("$@")
  local i=0 m dep
  while (( i < ${#queue[@]} )); do
    m="${queue[$i]}"; i=$((i + 1))
    [[ -n "${want[$m]:-}" ]] && continue
    want["$m"]=1
    if declare -F "mod_${m}_needs" >/dev/null; then
      while read -r dep; do
        [[ -n "$dep" ]] && queue+=("$dep")
      done < <("mod_${m}_needs")
    fi
  done
  for m in "${_PN_ALL_MODULES[@]}"; do
    [[ -n "${want[$m]:-}" ]] && printf '%s\n' "$m"
  done
  return 0
}

# ---- Cleanup orquestrado -----------------------------------------------------
# Trap único de EXIT (a setup_sudo_keepalive registra dentro deste contrato).
_PN_CLEANUP_PIDS=()
pn_register_cleanup_pid() { _PN_CLEANUP_PIDS+=("$1"); }

pn_cleanup() {
  local pid
  for pid in "${_PN_CLEANUP_PIDS[@]:-}"; do
    [[ -n "${pid:-}" ]] && kill "$pid" 2>/dev/null || true
  done
  [[ -f "${POWERTERMINAL_NOTES_FILE:-}" ]] && rm -f "$POWERTERMINAL_NOTES_FILE" 2>/dev/null || true
  [[ -f "${POWERTERMINAL_ANSWERS_FILE:-}" ]] && rm -f "$POWERTERMINAL_ANSWERS_FILE" 2>/dev/null || true
}

# ---- Status helpers ----------------------------------------------------------
status_line() {
  local ok="$1" label="$2"
  if [[ "$ok" == "1" ]]; then
    printf "  %s✓%s %s\n" "$C_GREEN" "$C_R" "$label"
  else
    printf "  %s✗%s %s\n" "$C_RED" "$C_R" "$label"
  fi
}
