@Timeout(Duration(seconds: 30))
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:powerterminal_launcher/cli/cli.dart';
import 'package:powerterminal_launcher/model/catalog.dart';
import 'package:powerterminal_launcher/queue/queue_controller.dart';
import 'package:powerterminal_launcher/session/pty_shell.dart';

final _support = '${Directory.current.path}/test/support';
final _fixture = File('test/fixtures/catalog.json').readAsStringSync();
const _password = 'segredo';

void main() {
  late Directory state;
  QueueController? controller;

  setUp(() async {
    state = await Directory.systemTemp.createTemp('pn_sudo_flow_');
  });

  tearDown(() async {
    final q = controller;
    controller = null;
    if (q != null) {
      await q.whenIdle();
      q.dispose();
    }
    await state.delete(recursive: true);
  });

  Future<QueueController> make({bool nvimPresent = false}) async {
    final json = jsonDecode(_fixture) as Map<String, dynamic>;
    if (nvimPresent) {
      for (final m in json['modules'] as List) {
        if (m['id'] == 'nvim') m['state'] = 'installed';
      }
    }
    final body = jsonEncode(json);
    final catalog = Catalog.fromJson(json);
    final env = {
      'PATH': '$_support/fake_bin:${Platform.environment['PATH']}',
      'FAKE_SUDO_STATE': state.path,
      'FAKE_SUDO_PASSWORD': _password,
      'FAKE_SUDO_MODULES': [
        for (final m in catalog.modules)
          if (m.sudo) m.id,
      ].join(','),
      'FAKE_NEEDS': [
        for (final m in catalog.modules)
          if (m.needs.isNotEmpty) '${m.id}:${m.needs.join(',')}',
      ].join(';'),
    };
    final q = controller = QueueController(
      cli: Cli(
        '$_support/fake_cli',
        runner: (exe, args, {workingDirectory, environment}) async =>
            ProcessResult(1, 0, body, ''),
      ),
      shellFactory: () =>
          PtyShell.start(workingDirectory: state.path, environment: env),
      repoDir: '$_support/fake_cli',
      eventsDir: Directory('${state.path}/events'),
    );
    await q.refresh();
    return q;
  }

  Future<(bool, int)> install(QueueController q, String id) async {
    var asked = 0;
    final ok = await q.enqueue(
      [QueueItem(id, OpKind.install)],
      askPassword: ({error}) async {
        asked++;
        return _password;
      },
    );
    await q.whenIdle();
    return (ok, asked);
  }

  void expectSuccess(QueueController q, String id) {
    final s = q.status(id);
    expect(s.error, isNull, reason: q.log.join('\n'));
    expect(s.phase, CardPhase.idle);
  }

  test('helpers sozinho não pede senha e instala', () async {
    final q = await make();
    final (ok, asked) = await install(q, 'helpers');
    expectSuccess(q, 'helpers');
    expect(ok, isTrue);
    expect(asked, 0);
  });

  test('nvim pede a senha e instala', () async {
    final q = await make();
    final (ok, asked) = await install(q, 'nvim');
    expectSuccess(q, 'nvim');
    expect(ok, isTrue);
    expect(asked, 1);
  });

  test('astronvim com nvim presente pede a senha pelo fecho', () async {
    final q = await make(nvimPresent: true);
    final (ok, asked) = await install(q, 'astronvim');
    expectSuccess(q, 'astronvim');
    expect(ok, isTrue);
    expect(asked, 1);
  });
}
