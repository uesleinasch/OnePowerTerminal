#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 3 ]]; then
  echo "uso: build-appimage.sh VERSAO BUNDLE_DIR SAIDA_DIR" >&2
  exit 2
fi

versao="$1"
bundle="$(cd "$2" && pwd)"
mkdir -p "$3"
saida="$(cd "$3" && pwd)"

aqui="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
raiz="$(cd "$aqui/../.." && pwd)"
cd "$raiz"

tmp="$(mktemp -d)"
limpar() { rm -rf "${tmp:?}"; }
trap limpar EXIT
appdir="$tmp/PowerTerminal.AppDir"
repo="$appdir/usr/share/powerterminal/repo"

mkdir -p "$appdir/usr/bin" "$repo" \
  "$appdir/usr/share/applications" "$appdir/usr/share/icons/hicolor/scalable/apps"

cp -a "$bundle/." "$appdir/usr/bin/"

git archive HEAD | tar -x -C "$repo"
[[ -f "$repo/VERSION" ]] || { echo "VERSION ausente no snapshot do repo" >&2; exit 1; }
[[ -x "$repo/bin/powerterminal" ]] || { echo "bin/powerterminal ausente ou sem permissão de execução no snapshot" >&2; exit 1; }

desktop=dev.powerterminal.powerterminal_launcher.desktop
install -m 0644 "$aqui/$desktop" "$appdir/$desktop"
install -m 0644 "$aqui/$desktop" "$appdir/usr/share/applications/$desktop"
install -m 0644 "$aqui/powerterminal.svg" "$appdir/powerterminal.svg"
install -m 0644 "$aqui/powerterminal.svg" "$appdir/usr/share/icons/hicolor/scalable/apps/powerterminal.svg"
install -m 0755 "$aqui/AppRun" "$appdir/AppRun"

ferramenta="${APPIMAGETOOL:-}"
if [[ -z "$ferramenta" ]]; then
  ferramenta="$tmp/appimagetool"
  curl -fsSL --retry 3 -o "$ferramenta" \
    https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage
  chmod +x "$ferramenta"
fi

APPIMAGE_EXTRACT_AND_RUN=1 ARCH=x86_64 "$ferramenta" "$appdir" "$saida/PowerTerminal-$versao-x86_64.AppImage"
echo "Gerado: $saida/PowerTerminal-$versao-x86_64.AppImage"
