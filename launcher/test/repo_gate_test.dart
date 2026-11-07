import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:powerterminal_launcher/repo/repo_copy.dart';
import 'package:powerterminal_launcher/theme/app_theme.dart';
import 'package:powerterminal_launcher/ui/repo_gate.dart';

Future<ProcessResult> noChmod(
  String exe,
  List<String> args, {
  String? workingDirectory,
  Map<String, String>? environment,
}) async => ProcessResult(1, 0, '', '');

late Directory tmp;
late String home;

void write(String rel, String body) =>
    (File('$home/$rel')..createSync(recursive: true)).writeAsStringSync(body);

Future<void> show(
  WidgetTester t,
  RepoCopy repo, {
  List<List<String>>? calls,
  ProcessResult Function(List<String> args)? result,
  List<String>? built,
}) async {
  await t.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: RepoGate(
        repo: repo,
        runner: (exe, args, {workingDirectory, environment}) async {
          calls?.add([exe, ...args]);
          return result!(args);
        },
        builder: (dir) {
          built?.add(dir);
          return const Text('home pronta');
        },
      ),
    ),
  );
  await t.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 50)),
  );
  await t.pump();
}

ProcessResult catalog(int contract) => ProcessResult(
  1,
  0,
  '{"contract_version":$contract,"version":"0.1.0",'
      '"distro":"x","arch":"x","profiles":{},"modules":[]}',
  '',
);

