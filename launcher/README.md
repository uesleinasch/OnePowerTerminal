# PowerTerminal Launcher

Aplicativo Flutter (Linux) que dá uma interface gráfica à CLI `bin/powerterminal`: mostra o catálogo de módulos, enfileira instalações, atualizações e remoções e acompanha o progresso. O launcher não tem lógica de instalação própria; toda mutação de sistema é um comando da CLI.

## Rodar do código

```bash
flutter pub get
flutter run -d linux
```

Requer o SDK do Flutter e, no Linux, `clang cmake ninja-build pkg-config libgtk-3-dev`.

## Testes

```bash
flutter analyze
flutter test
```

Os testes usam um `sudo` e uma CLI falsos (`test/support/`) e precisam do `script` do util-linux. Nenhum deles roda `sudo`, `apt` ou a CLI real.

## Distribuição

O AppImage sai nas releases a partir da v0.3.0.

Veja o [README do projeto](../README.md) para o PowerTerminal em si.
