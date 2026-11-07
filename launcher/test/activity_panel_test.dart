import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:powerterminal_launcher/cli/cli.dart';
import 'package:powerterminal_launcher/main.dart';
import 'package:powerterminal_launcher/model/catalog.dart';
import 'package:powerterminal_launcher/queue/queue_controller.dart';
import 'package:powerterminal_launcher/theme/app_theme.dart';
import 'package:powerterminal_launcher/ui/activity_panel.dart';

import 'module_card_test.dart' show RecordingActions;
import 'support/fake_shell.dart';

final _fixture = File('test/fixtures/catalog.json').readAsStringSync();

Future<QueueController> controller({ShellFactory? shell}) async {
  final q = QueueController(
    cli: Cli(
      '/repo',
      runner: (exe, args, {workingDirectory, environment}) async =>
          ProcessResult(1, 0, _fixture, ''),
    ),
    shellFactory: shell ?? () async => FakeShell(),
    repoDir: '/repo',
    eventsDir: Directory.systemTemp.createTempSync('pn-activity-test'),
  );
  await q.refresh();
  return q;
}

Future<void> pumpPanel(WidgetTester t, QueueController q) => t.pumpWidget(
  MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(body: ActivityPanel(controller: q)),
  ),
);

Future<void> pumpApp(
  WidgetTester t,
  QueueController q,
  Size size, {
  ValueNotifier<bool>? open,
  ThemeMode mode = ThemeMode.light,
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    PowerTerminalApp(
      controller: q,
      actions: RecordingActions(),
      themeMode: mode,
      activityOpen: open,
    ),
  );
}

