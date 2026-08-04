# home.local.example

Templates de personalização que **não** são gerenciados pelo PowerTerminal.

Como usar:

```bash
cp ~/PowerTerminal/home.local.example/.zshrc.local ~/.zshrc.local
$EDITOR ~/.zshrc.local
```

O `~/.zshrc` (gerenciado pelo PowerTerminal) faz `source ~/.zshrc.local` no final
quando esse arquivo existe. Coloque aqui:

- aliases pessoais (VPN, atalhos para Docker compose locais, etc.)
- exports de toolchain (JAVA_HOME, ghcup, gcloud, n, etc.)
- segredos / tokens / chaves (que **nunca** devem ir para um repo)

Cada máquina/usuário mantém seu próprio `~/.zshrc.local`.
