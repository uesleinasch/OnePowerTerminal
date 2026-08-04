#!/usr/bin/env bash
# link_safe / backup_path / unlink_safe — o único subsistema com risco de perda
# de dados: symlinks, backups .pnbak e a restauração no unlink.
set -euo pipefail
source "${POWERTERMINAL_HOME}/tests/lib.sh"
source "${POWERTERMINAL_HOME}/lib/core.sh"

sandbox="$(mktemp -d)"
trap 'rm -rf "$sandbox"' EXIT

# Repo canônico e HOME falsos, isolados da máquina.
POWERTERMINAL_HOME="$sandbox/repo"
mkdir -p "$POWERTERMINAL_HOME/home" "$sandbox/home"
src="$POWERTERMINAL_HOME/home/.zshrc"
printf 'conteudo canonico\n' > "$src"

# ---- link_safe -----------------------------------------------------------

dst_a="$sandbox/home/a.conf"

it "link_safe cria o symlink quando o destino nao existe"
link_safe "$src" "$dst_a" >/dev/null
assert_eq "$src" "$(readlink "$dst_a")"

it "reexecutar link_safe e idempotente (nenhum backup criado)"
link_safe "$src" "$dst_a" >/dev/null
assert_eq "0" "$(find "$sandbox/home" -name 'a.conf.pnbak.*' | wc -l)"

dst_b="$sandbox/home/b.conf"
printf 'arquivo do usuario\n' > "$dst_b"

it "link_safe move arquivo real preexistente para .pnbak"
link_safe "$src" "$dst_b" >/dev/null
bak_b="$(find "$sandbox/home" -name 'b.conf.pnbak.*' | head -1)"
assert_eq "arquivo do usuario" "$(cat "$bak_b")"

it "e o destino vira symlink para o canonico"
assert_eq "$src" "$(readlink "$dst_b")"

dst_c="$sandbox/home/c.conf"
outro="$sandbox/outro-gerenciador.conf"
printf 'alvo de outro gerenciador\n' > "$outro"
ln -s "$outro" "$dst_c"

it "link_safe avisa ao substituir symlink que nao e do PowerTerminal"
saida="$(link_safe "$src" "$dst_c" 2>&1)"
assert_contains "$saida" "não é do PowerTerminal"

it "o aviso registra o alvo antigo"
assert_contains "$saida" "$outro"

it "e o symlink substituido aponta para o canonico"
assert_eq "$src" "$(readlink "$dst_c")"

# ---- unlink_safe ---------------------------------------------------------

dst_d="$sandbox/home/d.conf"
printf 'backup antigo\n'   > "$dst_d.pnbak.20200101000000"
printf 'backup recente\n' > "$dst_d.pnbak.20210101000000"
ln -s "$src" "$dst_d"
unlink_safe "$dst_d" >/dev/null

it "unlink_safe remove o symlink do PowerTerminal"
assert_fail test -L "$dst_d"

it "e restaura o backup mais recente"
assert_eq "backup recente" "$(cat "$dst_d")"

dst_e="$sandbox/home/e.conf"
ln -s "$outro" "$dst_e"
printf 'backup de e\n' > "$dst_e.pnbak.20200101000000"
unlink_safe "$dst_e" >/dev/null 2>&1

it "unlink_safe ignora symlink de terceiros"
assert_eq "$outro" "$(readlink "$dst_e")"

it "e nao restaura backup por cima dele"
assert_ok test -f "$dst_e.pnbak.20200101000000"

# Regressão: dst é arquivo REAL do usuário (symlink removido por fora) e existe
# um .pnbak antigo — restaurar destruiria o arquivo atual.
dst_f="$sandbox/home/f.conf"
printf 'arquivo atual do usuario\n' > "$dst_f"
printf 'backup velho\n' > "$dst_f.pnbak.20200101000000"
unlink_safe "$dst_f" >/dev/null 2>&1

it "unlink_safe NAO sobrescreve arquivo real com backup antigo"
assert_eq "arquivo atual do usuario" "$(cat "$dst_f")"

it "e o backup antigo permanece intocado"
assert_ok test -f "$dst_f.pnbak.20200101000000"

dst_g="$sandbox/home/g.conf"
printf 'so restou o backup\n' > "$dst_g.pnbak.20200101000000"
unlink_safe "$dst_g" >/dev/null

it "com destino ausente, unlink_safe restaura o backup"
assert_eq "so restou o backup" "$(cat "$dst_g")"

dst_h="$sandbox/home/h.conf"
ln -s "$src" "$dst_h"
printf 'backup de h\n' > "$dst_h.pnbak.20200101000000"
( DRY_RUN=1; unlink_safe "$dst_h" ) >/dev/null

it "em dry-run, unlink_safe nao remove o symlink"
assert_ok test -L "$dst_h"

it "em dry-run, o backup nao e movido"
assert_ok test -f "$dst_h.pnbak.20200101000000"

test_summary
