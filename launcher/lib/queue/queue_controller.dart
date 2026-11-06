import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../cli/cli.dart';
import '../cli/events.dart';
import '../model/catalog.dart';
import '../session/event_tail.dart';
import '../session/pty_shell.dart';

enum CardPhase { idle, queued, running, failed }

class CardStatus {
  CardStatus({this.phase = CardPhase.idle});

  CardPhase phase;
  OpKind? kind;
  String? step;
  double? progress;
  String? error;
}

class QueueItem {
  const QueueItem(this.id, this.kind, {this.purgeData = false});

  final String id;
  final OpKind kind;
  final bool purgeData;
}

class PendingRestart {
  const PendingRestart(this.module, this.reason);

  final String module, reason;
}

typedef PasswordPrompt = Future<String?> Function({String? error});
typedef ShellFactory = Future<ShellSession> Function();

class QueueController extends ChangeNotifier {
  QueueController({
    required this.cli,
    required this.shellFactory,
    required this.repoDir,
    required this.eventsDir,
  });

  static const _maxLog = 5000;

  final Cli cli;
  final ShellFactory shellFactory;
  final String repoDir;
  final Directory eventsDir;

  Catalog? catalog;
  Object? catalogError;

  final _pending = <QueueItem>[];
  final _statuses = <String, CardStatus>{};
  final _log = <String>[];
  final _restarts = <PendingRestart>[];
  QueueItem? _current;
  ShellSession? _session;
  StreamSubscription<String>? _outputSub;
  Future<void>? _loop;
  var _sudoUnlocked = false;
  var _opCounter = 0;

  List<QueueItem> get pending => List.unmodifiable(_pending);
  QueueItem? get current => _current;
  bool get sudoUnlocked => _sudoUnlocked;
  List<String> get log => List.unmodifiable(_log);
  List<PendingRestart> get pendingRestarts => List.unmodifiable(_restarts);

  CardStatus status(String id) => _statuses[id] ?? CardStatus();

  Future<void> whenIdle() async {
    while (_loop != null) {
      await _loop;
    }
  }

  Future<void> refresh() async {
    try {
      catalog = await cli.catalog();
      catalogError = null;
    } on CatalogError catch (e) {
      catalogError = e;
    }
    notifyListeners();
  }

  void clearPendingRestarts() {
    _restarts.clear();
    notifyListeners();
  }

  void dequeue(String id) {
    final before = _pending.length;
    _pending.removeWhere((i) => i.id == id);
    if (_pending.length == before) return;
    _statuses[id] = CardStatus();
    notifyListeners();
  }

  Future<bool> enqueue(
    List<QueueItem> items, {
    required PasswordPrompt askPassword,
  }) async {
    final fresh = <QueueItem>[];
    for (final i in items) {
      final known =
          _current?.id == i.id ||
          _pending.any((p) => p.id == i.id) ||
          fresh.any((p) => p.id == i.id);
      if (!known) fresh.add(i);
    }
    if (fresh.isEmpty) return true;

    final needsSudo = fresh.any((i) => catalog?.byId(i.id)?.sudo == true);
    if (needsSudo && !_sudoUnlocked) {
      if (!await _unlock(askPassword)) {
        await _closeIfIdle();
        return false;
      }
    }

    for (final i in fresh) {
      _statuses[i.id] = CardStatus(phase: CardPhase.queued)..kind = i.kind;
      _pending.add(i);
    }
    notifyListeners();
    _loop ??= _runLoop();
    return true;
  }

