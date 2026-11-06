import 'dart:io';

import '../cli/cli.dart';

class SessionEnder {
  SessionEnder({ProcessRunner? runner, Map<String, String>? environment})
    : _runner = runner ?? _run,
      _env = environment ?? Platform.environment;

  final ProcessRunner _runner;
  final Map<String, String> _env;

  static Future<ProcessResult> _run(
    String exe,
    List<String> args, {
    String? workingDirectory,
    Map<String, String>? environment,
  }) => Process.run(exe, args);

  Future<bool> logout() async {
    if (await _ok('gnome-session-quit', const ['--logout', '--no-prompt'])) {
      return true;
    }
    final id = _env['XDG_SESSION_ID'];
    if (id == null || id.isEmpty) return false;
    return _ok('loginctl', ['terminate-session', id]);
  }

  Future<bool> _ok(String exe, List<String> args) async {
    try {
      return (await _runner(exe, args)).exitCode == 0;
    } on ProcessException {
      return false;
    }
  }
}
