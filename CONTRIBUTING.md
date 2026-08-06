# Contribuindo com o PowerTerminal

Obrigado pelo interesse. Este documento reúne o que você precisa saber para que
um PR passe no CI e se encaixe no desenho do projeto.

Toda a comunicação — issues, PRs, mensagens de commit e a saída do programa — é
em português do Brasil.

## Verificação local

O CI (`.github/workflows/ci.yml`) roda em todo push e PR. Reproduza tudo antes de
abrir o PR:

```bash
./tests/run.sh                     # suíte (runner caseiro, sem dependências)

shellcheck --severity=warning --shell=bash \
  install.sh bin/powerterminal lib/*.sh lib/modules/*.sh bin-helpers/* tests/*.sh

for f in install.sh bin/powerterminal lib/*.sh lib/modules/*.sh bin-helpers/* tests/*.sh; do
  bash -n "$f"
done
zsh -n home/.zshrc

./bin/powerterminal install --profile full --dry-run --yes   # smoke test
./bin/powerterminal doctor
```

`shellcheck` é a única dependência externa da verificação; no Ubuntu/Debian, use o
binário estável do [projeto](https://github.com/koalaman/shellcheck/releases) em
vez do pacote do apt, que é o que o CI faz para fixar a versão do linter.

O assistente de instalação é dirigível por pipe, porque o backend de texto lê de
`stdin` — é assim que os testes de UI funcionam:

```bash
printf '2\ny\n' | POWERTERMINAL_UI=text ./bin/powerterminal install --dry-run
```

Para exercitar um install de verdade sem tocar na sua máquina:

```bash
docker build -t powerterminal-test -f docker/Dockerfile .
docker run -it --rm powerterminal-test bash -lc \
  '~/PowerTerminal/bin/powerterminal install --profile full --yes && powerterminal doctor'
```

## Testes

Os testes ficam em `tests/`, um arquivo por área, e rodam sem instalar nada.
`tests/lib.sh` traz as asserções (`it`, `assert_eq`, `assert_contains`,
`assert_ok`, `assert_fail`) e `tests/run.sh` executa todo `tests/test_*.sh` — um
arquivo novo é descoberto sozinho, sem registro em lista.

Não acople um teste ao nome do diretório onde o repositório foi clonado: cada
pessoa clona onde quer.

## Adicionando um módulo

`bin/powerterminal` sourceia `lib/core.sh`, `lib/ui.sh` e **todos** os
`lib/modules/*.sh`. A lista canônica e ordenada vive no array `_PN_ALL_MODULES`
dentro de `bin/powerterminal` — **criar o arquivo em `lib/modules/` não basta**, é
preciso acrescentar o nome ao array.

Contrato de um módulo `X`:

| Função | Obrigatória | Papel |
|---|---|---|
| `mod_X_meta` | sim | descrição de uma linha (usada na TUI e no cabeçalho do install) |
| `mod_X_install` | sim | instalação idempotente |
| `mod_X_doctor` | sim | linhas de diagnóstico (`cmd_doctor` chama sem checar existência) |
| `mod_X_links` | não | pares `origem<TAB>destino`, um por linha |
| `mod_X_configure` | não | perguntas do módulo, feitas **antes** do install; grava com `pn_set_answer` |
| `mod_X_needs` | não | dependências, um nome de módulo por linha |
| `mod_X_cost` | não | `minutos<TAB>MB<TAB>sudo(0\|1)`, alimenta o resumo do assistente |

Funções auxiliares internas de módulo usam o prefixo `_vf_`.

### `mod_X_links` é a fonte única de verdade dos symlinks

Quatro consumidores leem esse manifesto: `link`, `unlink`, `status` e o
`make sync`. O `mod_X_install` faz os próprios `link_safe`, então **o manifesto
precisa espelhar exatamente o que o install linka** — se divergir, `link`,
`status` e `sync` ficam cegos para o caminho.

## Invariantes que um PR não pode quebrar

- **Dry-run.** Toda mutação passa por `run`, `as_sudo`, `apt_install`,
  `apt_update_once`, `curl_pipe`, `download_to`, `install_github_binary` ou
  `install_github_zip`. Um comando cru dentro de um módulo quebra o `--dry-run`
  em silêncio.
- **Idempotência.** Reexecutar `install` não pode duplicar nada nem gerar um
  `.pnbak.*` novo.
- **Subshell.** Cada módulo roda em subshell, então estado que precisa voltar ao
  processo pai vai para arquivo — é por isso que existem `post_install_note` e
  `pn_set_answer` em vez de arrays globais.
- **Trap único.** Existe um só `trap pn_cleanup EXIT`, instalado em
  `bin/powerterminal`. Registre PIDs de background com `pn_register_cleanup_pid`
  em vez de instalar traps próprios.
- **Binários do GitHub.** Prefira builds **musl** (estáticas). A glibc de
  referência é a 2.35, e releases `-gnu` recentes exigem 2.39 ou mais.
- **Saída ao usuário.** Sempre via `log_info`, `log_warn`, `log_error`,
  `log_success`, `log_section`, `log_dry` ou `status_line` — nunca `echo` cru.

## Os dotfiles em `home/` são um template público

Um guard no CI **falha o build se um caminho pessoal for versionado**. Nada de
`/home/seu-usuario/`, nome de empresa, host de VPN ou de SSH: use `$HOME` ou `~`,
com guardas de existência (`[[ -d … ]] && export PATH=…`) para que o arquivo
funcione em máquina que não tem a ferramenta.

Personalização de máquina e segredos pertencem a `~/.zshrc.local`, que é
gitignored e sourceado na última linha do `home/.zshrc` — de onde pode sobrescrever
qualquer coisa do template. O modelo está em `home.local.example/.zshrc.local`.

## Fora de escopo por design

Não são alvo do projeto: `git` e `~/.gitconfig`, `~/.npmrc`, configurações de
GNOME e `:Lazy sync` automático. Um PR que os adicione provavelmente será
recusado — abra uma issue antes para discutir.

## Convenções de código

- Bash com `set -euo pipefail`; cada arquivo de `lib/` começa com
  `# shellcheck shell=bash`.
- Comentário só onde o código não consegue se explicar: uma restrição ou
  invariante não óbvia. Nomes e estrutura fazem o resto.
- Mudança de plugin do Neovim inclui o `lazy-lock.json` atualizado.

## Mensagens de commit

[Conventional Commits](https://www.conventionalcommits.org/) com descrição em
pt-BR:

```
feat(install): wizard guiado de ponta a ponta
fix(ui): estabilidade de pn_log_file no processo pai
ci: roda a suíte de testes
docs: documenta o contrato de módulo
```

## Camada de nomes legados

Existe uma camada de compatibilidade que aceita nomes `POWERNEOVIM_*` como
alias das variáveis `POWERTERMINAL_*`, e um symlink `bin/powerneovim` →
`powerterminal`, ambos com aviso de depreciação. Ela sai na 1.0.

Vive num único bloco no topo de `lib/core.sh`, coberta por
`tests/test_compat.sh`. **Código novo usa apenas os nomes `POWERTERMINAL_*`** —
não estenda a camada.

## Código de conduta

Ao participar, você concorda com o [código de conduta](CODE_OF_CONDUCT.md).
