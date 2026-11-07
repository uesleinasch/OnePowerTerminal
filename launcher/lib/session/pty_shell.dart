import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'text_clean.dart';

const kSudoPrompt = '__PN_SUDO__';
const kRcMarker = '__PN_RC__';

enum SudoResult { ok, wrongPassword, notAllowed }

class RunResult {
  const RunResult(this.exitCode, this.sudoPromptSeen);
  final int exitCode;
  final bool sudoPromptSeen;
}

abstract class ShellSession {
  Stream<String> get output;
  Future<SudoResult> unlockSudo(String password);
  Future<RunResult> run(String commandLine);
  Future<void> close();
}

String actionCommandLine({
  required String repoDir,
  required List<String> args,
  required String eventsFile,
}) =>
    'cd -- ${shQuote(repoDir)} && ./bin/powerterminal '
    '${args.map(shQuote).join(' ')} --events-fd 3 3>${shQuote(eventsFile)}';

sealed class ScanHit {
  const ScanHit();
}

class OutputLine extends ScanHit {
  const OutputLine(this.text);
  final String text;
}

class RcMarker extends ScanHit {
  const RcMarker(this.code);
  final int code;
}

class SudoPrompt extends ScanHit {
  const SudoPrompt();
}

final _rcLine = RegExp('^(.*)$kRcMarker (\\d{1,3})\$');
final _controlChars = RegExp(r'[\x00-\x1F\x7F]');

class MarkerScanner {
  static const _maxPartial = 64 * 1024;
  static const _keptTail = 32;

  var _buffer = '';

  static String _lineText(String raw) {
    var end = raw.length;
    while (end > 0 && raw.codeUnitAt(end - 1) == 13) {
      end--;
    }
    final line = raw.substring(0, end);
    return cleanTerminalText(line.substring(line.lastIndexOf('\r') + 1));
  }

  List<ScanHit> feed(String chunk) {
    _buffer += chunk;
    final hits = <ScanHit>[];
    while (true) {
      final prompt = _buffer.indexOf(kSudoPrompt);
      final nl = _buffer.indexOf('\n');
      if (prompt >= 0 && (nl < 0 || prompt < nl)) {
        _buffer =
            _buffer.substring(0, prompt) +
            _buffer.substring(prompt + kSudoPrompt.length);
        hits.add(const SudoPrompt());
        continue;
      }
      if (nl < 0) {
        if (_buffer.length > _maxPartial) {
          var cut = _buffer.length - _keptTail;
          if (_buffer.codeUnitAt(cut - 1) & 0xFC00 == 0xD800) cut--;
          hits.add(OutputLine(_lineText(_buffer.substring(0, cut))));
          _buffer = _buffer.substring(cut);
        }
        return hits;
      }
      final line = _lineText(_buffer.substring(0, nl));
      _buffer = _buffer.substring(nl + 1);
      final m = _rcLine.firstMatch(line);
      if (m == null) {
        hits.add(OutputLine(line));
        continue;
      }
      if (m[1]!.isNotEmpty) hits.add(OutputLine(m[1]!));
      hits.add(RcMarker(int.parse(m[2]!)));
    }
  }
}

class PtyShell implements ShellSession {
  PtyShell._(this._proc) {
    _proc.stdout
        .transform(const Utf8Decoder(allowMalformed: true))
        .listen(_onChunk, onDone: _onExit);
    _proc.stderr.drain<void>().ignore();
    _proc.stdin.done.ignore();
  }

  final Process _proc;
  final _scanner = MarkerScanner();
  final _output = StreamController<String>.broadcast(sync: true);
  Future<void> _queue = Future.value();
  Completer<int>? _rc;
  void Function()? _onPrompt;
  var _ready = false;
  var _exited = false;
  Future<void>? _closing;

  static Future<PtyShell> start({
    required String workingDirectory,
    Map<String, String> environment = const {},
  }) async {
    final proc = await Process.start(
      'script',
      const ['-qfec', 'bash --noprofile --norc', '/dev/null'],
      workingDirectory: workingDirectory,
      environment: {
        ...environment,
        'SUDO_PROMPT': kSudoPrompt,
        'INPUTRC': '/dev/null',
        'HISTFILE': '/dev/null',
        'PS1': '',
        'PS2': '',
        'TERM': 'dumb',
        'POWERTERMINAL_UI': 'text',
        'LC_ALL': 'C.UTF-8',
      },
    );
    final shell = PtyShell._(proc);
    proc.stdin.write('stty -echo\n');
    try {
      // Sem o trap, o bash interativo aborta o resto da linha quando o
      // comando morre de SIGINT, e o marcador de rc nunca chegaria.
      await shell._serial(() => shell._exec('trap : INT', (_) {}));
    } catch (_) {
      proc.kill(ProcessSignal.sigkill);
      rethrow;
    }
    shell._ready = true;
    return shell;
  }

