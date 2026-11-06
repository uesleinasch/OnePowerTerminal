import 'dart:async';
import 'dart:io';

import 'package:powerterminal_launcher/session/pty_shell.dart';

class FakeShell implements ShellSession {
  FakeShell({
    this.results = const {},
    this.events = const {},
    List<SudoResult> sudo = const [SudoResult.ok],
    this.onRun,
    this.onUnlock,
  }) : _sudo = List.of(sudo);

  final Map<String, RunResult> results;
  final Map<String, List<String>> events;
  final List<SudoResult> _sudo;
  final Future<void> Function(String command)? onRun;
  final Future<void> Function()? onUnlock;

  final runs = <String>[];
  final passwords = <String>[];
  var closed = 0;
  final _out = StreamController<String>.broadcast(sync: true);
  Future<void> _tail = Future.value();

  void emit(String line) => _out.add(line);

  Future<T> _serial<T>(Future<T> Function() body) {
    final result = _tail.then((_) {
      if (closed > 0) throw StateError('A sessão do shell foi encerrada.');
      return body();
    });
    _tail = result.then<void>((_) {}, onError: (_) {});
    return result;
  }

  @override
  Stream<String> get output => _out.stream;

  @override
  Future<SudoResult> unlockSudo(String password) => _serial(() async {
    passwords.add(password);
    await onUnlock?.call();
    return _sudo.length > 1 ? _sudo.removeAt(0) : _sudo.first;
  });

  @override
  Future<RunResult> run(String commandLine) => _serial(() async {
    runs.add(commandLine);
    final target = RegExp(r"3>'([^']*)'").firstMatch(commandLine)?[1];
    final key = events.keys.where(commandLine.contains).firstOrNull;
    if (target != null && key != null) {
      File(target).writeAsStringSync(
        events[key]!.map((l) => '$l\n').join(),
        mode: FileMode.append,
      );
    }
    await onRun?.call(commandLine);
    final rKey = results.keys.where(commandLine.contains).firstOrNull;
    return rKey == null ? const RunResult(0, false) : results[rKey]!;
  });

  @override
  Future<void> close() async {
    closed++;
  }
}
