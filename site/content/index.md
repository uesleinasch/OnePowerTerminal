---
hide:
  - navigation
  - toc
---

# PowerTerminal

**Um comando monta o seu ambiente de desenvolvimento inteiro em Ubuntu, Debian ou Pop!_OS, e outro desfaz.**

Zsh, Neovim, Kitty, as CLIs do dia a dia e os dotfiles versionados num só lugar. Os módulos são independentes e idempotentes: rodar de novo atualiza em vez de duplicar.

[Instalar](instalacao.md){ .md-button .md-button--primary }
[Ver no GitHub](https://github.com/uesleinasch/OnePowerTerminal){ .md-button }
[Releases](https://github.com/uesleinasch/OnePowerTerminal/releases){ .md-button }

## O que você ganha

<div class="grid cards" markdown>

- **Shell**

    Zsh com Oh-My-Zsh, Powerlevel10k, autosuggestions e syntax highlighting, mais a fonte MesloLGS NF.

- **Editor**

    Neovim com a config AstroNvim versionada, VS Code, ou os dois. O assistente pergunta.

- **Terminal**

    Kitty configurado, com barra de abas própria e sessões salvas.

- **CLIs**

    eza, starship, lazygit, lazydocker, uv, yazi, Node (nvm ou n), Claude Code e Docker ou Podman.

- **Tema**

    Um flavor Catppuccin (latte, frappe, macchiato ou mocha) aplicado de uma vez no Kitty, no Neovim e no prompt.

- **Launcher**

    App gráfico que mostra o catálogo de módulos e enfileira instalações, atualizações e remoções.

</div>

## Perfis

| Perfil    | Inclui                                                                        |
|-----------|-------------------------------------------------------------------------------|
| `minimal` | apt, fonts, zsh e helpers                                                     |
| `dev`     | minimal, um editor, kitty, CLIs, node, claude, container e theme              |
| `full`    | tudo do `dev` com os dois editores, mais btop, ranger, picom, flameshot e notiont |

Dá para escolher um subset com `--module`. A lista completa está em [Módulos](modulos.md).

## Instalação

```bash
curl -fsSL https://raw.githubusercontent.com/uesleinasch/OnePowerTerminal/main/install.sh | bash
```

O script coloca o projeto em `~/PowerTerminal` e abre o assistente guiado. Prefere ler antes de executar?

```bash
curl -fsSL -o powerterminal-install.sh https://raw.githubusercontent.com/uesleinasch/OnePowerTerminal/main/install.sh
less powerterminal-install.sh
bash powerterminal-install.sh
```

Nada é irreversível: `--dry-run` simula, o link guarda qualquer arquivo preexistente como `.pnbak.<timestamp>` e `remove` desfaz o que o PowerTerminal criou. Os detalhes estão em [Instalação](instalacao.md).
