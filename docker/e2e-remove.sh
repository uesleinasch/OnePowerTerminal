#!/usr/bin/env bash
# Instala e remove módulos de verdade e confere se a máquina voltou ao estado
# anterior. Só roda DENTRO do container de teste (docker/Dockerfile):
#   docker run --rm -v "$PWD:/home/dev/PowerTerminal" powerterminal-test \
#     bash -lc '~/PowerTerminal/docker/e2e-remove.sh'
set -euo pipefail

if [[ ! -f /.dockerenv && ! -f /run/.containerenv ]]; then
  echo "e2e-remove: recusado — só roda dentro do container de teste (docker/Dockerfile)." >&2
  exit 2
fi

PT="$HOME/PowerTerminal/bin/powerterminal"
MODULOS=(zsh helpers kitty vscode claude)
OUT="$(mktemp -d)"

# O próprio estado do PowerTerminal (recibos) e o repositório montado não contam,
# nem os dados de usuário que o remove preserva de propósito (como o
# ~/.config/Code do vscode): ~/.claude e ~/.claude.json guardam login, settings
# e memórias do Claude Code, que o instalador cria já no primeiro uso.
PODA=(./PowerTerminal ./.local/state/powerterminal ./.claude ./.claude.json)

_home() {
  local -a expr=()
  local p
  for p in "${PODA[@]}"; do expr+=(${expr[0]+-o} -path "$p"); done
  (cd "$HOME" && find . -mindepth 1 \( "${expr[@]}" \) -prune -o "$@")
}

estado() {
  echo "## shell de login"
  getent passwd "$(id -un)" | cut -d: -f7
  echo "## pacotes instalados (code, zsh)"
  { dpkg -l code zsh 2>/dev/null || true; } | awk '/^ii/ {print $2}'
  echo "## repositórios apt"
  ls -1 /etc/apt/sources.list.d 2>/dev/null || true
  echo "## keyrings apt"
  ls -1 /etc/apt/keyrings 2>/dev/null || true
  echo "## arquivos e links do HOME"
  _home \( -type l -printf 'l %p -> %l\n' \) -o \( -type f -printf 'f %p\n' \) | LC_ALL=C sort
  echo "## conteúdo dos arquivos do HOME"
  _home -type f -print0 | LC_ALL=C sort -z | xargs -0 -r md5sum
}

# Diretório vazio que sobra (~/.local/bin, ~/.config…) é esperado: o undo nunca
# apaga diretório compartilhado. Vai para o relatório, mas não reprova.
diretorios() {
  _home -type d -print | LC_ALL=C sort
}

ok=0 comparados=0 skips=0
declare -a resumo=()

for m in "${MODULOS[@]}"; do
  echo "=== $m"
  estado >"$OUT/$m.antes"
  diretorios >"$OUT/$m.dirs-antes"

  if ! "$PT" install --module "$m" --yes >"$OUT/$m.install.log" 2>&1; then
    motivo="$(sed 's/\x1b\[[0-9;]*m//g' "$OUT/$m.install.log" | grep -Ei 'erro|falh|error|fail' | tail -2 | tr '\n' ' ')"
    [[ -n "$motivo" ]] || motivo="$(sed 's/\x1b\[[0-9;]*m//g' "$OUT/$m.install.log" | grep -v '^[[:space:]]*$' | tail -2 | tr '\n' ' ')"
    "$PT" remove --module "$m" --yes >"$OUT/$m.remove.log" 2>&1 || true
    echo "SKIP $m: install falhou neste container — $motivo"
    resumo+=("SKIP $m")
    skips=$((skips + 1))
    continue
  fi

  comparados=$((comparados + 1))
  rc_remove=0
  "$PT" remove --module "$m" --yes >"$OUT/$m.remove.log" 2>&1 || rc_remove=$?
  estado >"$OUT/$m.depois"
  diretorios >"$OUT/$m.dirs-depois"

  if [[ "$rc_remove" -ne 0 ]]; then
    echo "FALHA $m: remove saiu com $rc_remove"
    tail -20 "$OUT/$m.remove.log"
    resumo+=("FALHA $m (remove rc=$rc_remove)")
  elif ! diff -u "$OUT/$m.antes" "$OUT/$m.depois"; then
    echo "FALHA $m: o estado não voltou ao inicial (diff acima)"
    resumo+=("FALHA $m (estado)")
  else
    echo "OK $m"
    ok=$((ok + 1))
    resumo+=("OK $m")
  fi
  if ! diff -q "$OUT/$m.dirs-antes" "$OUT/$m.dirs-depois" >/dev/null; then
    echo "aviso $m: diretórios que sobraram (vazios ou compartilhados):"
    LC_ALL=C comm -13 "$OUT/$m.dirs-antes" "$OUT/$m.dirs-depois" | sed 's/^/  /'
  fi
done

echo
printf '%s\n' "${resumo[@]}"
sufixo=""
[[ "$skips" -eq 0 ]] || sufixo=" ($skips SKIP)"
echo "e2e-remove: $ok/$comparados voltaram ao estado inicial$sufixo"
[[ "$ok" -eq "$comparados" ]]
