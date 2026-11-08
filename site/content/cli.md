# CLI

Todos os comandos vivem em `powerterminal`. `powerterminal help [tópico]` mostra a ajuda de cada um.

| Comando | Função |
|---------|--------|
| `install` | Instala módulos: assistente, `--profile` ou `--module` |
| `update [--module a,b]` | Atualiza os módulos instalados que têm update próprio |
| `remove --module a,b` | Desfaz módulos pelo recibo |
| `adopt --module a,b` | Passa a gerenciar o que já estava instalado fora do PowerTerminal |
| `link` | Refaz só os symlinks, sem reinstalar |
| `unlink` | Remove os symlinks e restaura os backups |
| `status` | Mostra os symlinks gerenciados |
| `doctor` | Diagnóstico completo: versões, fontes, links e dependências |
| `theme [flavor]` | Troca o flavor Catppuccin em kitty, Neovim e prompt |
| `share [arquivo]` | Empacota o repositório num `.tar.gz` |
| `catalog --json` | Catálogo de módulos e estado em JSON, usado pelo launcher |

## install

```bash
powerterminal install                        # assistente
powerterminal install --profile full --yes   # sem perguntas
powerterminal install --module zsh,helpers   # subset
powerterminal install --profile dev --dry-run --yes
```

`--profile` e `--module` são exclusivos. Antes do primeiro módulo, o install confere as ferramentas que os módulos invocam (git, curl e afins) e instala via apt as que faltarem.

## update

Atualiza só os módulos que têm mecanismo próprio de atualização. Aceita `--dry-run` e `--yes`.

## remove

Desfaz o módulo pelo recibo que o install gravou: links, arquivos e pacotes que o PowerTerminal criou, restaurando os `.pnbak`. O que já existia antes fica. Aceita `--dry-run` e `--yes`.

Para o módulo `container`, `--purge-data` apaga também imagens, containers e volumes do runtime que o PowerTerminal instalou, com uma confirmação própria que só o `--yes` do comando pula.

## adopt

```bash
powerterminal adopt --module astronvim
```

Para módulos que já estavam instalados antes do PowerTerminal. Não baixa nada: aplica a config do repositório (a sua vira `.pnbak`) e registra num recibo, com origem "adotado", o que existe do programa. Depois disso o módulo é gerenciado, e remover desinstala também o programa, com segunda confirmação. O apt não é adotável.

## link, unlink, status e doctor

`link` recria os symlinks de `$HOME` para `home/`. `unlink` os remove e restaura o backup mais recente de cada um. `status` lista o que está linkado e `doctor` aponta o que saiu do lugar, inclusive pré-requisitos ausentes.

## theme

```bash
powerterminal theme            # menu
powerterminal theme latte      # tema claro
powerterminal theme status     # o que está em vigor
```

Os flavors são `latte` (claro), `frappe`, `macchiato` e `mocha` (escuros). A escolha fica em `~/.config/powerterminal/theme` e as ferramentas a acompanham: o Kitty muda na hora, Neovim e prompt valem em sessão nova.

## share

```bash
powerterminal share dotfiles-$(date +%Y%m%d).tar.gz
```

O pacote não leva `home.local` nem os `.pnbak.*`. O colega extrai em `$HOME` e roda `~/PowerTerminal/bin/powerterminal install`.

## catalog

`powerterminal catalog --json` descreve cada módulo (nome, estado, o que instala, pré-requisitos, custo) e os perfis. É o contrato entre a CLI e o [launcher](launcher.md), e a fonte da página de [módulos](modulos.md).
