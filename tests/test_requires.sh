#!/usr/bin/env bash
set -euo pipefail
source "${POWERTERMINAL_HOME}/tests/lib.sh"
source "${POWERTERMINAL_HOME}/lib/core.sh"
source "${POWERTERMINAL_HOME}/lib/ui.sh"
for m in "${POWERTERMINAL_HOME}"/lib/modules/*.sh; do
  # shellcheck source=/dev/null
  source "$m"
done
cd "$POWERTERMINAL_HOME"

MODULOS=(apt fonts zsh nvim astronvim vscode kitty tools node claude helpers extras notiont container theme)

# Cada teste simula a máquina sem git sobrescrevendo has_cmd dentro de um
# subshell: nada aqui depende de o host ter ou não ter o binário.
_sem_git() { [[ "$1" != "git" ]]; }

it "todo requires emite linhas comando<TAB>pacote"
ruim=""
for m in "${MODULOS[@]}"; do
  declare -F "mod_${m}_requires" >/dev/null || continue
  n="$("mod_${m}_requires" | awk -F'\t' 'NF != 2 {c++} END {print c+0}')"
  [[ "$n" == "0" ]] || ruim="$ruim $m"
done
assert_eq "" "$ruim"

it "zsh declara git (oh-my-zsh, p10k e plugins sao clones)"
assert_contains "$(mod_zsh_requires | cut -f1)" "git"

it "node declara git (n-install e nvm clonam)"
assert_contains "$(mod_node_requires | cut -f1)" "git"

it "pn_missing_requires devolve vazio quando tudo esta presente"
assert_eq "" "$( ( has_cmd() { return 0; }; pn_missing_requires "${MODULOS[@]}" ) )"

it "pn_missing_requires devolve so o que falta"
assert_eq "git	git" "$( ( has_cmd() { _sem_git "$1"; }; pn_missing_requires zsh ) )"

it "pn_missing_requires nao duplica requisito declarado por dois modulos"
assert_eq "1" "$( ( has_cmd() { _sem_git "$1"; }; pn_missing_requires zsh node ) | grep -c .)"

it "pn_missing_requires ignora modulo sem requires"
assert_eq "" "$( ( has_cmd() { return 1; }; pn_missing_requires helpers ) )"

it "pn_missing_requires_cmds junta so os comandos numa linha"
assert_eq "git curl" "$( ( has_cmd() { return 1; }; pn_missing_requires_cmds zsh ) )"

it "pn_install_requires instala os pacotes ausentes num unico apt_install"
registro="$(mktemp)"
( has_cmd() { _sem_git "$1"; }
  apt_update_once() { :; }
  apt_install() { printf '%s\n' "$*" >> "$registro"; }
  pn_install_requires zsh node ) >/dev/null
assert_eq "git" "$(cat "$registro")"

it "pn_install_requires roda apt-get update antes de instalar"
registro="$(mktemp)"
( has_cmd() { _sem_git "$1"; }
  apt_update_once() { echo update >> "$registro"; }
  apt_install() { echo "install $*" >> "$registro"; }
  pn_install_requires zsh ) >/dev/null
assert_eq "update
install git" "$(cat "$registro")"

it "pn_install_requires nao chama apt quando nada falta"
registro="$(mktemp)"
( has_cmd() { return 0; }
  apt_update_once() { echo update >> "$registro"; }
  apt_install() { printf '%s\n' "$*" >> "$registro"; }
  pn_install_requires "${MODULOS[@]}" ) >/dev/null
assert_eq "" "$(cat "$registro")"

it "pn_install_requires em dry-run so loga"
saida="$( ( has_cmd() { _sem_git "$1"; }; DRY_RUN=1 pn_install_requires zsh ) 2>&1)"
assert_contains "$saida" "[dry-run]"

it "ensure_git instala git quando ausente"
registro="$(mktemp)"
( has_cmd() { _sem_git "$1"; }
  apt_update_once() { :; }
  apt_install() { printf '%s\n' "$*" >> "$registro"; }
  ensure_git ) >/dev/null
assert_eq "git" "$(cat "$registro")"

it "ensure_git nao faz nada quando o git ja existe"
registro="$(mktemp)"
( has_cmd() { return 0; }
  apt_install() { printf '%s\n' "$*" >> "$registro"; }
  ensure_git ) >/dev/null
assert_eq "" "$(cat "$registro")"

it "clone_or_pull garante o git antes de clonar"
assert_eq "sim" "$(declare -f clone_or_pull | grep -q 'ensure_git' && echo sim || echo nao)"

it "ui_summary avisa os pre-requisitos ausentes"
assert_contains "$( ( has_cmd() { _sem_git "$1"; }; ui_summary zsh ) 2>&1)" "Pré-requisitos ausentes: git"

it "ui_summary pede senha quando ha pre-requisito ausente mesmo sem modulo com sudo"
assert_contains "$( ( has_cmd() { _sem_git "$1"; }; ui_summary node ) 2>&1)" "Pede sua senha"

it "ui_summary nao cita pre-requisitos quando nada falta"
saida="$( ( has_cmd() { return 0; }; ui_summary zsh ) 2>&1)"
if [[ "$saida" == *"Pré-requisitos"* ]]; then fail "não deveria citar pré-requisitos: $saida"; else pass; fi

it "ui_summary nao promete mais que nao instala git"
saida="$( ( has_cmd() { return 0; }; ui_summary zsh ) 2>&1)"
if [[ "$saida" == *"Não toca em: git"* ]]; then fail "texto desatualizado: $saida"; else pass; fi

it "pn_requires_doctor aponta o que falta"
assert_contains "$( ( has_cmd() { _sem_git "$1"; }; pn_requires_doctor zsh ) )" "faltam git"

it "pn_requires_doctor confirma quando tudo presente"
assert_contains "$( ( has_cmd() { return 0; }; pn_requires_doctor zsh ) )" "✓"

it "doctor mostra a linha de pre-requisitos"
assert_contains "$(./bin/powerterminal doctor 2>&1)" "Pré-requisitos"

# PATH sem git: espelha os binários do sistema num diretório temporário e deixa
# o git de fora. É o cenário real da máquina que motivou isto.
_path_sem_git="$(mktemp -d)"
for d in /usr/local/bin /usr/bin /bin; do
  [[ -d "$d" ]] || continue
  for b in "$d"/*; do
    nome="$(basename "$b")"
    [[ "$nome" == "git" || -L "$_path_sem_git/$nome" ]] && continue
    ln -s "$b" "$_path_sem_git/$nome"
  done
done

it "--module node sem git avisa o pre-requisito ausente"
saida="$(PATH="$_path_sem_git" ./bin/powerterminal install --module node --dry-run --yes 2>&1)"
assert_contains "$saida" "Pré-requisitos ausentes: git"

it "--module node sem git instala git via apt (dry-run)"
saida="$(PATH="$_path_sem_git" ./bin/powerterminal install --module node --dry-run --yes 2>&1)"
assert_contains "$saida" "apt-get install -y git"

it "o wizard sem git mostra o passo de requisitos"
saida="$(printf '2\ny\n' | PATH="$_path_sem_git" POWERTERMINAL_UI=text ./bin/powerterminal install --dry-run 2>&1)"
assert_contains "$saida" "requisitos"

it "o wizard sem git avisa nas boas-vindas"
saida="$(printf '2\nn\n' | PATH="$_path_sem_git" POWERTERMINAL_UI=text ./bin/powerterminal install --dry-run 2>&1)"
assert_contains "$saida" "faltam git"

rm -rf "$_path_sem_git"

test_summary
