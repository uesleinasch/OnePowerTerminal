import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:powerterminal_launcher/cli/cli.dart';
import 'package:powerterminal_launcher/queue/queue_controller.dart';
import 'package:powerterminal_launcher/theme/app_theme.dart';
import 'package:powerterminal_launcher/ui/format.dart';
import 'package:powerterminal_launcher/ui/home_page.dart';

import 'module_card_test.dart' show RecordingActions;
import 'support/fake_shell.dart';

final _fixture = File('test/fixtures/catalog.json').readAsStringSync();

Future<QueueController> controller({ProcessResult Function()? result}) async {
  final q = QueueController(
    cli: Cli(
      '/repo',
      runner: (exe, args, {workingDirectory, environment}) async =>
          result?.call() ?? ProcessResult(1, 0, _fixture, ''),
    ),
    shellFactory: () async => FakeShell(),
    repoDir: '/repo',
    eventsDir: Directory.systemTemp.createTempSync('pn-home-test'),
  );
  await q.refresh();
  return q;
}

Future<RecordingActions> show(WidgetTester t, QueueController q) async {
  t.view.physicalSize = const Size(1400, 4000);
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

void main() {
  test('formatMb', () {
    expect(formatMb(150), '150 MB');
    expect(formatMb(999), '999 MB');
    expect(formatMb(1500), '1,5 GB');
  });

  testWidgets('sem filtro mostra todos os módulos e a barra', (t) async {
    await show(t, await controller());
    expect(cards(t), 15);
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
    expect(cards(t), lessThan(15));
  });

  testWidgets('busca sem resultado mostra o vazio', (t) async {
    await show(t, await controller());
    await t.enterText(find.byType(TextField), 'zzzzzz');
    await t.pump();
    expect(find.text('Nenhum módulo com esse filtro.'), findsOneWidget);
  });

  testWidgets('resumo em dev conta os available do perfil', (t) async {
    final q = await controller();
    final a = await show(t, q);
    await pickProfile(t, 'dev');
    final catalog = q.catalog!;
    final n = catalog.profiles['dev']!
        .where((id) => !catalog.byId(id)!.isPresent)
        .length;
    expect(find.text('Instalar $n restantes'), findsOneWidget);
    await t.tap(find.text('Instalar $n restantes'));
    expect(a.calls, ['installProfile:dev']);
  });

  testWidgets('erro de catálogo mostra Tentar de novo', (t) async {
    final q = await controller(
      result: () => ProcessResult(1, 2, '', 'falhou feio'),
    );
    await show(t, q);
    expect(find.text('Tentar de novo'), findsOneWidget);
    expect(find.text('falhou feio'), findsOneWidget);
  });
}
