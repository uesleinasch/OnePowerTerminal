# Instalação

O PowerTerminal funciona em Ubuntu, Debian e Pop!_OS. Ele não configura o git: instala o binário quando falta, mas assume que você já tem `~/.gitconfig`, `~/.npmrc` e suas credenciais.

## Instalar

```bash
curl -fsSL https://raw.githubusercontent.com/uesleinasch/OnePowerTerminal/main/install.sh | bash
```

O script coloca o projeto em `~/PowerTerminal` e abre o assistente guiado. Ele usa `git clone` quando há git na máquina e cai para o pacote `.tar.gz` quando não há.

Para instalar sem responder perguntas, repasse as flags da CLI:

```bash
curl -fsSL https://raw.githubusercontent.com/uesleinasch/OnePowerTerminal/main/install.sh | bash -s -- --profile full --yes
```

Rodar de novo no mesmo destino atualiza o clone. Para instalar em outro lugar, defina `POWERTERMINAL_HOME`.

### Sem canalizar para o shell

`curl | bash` executa código remoto sem você ler antes. Se preferir inspecionar:

```bash
curl -fsSL -o powerterminal-install.sh https://raw.githubusercontent.com/uesleinasch/OnePowerTerminal/main/install.sh
less powerterminal-install.sh
bash powerterminal-install.sh
```

## Primeiro uso

`powerterminal install` sem argumentos abre o assistente:

1. verificação do ambiente (distro, sudo, conexão, espaço em disco e shell padrão);
2. escolha do perfil, e do editor nos perfis `dev` e `full`;
3. ajuste fino, se você escolher módulo a módulo, com as dependências marcadas sozinhas;
4. todas as perguntas de uma vez, antes de qualquer mudança no sistema;
5. resumo com tempo e espaço estimados, e a senha do sudo pedida uma única vez;
6. execução com progresso por módulo (o log completo vai para `~/.local/state/powerterminal/`);
7. tela final com o que deu certo, o que falhou e os próximos passos.

As flags `--profile`, `--module`, `--yes` e `--dry-run` pulam o assistente.

```bash
~/PowerTerminal/bin/powerterminal install --profile full --yes
~/PowerTerminal/bin/powerterminal install --module zsh,fonts,helpers
```

Depois do install, o shell de login e o grupo `docker` só valem no próximo login. Para a sessão atual, use `exec zsh` e `newgrp docker`.

## Simular antes de aplicar

`--dry-run` mostra o que aconteceria sem tocar em disco:

```bash
~/PowerTerminal/bin/powerterminal install --profile dev --dry-run --yes
```

## Testar num container

Para experimentar isolado, use a imagem de teste do repositório:

```bash
docker build -t powerterminal-test -f docker/Dockerfile .
docker run -it --rm powerterminal-test bash -lc \
  '~/PowerTerminal/bin/powerterminal install --profile full --yes && powerterminal doctor'
```

Dentro de um container o módulo `container` se pula de propósito e vira tarefa manual.

## Personalização

Aliases, toolchains e segredos ficam em `~/.zshrc.local`, que o PowerTerminal nunca toca:

```bash
cp ~/PowerTerminal/home.local.example/.zshrc.local ~/.zshrc.local
```

## Problemas comuns

| Sintoma | Solução |
|---------|---------|
| Powerlevel10k mostra ícones quebrados | Selecione `MesloLGS NF` no terminal ou no editor. |
| O terminal ainda abre em bash depois do `chsh` | Vale no próximo login. Para a sessão atual, `exec zsh`. |
| `powerterminal doctor` reclama de symlink | Rode `powerterminal link`. |
| Quero voltar à config anterior | `powerterminal unlink` restaura os `.pnbak.<timestamp>` mais recentes. |
| `docker` responde `permission denied` | Você não está no grupo `docker` nesta sessão. Reinicie a sessão ou use `newgrp docker`. |
