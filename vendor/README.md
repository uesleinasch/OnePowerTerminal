# vendor/

## Por que há um binário no repositório

`gum` (charmbracelet/gum) desenha o wizard de instalação. Ele fica versionado
para que `powerterminal install` funcione numa máquina recém-formatada e **sem
rede** — inclusive quando o projeto chega por pendrive ou por
`powerterminal share`, e não por `git clone`.

- Versão: **v0.17.0** · Arquitetura: **linux x86_64** · Licença: MIT (`LICENSE-gum`)
- Origem: <https://github.com/charmbracelet/gum/releases/tag/v0.17.0>

Em arquiteturas diferentes de x86_64, o PowerTerminal usa o `gum` do `PATH` se
houver; caso contrário cai no menu de texto. Nada quebra.

## Como atualizar

```bash
V=0.17.0   # troque pela versão desejada
TMP="$(mktemp -d)"
curl -fsSL -o "$TMP/gum.tar.gz" \
  "https://github.com/charmbracelet/gum/releases/download/v${V}/gum_${V}_Linux_x86_64.tar.gz"
tar -xzf "$TMP/gum.tar.gz" -C "$TMP"
install -m 0755 "$(find "$TMP" -type f -name gum -print -quit)" vendor/gum
rm -rf "$TMP" && ./vendor/gum --version
```

Cada atualização soma ~4,5 MB permanentes ao histórico do git. É o custo
aceito em troca de funcionar offline.
