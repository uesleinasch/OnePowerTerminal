import 'dart:async';
import 'dart:io';

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
  testWidgets('sem itens mostra Nada na fila.', (t) async {
    final q = await controller();
    await pumpPanel(t, q);
    expect(find.text('Atividade'), findsOneWidget);
    expect(find.text('Nada na fila.'), findsOneWidget);
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
        const QueueItem('tools', OpKind.remove),
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
  });

  testWidgets('em 1200 px o painel fica ao lado do conteúdo', (t) async {
    final q = await controller();
    final open = ValueNotifier(true);
    await pumpApp(t, q, const Size(1200, 900), open: open);
    final panel = t.getTopLeft(find.byType(ActivityPanel));
    final content = t.getTopLeft(find.text('Buscar módulos').first);
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
      greaterThan(t.getTopLeft(find.text('Buscar módulos').first).dy),
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
}
