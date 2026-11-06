#!/usr/bin/env bash
set -euo pipefail
source "${POWERTERMINAL_HOME}/tests/lib.sh"
source "${POWERTERMINAL_HOME}/lib/core.sh"
source "${POWERTERMINAL_HOME}/lib/events.sh"
cd "$POWERTERMINAL_HOME"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
export HOME="$TMP/home" XDG_STATE_HOME="$TMP/state"
mkdir -p "$HOME"

tipos() { python3 -c 'import json,sys;print(" ".join(json.loads(l)["event"] for l in sys.stdin))' <"$1"; }

it "pn_json_str escapa aspas, barra e quebra de linha"
assert_eq '"a\"b\\c\nd"' "$(pn_json_str $'a"b\\c\nd')"

it "pn_json_str escapa controles como \\u00XX"
assert_eq '"\u0001"' "$(pn_json_str $'\x01')"

it "pn_event tipa número, booleano e string, e aceita JSON pronto"
EV="$TMP/ev0"; exec 7>"$EV"; PN_EVENTS_FD=7
pn_event t n=3 neg=-2 b=true s=olá "l:=$(pn_json_array a 'b"c')"
exec 7>&-; unset PN_EVENTS_FD
assert_eq '{"event":"t","n":3,"neg":-2,"b":true,"s":"olá","l":["a","b\"c"]}' "$(cat "$EV")"

it "pn_event sem fd não faz nada"
assert_ok pn_event x a=1

it "pn_session_restart emite o evento e grava a nota"
EV="$TMP/ev1"; exec 7>"$EV"; PN_EVENTS_FD=7
POWERTERMINAL_NOTES_FILE="$TMP/notes"; : >"$POWERTERMINAL_NOTES_FILE"
PN_EVENT_MODULE=zsh pn_session_restart "o zsh valer" >/dev/null
exec 7>&-; unset PN_EVENTS_FD
assert_contains "$(cat "$EV")" '{"event":"session_restart","module":"zsh","reason":"o zsh valer"}'

it "a nota de session_restart foi gravada"
assert_contains "$(cat "$POWERTERMINAL_NOTES_FILE")" "o zsh valer"

it "pn_step loga e emite step"
EV="$TMP/ev2"; exec 7>"$EV"; PN_EVENTS_FD=7
saida="$(PN_EVENT_MODULE=nvim pn_step 2 5 "Baixando")"
exec 7>&-; unset PN_EVENTS_FD
assert_eq '{"event":"step","module":"nvim","text":"Baixando","n":2,"m":5}' "$(cat "$EV")"

it "pn_step mostra o texto no log humano"
assert_contains "$saida" "Baixando"

EV="$TMP/ev3"
./bin/powerterminal install --module helpers --dry-run --yes --events-fd 3 3>"$EV" >/dev/null 2>&1 || true

it "install --events-fd emite só JSON válido"
assert_ok python3 -c 'import json,sys;[json.loads(l) for l in sys.stdin]' <"$EV"

it "install --events-fd emite module_begin, module_end e done"
assert_eq "module_begin module_end done" "$(tipos "$EV")"

it "done lista o módulo em ok"
assert_contains "$(tail -n1 "$EV")" '"ok":["helpers"]'

it "done traz failed como array vazio"
assert_contains "$(tail -n1 "$EV")" '"failed":[]'

it "fd fechado falha com mensagem clara"
assert_contains "$(./bin/powerterminal install --module helpers --dry-run --yes --events-fd 9 2>&1 || true)" "--events-fd 9 não está aberto"

it "sem --events-fd a saída humana não tem JSON de evento"
out="$(./bin/powerterminal install --module helpers --dry-run --yes 2>&1 || true)"
[[ "$out" != *'"event"'* ]] && pass || fail "vazou evento"

test_summary
