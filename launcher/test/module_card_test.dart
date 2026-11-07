import 'package:flutter/foundation.dart';

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:powerterminal_launcher/model/catalog.dart';
import 'package:powerterminal_launcher/queue/queue_controller.dart';
import 'package:powerterminal_launcher/theme/app_theme.dart';
import 'package:powerterminal_launcher/ui/home_actions.dart';
import 'package:powerterminal_launcher/ui/module_card.dart';

class RecordingActions implements HomeActions {
  final calls = <String>[];
  @override
  void install(String id) => calls.add('install:$id');
  @override
  void update(String id) => calls.add('update:$id');
  @override
  void remove(String id) => calls.add('remove:$id');
  @override
  void installProfile(String profile) => calls.add('installProfile:$profile');
  @override
  void updateProfile(String profile) => calls.add('updateProfile:$profile');
  @override
  void showLog() => calls.add('showLog');
}

final _catalog = Catalog.fromJson(
  jsonDecode(File('test/fixtures/catalog.json').readAsStringSync())
      as Map<String, dynamic>,
);

Future<RecordingActions> pump(
  WidgetTester t,
  String id,
  CardStatus status, {
  VoidCallback? onDequeue,
  TargetPlatform? platform,
}) async {
  debugDefaultTargetPlatformOverride = platform;
  final actions = RecordingActions();
  await t.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: SingleChildScrollView(
          child: SizedBox(
            width: 320,
            child: ModuleCard(
              module: _catalog.byId(id)!,
              status: status,
              actions: actions,
              onDequeue: onDequeue,
            ),
          ),
        ),
      ),
    ),
  );
  debugDefaultTargetPlatformOverride = null;
  return actions;
}

void main() {
  testWidgets('available mostra Instalar e chama install', (t) async {
    final a = await pump(t, 'helpers', const CardStatus());
    expect(find.text('Instalar'), findsOneWidget);
    expect(find.text('Atualizar'), findsNothing);
    expect(find.text('Remover'), findsNothing);
    await t.tap(find.text('Instalar'));
    expect(a.calls, ['install:helpers']);
  });

  testWidgets('installed com update e remove', (t) async {
    final a = await pump(t, 'zsh', const CardStatus());
    expect(find.text('Instalado'), findsOneWidget);
    expect(find.text('Instalar'), findsNothing);
    await t.tap(find.text('Atualizar'));
    await t.tap(find.text('Remover'));
    expect(a.calls, ['update:zsh', 'remove:zsh']);
  });

  testWidgets('preexisting mostra Já estava instalado', (t) async {
    await pump(t, 'vscode', const CardStatus());
    expect(find.text('Já estava instalado'), findsOneWidget);
  });

  testWidgets('módulo instalado sem canRemove mostra a nota', (t) async {
    final m = ModuleInfo(
      id: 'apt',
      name: 'Pacotes base',
      category: 'base',
      description: 'd',
      minutes: 1,
      mb: 1,
      sudo: false,
      editor: false,
      canUpdate: true,
      canRemove: false,
      needs: const [],
      state: ModuleState.installed,
    );
    await t.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: ModuleCard(
            module: m,
            status: const CardStatus(),
            actions: RecordingActions(),
          ),
        ),
      ),
    );
    expect(find.text('Base de outros módulos'), findsOneWidget);
    expect(find.text('Remover'), findsNothing);
    expect(find.text('Atualizar'), findsOneWidget);
  });

  testWidgets('módulo sem canUpdate não mostra Atualizar', (t) async {
    final id = _catalog.modules.firstWhere((m) => m.isPresent && !m.canUpdate);
    await pump(t, id.id, const CardStatus());
    expect(find.text('Atualizar'), findsNothing);
  });

  testWidgets('queued mostra Na fila e Tirar da fila', (t) async {
    var dequeued = 0;
    await pump(
      t,
      'helpers',
      const CardStatus(phase: CardPhase.queued, kind: OpKind.install),
      onDequeue: () => dequeued++,
    );
    expect(find.text('Na fila'), findsOneWidget);
    expect(find.text('Instalar'), findsNothing);
    await t.tap(find.text('Tirar da fila'));
    expect(dequeued, 1);
  });

  testWidgets('running mostra barra determinada, passo e sem botões', (
    t,
  ) async {
    await pump(
      t,
      'zsh',
      const CardStatus(
        phase: CardPhase.running,
        kind: OpKind.update,
        step: 'Baixando',
        progress: 0.5,
      ),
    );
    expect(find.text('Atualizando'), findsOneWidget);
    expect(find.text('Baixando'), findsOneWidget);
    final bar = t.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(bar.value, 0.5);
    expect(find.text('Atualizar'), findsNothing);
    expect(find.text('Remover'), findsNothing);
  });

  testWidgets('running sem progresso fica indeterminado', (t) async {
    await pump(
      t,
      'helpers',
      const CardStatus(phase: CardPhase.running, kind: OpKind.install),
    );
    expect(find.text('Instalando'), findsOneWidget);
    expect(
      t
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .value,
      isNull,
    );
  });

  testWidgets('failed mostra erro, Ver log e as ações do catálogo', (t) async {
    final a = await pump(
      t,
      'helpers',
      const CardStatus(phase: CardPhase.failed, error: 'rc 1'),
    );
    expect(find.text('rc 1'), findsOneWidget);
    expect(find.text('Instalar'), findsOneWidget);
    await t.tap(find.text('Ver log'));
    expect(a.calls, ['showLog']);
  });

  testWidgets('tags de tempo, tamanho, sudo e requer', (t) async {
    await pump(t, 'astronvim', const CardStatus());
    expect(find.text('~1 min'), findsOneWidget);
    expect(find.text('5 MB'), findsOneWidget);
    expect(find.text('requer nvim'), findsOneWidget);
    expect(find.text('sudo'), findsNothing);
    await pump(t, 'apt', const CardStatus());
    expect(find.text('~2 min'), findsOneWidget);
    expect(find.text('150 MB'), findsOneWidget);
    expect(find.text('sudo'), findsOneWidget);
  });
}
