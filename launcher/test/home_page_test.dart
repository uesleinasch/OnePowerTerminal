import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:powerterminal_launcher/cli/cli.dart';
import 'package:powerterminal_launcher/model/catalog.dart';
import 'package:powerterminal_launcher/queue/queue_controller.dart';
import 'package:powerterminal_launcher/session/pty_shell.dart';
import 'package:powerterminal_launcher/system/prefs.dart';
import 'package:powerterminal_launcher/system/update_check.dart';
import 'package:powerterminal_launcher/theme/app_theme.dart';
import 'package:powerterminal_launcher/ui/format.dart';
import 'package:powerterminal_launcher/ui/home_page.dart';

import 'module_card_test.dart' show RecordingActions;
import 'support/fake_shell.dart';

final _fixture = File('test/fixtures/catalog.json').readAsStringSync();

String _withStates(
  Map<String, String> states, [
  Map<String, String> descriptions = const {},
]) {
  final j = jsonDecode(_fixture) as Map<String, dynamic>;
  for (final m in j['modules'] as List) {
    final s = states[m['id']];
    if (s != null) m['state'] = s;
    final d = descriptions[m['id']];
    if (d != null) m['description'] = d;
  }
  return jsonEncode(j);
}

Future<QueueController> controller({
  ProcessResult Function()? result,
  Map<String, String> states = const {},
  Map<String, String> descriptions = const {},
  ShellFactory? shell,
}) async {
  final body = _withStates(states, descriptions);
  final q = QueueController(
    cli: Cli(
      '/repo',
      runner: (exe, args, {workingDirectory, environment}) async =>
          result?.call() ?? ProcessResult(1, 0, body, ''),
    ),
    shellFactory: shell ?? () async => FakeShell(),
    repoDir: '/repo',
    eventsDir: Directory.systemTemp.createTempSync('pn-home-test'),
  );
  await q.refresh();
  return q;
}

Future<RecordingActions> show(
  WidgetTester t,
  QueueController q, {
  double width = 1400,
}) async {
  t.view.physicalSize = Size(width, 4000);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final actions = RecordingActions();
  await t.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: HomePage(controller: q, actions: actions),
    ),
  );
  return actions;
}

Future<void> pickProfile(WidgetTester t, String p) async {
  await t.tap(
    find.descendant(
      of: find.byType(SegmentedButton<String>),
      matching: find.text(p),
    ),
  );
  await t.pump();
}

int cards(WidgetTester t) => find.byType(Card).evaluate().length;

Future<void> finish(WidgetTester t, QueueController q, QueueItem item) async {
  await t.runAsync(() async {
    await q.enqueue([item], askPassword: ({error}) async => null);
    await q.whenIdle();
    await Future<void>.delayed(const Duration(milliseconds: 20));
  });
  await t.pump();
  await t.pump(const Duration(milliseconds: 300));
}

