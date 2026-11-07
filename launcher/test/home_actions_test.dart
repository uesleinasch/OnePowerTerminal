import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:powerterminal_launcher/cli/cli.dart';
import 'package:powerterminal_launcher/queue/queue_controller.dart';
import 'package:powerterminal_launcher/system/session_ender.dart';
import 'package:powerterminal_launcher/theme/app_theme.dart';
import 'package:powerterminal_launcher/ui/home_actions_impl.dart';

import 'support/fake_shell.dart';

String _catalogJson({
  Map<String, String> states = const {},
  Set<String> sudo = const {},
}) {
  final c = jsonDecode(
    File('test/fixtures/catalog.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  for (final m in c['modules'] as List) {
    m['sudo'] = sudo.contains(m['id']);
    final s = states[m['id']];
    if (s != null) m['state'] = s;
  }
  return jsonEncode(c);
}

class _Rig {
  _Rig(this.shell, this.tmp, this.controller, this.actions, this.ender);

  final FakeShell shell;
  final Directory tmp;
  final QueueController controller;
  final HomeActionsImpl actions;
  final List<String> ender;
}

const restartEvent =
    '{"event":"session_restart","module":"helpers","reason":"grupo docker"}';

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('ha_'));
  tearDown(() => tmp.deleteSync(recursive: true));

  Future<_Rig> pumpRig(
    WidgetTester t, {
    Map<String, String> states = const {},
    FakeShell? shell,
    int enderExit = 0,
    Set<String> sudo = const {},
  }) async {
    final sh = shell ?? FakeShell();
    final cli = Cli(
      '/repo',
      runner: (exe, args, {workingDirectory, environment}) async =>
          ProcessResult(1, 0, _catalogJson(states: states, sudo: sudo), ''),
    );
    final controller = QueueController(
      cli: cli,
      shellFactory: () async => sh,
      repoDir: '/repo',
      eventsDir: Directory('${tmp.path}/events'),
    );
    final key = GlobalKey<NavigatorState>();
    final ender = <String>[];
    final actions = HomeActionsImpl(
      controller: controller,
      navigatorKey: key,
      sessionEnder: SessionEnder(
        environment: const {'XDG_SESSION_ID': '3'},
        runner: (exe, args, {workingDirectory, environment}) async {
          ender.add('$exe ${args.join(' ')}');
          return ProcessResult(1, enderExit, '', '');
        },
      ),
      onShowLog: () {},
    );
    await t.pumpWidget(
      MaterialApp(
        navigatorKey: key,
        theme: AppTheme.light(),
        home: const Scaffold(),
      ),
    );
    await t.runAsync(controller.refresh);
    addTearDown(() {
      actions.dispose();
      controller.dispose();
    });
    return _Rig(sh, tmp, controller, actions, ender);
  }

  Future<void> settle(WidgetTester t, QueueController c) async {
    for (var i = 0; i < 100; i++) {
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await t.pump(const Duration(milliseconds: 120));
      if (c.current == null && c.pending.isEmpty) {
        await t.runAsync(c.whenIdle);
        await t.pumpAndSettle();
        return;
      }
    }
    fail('fila não esvaziou');
  }

  List<String> modulesRun(FakeShell s) => [
    for (final r in s.runs)
      RegExp(r"'--module' '([^']+)'").firstMatch(r)?[1] ?? r,
  ];

  testWidgets('instalar astronvim com nvim ausente: sim enfileira nvim antes', (
    t,
  ) async {
    final rig = await pumpRig(t);
    rig.actions.install('astronvim');
    await t.pumpAndSettle();
    expect(find.text('AstroNvim depende de Neovim'), findsOneWidget);
    await t.tap(find.text('Instalar os 2'));
    await t.pumpAndSettle();
    await settle(t, rig.controller);
    expect(modulesRun(rig.shell), ['nvim', 'astronvim']);
  });

  testWidgets('Cancelar na dependência não enfileira nada', (t) async {
    final rig = await pumpRig(t);
    rig.actions.install('astronvim');
    await t.pumpAndSettle();
    await t.tap(find.text('Cancelar'));
    await t.pumpAndSettle();
    expect(rig.controller.pending, isEmpty);
    expect(rig.controller.current, isNull);
    expect(rig.shell.runs, isEmpty);
  });

  testWidgets('instalar sem dependência faltando não abre diálogo', (t) async {
    final rig = await pumpRig(t, states: {'nvim': 'installed'});
    rig.actions.install('astronvim');
    await t.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    await settle(t, rig.controller);
    expect(modulesRun(rig.shell), ['astronvim']);
  });

  testWidgets('installProfile dev sem editor pergunta e vscode não leva nvim', (
    t,
  ) async {
    final rig = await pumpRig(t, states: {'vscode': 'available'});
    rig.actions.installProfile('dev');
    await t.pumpAndSettle();
    expect(find.text('Qual editor?'), findsOneWidget);
    await t.tap(find.text('Visual Studio Code'));
    await t.pump();
    await t.tap(find.text('Continuar'));
    await t.pumpAndSettle();
    await settle(t, rig.controller);
    final run = modulesRun(rig.shell);
    expect(run, contains('vscode'));
    expect(run, isNot(contains('nvim')));
    expect(run, isNot(contains('astronvim')));
  });

  testWidgets('installProfile cancelando o editor não enfileira', (t) async {
    final rig = await pumpRig(t, states: {'vscode': 'available'});
    rig.actions.installProfile('dev');
    await t.pumpAndSettle();
    await t.tap(find.text('Cancelar'));
    await t.pumpAndSettle();
    expect(rig.controller.pending, isEmpty);
    expect(rig.shell.runs, isEmpty);
  });

  testWidgets('dev com vscode já presente não pergunta o editor', (t) async {
    final rig = await pumpRig(t);
    rig.actions.installProfile('dev');
    await t.pumpAndSettle();
    expect(find.text('Qual editor?'), findsNothing);
    await settle(t, rig.controller);
    expect(modulesRun(rig.shell), isNot(contains('vscode')));
  });

  testWidgets('módulo com sudo passa pela senha real e roda', (t) async {
    final rig = await pumpRig(t, sudo: {'nvim'});
    rig.actions.install('nvim');
    await t.pumpAndSettle();
    expect(find.text('Senha de administrador'), findsOneWidget);
    await t.enterText(find.byType(TextField), 'minha senha');
    await t.tap(find.text('Liberar'));
    await t.pumpAndSettle();
    await settle(t, rig.controller);
    expect(rig.shell.passwords, ['minha senha']);
    expect(modulesRun(rig.shell), ['nvim']);
  });

  testWidgets('diálogo de sessão espera a senha pendente e o fim da fila', (
    t,
  ) async {
    final rig = await pumpRig(
      t,
      sudo: {'nvim'},
      shell: FakeShell(
        events: {
          'helpers': [restartEvent],
        },
      ),
    );
    rig.actions.install('helpers');
    rig.actions.install('nvim');
    for (var i = 0; i < 20; i++) {
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await t.pump(const Duration(milliseconds: 120));
    }
    expect(rig.shell.runs, hasLength(1));
    expect(rig.controller.pendingRestarts, isNotEmpty);
    expect(find.text('Senha de administrador'), findsOneWidget);
    expect(find.text('Para concluir, encerre a sessão'), findsNothing);
    await t.enterText(find.byType(TextField), 'x');
    await t.tap(find.text('Liberar'));
    await t.pumpAndSettle();
    await settle(t, rig.controller);
    expect(modulesRun(rig.shell), ['helpers', 'nvim']);
    expect(find.text('Para concluir, encerre a sessão'), findsOneWidget);
    await t.tap(find.text('Depois'));
    await t.pumpAndSettle();
    expect(find.text('Para concluir, encerre a sessão'), findsNothing);
  });

  testWidgets('installProfile com editor já presente não pergunta', (t) async {
    final rig = await pumpRig(t);
    rig.actions.installProfile('minimal');
    await t.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    await settle(t, rig.controller);
    expect(modulesRun(rig.shell), ['apt', 'fonts', 'helpers']);
  });

  testWidgets('updateProfile atualiza só presentes com canUpdate', (t) async {
    final rig = await pumpRig(t);
    rig.actions.updateProfile('minimal');
    await settle(t, rig.controller);
    expect(modulesRun(rig.shell), ['zsh']);
    expect(rig.shell.runs.single, contains("'update'"));
  });

  testWidgets('remover enfileira remove com purgeData', (t) async {
    final rig = await pumpRig(t);
    rig.actions.remove('container');
    await t.pumpAndSettle();
    await t.tap(find.byType(CheckboxListTile));
    await t.pump();
    await t.tap(find.text('Remover'));
    await t.pumpAndSettle();
    await t.tap(find.text('Apagar tudo'));
    await t.pumpAndSettle();
    await settle(t, rig.controller);
    expect(rig.shell.runs.single, contains("'remove'"));
    expect(rig.shell.runs.single, contains('--purge-data'));
  });

  testWidgets('remover cancelado não enfileira', (t) async {
    final rig = await pumpRig(t);
    rig.actions.remove('helpers');
    await t.pumpAndSettle();
    await t.tap(find.text('Cancelar'));
    await t.pumpAndSettle();
    expect(rig.shell.runs, isEmpty);
  });

  testWidgets('fila com SessionRestart abre o diálogo uma vez; Depois limpa', (
    t,
  ) async {
    final rig = await pumpRig(
      t,
      shell: FakeShell(
        events: {
          'helpers': [restartEvent],
        },
      ),
    );
    rig.actions.install('helpers');
    await settle(t, rig.controller);
    expect(find.text('Para concluir, encerre a sessão'), findsOneWidget);
    expect(find.textContaining('grupo docker'), findsOneWidget);
    expect(find.textContaining('Cheatsheets'), findsOneWidget);
    await t.tap(find.text('Depois'));
    await t.pumpAndSettle();
    expect(find.text('Para concluir, encerre a sessão'), findsNothing);
    expect(rig.controller.pendingRestarts, isEmpty);
    expect(rig.ender, isEmpty);
  });

  testWidgets('Encerrar sessão agora chama o SessionEnder', (t) async {
    final rig = await pumpRig(
      t,
      shell: FakeShell(
        events: {
          'helpers': [restartEvent],
        },
      ),
    );
    rig.actions.install('helpers');
    await settle(t, rig.controller);
    await t.tap(find.text('Encerrar sessão agora'));
    await t.pumpAndSettle();
    expect(rig.ender, ['gnome-session-quit --logout --no-prompt']);
    expect(rig.controller.pendingRestarts, isEmpty);
  });

  testWidgets('falha ao encerrar mostra o aviso', (t) async {
    final rig = await pumpRig(
      t,
      shell: FakeShell(
        events: {
          'helpers': [restartEvent],
        },
      ),
      enderExit: 1,
    );
    rig.actions.install('helpers');
    await settle(t, rig.controller);
    await t.tap(find.text('Encerrar sessão agora'));
    await t.pumpAndSettle();
    expect(
      find.textContaining('Não consegui encerrar a sessão'),
      findsOneWidget,
    );
  });
}
