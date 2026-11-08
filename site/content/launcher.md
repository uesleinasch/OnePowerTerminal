# Launcher

O launcher é um app Flutter para Linux que dá uma interface gráfica à CLI. Ele não instala nada por conta própria: cada ação é um comando `bin/powerterminal`.

## O que faz

- **Cards de módulos:** o catálogo com o estado de cada módulo nesta máquina.
- **Detalhe:** o que o módulo instala, o que ele exige e o que o `remove` desfaz.
- **Fila:** instalações, atualizações e remoções rodam em série, com o progresso acompanhado na janela.
- **Senha uma vez:** a senha do `sudo` é pedida na própria janela, só quando alguma operação da fila precisa, e nunca é gravada em arquivo, variável de ambiente ou argumento.
- **Adoção:** módulos que já estavam instalados fora do PowerTerminal podem passar a ser gerenciados por ele.
- **Remover:** desfaz só o que consta no recibo, sem tocar no que já existia.

## Como rodar hoje

É preciso o SDK do Flutter e, no Linux, `clang cmake ninja-build pkg-config libgtk-3-dev`.

```bash
cd launcher
flutter pub get
flutter run -d linux
```

Os testes usam um `sudo` e uma CLI falsos, então nenhum deles roda `sudo`, `apt` ou a CLI real:

```bash
flutter analyze
flutter test
```

## AppImage

O AppImage sai nas releases a partir da v0.3.0. Até lá, o launcher roda pelo código-fonte.
