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
assert_eq True "$(campo 'all(set(m)=={"id","name","category","description","minutes","mb","sudo","needs","editor","state","origin","can_update","can_remove","data_mb","about","provides","requires","receipt"} for m in d["modules"])' <"$TMP/c.json")"

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

mkdir -p "$TMP/semxz" "$TMP/comxz"
IFS=: read -ra _dirs <<<"$PATH"
for _d in "${_dirs[@]}"; do
  for _f in "$_d"/*; do
    _n="${_f##*/}"
    [[ "$_n" == xz || -e "$TMP/semxz/$_n" || ! -x "$_f" ]] || ln -s "$_f" "$TMP/semxz/$_n"
  done
done
for c in xz curl; do printf '#!/bin/sh\nexit 0\n' >"$TMP/comxz/$c"; chmod +x "$TMP/comxz/$c"; done
kitty_sudo() { campo '[m for m in d["modules"] if m["id"]=="kitty"][0]["sudo"]'; }

it "pré-requisito ausente (xz do kitty) liga o sudo do módulo"
PATH="$TMP/semxz" "$CLI" catalog --json >"$TMP/sx.json" 2>/dev/null || true
assert_eq True "$(kitty_sudo <"$TMP/sx.json")"

it "com o pré-requisito presente o sudo segue o cost"
PATH="$TMP/comxz:$TMP/semxz" "$CLI" catalog --json >"$TMP/cx.json" 2>/dev/null || true
assert_eq False "$(kitty_sudo <"$TMP/cx.json")"

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

mod_estado() { campo '[m for m in d["modules"] if m["id"]=="'"$1"'"][0]["'"${2:-state}"'"]'; }

it "astronvim com ~/.config/nvim em cópia idêntica do repo é preexisting"
mkdir -p "$HOME/.config"
cp -r home/.config/nvim "$HOME/.config/nvim"
"$CLI" catalog --json >"$TMP/a1.json" 2>/dev/null || true
assert_eq preexisting "$(mod_estado astronvim <"$TMP/a1.json")"

it "astronvim com uma linha diferente na cópia é available"
printf -- '-- divergente\n' >>"$HOME/.config/nvim/init.lua"
"$CLI" catalog --json >"$TMP/a2.json" 2>/dev/null || true
assert_eq available "$(mod_estado astronvim <"$TMP/a2.json")"
rm -rf "$HOME/.config/nvim"

it "btop com config em cópia idêntica e sem o programa no PATH é available"
cp -r home/.config/btop "$HOME/.config/btop"
mkdir -p "$TMP/sembtop"
for _d in "${_dirs[@]}"; do
  for _f in "$_d"/*; do
    _n="${_f##*/}"
    [[ "$_n" == btop || -e "$TMP/sembtop/$_n" || ! -x "$_f" ]] || ln -s "$_f" "$TMP/sembtop/$_n"
  done
done
PATH="$TMP/sembtop" "$CLI" catalog --json >"$TMP/b.json" 2>/dev/null || true
assert_eq available "$(mod_estado btop <"$TMP/b.json")"
rm -rf "$HOME/.config/btop"

it "fontes em ~/.fonts contam para o módulo fonts"
mkdir -p "$HOME/.fonts"
for f in Regular Bold Italic "Bold Italic"; do : >"$HOME/.fonts/MesloLGS NF $f.ttf"; done
"$CLI" catalog --json >"$TMP/f2.json" 2>/dev/null || true
assert_eq preexisting "$(mod_estado fonts <"$TMP/f2.json")"

it "módulo preexisting não oferece remover"
assert_eq "preexisting False" "$(campo '[(m["state"]+" "+str(m["can_remove"])) for m in d["modules"] if m["id"]=="fonts"][0]' <"$TMP/f2.json")"

it "módulo com recibo traz receipt não vazio e can_remove verdadeiro"
assert_eq "installed True True" "$(campo '[(m["state"]+" "+str(len(m["receipt"])>0)+" "+str(m["can_remove"])) for m in d["modules"] if m["id"]=="helpers"][0]' <"$TMP/h.json")"

it "receipt troca o HOME por ~ e não traz origin"
assert_eq True "$(campo 'all(set(e)=={"kind","value"} and e["kind"]!="origin" and "'"$HOME"'" not in e["value"] for e in [m for m in d["modules"] if m["id"]=="helpers"][0]["receipt"])' <"$TMP/h.json")"

it "módulo sem recibo tem receipt vazio"
assert_eq "[]" "$(mod_estado vscode receipt <"$TMP/p.json")"

it "provides do kitty inclui o diretório da instalação"
assert_eq True "$(campo '{"kind":"dir","value":"~/.local/kitty.app"} in [m for m in d["modules"] if m["id"]=="kitty"][0]["provides"]' <"$TMP/c.json")"

it "requires lista só os comandos"
assert_eq "['curl', 'xz']" "$(mod_estado kitty requires <"$TMP/c.json")"

it "about cai na description quando o módulo não define mod_X_about"
cp lib/modules/apt.sh "$TMP/repo/lib/modules/apt.sh"
sed -i '/^mod_apt_about()/,/^}/d' "$TMP/repo/lib/modules/apt.sh"
"$TMP/repo/bin/powerterminal" catalog --json >"$TMP/ab.json" 2>/dev/null || true
assert_eq True "$(campo '[(m["about"]==m["description"]) for m in d["modules"] if m["id"]=="apt"][0]' <"$TMP/ab.json")"

test_summary