  @override
  Stream<String> get output => _output.stream;

  @override
  Future<RunResult> run(String commandLine) => _serial(() async {
    final (code, prompts) = await _exec(commandLine, (_) => _interrupt());
    return RunResult(code, prompts > 0);
  });

  @override
  Future<SudoResult> unlockSudo(
    String password, {
    Duration timeout = const Duration(seconds: 20),
  }) => _serial(() async {
    var timedOut = false;
    Timer? timer;
    void arm() {
      timer?.cancel();
      timer = Timer(timeout, () {
        timedOut = true;
        _interrupt();
      });
    }

    arm();
    try {
      final (code, prompts) = await _exec('sudo -v', (n) {
        arm();
        if (n == 1) {
          _proc.stdin.add([...utf8.encode(password), 10]);
        } else {
          _interrupt();
        }
      });
      if (timedOut) return SudoResult.notAllowed;
      if (prompts > 1) return SudoResult.wrongPassword;
      return code == 0 ? SudoResult.ok : SudoResult.notAllowed;
    } finally {
      timer?.cancel();
    }
  });

  @override
  Future<void> close() => _closing ??= _shutdown();

  Future<void> _shutdown() async {
    const grace = Duration(seconds: 3);
    var idle = await _settles(grace);
    if (!idle && !_exited) {
      _interrupt();
      idle = await _settles(const Duration(seconds: 1));
    }
    if (idle && !_exited) {
      try {
        await _exec('sudo -k', (_) => _interrupt()).timeout(grace);
        _proc.stdin.write('exit\n');
        await _proc.exitCode.timeout(grace);
      } catch (_) {}
    }
    if (!_exited) _proc.kill(ProcessSignal.sigkill);
    await _proc.exitCode;
    if (!_output.isClosed) await _output.close();
  }

  Future<T> _serial<T>(Future<T> Function() body) {
    if (_closing != null) {
      return Future.error(StateError('A sessão do shell foi encerrada.'));
    }
    final result = _queue.then(
      (_) => _closing == null
          ? body()
          : throw StateError('A sessão do shell foi encerrada.'),
    );
    _queue = result.then<void>((_) {}, onError: (_) {});
    return result;
  }

  Future<bool> _settles(Duration limit) async {
    try {
      await _queue.timeout(limit);
      return true;
    } on TimeoutException {
      return false;
    }
  }

  void _interrupt() => _proc.stdin.add(const [3]);

  Future<(int, int)> _exec(String cmd, void Function(int n) onPrompt) async {
    if (cmd.contains(_controlChars)) {
      throw ArgumentError.value(
        cmd,
        'commandLine',
        'não pode ter quebra de linha nem caractere de controle',
      );
    }
    if (_exited) throw StateError('O shell da sessão terminou.');
    final rc = _rc = Completer<int>();
    var prompts = 0;
    _onPrompt = () => onPrompt(++prompts);
    _proc.stdin.write(
      "eval ${shQuote(cmd)}; printf '__PN_%s__ %d\\n' RC \$?\n",
    );
    try {
      return (await rc.future, prompts);
    } finally {
      _rc = null;
      _onPrompt = null;
    }
  }

  void _onChunk(String chunk) {
    for (final hit in _scanner.feed(chunk)) {
      switch (hit) {
        case OutputLine(:final text):
          if (_ready && !_output.isClosed) _output.add(text);
        case SudoPrompt():
          _onPrompt?.call();
        case RcMarker(:final code):
          final rc = _rc;
          if (rc != null && !rc.isCompleted) rc.complete(code);
      }
    }
  }

  void _onExit() {
    _exited = true;
    if (!_output.isClosed) _output.close().ignore();
    final rc = _rc;
    if (rc != null && !rc.isCompleted) {
      rc.completeError(StateError('O shell da sessão terminou.'));
    }
  }
}
