# Testando o PowerTerminal no Docker

Use isto para validar antes de aplicar na máquina real.

## Build

```bash
cd ~/PowerTerminal
docker build -t powerterminal-test -f docker/Dockerfile .
```

A imagem é Ubuntu 22.04, usuário `dev` com sudo NOPASSWD, e já tem o repo
copiado em `/home/dev/PowerTerminal`.

## Cenários de teste

### 1) Install completo (não-interativo)

```bash
docker run -it --rm powerterminal-test bash -lc \
  '~/PowerTerminal/bin/powerterminal install --profile full --yes'
```

### 2) Modo interativo (TUI)

```bash
docker run -it --rm powerterminal-test
# dentro do container:
powerterminal install
```

### 3) Dry-run (não executa nada)

```bash
docker run -it --rm powerterminal-test bash -lc \
  '~/PowerTerminal/bin/powerterminal install --profile dev --yes --dry-run'
```

### 4) Subset de módulos

```bash
docker run -it --rm powerterminal-test bash -lc \
  '~/PowerTerminal/bin/powerterminal install --module zsh,fonts,helpers --yes'
```

### 5) Doctor depois do install

```bash
docker run -it --rm powerterminal-test bash -lc \
  '~/PowerTerminal/bin/powerterminal install --profile full --yes && powerterminal doctor'
```

## Iteração rápida (mount do host)

Para iterar nos scripts sem rebuild:

```bash
docker run -it --rm \
  -v "$PWD:/home/dev/PowerTerminal" \
  powerterminal-test bash -lc 'cd ~/PowerTerminal && bin/powerterminal install --profile full --yes'
```

> Atenção: nessa forma os symlinks que o powerterminal cria no `$HOME` do
> container apontam para `/home/dev/PowerTerminal/...` (o mount). É exatamente
> isto que aconteceria na sua máquina real.

## O que validar

- [ ] `powerterminal install --dry-run --yes` lista as ações sem fazer nada.
- [ ] `powerterminal install --profile full --yes` termina sem erro.
- [ ] `powerterminal doctor` mostra `✓` em todos os módulos.
- [ ] `ls -la ~/.config/nvim ~/.zshrc ~/.p10k.zsh` mostra symlinks para o repo.
- [ ] `nvim` abre e o Lazy.nvim baixa os plugins.
- [ ] Backup: rode `install` duas vezes — não deve criar `.pnbak.*` na segunda.
- [ ] `powerterminal unlink` remove os symlinks (e restaura backups se houver).

## Limitações conhecidas em container

- `chsh` costuma falhar (PAM) — o módulo zsh continua mesmo assim.
- A fonte só funciona dentro de um terminal gráfico (não na shell do
  container). Para validar visualmente, use a fonte na máquina real.
- Kitty pode falhar ao instalar o launcher `.desktop` — esperado em headless.
