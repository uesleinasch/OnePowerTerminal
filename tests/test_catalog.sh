#!/usr/bin/env bash
set -euo pipefail
source "${POWERTERMINAL_HOME}/tests/lib.sh"
cd "$POWERTERMINAL_HOME"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
export HOME="$TMP/home" XDG_STATE_HOME="$TMP/state"
mkdir -p "$HOME" "$TMP/bin"
printf '#!/bin/sh\nexit 0\n' >"$TMP/bin/code"; chmod +x "$TMP/bin/code"
mkdir -p "$TMP/shims"
for c in sudo apt-get dpkg; do printf '#!/bin/sh\nexit 0\n' >"$TMP/shims/$c"; chmod +x "$TMP/shims/$c"; done
# O catálogo mede os dados do container (docker/podman system df): nunca o daemon real.
mkdir -p "$TMP/norun"
for c in docker podman; do printf '#!/bin/sh\nexit 1\n' >"$TMP/norun/$c"; chmod +x "$TMP/norun/$c"; done
export PATH="$TMP/norun:$PATH"

CLI=bin/powerterminal
campo() { python3 -c 'import json,sys;d=json.load(sys.stdin);print(eval(sys.argv[1]))' "$1"; }

it "catalog --json é JSON válido"
"$CLI" catalog --json >"$TMP/c.json" 2>/dev/null || true
assert_ok python3 -c 'import json,sys;json.load(sys.stdin)' <"$TMP/c.json"

it "stdout não tem nada além do JSON mesmo com POWERTERMINAL_EDITOR inválido"
POWERTERMINAL_EDITOR=emacs "$CLI" catalog --json >"$TMP/e.json" 2>/dev/null || true
assert_ok python3 -c 'import json,sys;json.loads(sys.stdin.read())' <"$TMP/e.json"

it "contract_version é 1"
assert_eq 1 "$(campo 'd["contract_version"]' <"$TMP/c.json")"

it "lista todos os módulos de _PN_ALL_MODULES na ordem"
esperado="$(sed -nE 's/^_PN_ALL_MODULES=\((.*)\)$/\1/p' "$CLI")"
assert_eq "$esperado" "$(campo '" ".join(m["id"] for m in d["modules"])' <"$TMP/c.json")"

it "dev inclui os três editores no catálogo"
assert_eq True "$(campo 'all(x in d["profiles"]["dev"] for x in ("nvim","astronvim","vscode"))' <"$TMP/c.json")"

it "cada módulo traz os campos do contrato"
assert_eq True "$(campo 'all(set(m)=={"id","name","category","description","minutes","mb","sudo","needs","editor","state","origin","can_update","can_remove","data_mb"} for m in d["modules"])' <"$TMP/c.json")"

it "módulo sem recibo e com ferramenta presente é preexisting"
PATH="$TMP/bin:$PATH" "$CLI" catalog --json >"$TMP/p.json" 2>/dev/null || true
assert_eq preexisting "$(campo '[m for m in d["modules"] if m["id"]=="vscode"][0]["state"]' <"$TMP/p.json")"

it "helpers instalado pela CLI vira installed com origin installed"
PATH="$TMP/shims:$PATH" "$CLI" install --module helpers --yes >/dev/null 2>&1 || true
"$CLI" catalog --json >"$TMP/h.json" 2>/dev/null || true
assert_eq "installed installed" "$(campo '[(m["state"]+" "+m["origin"]) for m in d["modules"] if m["id"]=="helpers"][0]' <"$TMP/h.json")"

it "todo módulo tem name, category, description e state válidos"
assert_eq True "$(campo 'all(m["name"] and m["category"] and m["description"] and m["state"] in ("installed","preexisting","available") for m in d["modules"])' <"$TMP/c.json")"

it "mod_X_name ausente aborta o catálogo com o módulo no stderr"
mkdir -p "$TMP/repo/bin"
cp "$CLI" "$TMP/repo/bin/powerterminal"; cp -r lib VERSION "$TMP/repo/"
sed -i '/^mod_apt_name()/d' "$TMP/repo/lib/modules/apt.sh"
rc=0; "$TMP/repo/bin/powerterminal" catalog --json >"$TMP/f.out" 2>"$TMP/f.err" || rc=$?
assert_eq 1 "$rc"
assert_contains "$(cat "$TMP/f.err")" "mod_apt_name"
assert_eq "" "$(cat "$TMP/f.out")"

it "data_mb é null quando não dá para medir"
assert_eq None "$(campo '[m for m in d["modules"] if m["id"]=="container"][0]["data_mb"]' <"$TMP/c.json")"

it "data_mb do container vem do docker system df"
mkdir -p "$TMP/df"
cat >"$TMP/df/docker" <<'EOF'
#!/bin/sh
[ "$1" = --version ] && { echo "Docker version 24.0.7"; exit 0; }
[ "$1 $2" = "system df" ] && { printf 'Images\t2GB\nLocal Volumes\t512MB\nBuild Cache\t9GB\n'; exit 0; }
exit 1
EOF
printf '#!/bin/sh\n[ "$1" = is-active ] && exit 0\nexit 1\n' >"$TMP/df/systemctl"
chmod +x "$TMP/df/docker" "$TMP/df/systemctl"
PATH="$TMP/df:$PATH" "$CLI" catalog --json >"$TMP/d.json" 2>/dev/null || true
assert_eq 2512 "$(campo '[m for m in d["modules"] if m["id"]=="container"][0]["data_mb"]' <"$TMP/d.json")"

it "catalog sem --json falha"
assert_fail "$CLI" catalog

it "catalog com argumento extra falha sem imprimir JSON"
rc=0; "$CLI" catalog --json --tudo >"$TMP/x.out" 2>"$TMP/x.err" || rc=$?
[[ "$rc" -ne 0 && ! -s "$TMP/x.out" && "$(cat "$TMP/x.err")" == *--tudo* ]] && pass || fail "rc=$rc $(cat "$TMP/x.err")"

it "origin de recibo editado à mão continua JSON válido"
printf 'origin\tde"du\\zido\n' >"$XDG_STATE_HOME/powerterminal/receipts/fonts"
"$CLI" catalog --json >"$TMP/o.json" 2>/dev/null || true
assert_eq 'de"du\zido' "$(campo '[m for m in d["modules"] if m["id"]=="fonts"][0]["origin"]' <"$TMP/o.json" 2>&1)"
rm -f "$XDG_STATE_HOME/powerterminal/receipts/fonts"

test_summary