void main() {
  testWidgets('cores do log: launcher, sucesso e dry-run', (t) async {
    final q = await controller();
    q.note('[launcher] instalar zsh');
    q.note('[powerterminal] Instalação concluída.');
    q.note('[dry-run] apt-get install zsh');
    q.note('[powerterminal] instalando zsh');
    await pumpPanel(t, q);
    await t.pump();
    final theme = AppTheme.light();
    final cs = theme.colorScheme;
    Color? color(String s) => t.widget<Text>(find.text(s)).style?.color;
    expect(color('[launcher] instalar zsh'), cs.primary);
    expect(
      color('[powerterminal] Instalação concluída.'),
      theme.extension<PnColors>()!.success,
    );
    expect(color('[dry-run] apt-get install zsh'), cs.onSurfaceVariant);
    expect(color('[powerterminal] instalando zsh'), cs.onSurface);
  });

  test('classifyLogLine reconhece o que a CLI realmente imprime', () {
    // A CLI usa "[powerterminal]" para info e sucesso (cor removida em
    // text_clean.dart); sucesso = os textos de log_success em bin/ e lib/,
    // mais as linhas "OK: ..." de log_info dos módulos.
    const success = [
      '[powerterminal] Instalação concluída.',
      '[powerterminal] Remoção concluída.',
      '[powerterminal] Update concluído.',
      '[powerterminal] Unlink concluído.',
      '[powerterminal] Symlinks atualizados.',
      '[powerterminal] OK: lazygit presente',
      '[powerterminal] Neovim instalado: NVIM v0.10',
      '[powerterminal] VS Code instalado: 1.90',
      '[powerterminal] Tema: mocha',
      '[powerterminal] zsh definido como shell padrão.',
    ];
    for (final l in success) {
      expect(classifyLogLine(l), LogLineKind.success, reason: l);
    }
    expect(classifyLogLine('[launcher] x'), LogLineKind.launcher);
    expect(classifyLogLine('[dry-run] x'), LogLineKind.dryRun);
    expect(
      classifyLogLine('[powerterminal] Instalando zsh'),
      LogLineKind.plain,
    );
    expect(classifyLogLine('Reading package lists...'), LogLineKind.plain);
  });

  testWidgets('sem itens mostra Nada na fila.', (t) async {
    final q = await controller();
    await pumpPanel(t, q);
    expect(find.text('Atividade'), findsOneWidget);
    expect(find.text('Nada na fila.'), findsOneWidget);
    expect(
      find.text('Log · ~/.local/state/powerterminal/install.log'),
      findsOneWidget,
    );
  });

  testWidgets('mostra o atual com % e os pendentes com o tipo', (t) async {
    final gate = (await t.runAsync(() async => Completer<void>()))!;
    final shell = (await t.runAsync(
      () async => FakeShell(
        events: {
          'helpers': [
            '{"event":"step","module":"helpers","text":"Baixando","n":1,"m":4}',
          ],
        },
        onRun: (_) => gate.future,
      ),
    ))!;
    final q = (await t.runAsync(() => controller(shell: () async => shell)))!;
    final byId = q.catalog!.byId;
    await t.runAsync(() async {
      await q.enqueue([
        const QueueItem('helpers', OpKind.install),
        const QueueItem('kitty', OpKind.update),
        const QueueItem('claude', OpKind.remove),
      ], askPassword: ({error}) async => null);
      for (var i = 0; i < 60; i++) {
        if (q.status('helpers').progress != null) break;
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    });
    await pumpPanel(t, q);
    expect(find.text(byId('helpers')!.name), findsOneWidget);
    expect(find.text('25%'), findsOneWidget);
    expect(find.text(byId('kitty')!.name), findsOneWidget);
    expect(find.text('atualizar'), findsOneWidget);
    expect(find.text('remover'), findsOneWidget);
    expect(find.text('Nada na fila.'), findsNothing);
    final item = t.widget<Container>(
      find
          .ancestor(
            of: find.text(byId('kitty')!.name),
            matching: find.byType(Container),
          )
          .first,
    );
    expect(
      (item.decoration! as BoxDecoration).borderRadius,
      BorderRadius.circular(8),
    );
    await t.runAsync(() async {
      gate.complete();
      await q.whenIdle();
    });
  });

  testWidgets('as linhas do log aparecem em fonte mono', (t) async {
    final q = await controller();
    q.note('primeira linha');
    q.note('segunda linha');
    await pumpPanel(t, q);
    await t.pump();
    final text = t.widget<Text>(find.text('primeira linha'));
    expect(text.style?.fontFamily, kMonoFont);
    expect(find.text('segunda linha'), findsOneWidget);
    expect(find.byType(SelectionArea), findsOneWidget);
  });

  testWidgets('segue o fim do log enquanto está embaixo e para ao rolar', (
    t,
  ) async {
    final q = await controller();
    t.view.physicalSize = const Size(400, 700);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    for (var i = 0; i < 100; i++) {
      q.note('linha $i');
    }
    await pumpPanel(t, q);
    await t.pump();
    await t.pump();
    expect(find.text('linha 99'), findsOneWidget);
    q.note('linha 100');
    await t.pump();
    await t.pump();
    expect(find.text('linha 100'), findsOneWidget);

    await t.drag(find.text('linha 100'), const Offset(0, 600));
    await t.pump();
    expect(find.text('linha 100'), findsNothing);
    q.note('linha 101');
    await t.pump();
    await t.pump();
    expect(find.text('linha 101'), findsNothing);

    await t.drag(find.byType(ListView).last, const Offset(0, -5000));
    await t.pump();
    q.note('linha 102');
    await t.pump();
    await t.pump();
    expect(find.text('linha 102'), findsOneWidget);
  });

  testWidgets('passa de 5000 linhas e continua seguindo o fim', (t) async {
    final q = await controller();
    t.view.physicalSize = const Size(400, 700);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    for (var i = 0; i < 5000; i++) {
      q.note('linha $i');
    }
    await pumpPanel(t, q);
    await t.pump();
    await t.pump();
    expect(find.text('linha 4999'), findsOneWidget);
    for (var i = 0; i < 40; i++) {
      q.note('${'x' * 400} $i');
    }
    q.note('fim');
    for (var i = 0; i < 4; i++) {
      await t.pump();
    }
    expect(q.log, hasLength(5000));
    expect(q.logAppended, 5041);
    expect(find.text('fim'), findsOneWidget);
  });

  testWidgets('em 1200 px o painel fica ao lado do conteúdo', (t) async {
    final q = await controller();
    final open = ValueNotifier(true);
    await pumpApp(t, q, const Size(1200, 900), open: open);
    final panel = t.getTopLeft(find.byType(ActivityPanel));
    final content = t.getTopLeft(find.text('Buscar módulo, ferramenta…').first);
    expect(t.getSize(find.byType(ActivityPanel)).width, 340);
    expect(panel.dx, 1200 - 340);
    expect(panel.dx, greaterThan(content.dx));
  });

  testWidgets('em 700 px o painel fica abaixo do conteúdo', (t) async {
    final q = await controller();
    final open = ValueNotifier(true);
    await pumpApp(t, q, const Size(700, 900), open: open);
    final panel = t.getTopLeft(find.byType(ActivityPanel));
    expect(panel.dx, 0);
    expect(
      panel.dy,
      greaterThan(
        t.getTopLeft(find.text('Buscar módulo, ferramenta…').first).dy,
      ),
    );
    expect(t.getSize(find.byType(ActivityPanel)).width, 700);
  });

  testWidgets('abre pelo botão e pelo notifier, fecha pelo X', (t) async {
    final q = await controller();
    final open = ValueNotifier(false);
    await pumpApp(t, q, const Size(1200, 900), open: open);
    expect(find.byType(ActivityPanel), findsNothing);
    await t.tap(find.byTooltip('Atividade'));
    await t.pump();
    expect(find.byType(ActivityPanel), findsOneWidget);
    await t.tap(find.byTooltip('Fechar atividade'));
    await t.pump();
    expect(find.byType(ActivityPanel), findsNothing);
    expect(open.value, isFalse);
    open.value = true;
    await t.pump();
    expect(find.byType(ActivityPanel), findsOneWidget);
  });

  testWidgets('o botão de tema alterna claro e escuro', (t) async {
    final q = await controller();
    await pumpApp(t, q, const Size(1200, 900));
    Brightness now() =>
        Theme.of(t.element(find.byType(Scaffold).first)).brightness;
    expect(now(), Brightness.light);
    expect(find.byIcon(Icons.dark_mode_rounded), findsOneWidget);
    await t.tap(find.byTooltip('Alternar tema'));
    await t.pumpAndSettle();
    expect(now(), Brightness.dark);
    expect(find.byIcon(Icons.light_mode_rounded), findsOneWidget);
    await t.tap(find.byTooltip('Alternar tema'));
    await t.pumpAndSettle();
    expect(now(), Brightness.light);
  });

  testWidgets('em 899 px é bloco abaixo e em 900 px é lateral', (t) async {
    final q = await controller();
    final open = ValueNotifier(true);
    await pumpApp(t, q, const Size(899, 900), open: open);
    expect(t.getTopLeft(find.byType(ActivityPanel)).dx, 0);
    await pumpApp(t, q, const Size(900, 900), open: open);
    await t.pump();
    expect(t.getTopLeft(find.byType(ActivityPanel)).dx, 900 - 340);
  });

  testWidgets('janela estreita e baixa não gera overflow', (t) async {
    final q = await controller();
    await pumpApp(t, q, const Size(700, 400), open: ValueNotifier(true));
    expect(t.takeException(), isNull);
    expect(
      t.getSize(find.byType(ActivityPanel)).height,
      lessThanOrEqualTo(200),
    );
  });

  testWidgets('o listener de saída remove o diretório de eventos', (t) async {
    final q = await controller();
    final dir = Directory.systemTemp.createTempSync('pn-exit-test');
    addTearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });
    await t.pumpWidget(
      PowerTerminalApp(
        controller: q,
        actions: RecordingActions(),
        eventsDir: dir,
      ),
    );
    expect(t.takeException(), isNull);
    await t.binding.handleRequestAppExit();
    expect(dir.existsSync(), isFalse);
  });

  testWidgets('fechar com operação em andamento pergunta antes', (t) async {
    final gate = (await t.runAsync(() async => Completer<void>()))!;
    final shell = (await t.runAsync(
      () async => FakeShell(onRun: (_) => gate.future),
    ))!;
    final q = (await t.runAsync(() => controller(shell: () async => shell)))!;
    final dir = Directory.systemTemp.createTempSync('pn-exit-busy');
    addTearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });
    await t.pumpWidget(
      PowerTerminalApp(
        controller: q,
        actions: RecordingActions(),
        eventsDir: dir,
      ),
    );
    await t.runAsync(() async {
      await q.enqueue([
        const QueueItem('helpers', OpKind.install),
      ], askPassword: ({error}) async => null);
      while (shell.runs.isEmpty) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    expect(q.isBusy, isTrue);

    AppExitResponse? answer;
    Future<void> requestExit() async {
      answer = null;
      unawaited(t.binding.handleRequestAppExit().then((r) => answer = r));
      await t.pump();
      await t.pump(const Duration(milliseconds: 300));
    }

    Future<void> untilAnswered() async {
      for (var i = 0; i < 100 && answer == null; i++) {
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await t.pump(const Duration(milliseconds: 50));
      }
    }

    await requestExit();
    expect(
      find.text('Há uma operação em andamento. Fechar mesmo assim?'),
      findsOneWidget,
    );
    await t.tap(find.text('Cancelar'));
    await untilAnswered();
    expect(answer, AppExitResponse.cancel);
    expect(dir.existsSync(), isTrue);
    expect(shell.closed, 0);

    await requestExit();
    await t.tap(find.text('Fechar'));
    await untilAnswered();
    expect(answer, AppExitResponse.exit);
    await t.runAsync(() async => gate.complete());
    expect(shell.closed, greaterThan(0));
    expect(dir.existsSync(), isFalse);
  });
}