void main() {
  test('pullCommand usa ~ dentro do HOME e aspas quando precisa', () {
    expect(
      pullCommand('/h/u/PowerTerminal', '/h/u'),
      'git -C ~/PowerTerminal pull --ff-only',
    );
    expect(
      pullCommand('/h/u/src/pt', '/h/u/'),
      'git -C ~/src/pt pull --ff-only',
    );
    expect(pullCommand('/opt/pt', '/h/u'), 'git -C /opt/pt pull --ff-only');
    expect(
      pullCommand("/h/u/meu repo", '/h/u'),
      "git -C '/h/u/meu repo' pull --ff-only",
    );
    expect(pullCommand('/h/uv/pt', '/h/u'), 'git -C /h/uv/pt pull --ff-only');
  });

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('pn-gate');
    home = '${tmp.path}/home';
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  testWidgets('foreign mostra a mensagem e não constrói a home', (t) async {
    write('PowerTerminal/qualquer.txt', 'x');
    final built = <String>[];
    await show(
      t,
      RepoCopy(home: home),
      built: built,
      result: (_) => catalog(1),
    );
    expect(
      find.textContaining('existe e não é o PowerTerminal'),
      findsOneWidget,
    );
    expect(find.textContaining('Renomeie ou remova'), findsOneWidget);
    expect(built, isEmpty);
  });

  testWidgets('absent sem instantâneo mostra o comando de instalação', (
    t,
  ) async {
    await show(t, RepoCopy(home: home), result: (_) => catalog(1));
    expect(
      find.text('PowerTerminal não encontrado em ~/PowerTerminal'),
      findsOneWidget,
    );
    expect(find.text(kInstallCommand), findsOneWidget);
  });

  testWidgets('falha ao extrair mostra erro, não gira para sempre', (t) async {
    final snap = '${tmp.path}/snap';
    (File('$snap/VERSION')..createSync(recursive: true)).writeAsStringSync('1');
    (File(
      '$snap/bin/powerterminal',
    )..createSync(recursive: true)).writeAsStringSync('x');
    final repo = RepoCopy(
      home: home,
      snapshotDir: snap,
      runner: (exe, args, {workingDirectory, environment}) async =>
          throw ProcessException(exe, args, 'sem chmod'),
    );
    await show(t, repo, result: (_) => catalog(1));
    expect(
      find.text('Não foi possível preparar ~/PowerTerminal'),
      findsOneWidget,
    );
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('onReady dispara uma vez ao liberar a home', (t) async {
    write('PowerTerminal/.git/HEAD', 'ref');
    write('PowerTerminal/bin/powerterminal', 'x');
    var ready = 0;
    await t.pumpWidget(
      MaterialApp(
        home: RepoGate(
          repo: RepoCopy(home: home),
          runner: (exe, args, {workingDirectory, environment}) async =>
              catalog(1),
          onReady: (_) => ready++,
          builder: (_) => const Text('home pronta'),
        ),
      ),
    );
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await t.pump();
    await t.pump();
    expect(ready, 1);
  });

  testWidgets('absent com instantâneo extrai e segue', (t) async {
    final snap = '${tmp.path}/snap';
    (File('$snap/VERSION')..createSync(recursive: true)).writeAsStringSync('1');
    (File(
      '$snap/bin/powerterminal',
    )..createSync(recursive: true)).writeAsStringSync('#!/bin/bash');
    final built = <String>[];
    final repo = RepoCopy(home: home, snapshotDir: snap, runner: noChmod);
    await show(t, repo, built: built, result: (_) => catalog(1));
    expect(find.text('home pronta'), findsOneWidget);
    expect(built, [repo.dir]);
    expect(repo.inspect(), RepoKind.extracted);
  });

  testWidgets('extracted antiga atualiza e lista os .pnnew', (t) async {
    final snap = '${tmp.path}/snap';
    (File('$snap/VERSION')..createSync(recursive: true)).writeAsStringSync('2');
    (File(
      '$snap/bin/powerterminal',
    )..createSync(recursive: true)).writeAsStringSync('novo');
    (File(
      '$snap/home/.zshrc',
    )..createSync(recursive: true)).writeAsStringSync('novo');
    write('PowerTerminal/VERSION', '1');
    write('PowerTerminal/bin/powerterminal', 'meu');
    write('PowerTerminal/home/.zshrc', 'meu');
    final repo = RepoCopy(home: home, snapshotDir: snap, runner: noChmod);
    await show(t, repo, result: (_) => catalog(1));
    expect(find.text('home pronta'), findsOneWidget);
    await t.pumpAndSettle();
    expect(find.text('Arquivos que você editou'), findsOneWidget);
    expect(find.text('home/.zshrc'), findsOneWidget);
    await t.tap(find.text('Entendi'));
    await t.pumpAndSettle();
    expect(find.text('Arquivos que você editou'), findsNothing);
  });

  group('clone git', () {
    setUp(() {
      write('PowerTerminal/.git/HEAD', 'ref');
      write('PowerTerminal/bin/powerterminal', '#!/bin/bash');
    });

    testWidgets('contrato atual segue direto', (t) async {
      await show(t, RepoCopy(home: home), result: (_) => catalog(1));
      expect(find.text('home pronta'), findsOneWidget);
    });

    testWidgets('contract_version 0 mostra o banner e o pull funciona', (
      t,
    ) async {
      write('PowerTerminal/VERSION', '0.1.0');
      final calls = <List<String>>[];
      var pulled = false;
      await show(
        t,
        RepoCopy(home: home),
        calls: calls,
        result: (args) {
          if (args.contains('pull')) {
            pulled = true;
            return ProcessResult(1, 0, '', '');
          }
          return catalog(pulled ? 1 : 0);
        },
      );
      expect(find.text('Sua cópia (git) está na versão 0.1.0'), findsOneWidget);
      await t.tap(find.text('Atualizar com git pull'));
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await t.pump();
      expect(
        calls.any(
          (c) =>
              c.first == 'git' &&
              c.join(' ') == 'git -C $home/PowerTerminal pull --ff-only',
        ),
        isTrue,
      );
      expect(find.text('home pronta'), findsOneWidget);
    });

    testWidgets('comando desconhecido também mostra o banner', (t) async {
      await show(
        t,
        RepoCopy(home: home),
        result: (_) => ProcessResult(
          1,
          1,
          '',
          "[powerterminal] Comando desconhecido: catalog.",
        ),
      );
      expect(find.text('Atualizar com git pull'), findsOneWidget);
    });

    testWidgets('pull com rc diferente de 0 mostra o comando', (t) async {
      await show(
        t,
        RepoCopy(home: home),
        result: (args) => args.contains('pull')
            ? ProcessResult(1, 1, '', 'fatal: divergiu')
            : catalog(0),
      );
      await t.tap(find.text('Atualizar com git pull'));
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await t.pump();
      expect(
        find.text('git -C ~/PowerTerminal pull --ff-only'),
        findsOneWidget,
      );
      expect(find.textContaining('fatal: divergiu'), findsOneWidget);
      expect(find.text('home pronta'), findsNothing);
    });

    testWidgets('pull ok mas contrato ainda antigo mostra aviso específico', (
      t,
    ) async {
      await show(
        t,
        RepoCopy(home: home),
        result: (args) =>
            args.contains('pull') ? ProcessResult(1, 0, '', '') : catalog(0),
      );
      await t.tap(find.text('Atualizar com git pull'));
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await t.pump();
      expect(find.text('A cópia ainda é antiga'), findsOneWidget);
      expect(
        find.text(
          'A cópia foi atualizada, mas a branch atual ainda não tem a versão '
          'que este launcher precisa.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('pull que falha mostra o comando da pasta em uso', (t) async {
      final other = '${tmp.path}/outro';
      File('$other/.git/HEAD').createSync(recursive: true);
      File('$other/bin/powerterminal').createSync(recursive: true);
      await show(
        t,
        RepoCopy(home: home, dir: other),
        result: (args) => args.contains('pull')
            ? ProcessResult(1, 1, '', 'fatal')
            : catalog(0),
      );
      await t.tap(find.text('Atualizar com git pull'));
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await t.pump();
      expect(find.text('git -C $other pull --ff-only'), findsOneWidget);
    });

    testWidgets('outro erro de catálogo segue para a home', (t) async {
      await show(
        t,
        RepoCopy(home: home),
        result: (_) => ProcessResult(1, 1, '', 'quebrou'),
      );
      expect(find.text('home pronta'), findsOneWidget);
    });
  });
}
