import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:powerterminal_launcher/cli/cli.dart';
import 'package:powerterminal_launcher/model/catalog.dart';
import 'package:powerterminal_launcher/queue/queue_controller.dart';
import 'package:powerterminal_launcher/theme/app_theme.dart';
import 'package:powerterminal_launcher/ui/activity_panel.dart';
import 'package:powerterminal_launcher/ui/home_page.dart';
import 'package:powerterminal_launcher/ui/module_detail.dart';

import 'home_page_test.dart' show controller;
import 'support/fake_shell.dart';
import 'module_card_test.dart' show RecordingActions;

final _raw = jsonDecode(
  File('test/fixtures/catalog.json').readAsStringSync(),
) as Map<String, dynamic>;
final _catalog = Catalog.fromJson(_raw);

Finder _inDetail(String text) =>
    find.descendant(of: find.byType(ModuleDetail), matching: find.text(text));

Finder _card(String name) =>
    find.ancestor(of: find.text(name), matching: find.byType(Card));

Future<RecordingActions> _home(
  WidgetTester t, {
  double width = 1400,
  ValueNotifier<bool>? activityOpen,
  QueueController? q,
}) async {
  q ??= await controller();
  t.view.physicalSize = Size(width, 4000);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final actions = RecordingActions();
  await t.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: HomePage(
        controller: q,
        actions: actions,
        activityOpen: activityOpen,
      ),
    ),
  );
  return actions;
}

Future<void> _openZsh(WidgetTester t) async {
  await t.tap(
    find.descendant(
      of: _card('Zsh + Powerlevel10k'),
      matching: find.text('zsh'),
    ),
  );
  await t.pumpAndSettle();
}

class _QueueActions extends RecordingActions {
  _QueueActions(this.q);
  final QueueController q;
  @override
  void install(String id) {
    super.install(id);
    Zone.root.run(
      () => q.enqueue([
        QueueItem(id, OpKind.install),
      ], askPassword: ({error}) async => null),
    );
  }
}

Future<void> _liveStatus(WidgetTester t, {required double width}) async {
  final gate = Completer<void>();
  var installed = false;
  String current() => jsonEncode({
    ..._raw,
    'modules': [
      for (final m in _raw['modules'] as List)
        (m as Map<String, dynamic>)['id'] == 'helpers'
            ? {...m, 'state': installed ? 'installed' : 'available'}
            : m,
    ],
  });
  final q = (await t.runAsync(
    () async => QueueController(
      cli: Cli(
        '/repo',
        runner: (exe, args, {workingDirectory, environment}) async =>
            ProcessResult(1, 0, current(), ''),
      ),
      shellFactory: () async => FakeShell(
        events: {
          'helpers': [
            '{"event":"step","module":"helpers","text":"Baixando","n":1,"m":4}',
          ],
        },
        onRun: (_) async {
          await gate.future;
          installed = true;
        },
      ),
      repoDir: '/repo',
      eventsDir: Directory.systemTemp.createTempSync('pn-detail-live'),
    ),
  ))!;
  await t.runAsync(q.refresh);
  t.view.physicalSize = Size(width, 4000);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final actions = _QueueActions(q);
  await t.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: HomePage(controller: q, actions: actions),
    ),
  );
  await t.tap(
    find.descendant(of: _card('Cheatsheets'), matching: find.text('helpers')),
  );
  await t.pumpAndSettle();
  expect(_inDetail('Instalar'), findsOneWidget);
  await t.tap(_inDetail('Instalar'));
  await t.runAsync(() async {
    for (var i = 0; i < 100 && q.status('helpers').step == null; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    await Future<void>.delayed(const Duration(milliseconds: 100));
  });
  await t.pump();
  await t.pump(const Duration(milliseconds: 100));
  expect(_inDetail('Instalando'), findsOneWidget);
  expect(_inDetail('Baixando'), findsOneWidget);
  expect(_inDetail('25%'), findsOneWidget);
  expect(
    find.descendant(
      of: find.byType(ModuleDetail),
      matching: find.byType(LinearProgressIndicator),
    ),
    findsOneWidget,
  );
  expect(_inDetail('Instalar'), findsNothing);
  gate.complete();
  await t.runAsync(q.whenIdle);
  await t.pump();
  expect(find.byType(ModuleDetail), findsOneWidget);
  expect(_inDetail('Instalando'), findsNothing);
  expect(find.byType(LinearProgressIndicator), findsNothing);
  expect(_inDetail('Instalado'), findsOneWidget);
}

