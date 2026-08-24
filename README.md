# PowerTerminal

[![CI](https://github.com/uesleinasch/OnePowerTerminal/actions/workflows/ci.yml/badge.svg)](https://github.com/uesleinasch/OnePowerTerminal/actions/workflows/ci.yml)
[![Licença: MIT](https://img.shields.io/badge/licença-MIT-blue.svg)](LICENSE)

CLI para replicar e compartilhar um ambiente de desenvolvimento
(**Neovim + AstroNvim, Zsh + Oh-My-Zsh + Powerlevel10k, Kitty, helpers
`myastro`/`mykitty`/`myyazi` e ferramentas CLI**) em qualquer máquina **Ubuntu /
Debian / Pop!_OS**.

Montar esse ambiente à mão custa horas — instalar pacote por pacote, buscar os
binários que o apt não tem na versão certa, copiar dotfiles de algum backup e
descobrir na primeira semana o que ficou faltando. O PowerTerminal reduz isso a
um comando. São doze módulos independentes e idempotentes: rodar de novo
atualiza em vez de duplicar, e você escolhe entre um perfil pronto
(`minimal`/`dev`/`full`) ou um subset via `--module`.

As configs ficam versionadas em `home/`, com `$HOME` apontando para lá por
symlink — você edita o arquivo onde sempre editou e o repositório acompanha, o
que torna o ambiente algo que se leva de máquina em máquina e se compartilha com
um colega (`powerterminal share`).

E nada é irreversível: `--dry-run` mostra o que aconteceria sem tocar em disco,
o link move qualquer arquivo preexistente para `.pnbak.<timestamp>` antes de
substituir, `doctor` diagnostica o que saiu do lugar e `unlink` desfaz
restaurando os backups.

> **Não toca em git.** Assume que o usuário já tem `~/.gitconfig`,
> `~/.npmrc` e suas credenciais configuradas.
>
> **Node.js é opcional**: o módulo `node` instala o gerenciador de versões
> de sua escolha (`nvm` ou `n`) e o Node LTS. Se você já tem um deles,
> o módulo só garante o Node LTS e os PATHs no `~/.zshrc`.

## Instalação

```bash
curl -fsSL https://raw.githubusercontent.com/uesleinasch/OnePowerTerminal/main/install.sh | bash
```

O script coloca o projeto em `~/PowerTerminal` e abre o assistente guiado. Ele usa
`git clone` quando há git na máquina e cai para o pacote `.tar.gz` quando não há —
o instalador não depende de git para funcionar.

Para instalar sem responder perguntas, repasse as flags da CLI:

```bash
curl -fsSL https://raw.githubusercontent.com/uesleinasch/OnePowerTerminal/main/install.sh | bash -s -- --profile full --yes
```

Rodar de novo no mesmo destino atualiza o clone em vez de duplicar nada. Para
instalar em outro lugar, defina `POWERTERMINAL_HOME`.

### Preferindo não canalizar um script para o shell

`curl | bash` executa código remoto sem você ler antes. Se preferir inspecionar:

```bash
curl -fsSL -o powerterminal-install.sh https://raw.githubusercontent.com/uesleinasch/OnePowerTerminal/main/install.sh
less powerterminal-install.sh
bash powerterminal-install.sh
```

### Para contribuir

Clone completo (o bootstrap usa `--depth 1`, que basta para instalar mas não para
trabalhar no projeto) e veja o [CONTRIBUTING.md](CONTRIBUTING.md):

```bash
git clone https://github.com/uesleinasch/OnePowerTerminal.git ~/PowerTerminal
cd ~/PowerTerminal && ./tests/run.sh
```

## Princípios

- **Symlinks (estilo stow)**: as configs ficam em `~/PowerTerminal/home/...` e
  `$HOME/...` são symlinks para lá. Você edita o arquivo onde sempre editou
  e o "repo" reflete sozinho.
- **Idempotente**: rodar duas vezes não duplica nada nem cria backups vazios.
- **Sem segredos**: tokens e identidade pessoal ficam em `~/.zshrc.local`
  (ignorado, nunca empacotado).
- **Compartilhável**: `powerterminal share` gera um `.tar.gz` que o colega
  extrai em `$HOME` e roda `~/PowerTerminal/bin/powerterminal install`.

## Estrutura

```
~/PowerTerminal/
├── bin/powerterminal              # entrypoint da CLI
├── lib/
│   ├── core.sh               # log, link_safe, backup, sudo wrapper, dry-run
│   ├── ui.sh                 # TUI gum (vendorizado) + fallback texto
│   └── modules/              # 13 módulos independentes
│       ├── apt.sh            # base: curl, ripgrep, fzf, jq, …
│       ├── fonts.sh          # MesloLGS NF (Powerlevel10k)
│       ├── zsh.sh            # zsh + OMZ + p10k + plugins
│       ├── nvim.sh           # binário Neovim em /opt
│       ├── astronvim.sh      # link de ~/.config/nvim
│       ├── kitty.sh          # Kitty + link da kitty.conf
│       ├── tools.sh          # eza, starship, lazygit, lazydocker, uv, yazi
│       ├── node.sh           # nvm OU n (escolha) + Node LTS
│       ├── helpers.sh        # link de myastro / mykitty / myyazi
│       ├── extras.sh         # btop, ranger, yazi, picom, flameshot, …
│       ├── notiont.sh        # notion-t (CLI Notion via pipx)
│       ├── container.sh      # Docker OU Podman (escolha) + grupo/rootless
│       └── theme.sh          # flavor Catppuccin (kitty + Neovim + prompt)
├── home/                     # estado canônico das configs
│   ├── .zshrc                # template comum (sourceia .zshrc.local)
│   ├── .p10k.zsh
│   └── .config/
│       ├── powerterminal/    # flavor em vigor + override de cor do prompt
│       ├── kitty/themes/     # as 4 paletas Catppuccin
│       └── {nvim,btop,ranger,yazi,…}
├── home.local.example/       # personalização não versionada
├── bin-helpers/              # myastro, mykitty, myyazi
├── docker/                   # Dockerfile para testar isolado
└── VERSION
```

## Uso rápido

```bash
# Assistente guiado (recomendado no primeiro uso)
~/PowerTerminal/bin/powerterminal install

# Tudo, sem perguntas
~/PowerTerminal/bin/powerterminal install --profile full --yes

# Subset
~/PowerTerminal/bin/powerterminal install --module zsh,fonts,helpers

# Só Node (escolha interativa entre nvm e n)
~/PowerTerminal/bin/powerterminal install --module node

# Node não-interativo, forçando o gerenciador
POWERTERMINAL_NODE_MANAGER=nvm ~/PowerTerminal/bin/powerterminal install --module node --yes
POWERTERMINAL_NODE_MANAGER=n   ~/PowerTerminal/bin/powerterminal install --module node --yes

# Simular sem executar nada
~/PowerTerminal/bin/powerterminal install --profile dev --dry-run --yes

# Diagnóstico
powerterminal doctor

# Empacotar para um colega
powerterminal share dotfiles-$(date +%Y%m%d).tar.gz
```

## O assistente

`powerterminal install` sem argumentos abre um assistente que conduz o primeiro
uso do começo ao fim:

1. **Boas-vindas com verificação do ambiente** — distro, sudo, conexão, espaço
   em disco e shell padrão. Só distro não suportada impede seguir; o resto é
   informativo.
2. **Escolha do perfil** — `dev`, `minimal`, `full` ou módulo a módulo.
3. **Ajuste fino** (só se você escolher módulo a módulo), com as dependências
   marcadas automaticamente: pedir `astronvim` traz o `nvim` junto.
4. **Todas as perguntas de uma vez**, antes de qualquer mudança no sistema.
5. **Resumo** do que será instalado, com tempo e espaço estimados, e o aviso de
   que a senha do sudo será pedida uma única vez — ali, não no meio do processo.
6. **Execução com progresso por módulo**. A saída detalhada vai para
   `~/.local/state/powerterminal/install-<data>.log`; a tela mostra só o status.
   Um módulo que falha não interrompe os demais.
7. **Tela final** com o que deu certo, o que falhou (já com o comando de
   reexecução) e os próximos passos.

As flags `--profile`, `--module`, `--yes` e `--dry-run` pulam o assistente e
mantêm o comportamento não-interativo de sempre — é o que o CI e o container de
teste usam.

A interface usa o [gum](https://github.com/charmbracelet/gum), versionado em
`vendor/` para funcionar offline (veja [vendor/README.md](vendor/README.md)).
Fora de x86_64, o assistente cai num menu de texto equivalente. Para forçar um
dos dois: `POWERTERMINAL_UI=text` ou `POWERTERMINAL_UI=gum`.

## Profiles

| Profile   | Inclui                                                                 |
|-----------|------------------------------------------------------------------------|
| `minimal` | apt + fonts + zsh + helpers                                            |
| `dev`     | minimal + nvim + astronvim + kitty + tools + node + container + theme  |
| `full`    | tudo (= dev + extras + notiont)                                        |

## Comandos

| Comando            | Função                                                          |
|--------------------|-----------------------------------------------------------------|
| `install`          | Instala módulos (TUI / `--profile` / `--module`)                |
| `link`             | Refaz só os symlinks (sem reinstalar)                           |
| `unlink`           | Remove symlinks + restaura backups (`.pnbak.<timestamp>`)       |
| `status`           | Mostra symlinks gerenciados                                     |
| `doctor`           | Diagnóstico completo (versões, fontes, links, dependências)     |
| `theme [flavor]`   | Troca o flavor Catppuccin em kitty + Neovim + prompt            |
| `share [arquivo]`  | Empacota o repo em `.tar.gz` (sem `home.local`, sem `.pnbak.*`) |
| `update`           | Atualiza P10k e plugins zsh (e dá hint para `:Lazy sync`)       |
| `help [tópico]`    | Ajuda                                                           |

## Tema (`powerterminal theme`)

Os quatro flavors do [Catppuccin](https://catppuccin.com/palette/) — `latte`
(claro), `frappe`, `macchiato` e `mocha` (escuros) — aplicados de uma vez no
Kitty, no Neovim e no prompt.

```bash
powerterminal theme            # menu
powerterminal theme latte      # tema claro
powerterminal theme status     # o que está em vigor, e se todos concordam
```

A escolha vive num arquivo só, `~/.config/powerterminal/theme`. Cada ferramenta
acompanha de um jeito:

| Consumidor    | Como acompanha                                                                          |
|---------------|-----------------------------------------------------------------------------------------|
| Kitty         | `current-theme.conf` (derivado) faz `include themes/<flavor>.conf`, recarregado nas janelas abertas |
| Barra de abas | `tab_bar.py` identifica o flavor pelo `background` em vigor e escolhe a paleta de 10 matizes |
| Neovim        | `lua/plugins/catppuccin.lua` lê o arquivo no startup                                    |
| Prompt        | 195 das 208 cores do `.p10k.zsh` usam índices ANSI 0-15, que o Kitty remapeia por flavor; `p10k-theme.zsh` corrige as três que usavam cor fixa do cubo 256 |
| Claude Code   | `~/.claude/settings.json` recebe `light` no latte e `dark` nos outros — o syntax highlighting dele tem cor própria e sumiria sobre fundo claro |

As paletas em `home/.config/kitty/themes/` são o porte oficial
([catppuccin/kitty](https://github.com/catppuccin/kitty)), copiadas sem
modificação — os embutidos no Kitty são de uma versão anterior, sem as cores de
scrollbar e de marks.

O Kitty muda na hora; Neovim e prompt leem o flavor no startup, então valem em
sessão nova, e as cores das abas pedem uma janela nova (o `tab_bar.py` já está
importado no processo). A moldura do split em foco é sobrescrita de propósito no
`kitty.conf`: o lavender dos flavors não destaca o suficiente com
`draw_minimal_borders no`.

O `settings.json` do Claude Code é editado por substituição cirúrgica da chave
`theme`, com validação do JSON antes de gravar e escrita atômica — nunca por
round-trip, que reformataria os hooks e as permissões do arquivo. Se a chave não
existir, o comando avisa e não toca no arquivo.

## Módulo `node` (nvm ou n)

Instala um gerenciador de versões e o Node LTS, sem mexer em `~/.npmrc`.

**Quem é escolhido?** A precedência (de cima pra baixo):

1. Se já existe `~/.nvm` ou `~/n` (ou `n` no PATH) → reusa o que está lá.
2. `POWERTERMINAL_NODE_MANAGER=nvm|n` (env) → respeita a escolha.
3. Modo não-interativo (`--yes` / sem TTY) → default `nvm`.
4. Modo interativo → menu `gum` (ou prompt de texto) perguntando.

**O que o instalador faz:**

| Manager | Onde instala     | Como o Node entra no PATH                              |
|---------|------------------|--------------------------------------------------------|
| `nvm`   | `~/.nvm` (v0.40.1) | `~/.zshrc` faz `source $NVM_DIR/nvm.sh` se existir    |
| `n`     | `~/n` (via `n-install -n`) | `~/.zshrc` prependa `~/n/bin` ao `PATH` se existir |

Ambos os casos: depois do install, é instalado o **Node LTS** (`nvm install --lts`
ou `n lts`) e o `~/.zshrc` do PowerTerminal já tem o auto-detect — basta
**reabrir o terminal** ou rodar `exec zsh`.

> **Idempotente.** Reexecutar `powerterminal install --module node` é seguro:
> se o gerenciador já existe, ele só garante o Node LTS e os PATHs.

## Módulo `container` (Docker ou Podman)

Instala **um** runtime de container e o deixa pronto para usar sem `sudo`.

**Quem é escolhido?** A precedência (de cima pra baixo):

1. `POWERTERMINAL_CONTAINER_RUNTIME=docker|podman` (env) → respeita o pedido,
   mesmo que o outro runtime já esteja instalado (avisa sobre o conflito).
2. Se já existe um runtime → reusa o que está lá (Docker ganha se ambos).
3. Modo não-interativo (`--yes` / sem TTY) → default `docker`.
4. Modo interativo → menu perguntando.

**O que cada caminho faz:**

| Runtime  | Origem                                      | Configuração aplicada                                     |
|----------|---------------------------------------------|-----------------------------------------------------------|
| `docker` | repo oficial `download.docker.com`, com keyring em `/etc/apt/keyrings/docker.asc` | `docker-ce`, `docker-ce-cli`, `containerd.io`, `buildx` e **Compose v2**; habilita `docker.service`; adiciona seu usuário ao grupo `docker` |
| `podman` | pacotes da distro (o repo Kubic foi arquivado) | `podman` + `podman-docker` (comando `docker`) + `podman-compose`; garante `subuid`/`subgid`; habilita `podman.socket` do usuário |

Escolhendo Podman, o `~/.zshrc` do PowerTerminal exporta `DOCKER_HOST` apontando
para o socket rootless **só quando ele existe** — ferramentas que falam a API do
Docker (Compose, testcontainers) funcionam sem daemon root.

> **O grupo `docker` só vale no próximo login.** Grupos são fixados no login e
> nenhum comando muda isso de fora. Reinicie a máquina (ou saia da sessão e entre
> de novo). Para testar na sessão atual: `newgrp docker`.

> **Dentro de um container o módulo se pula de propósito.** Instalar um runtime
> dentro de outro não produz ambiente utilizável, então rodar o instalador na
> imagem de teste do repo deixa o passo como tarefa manual em vez de falhar.

> **Idempotente.** Reexecutar é seguro: o keyring e a lista são reescritos, e o
> `usermod` só roda se você ainda não estiver no grupo.

## Personalização (`~/.zshrc.local`)

Copie o template e edite à vontade. O `~/.zshrc` gerenciado pelo PowerTerminal
faz `source ~/.zshrc.local` no final.

```bash
cp ~/PowerTerminal/home.local.example/.zshrc.local ~/.zshrc.local
$EDITOR ~/.zshrc.local
```

Use `~/.zshrc.local` para:
- aliases pessoais (VPN, Docker, etc.)
- toolchains específicas (JAVA_HOME, ghcup, gcloud SDK)
- segredos (tokens, chaves)

Esse arquivo nunca é tocado pelo PowerTerminal.

## Compartilhar com um colega

Da sua máquina:

```bash
~/PowerTerminal/bin/powerterminal share
# Gera: powerterminal-share-YYYYMMDD.tar.gz
```

Na máquina do colega:

```bash
tar -xzf powerterminal-share-YYYYMMDD.tar.gz -C $HOME
~/PowerTerminal/bin/powerterminal install
```

A TUI permite que ele desligue módulos que não quer. `--profile minimal`
deixa ele sem Neovim/Kitty caso não use.

## Testar antes de aplicar

Veja [`docker/README.md`](docker/README.md). Resumo:

```bash
docker build -t powerterminal-test -f docker/Dockerfile .
docker run -it --rm powerterminal-test bash -lc \
  '~/PowerTerminal/bin/powerterminal install --profile full --yes && powerterminal doctor'
```

## Atualizando configs

Como `$HOME/.zshrc` é symlink para `~/PowerTerminal/home/.zshrc`, **editar
qualquer arquivo de config já atualiza o repo**. Para aplicar em outras
máquinas: copie a pasta `~/PowerTerminal/` (via `powerterminal share`, USB, rsync,
ou — mais tarde — git push) e rode `powerterminal link`.

## O que NÃO faz (por design)

- Não instala / configura `git` (assumimos que você cuida).
- Não toca em `~/.gitconfig`, `~/.gitignore_global`, `~/.npmrc`.
- Não muda configurações do GNOME / desktop.
- Não roda `:Lazy sync` automático no Neovim — o Lazy.nvim pega na
  primeira execução.
- Não escolhe entre `nvm` e `n` por você quando está no modo interativo —
  o módulo `node` pergunta.

## Yazi (file explorer no terminal)

O módulo `tools` instala o **yazi** em `~/.local/bin` (binários `yazi` e `ya`),
usando a build **musl** — estática, para não depender da glibc do sistema
(releases `-gnu` recentes exigem glibc ≥ 2.39). A config fica em
`home/.config/yazi/` (gerenciada como os demais dotfiles) e o `~/.zshrc` define:

- `EDITOR=nvim` — arquivos abertos de dentro do yazi vão para o Neovim.
- a função `y` — abre o yazi e, ao sair com `q`, deixa o terminal no diretório
  navegado (atalho do [quick-start](https://yazi-rs.github.io/docs/quick-start)).

```bash
y            # abre o yazi; `q` sai já trocando o terminal p/ o diretório atual
yazi         # idem, mas sem trocar o diretório do shell ao sair
```

Para o guia completo de comandos do yazi, rode **`myyazi`** (cheatsheet no
estilo do `myastro`/`mykitty`, instalado pelo módulo `helpers`):

```bash
myyazi             # exibe tudo
myyazi files       # filtra uma seção (nav, files, find, tabs, cli, …)
```

## Troubleshooting

| Sintoma                                       | Causa / fix                                                                   |
|-----------------------------------------------|--------------------------------------------------------------------------------|
| Powerlevel10k mostra ícones quebrados         | Selecione `MesloLGS NF` no terminal/IDE.                                       |
| `chsh` falhou no install                      | Comum em containers. Faça manualmente: `chsh -s $(command -v zsh)`.            |
| Rodei o `chsh` e o terminal ainda abre em bash | O shell gravado só vale no **próximo login**: reinicie a máquina, ou saia da sessão e entre de novo. Para a sessão atual, `exec zsh`. |
| Ainda preciso digitar `zsh` a cada terminal   | O `chsh` não foi aplicado. Confira com `getent passwd "$USER"` — o último campo deve ser o caminho do zsh. |
| Plugins do Neovim não apareceram              | Abra `nvim` e aguarde o Lazy.nvim. Se travar: `:Lazy sync`.                    |
| `powerterminal doctor` reclama de symlink          | Rode `powerterminal link` para refazer.                                             |
| Quero voltar à config anterior                | `powerterminal unlink` — restaura os `.pnbak.<timestamp>` mais recentes.            |
| `node`/`npm` não aparecem após install        | Reabra o terminal ou rode `exec zsh` — o `~/.zshrc` carrega `nvm`/`n` no startup. |
| Quero forçar `nvm` (ou `n`) num install `--yes` | `POWERTERMINAL_NODE_MANAGER=nvm powerterminal install --module node --yes`.         |
| Quero forçar Podman (ou Docker) num install `--yes` | `POWERTERMINAL_CONTAINER_RUNTIME=podman powerterminal install --module container --yes`. |
| `docker` responde `permission denied` no socket | Você não está no grupo `docker`, ou entrou nele nesta sessão. Confira com `id -nG`; se aparecer, reinicie a sessão (ou `newgrp docker`). |
| Instalei Podman e `docker compose` não acha o daemon | O socket rootless não subiu: `systemctl --user enable --now podman.socket`. O `DOCKER_HOST` do `~/.zshrc` só é exportado quando o socket existe, então reabra o terminal depois. |
| O módulo `container` foi pulado no install | A instalação rodou dentro de um container (detectado por `/.dockerenv` ou `/run/.containerenv`). Rode `powerterminal install --module container` na máquina real. |
| Erro `unknown style 'zdiff3'` no `git`        | Git < 2.35; use `merge.conflictstyle=diff3` ou atualize via `ppa:git-core/ppa`. |
| Shader `paper` do picom não aplica            | O picom < v10 exige caminho absoluto em `glx-fshader`. Descomente a linha em `home/.config/picom/picom.conf` trocando `SEU_USUARIO`. |

## Contribuindo

Contribuições são bem-vindas. O [CONTRIBUTING.md](CONTRIBUTING.md) cobre como
rodar a verificação local que o CI cobra, o contrato de um módulo novo, as
invariantes que um PR não pode quebrar e a regra de ouro do repositório: os
dotfiles em `home/` são um **template público**, então nenhum caminho pessoal
pode ser versionado — um guard no CI falha o build se um aparecer.

Ao participar, você concorda com o [código de conduta](CODE_OF_CONDUCT.md).

## Licença

MIT — veja [LICENSE](LICENSE). Copyright (c) 2026 Ueslei Nascimento.