void main() {
  group('aviso de conclusão', () {
    Future<QueueController> withShell(
      WidgetTester t,
      FakeShell Function() make,
    ) async {
      final shell = (await t.runAsync(() async => make()))!;
      return (await t.runAsync(() => controller(shell: () async => shell)))!;
    }

    testWidgets('instalação ok mostra o snackbar por 4,2 s, sem ação', (
      t,
    ) async {
      final q = await withShell(t, FakeShell.new);
      await show(t, q);
      final name = q.catalog!.byId('helpers')!.name;
      await finish(t, q, const QueueItem('helpers', OpKind.install));
      expect(find.text('$name instalado.'), findsOneWidget);
      expect(find.text('Ver próximos passos'), findsNothing);
      expect(
        t.widget<SnackBar>(find.byType(SnackBar)).duration,
        const Duration(milliseconds: 4200),
      );
    });

    for (final (kind, text) in [
      (OpKind.update, 'atualizado.'),
      (OpKind.remove, 'removido.'),
    ]) {
      testWidgets('${kind.name} usa o verbo "$text"', (t) async {
        final q = await withShell(t, FakeShell.new);
        await show(t, q);
        final name = q.catalog!.byId('helpers')!.name;
        await finish(t, q, QueueItem('helpers', kind));
        expect(find.text('$name $text'), findsOneWidget);
      });
    }

    testWidgets('com notas, a ação abre o diálogo com elas', (t) async {
      final q = await withShell(
        t,
        () => FakeShell(
          events: {
            'helpers': [
              '{"event":"note","module":"helpers","text":"Abra um novo terminal."}',
              '{"event":"note","module":"helpers","text":"Rode p10k configure."}',
            ],
          },
        ),
      );
      await show(t, q);
      await finish(t, q, const QueueItem('helpers', OpKind.install));
      await t.tap(find.text('Ver próximos passos'));
      await t.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Abra um novo terminal.'), findsOneWidget);
      expect(find.text('Rode p10k configure.'), findsOneWidget);
      await t.tap(find.text('Fechar'));
      await t.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('falha não mostra snackbar de sucesso', (t) async {
      final q = await withShell(
        t,
        () => FakeShell(results: {"'helpers'": const RunResult(1, false)}),
      );
      await show(t, q);
      await finish(t, q, const QueueItem('helpers', OpKind.install));
      expect(find.byType(SnackBar), findsNothing);
    });
  });

  testWidgets('largura de 500 px não gera exceção', (t) async {
    final q = await controller();
    t.view.physicalSize = const Size(500, 3000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: HomePage(controller: q, actions: RecordingActions()),
      ),
    );
    final ex = t.takeException();
    expect(ex, isNull);
  });

  test('formatMb', () {
    expect(formatMb(150), '150 MB');
    expect(formatMb(999), '999 MB');
    expect(formatMb(1500), '1,5 GB');
  });

  testWidgets('sem filtro mostra todos os módulos e a barra', (t) async {
    await show(t, await controller());
    expect(cards(t), 23);
    expect(find.text('PowerTerminal'), findsOneWidget);
    expect(find.text('v0.2.0 · Ubuntu 22.04.5 LTS · x86_64'), findsOneWidget);
    expect(find.text('sudo liberado'), findsNothing);
    expect(find.text('Todos os módulos'), findsOneWidget);
    expect(find.text('Instalar'), findsWidgets);
    expect(find.textContaining('restante'), findsNothing);
  });

  testWidgets('filtro minimal mostra só os 4 módulos', (t) async {
    await show(t, await controller());
    await pickProfile(t, 'minimal');
    expect(cards(t), 4);
    expect(find.text('Perfil minimal'), findsOneWidget);
    expect(find.text('Instalar 3 restantes'), findsOneWidget);
  });

  testWidgets('só instalados esconde os available', (t) async {
    await show(t, await controller());
    await t.tap(find.text('Só instalados'));
    await t.pump();
    expect(cards(t), 9);
    expect(find.text('Instalar'), findsNothing);
  });

  testWidgets('busca por code acha vscode', (t) async {
    await show(t, await controller());
    await t.enterText(find.byType(TextField), 'CODE');
    await t.pump();
    expect(find.text('vscode'), findsOneWidget);
    expect(find.text('zsh'), findsNothing);
    expect(cards(t), lessThan(23));
  });

  testWidgets('busca sem resultado mostra o vazio', (t) async {
    await show(t, await controller());
    await t.enterText(find.byType(TextField), 'zzzzzz');
    await t.pump();
    expect(find.text('Nenhum módulo com esse filtro.'), findsOneWidget);
  });

  testWidgets('resumo em dev com só o vscode não conta o nvim', (t) async {
    final a = await show(t, await controller());
    await pickProfile(t, 'dev');
    expect(find.text('8 de 16 instalados'), findsOneWidget);
    expect(find.text('Instalar 8 restantes'), findsOneWidget);
    await t.tap(find.text('Instalar 8 restantes'));
    expect(a.calls, ['installProfile:dev']);
  });

  testWidgets('resumo em dev com só o nvim não conta o vscode', (t) async {
    await show(
      t,
      await controller(states: {'nvim': 'installed', 'vscode': 'available'}),
    );
    await pickProfile(t, 'dev');
    expect(find.text('8 de 17 instalados'), findsOneWidget);
    expect(find.text('Instalar 9 restantes'), findsOneWidget);
  });

  testWidgets('erro ao recarregar com catálogo vira banner sobre os cards', (
    t,
  ) async {
    var fail = false;
    final q = await controller(
      result: () => fail
          ? ProcessResult(1, 2, '', 'falhou feio')
          : ProcessResult(1, 0, _fixture, ''),
    );
    await show(t, q);
    fail = true;
    await t.runAsync(q.refresh);
    await t.pump();
    expect(q.catalog, isNotNull);
    expect(
      find.text('Não foi possível ler o catálogo da CLI.'),
      findsOneWidget,
    );
    expect(find.text('Tentar de novo'), findsOneWidget);
    expect(cards(t), 23);
    fail = false;
    await t.tap(find.text('Tentar de novo'));
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await t.pump();
    expect(find.text('Tentar de novo'), findsNothing);
    expect(cards(t), 23);
  });

  testWidgets('erro de catálogo mostra Tentar de novo', (t) async {
    final q = await controller(
      result: () => ProcessResult(1, 2, '', 'falhou feio'),
    );
    await show(t, q);
    expect(find.text('Tentar de novo'), findsOneWidget);
    expect(find.text('falhou feio'), findsOneWidget);
  });

  for (final (width, scale) in [
    (1280.0, 1.0),
    (700.0, 1.0),
    (620.0, 1.0),
    (620.0, 1.5),
  ]) {
    testWidgets(
      'cards da mesma fileira têm a mesma altura em $width px, texto x$scale',
      (t) async {
        t.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
        final q = await controller(
          descriptions: {
            'apt': 'Linha um do texto longo. ' * 12,
            'fonts': 'Curto.',
          },
        );
        await show(t, q, width: width);
        expect(t.takeException(), isNull);
        Finder card(String id) =>
            find.ancestor(of: find.text(id), matching: find.byType(Card));
        final a = card('apt');
        final b = card('fonts');
        expect(t.getTopLeft(a).dy, t.getTopLeft(b).dy, reason: 'mesma fileira');
        expect(t.getSize(a).height, t.getSize(b).height);
        double buttonTop(Finder c) => t
            .getTopLeft(
              find.descendant(of: c, matching: find.byType(FilledButton)),
            )
            .dy;
        expect(buttonTop(a), buttonTop(b));
      },
    );
  }

  testWidgets('aviso de versão nova: três ações e "Agora não" grava', (
    t,
  ) async {
    final q = await controller();
    final dir = Directory.systemTemp.createTempSync('pn-home-update');
    addTearDown(() => dir.deleteSync(recursive: true));
    final prefs = File('${dir.path}/launcher.json');
    final update = ValueNotifier<ReleaseInfo?>(
      ReleaseInfo(
        version: '0.3.0',
        tag: 'v0.3.0',
        htmlUrl: Uri.parse('https://example.test/r'),
        appImageUrl: Uri.parse('https://example.test/app'),
        sumsUrl: Uri.parse('https://example.test/sums'),
      ),
    );
    t.view.physicalSize = const Size(1400, 4000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: HomePage(
          controller: q,
          actions: RecordingActions(),
          prefsFile: prefs,
          update: update,
        ),
      ),
    );
    expect(find.text('PowerTerminal 0.3.0 disponível'), findsOneWidget);
    expect(find.text('Notas da versão'), findsOneWidget);
    expect(find.text('Agora não'), findsOneWidget);
    expect(find.text('Baixar e reiniciar'), findsOneWidget);
    await t.tap(find.text('Agora não'));
    await t.pump();
    expect(find.text('PowerTerminal 0.3.0 disponível'), findsNothing);
    expect(Prefs.load(prefs).dismissedVersion, '0.3.0');
  });
}