void main() {
  testWidgets('painel lateral acompanha a fila: progresso e fim', (t) async {
    await _liveStatus(t, width: 1400);
  });

  testWidgets('página estreita acompanha a fila: progresso e fim', (t) async {
    await _liveStatus(t, width: 620);
  });
  testWidgets('tocar no card abre o painel com todas as seções', (t) async {
    await _home(t);
    expect(find.text('O que instala'), findsNothing);
    await _openZsh(t);
    final zsh = _catalog.byId('zsh')!;
    expect(find.text(zsh.about), findsOneWidget);
    expect(find.text('Shell e aparência'), findsWidgets);
    expect(find.text('O que instala'), findsOneWidget);
    expect(
      find.text('~/.oh-my-zsh/custom/themes/powerlevel10k'),
      findsOneWidget,
    );
    expect(find.text('Pré-requisitos'), findsOneWidget);
    expect(find.text('git'), findsOneWidget);
    expect(find.text('Registrado pelo PowerTerminal'), findsOneWidget);
    expect(find.text('~/.oh-my-zsh'), findsNWidgets(2));
    expect(_inDetail('~2 min'), findsOneWidget);
    expect(find.text('Fechar detalhe'), findsNothing);
    expect(find.byTooltip('Fechar detalhe'), findsOneWidget);
    expect(_inDetail('Atualizar'), findsOneWidget);
    expect(find.text('Depende de'), findsNothing);
  });

  testWidgets('Depende de lista o nome dos módulos requeridos', (t) async {
    await _home(t);
    await t.tap(
      find.descendant(of: _card('AstroNvim'), matching: find.text('astronvim')),
    );
    await t.pumpAndSettle();
    expect(find.text('Depende de'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(ModuleDetail),
        matching: find.text('Neovim'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('tocar num botão do card não abre o painel', (t) async {
    final a = await _home(t);
    await t.tap(
      find.descendant(
        of: _card('Pacotes base'),
        matching: find.text('Instalar'),
      ),
    );
    await t.pumpAndSettle();
    expect(a.calls, ['install:apt']);
    expect(find.byType(ModuleDetail), findsNothing);
  });

  testWidgets('os botões do painel chamam as mesmas ações', (t) async {
    final a = await _home(t);
    await t.tap(
      find.descendant(of: _card('Cheatsheets'), matching: find.text('helpers')),
    );
    await t.pumpAndSettle();
    await t.tap(
      find.descendant(
        of: find.byType(ModuleDetail),
        matching: find.text('Instalar'),
      ),
    );
    expect(a.calls, ['install:helpers']);
  });

  testWidgets('X e Esc fecham o painel', (t) async {
    await _home(t);
    await _openZsh(t);
    await t.tap(find.byTooltip('Fechar detalhe'));
    await t.pumpAndSettle();
    expect(find.byType(ModuleDetail), findsNothing);
    await _openZsh(t);
    expect(find.byType(ModuleDetail), findsOneWidget);
    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    await t.pumpAndSettle();
    expect(find.byType(ModuleDetail), findsNothing);
  });

  testWidgets('em tela larga o painel ocupa a coluna do Atividade', (t) async {
    final open = ValueNotifier(true);
    await _home(t, activityOpen: open);
    expect(find.byType(ActivityPanel), findsOneWidget);
    await _openZsh(t);
    expect(find.byType(ActivityPanel), findsNothing);
    expect(t.getSize(find.byType(ModuleDetail)).width, kActivityPanelWidth);
    await t.tap(find.byTooltip('Fechar detalhe'));
    await t.pumpAndSettle();
    expect(find.byType(ActivityPanel), findsOneWidget);
    await _openZsh(t);
    await t.tap(find.byTooltip('Atividade'));
    await t.pumpAndSettle();
    expect(find.byType(ModuleDetail), findsNothing);
    expect(find.byType(ActivityPanel), findsOneWidget);
  });

  testWidgets('fechar o detalhe com Atividade fechada não a abre', (t) async {
    await _home(t);
    await _openZsh(t);
    await t.tap(find.byTooltip('Fechar detalhe'));
    await t.pumpAndSettle();
    expect(find.byType(ActivityPanel), findsNothing);
  });

  testWidgets('em tela estreita abre como página com botão voltar', (t) async {
    await _home(t, width: 600);
    await _openZsh(t);
    expect(find.byType(ModuleDetail), findsOneWidget);
    expect(t.getSize(find.byType(ModuleDetail)).width, 600);
    expect(find.byTooltip('Fechar detalhe'), findsNothing);
    await t.tap(find.byTooltip('Voltar'));
    await t.pumpAndSettle();
    expect(find.byType(ModuleDetail), findsNothing);
    expect(find.text('Instalar'), findsWidgets);
  });

  testWidgets('preexisting não mostra Remover nem com can_remove no JSON', (
    t,
  ) async {
    final j = jsonDecode(jsonEncode(_raw)) as Map<String, dynamic>;
    for (final m in j['modules'] as List) {
      if (m['id'] == 'vscode') m['can_remove'] = true;
    }
    final q = await controller(
      result: () => ProcessResult(1, 0, jsonEncode(j), ''),
    );
    await _home(t, q: q);
    expect(q.catalog!.byId('vscode')!.canRemove, isTrue);
    await t.tap(
      find.descendant(
        of: _card('Visual Studio Code'),
        matching: find.text('vscode'),
      ),
    );
    await t.pumpAndSettle();
    expect(
      find.text('Instalado fora do PowerTerminal: nada para remover aqui.'),
      findsOneWidget,
    );
    expect(_inDetail('Remover'), findsNothing);
  });

  group('ModuleDetail isolado', () {
    Future<void> pumpDetail(WidgetTester t, ModuleInfo m, CardStatus s) async {
      await t.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: SizedBox(
              width: 340,
              height: 900,
              child: ModuleDetail(
                module: m,
                status: s,
                catalog: _catalog,
                actions: RecordingActions(),
                onClose: () {},
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('mostra o progresso da operação em andamento', (t) async {
      await pumpDetail(
        t,
        _catalog.byId('helpers')!,
        const CardStatus(
          phase: CardPhase.running,
          kind: OpKind.install,
          step: 'Baixando',
          progress: 0.4,
        ),
      );
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.text('Baixando'), findsOneWidget);
      expect(find.text('40%'), findsOneWidget);
      expect(find.text('Instalar'), findsNothing);
      expect(find.text('Instalando'), findsOneWidget);
    });

    testWidgets('falha mostra o erro e Ver log', (t) async {
      await pumpDetail(
        t,
        _catalog.byId('helpers')!,
        const CardStatus(phase: CardPhase.failed, error: 'quebrou'),
      );
      expect(find.text('quebrou'), findsOneWidget);
      expect(find.text('Ver log'), findsOneWidget);
    });

    testWidgets('seções vazias não aparecem e kind desconhecido tem ícone', (
      t,
    ) async {
      final m = ModuleInfo(
        id: 'x',
        name: 'X',
        category: 'dev',
        description: 'd',
        minutes: 1,
        mb: 1,
        sudo: false,
        editor: false,
        canUpdate: false,
        canRemove: false,
        needs: const [],
        state: ModuleState.available,
        provides: const [ModuleItem(kind: 'qualquer', value: 'v')],
      );
      await pumpDetail(t, m, const CardStatus());
      expect(find.text('O que instala'), findsOneWidget);
      expect(find.text('Depende de'), findsNothing);
      expect(find.text('Pré-requisitos'), findsNothing);
      expect(find.text('Registrado pelo PowerTerminal'), findsNothing);
      expect(find.byIcon(itemIcon('qualquer')), findsOneWidget);
    });
  });
}
