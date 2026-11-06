import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:powerterminal_launcher/cli/cli.dart';
import 'package:powerterminal_launcher/model/catalog.dart';
import 'package:powerterminal_launcher/queue/queue_controller.dart';
import 'package:powerterminal_launcher/session/pty_shell.dart';
import 'package:powerterminal_launcher/system/session_ender.dart';

import 'support/fake_shell.dart';

final _fixture = File('test/fixtures/catalog.json').readAsStringSync();

void main() {
  late Directory tmp;
  late int catalogCalls;
  late FakeShell shell;
  late int factoryCalls;
  late List<FakeShell> created;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('qc_');
    catalogCalls = 0;
    factoryCalls = 0;
    created = [];
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  Future<QueueController> make(
    FakeShell s, {
    List<FakeShell> next = const [],
    Future<void> Function()? factoryHook,
  }) async {
    shell = s;
    final all = [s, ...next];
    final cli = Cli(
      '/repo',
      runner: (exe, args, {workingDirectory, environment}) async {
        catalogCalls++;
        return ProcessResult(1, 0, _fixture, '');
      },
    );
    final q = QueueController(
      cli: cli,
      shellFactory: () async {
        await factoryHook?.call();
        final i = factoryCalls++;
        final sh = all[i < all.length ? i : all.length - 1];
        created.add(sh);
        shell = sh;
        return sh;
      },
      repoDir: '/repo',
      eventsDir: Directory('${tmp.path}/events'),
    );
    await q.refresh();
    catalogCalls = 0;
    return q;
  }

  QueueItem inst(String id) => QueueItem(id, OpKind.install);

  Future<void> until(bool Function() cond) async {
    for (var i = 0; i < 200 && !cond(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(cond(), isTrue, reason: 'condição não atingida');
  }

  test('módulo sem sudo não pede senha, termina idle e faz refresh', () async {
    final q = await make(FakeShell());
    var asked = 0;
    final ok = await q.enqueue(
      [inst('helpers')],
      askPassword: ({error}) async {
        asked++;
        return 'x';
      },
    );
    await q.whenIdle();
    expect(ok, isTrue);
    expect(asked, 0);
    expect(q.status('helpers').phase, CardPhase.idle);
    expect(catalogCalls, 1);
    expect(shell.runs.single, contains("'install' '--module' 'helpers'"));
    expect(q.log, contains('[launcher] instalar helpers'));
  });

  test('senha cancelada não enfileira nada', () async {
    final q = await make(FakeShell());
    var asked = 0;
    final ok = await q.enqueue(
      [inst('nvim')],
      askPassword: ({error}) async {
        asked++;
        return null;
      },
    );
    expect(ok, isFalse);
    expect(asked, 1);
    expect(q.pending, isEmpty);
    expect(q.current, isNull);
    expect(shell.runs, isEmpty);
    expect(shell.closed, 1);
  });

  test('senha errada e depois certa chama askPassword duas vezes', () async {
    final q = await make(
      FakeShell(sudo: [SudoResult.wrongPassword, SudoResult.ok]),
    );
    final errors = <String?>[];
    final ok = await q.enqueue(
      [inst('nvim')],
      askPassword: ({error}) async {
        errors.add(error);
        return 'pw';
      },
    );
    await q.whenIdle();
    expect(ok, isTrue);
    expect(errors, [null, 'Senha incorreta. Tente de novo.']);
    expect(q.log.join('\n'), isNot(contains('pw')));
  });

  test('notAllowed para, registra no log e devolve false', () async {
    final q = await make(FakeShell(sudo: [SudoResult.notAllowed]));
    var asked = 0;
    final ok = await q.enqueue(
      [inst('nvim')],
      askPassword: ({error}) async {
        asked++;
        return 'pw';
      },
    );
    expect(ok, isFalse);
    expect(asked, 1);
    expect(q.log, contains('Sua conta não pode usar sudo nesta máquina.'));
    expect(q.pending, isEmpty);
  });

  test('dois itens com sudo pedem uma senha só; fecha ao esvaziar', () async {
    var asked = 0;
    late QueueController q;
    final during = <bool>[];
    final s = FakeShell(onRun: (_) async => during.add(q.sudoUnlocked));
    q = await make(s);
    await q.enqueue(
      [inst('nvim'), inst('fonts')],
      askPassword: ({error}) async {
        asked++;
        return 'pw';
      },
    );
    await q.whenIdle();
    expect(asked, 1);
    expect(shell.passwords, ['pw']);
    expect(during, [true, true]);
    expect(q.sudoUnlocked, isFalse);
    expect(shell.closed, 1);
    expect(factoryCalls, 1);
  });

  test('Step vira progresso e texto', () async {
    final gate = Completer<void>();
    final q = await make(
      FakeShell(
        events: {
          'helpers': [
            '{"event":"step","module":"helpers","text":"Baixando","n":1,"m":4}',
          ],
        },
        onRun: (_) => gate.future,
      ),
    );
    await q.enqueue([inst('helpers')], askPassword: ({error}) async => null);
    for (var i = 0; i < 40; i++) {
      if (q.status('helpers').step != null) break;
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    final st = q.status('helpers');
    gate.complete();
    expect(st.phase, CardPhase.running);
    expect(st.step, 'Baixando');
    expect(st.progress, 0.25);
    await q.whenIdle();
  });

  test('rc 2 vira failed e o próximo item roda', () async {
    final q = await make(
      FakeShell(results: {"'helpers'": const RunResult(2, false)}),
    );
    await q.enqueue([
      inst('helpers'),
      inst('theme'),
    ], askPassword: ({error}) async => null);
    await q.whenIdle();
    expect(q.status('helpers').phase, CardPhase.failed);
    expect(q.status('helpers').error, 'Falhou. Veja o log.');
    expect(q.status('theme').phase, CardPhase.idle);
    expect(shell.runs.length, 2);
  });

  test('ModuleEnd ok:false com rc 0 também falha', () async {
    final q = await make(
      FakeShell(
        events: {
          'helpers': [
            '{"event":"module_end","module":"helpers","action":"install","ok":false}',
          ],
        },
      ),
    );
    await q.enqueue([inst('helpers')], askPassword: ({error}) async => null);
    await q.whenIdle();
    expect(q.status('helpers').phase, CardPhase.failed);
  });

  test('sudoPromptSeen indica sessão do sudo expirada', () async {
    final q = await make(
      FakeShell(results: {"'helpers'": const RunResult(1, true)}),
    );
    await q.enqueue([inst('helpers')], askPassword: ({error}) async => null);
    await q.whenIdle();
    expect(q.status('helpers').error, 'A sessão do sudo expirou.');
  });

  test('SessionRestart acumula um por evento', () async {
    final q = await make(
      FakeShell(
        events: {
          'helpers': [
            '{"event":"session_restart","module":"helpers","reason":"grupo docker"}',
            '{"event":"note","module":"helpers","text":"grupo docker"}',
          ],
          'theme': [
            '{"event":"session_restart","module":"theme","reason":"shell"}',
          ],
        },
      ),
    );
    await q.enqueue([
      inst('helpers'),
      inst('theme'),
    ], askPassword: ({error}) async => null);
    await q.whenIdle();
    expect(q.pendingRestarts.map((r) => '${r.module}:${r.reason}'), [
      'helpers:grupo docker',
      'theme:shell',
    ]);
    q.clearPendingRestarts();
    expect(q.pendingRestarts, isEmpty);
  });

  test('dequeue só remove pendente; id repetido é ignorado', () async {
    late QueueController q;
    QueueItem? during;
    final s = FakeShell(
      onRun: (cmd) async {
        if (!cmd.contains("'helpers'")) return;
        during = q.current;
        q.dequeue('helpers');
        q.dequeue('theme');
        expect(q.pending.map((i) => i.id), isNot(contains('theme')));
        expect(q.status('theme').phase, CardPhase.idle);
        await q.enqueue([
          inst('theme'),
          inst('helpers'),
        ], askPassword: ({error}) async => null);
      },
    );
    q = await make(s);
    await q.enqueue([
      inst('helpers'),
      inst('theme'),
      inst('helpers'),
    ], askPassword: ({error}) async => null);
    await q.whenIdle();
    expect(during?.id, 'helpers');
    expect(shell.runs.where((r) => r.contains("'helpers'")).length, 1);
    expect(shell.runs.where((r) => r.contains("'theme'")).length, 1);
    expect(q.status('theme').phase, CardPhase.idle);
  });

  test('linhas da sessão vão para o log e ele é limitado', () async {
    final gate = Completer<void>();
    final q = await make(FakeShell(onRun: (_) => gate.future));
    await q.enqueue([inst('helpers')], askPassword: ({error}) async => null);
    await until(() => shell.runs.isNotEmpty);
    shell.emit('olá');
    expect(q.log.last, 'olá');
    for (var i = 0; i < 5100; i++) {
      shell.emit('l$i');
    }
    expect(q.log.length, 5000);
    expect(q.log.last, 'l5099');
    gate.complete();
    await q.whenIdle();
  });

  test(
    'senha pedida com item sem sudo rodando: nvim usa a sessão liberada',
    () async {
      final gate = Completer<void>();
      final s1 = FakeShell(
        onRun: (c) => c.contains("'node'") ? gate.future : Future.value(),
        onUnlock: () => Future.delayed(const Duration(milliseconds: 60)),
      );
      final s2 = FakeShell();
      final q = await make(s1, next: [s2]);
      await q.enqueue([inst('node')], askPassword: ({error}) async => null);
      await until(() => s1.runs.isNotEmpty);
      final ok = q.enqueue([
        inst('nvim'),
      ], askPassword: ({error}) async => 'pw');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      gate.complete();
      expect(await ok, isTrue);
      await q.whenIdle();
      expect(s1.passwords, ['pw']);
      expect(s1.runs.where((r) => r.contains("'nvim'")).length, 1);
      expect(s2.runs, isEmpty);
      expect(factoryCalls, 1);
      expect(q.status('nvim').phase, CardPhase.idle);
      expect(s1.closed, 1);
    },
  );

  test('dispose com run preso não notifica nem abre nova sessão', () async {
    final gate = Completer<void>();
    final q = await make(FakeShell(onRun: (_) => gate.future));
    await q.enqueue([
      inst('helpers'),
      inst('theme'),
    ], askPassword: ({error}) async => null);
    await until(() => shell.runs.isNotEmpty);
    q.dispose();
    gate.complete();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(factoryCalls, 1);
    expect(shell.runs.length, 1);
    expect(q.pending, isEmpty);
    expect(shell.closed, 1);
  });

  test(
    'shellFactory que falha: com sudo devolve false, sem sudo falha o item',
    () async {
      var fail = true;
      final q = await make(
        FakeShell(),
        factoryHook: () async {
          if (fail) throw StateError('sem shell');
        },
      );
      final ok = await q.enqueue([
        inst('nvim'),
      ], askPassword: ({error}) async => 'pw');
      expect(ok, isFalse);
      expect(q.pending, isEmpty);
      await q.enqueue([inst('helpers')], askPassword: ({error}) async => null);
      await q.whenIdle();
      expect(q.status('helpers').phase, CardPhase.failed);
      fail = false;
      await q.enqueue([inst('helpers')], askPassword: ({error}) async => null);
      await q.whenIdle();
      expect(q.status('helpers').phase, CardPhase.idle);
      expect(q.status('helpers').error, isNull);
    },
  );

  test('unlockSudo que lança devolve false e fecha a sessão', () async {
    final q = await make(
      FakeShell(onUnlock: () async => throw StateError('morreu')),
    );
    final ok = await q.enqueue([
      inst('nvim'),
    ], askPassword: ({error}) async => 'pw');
    expect(ok, isFalse);
    expect(q.pending, isEmpty);
    expect(shell.closed, 1);
  });

  test('askPassword que lança fecha a sessão e relança', () async {
    final q = await make(FakeShell());
    await expectLater(
      q.enqueue([inst('nvim')], askPassword: ({error}) async => throw 'boom'),
      throwsA('boom'),
    );
    expect(shell.closed, 1);
    expect(q.pending, isEmpty);
  });

  test(
    'StateError no run derruba a sessão e o próximo item abre outra',
    () async {
      final s1 = FakeShell(
        onRun: (c) async {
          if (c.contains("'helpers'")) throw StateError('shell morreu');
        },
      );
      final s2 = FakeShell();
      final q = await make(s1, next: [s2]);
      await q.enqueue([
        inst('helpers'),
        inst('theme'),
      ], askPassword: ({error}) async => null);
      await q.whenIdle();
      expect(q.status('helpers').phase, CardPhase.failed);
      expect(q.status('theme').phase, CardPhase.idle);
      expect(factoryCalls, 2);
      expect(s2.runs.single, contains("'theme'"));
    },
  );

  test('falha é zerada por novo enqueue e por sucesso posterior', () async {
    final gate = Completer<void>();
    final q = await make(
      FakeShell(results: {"'helpers'": const RunResult(2, false)}),
      next: [FakeShell(onRun: (_) => gate.future)],
    );
    await q.enqueue([inst('helpers')], askPassword: ({error}) async => null);
    await q.whenIdle();
    expect(q.status('helpers').phase, CardPhase.failed);
    await q.enqueue([inst('helpers')], askPassword: ({error}) async => null);
    await until(() => q.status('helpers').phase == CardPhase.running);
    expect(q.status('helpers').error, isNull);
    gate.complete();
    await q.whenIdle();
    expect(q.status('helpers').phase, CardPhase.idle);
    expect(q.status('helpers').error, isNull);
  });

  test('refresh captura qualquer erro em catalogError', () async {
    final q = QueueController(
      cli: Cli(
        '/repo',
        runner: (exe, args, {workingDirectory, environment}) async =>
            throw const FormatException('x'),
      ),
      shellFactory: () async => FakeShell(),
      repoDir: '/repo',
      eventsDir: Directory('${tmp.path}/events'),
    );
    await q.refresh();
    expect(q.catalogError, isNotNull);
  });

  group('SessionEnder', () {
    test('gnome-session-quit ok não chama loginctl', () async {
      final calls = <String>[];
      final e = SessionEnder(
        runner: (exe, args, {workingDirectory, environment}) async {
          calls.add(exe);
          return ProcessResult(1, 0, '', '');
        },
        environment: {'XDG_SESSION_ID': '3'},
      );
      expect(await e.logout(), isTrue);
      expect(calls, ['gnome-session-quit']);
    });

    test('rc != 0 cai em loginctl terminate-session', () async {
      final calls = <String>[];
      final e = SessionEnder(
        runner: (exe, args, {workingDirectory, environment}) async {
          calls.add('$exe ${args.join(' ')}');
          return ProcessResult(1, exe == 'loginctl' ? 0 : 1, '', '');
        },
        environment: {'XDG_SESSION_ID': '3'},
      );
      expect(await e.logout(), isTrue);
      expect(calls.last, 'loginctl terminate-session 3');
    });

    test('sem XDG_SESSION_ID devolve false', () async {
      final e = SessionEnder(
        runner: (exe, args, {workingDirectory, environment}) async =>
            ProcessResult(1, 1, '', ''),
        environment: {},
      );
      expect(await e.logout(), isFalse);
    });
  });
}