  Future<bool> _unlock(PasswordPrompt askPassword) async {
    final ShellSession session;
    try {
      session = await _ensureSession();
    } catch (e) {
      _addLog('[launcher] Não foi possível abrir o shell: $e');
      return false;
    }
    String? error;
    while (true) {
      final password = await askPassword(error: error);
      if (password == null) return false;
      final SudoResult result;
      try {
        result = await session.unlockSudo(password);
      } catch (e) {
        _addLog('[launcher] Falha ao liberar o sudo: $e');
        return false;
      }
      switch (result) {
        case SudoResult.ok:
          _sudoUnlocked = true;
          notifyListeners();
          return true;
        case SudoResult.wrongPassword:
          error = 'Senha incorreta. Tente de novo.';
        case SudoResult.notAllowed:
          _addLog('Sua conta não pode usar sudo nesta máquina.');
          return false;
      }
    }
  }

  Future<ShellSession> _ensureSession() async {
    final existing = _session;
    if (existing != null) return existing;
    final session = await shellFactory();
    _session = session;
    _outputSub = session.output.listen(_addLog);
    return session;
  }

  Future<void> _closeIfIdle() async {
    if (_loop != null || _pending.isNotEmpty) return;
    await _closeSession();
  }

  Future<void> _closeSession() async {
    final session = _session;
    final sub = _outputSub;
    _session = null;
    _outputSub = null;
    _sudoUnlocked = false;
    if (session != null) {
      try {
        await session.close();
      } catch (_) {}
    }
    await sub?.cancel();
    notifyListeners();
  }

  Future<void> _runLoop() async {
    try {
      while (true) {
        while (_pending.isNotEmpty) {
          final item = _pending.removeAt(0);
          _current = item;
          notifyListeners();
          await _runItem(item);
          _current = null;
          await refresh();
        }
        await _closeSession();
        if (_pending.isEmpty) break;
      }
    } finally {
      _current = null;
      _loop = null;
      notifyListeners();
    }
  }

  Future<void> _runItem(QueueItem item) async {
    final status = _statuses[item.id] = CardStatus(phase: CardPhase.running)
      ..kind = item.kind;
    _addLog('[launcher] ${_verb(item.kind)} ${item.id}');
    var failed = false;
    String? error;
    File? file;
    try {
      final session = await _ensureSession();
      await eventsDir.create(recursive: true);
      file = File('${eventsDir.path}/${++_opCounter}.jsonl');
      final stop = Completer<void>();
      final tail = tailEvents(file, stop.future).listen((e) {
        switch (e) {
          case Step(:final text, :final n, :final m):
            status
              ..step = text
              ..progress = (n != null && m != null && m > 0) ? n / m : null;
          case SessionRestart(:final module, :final reason):
            _restarts.add(PendingRestart(module, reason));
          case ModuleEnd(:final ok) when !ok:
            failed = true;
          default:
        }
        notifyListeners();
      });
      final RunResult result;
      try {
        result = await session.run(
          actionCommandLine(
            repoDir: repoDir,
            args: Cli.actionArgs(
              item.kind,
              [item.id],
              purgeData: item.purgeData,
            ),
            eventsFile: file.path,
          ),
        );
      } finally {
        stop.complete();
        await tail.asFuture<void>().catchError((_) {});
      }
      if (result.exitCode != 0) failed = true;
      if (failed) {
        error = result.sudoPromptSeen
            ? 'A sessão do sudo expirou.'
            : 'Falhou. Veja o log.';
      }
    } catch (e) {
      failed = true;
      error = 'Falhou. Veja o log.';
      _addLog('[launcher] Erro: $e');
    } finally {
      try {
        await file?.delete();
      } catch (_) {}
    }
    status
      ..step = null
      ..progress = null;
    if (failed) {
      status
        ..phase = CardPhase.failed
        ..error = error;
    } else {
      status.phase = CardPhase.idle;
    }
    notifyListeners();
  }

  String _verb(OpKind k) => switch (k) {
    OpKind.install => 'instalar',
    OpKind.update => 'atualizar',
    OpKind.remove => 'remover',
  };

  void _addLog(String line) {
    _log.add(line);
    if (_log.length > _maxLog) _log.removeRange(0, _log.length - _maxLog);
    notifyListeners();
  }

  @override
  void dispose() {
    unawaited(_closeSession());
    super.dispose();
  }
}
