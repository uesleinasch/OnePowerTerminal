@Timeout(Duration(seconds: 10))
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:powerterminal_launcher/cli/cli.dart';
import 'package:powerterminal_launcher/cli/events.dart';
import 'package:powerterminal_launcher/model/catalog.dart';
import 'package:powerterminal_launcher/session/event_tail.dart';
import 'package:powerterminal_launcher/session/pty_shell.dart';

final _support = '${Directory.current.path}/test/support';
final _fakeBin = '$_support/fake_bin';
final _fakeCli = '$_support/fake_cli';

void main() {
  group('MarkerScanner', () {
    test('marcador de rc partido entre dois chunks', () {
      final s = MarkerScanner();
      expect(s.feed('__PN_R'), isEmpty);
      final hits = s.feed('C__ 0\r\n');
      expect(hits.single, isA<RcMarker>().having((h) => h.code, 'code', 0));
    });

    test('prompt do sudo partido e sem quebra de linha', () {
      final s = MarkerScanner();
      expect(s.feed('__PN_SU'), isEmpty);
      expect(s.feed('DO__').single, isA<SudoPrompt>());
    });

    test('linhas limpas e marcador colado em saída sem \\n', () {
      final s = MarkerScanner();
      final hits = s.feed('\x1B[32mok\x1B[0m\r\nparcial');
      expect(hits.single, isA<OutputLine>().having((h) => h.text, 't', 'ok'));
      final rest = s.feed('__PN_RC__ 7\r\n');
      expect(rest, hasLength(2));
      expect(rest[0], isA<OutputLine>().having((h) => h.text, 't', 'parcial'));
      expect(rest[1], isA<RcMarker>().having((h) => h.code, 'code', 7));
    });

    test('texto depois do prompt continua na linha', () {
      final s = MarkerScanner();
      final hits = s.feed('__PN_SUDO__\r\nSorry, try again.\r\n__PN_SUDO__');
      expect(hits.map((h) => h.runtimeType).toList(), [
        SudoPrompt,
        OutputLine,
        OutputLine,
        SudoPrompt,
      ]);
      expect((hits[2] as OutputLine).text, 'Sorry, try again.');
    });

    test('UTF-8 multibyte não depende do scanner', () {
      final s = MarkerScanner();
      expect((s.feed('ação\n').single as OutputLine).text, 'ação');
    });
  });

  test('actionCommandLine', () {
    expect(
      actionCommandLine(
        repoDir: "/r/a b'c",
        args: ['install', '--module', 'zsh,x y'],
        eventsFile: '/t/ev.jsonl',
      ),
      "cd -- '/r/a b'\\''c' && ./bin/powerterminal 'install' '--module' "
      "'zsh,x y' --events-fd 3 3>'/t/ev.jsonl'",
    );
  });

  group('tailEvents', () {
    late Directory dir;
    setUp(() async => dir = await Directory.systemTemp.createTemp('pn_tail_'));
    tearDown(() => dir.delete(recursive: true));

    test('linha parcial espera o \\n e stop faz a última leitura', () async {
      final f = File('${dir.path}/ev.jsonl');
      final stop = Completer<void>();
      final got = <CliEvent>[];
      final finished = tailEvents(f, stop.future).forEach(got.add);
      await Future<void>.delayed(const Duration(milliseconds: 150));
      f.writeAsStringSync('{"event":"note","module":"a","text":"t"}\n{"ev');
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(got.single, isA<Note>());
      f.writeAsStringSync(
        'ent":"done","ok":["a"],"failed":[]}\n',
        mode: FileMode.append,
      );
      stop.complete();
      await finished;
      expect(got, hasLength(2));
      expect((got[1] as Done).ok, ['a']);
    });
  });

  group('PtyShell', () {
    late Directory state;
    PtyShell? shell;
    StreamSubscription<String>? sub;
    late List<String> lines;

    setUp(() async {
      state = await Directory.systemTemp.createTemp('pn_pty_');
      lines = [];
    });

    tearDown(() async {
      await shell?.close();
      shell = null;
      await sub?.cancel();
      sub = null;
      await state.delete(recursive: true);
    });

    Future<PtyShell> start({
      String password = 'segredo',
      Map<String, String> extra = const {},
    }) async {
      final s = await PtyShell.start(
        workingDirectory: state.path,
        environment: {
          'PATH': '$_fakeBin:${Platform.environment['PATH']}',
          'FAKE_SUDO_STATE': state.path,
          'FAKE_SUDO_PASSWORD': password,
          ...extra,
        },
      );
      sub = s.output.listen(lines.add);
      return shell = s;
    }

    String action(String module, String eventsFile) => actionCommandLine(
      repoDir: _fakeCli,
      args: Cli.actionArgs(OpKind.install, [module]),
      eventsFile: eventsFile,
    );

    test('senha certa libera o sudo e não aparece na saída', () async {
      final s = await start();
      expect(await s.unlockSudo('segredo'), SudoResult.ok);
      expect(File('${state.path}/ticket').existsSync(), isTrue);
      expect(lines.where((l) => l.contains('segredo')), isEmpty);
      expect(lines.where((l) => l.contains('__PN_')), isEmpty);
      expect(await s.unlockSudo('qualquer'), SudoResult.ok);
    });

    test('senha com especiais chega intacta', () async {
      const pw = 'pa ss\'"\$\\é';
      final s = await start(password: pw);
      expect(await s.unlockSudo(pw), SudoResult.ok);
    });

    test('senha errada e a sessão continua utilizável', () async {
      final s = await start();
      expect(await s.unlockSudo('errada'), SudoResult.wrongPassword);
      expect(File('${state.path}/ticket').existsSync(), isFalse);
      expect((await s.run('true')).exitCode, 0);
    });

    test('usuário fora do sudoers', () async {
      final s = await start(extra: {'FAKE_SUDO_DENY': '1'});
      expect(await s.unlockSudo('segredo'), SudoResult.notAllowed);
    });

    test('rc do comando', () async {
      final s = await start();
      final r = await s.run('(exit 3)');
      expect(r.exitCode, 3);
      expect(r.sudoPromptSeen, isFalse);
    });

    test('prompt do sudo no meio da operação manda Ctrl-C', () async {
      final s = await start();
      final r = await s.run(action('needsudo', '${state.path}/ev.jsonl'));
      expect(r.sudoPromptSeen, isTrue);
      expect(r.exitCode, isNot(0));
      expect((await s.run('true')).exitCode, 0);
    });

    test('com ticket a operação que pede sudo segue sem prompt', () async {
      final s = await start();
      expect(await s.unlockSudo('segredo'), SudoResult.ok);
      final r = await s.run(action('needsudo', '${state.path}/ev.jsonl'));
      expect(r.sudoPromptSeen, isFalse);
      expect(r.exitCode, 0);
    });

    Future<(RunResult, List<CliEvent>)> runWithEvents(
      PtyShell s,
      String module,
    ) async {
      final f = File('${state.path}/$module.jsonl');
      final stop = Completer<void>();
      final events = tailEvents(f, stop.future).toList();
      final r = await s.run(action(module, f.path));
      stop.complete();
      return (r, await events);
    }

    test('eventos da CLI e saída limpa', () async {
      final s = await start();
      final (r, ev) = await runWithEvents(s, 'zsh');
      expect(r.exitCode, 0);
      expect(ev.map((e) => e.runtimeType).toList(), [
        ModuleBegin,
        Step,
        Step,
        ModuleEnd,
        Done,
      ]);
      final steps = ev.whereType<Step>().toList();
      expect([steps[0].n, steps[0].m, steps[1].n], [1, 2, 2]);
      expect((ev[3] as ModuleEnd).ok, isTrue);
      expect(lines, contains('==> install zsh'));
      expect(lines, contains('pronto'));
      expect(
        lines.where((l) => l.contains('\x1B') || l.contains('\r')),
        isEmpty,
      );
    });

    test('CLI que morre sem done', () async {
      final s = await start();
      final (r, ev) = await runWithEvents(s, 'boom');
      expect(r.exitCode, 2);
      expect(ev.single, isA<ModuleBegin>());
    });

    test('note e session_restart', () async {
      final s = await start();
      final (r, ev) = await runWithEvents(s, 'restart');
      expect(r.exitCode, 0);
      expect(ev.whereType<Note>(), hasLength(1));
      expect(ev.whereType<SessionRestart>(), hasLength(1));
      expect(ev.last, isA<Done>());
    });

    test('run concorrente espera o anterior', () async {
      final s = await start();
      final rs = await Future.wait([
        s.run('sleep 0.3; echo primeiro; (exit 4)'),
        s.run('echo segundo; (exit 5)'),
      ]);
      expect(rs.map((r) => r.exitCode), [4, 5]);
      expect(lines.where((l) => l == 'primeiro' || l == 'segundo'), [
        'primeiro',
        'segundo',
      ]);
    });

    test('close não trava atrás de um comando preso', () async {
      final s = await start();
      final stuck = s.run('sleep 60');
      final failed = expectLater(stuck, throwsStateError);
      await Future<void>.delayed(const Duration(milliseconds: 200));
      await s.close();
      await failed;
      await expectLater(s.run('true'), throwsStateError);
    });
  });
}
