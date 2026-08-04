## O que muda

<!-- Uma ou duas frases. Se houver issue relacionada, referencie: Closes #123 -->

## Tipo de mudança

- [ ] Correção de bug
- [ ] Nova funcionalidade
- [ ] Novo módulo (`lib/modules/`)
- [ ] Mudança nos dotfiles (`home/`)
- [ ] Documentação
- [ ] Infraestrutura / CI

## Como testar

<!-- Comandos que o revisor pode rodar. Ex.: bin/powerterminal install --module zsh --dry-run -->

## Verificação

- [ ] `./tests/run.sh` passa
- [ ] `shellcheck --severity=warning --shell=bash bin/powerterminal lib/*.sh lib/modules/*.sh bin-helpers/* tests/*.sh` sem achados
- [ ] `bash -n` em cada script alterado e `zsh -n home/.zshrc`
- [ ] `bin/powerterminal install --profile full --dry-run --yes` e `doctor` rodam
- [ ] Reexecutar o install não duplica nada nem cria `.pnbak.*` novo (idempotência)
- [ ] Nenhum caminho pessoal versionado — `$HOME`/`~` em vez de `/home/seu-usuario/`

## Se aplicável

- [ ] Módulo novo acrescentado ao array `_PN_ALL_MODULES` em `bin/powerterminal`
- [ ] `mod_X_links` espelha exatamente o que o `mod_X_install` linka
- [ ] Toda mutação passa por `run` / `as_sudo` / `apt_install` / … (dry-run intacto)
- [ ] Mudança de plugin do Neovim inclui o `lazy-lock.json` atualizado
- [ ] Teste novo cobrindo o comportamento alterado
