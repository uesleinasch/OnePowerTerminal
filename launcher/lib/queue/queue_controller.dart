import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../cli/cli.dart';
import '../cli/events.dart';
import '../model/catalog.dart';
import '../session/event_tail.dart';
import '../session/pty_shell.dart';

enum CardPhase { idle, queued, running, failed }

@immutable
class CardStatus {
  const CardStatus({
    this.phase = CardPhase.idle,
    this.kind,
    this.step,
    this.progress,
    this.error,
  });

  final CardPhase phase;
  final OpKind? kind;
  final String? step;
  final double? progress;
  final String? error;
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
  }) {
    _logView = UnmodifiableListView(_log);
  }

  static const _maxLog = 5000;
  static const _closedMsg = 'A sessão do shell foi encerrada.';

  final Cli cli;
  final ShellFactory shellFactory;
  final String repoDir;
  final Directory eventsDir;

  Catalog? catalog;
  Object? catalogError;

  final _pending = <QueueItem>[];
  final _statuses = <String, CardStatus>{};
  final _log = <String>[];
  late final List<String> _logView;
  final _restarts = <PendingRestart>[];
  QueueItem? _current;
  ShellSession? _session;
  Future<ShellSession>? _sessionFuture;
  StreamSubscription<String>? _outputSub;
  Future<void>? _loop;
  Future<void> _enqueueTail = Future.value();
  var _enqueuing = 0;
  var _generation = 0;
  var _sudoUnlocked = false;
  var _opCounter = 0;
  var _disposed = false;
  var _logNotifyScheduled = false;

  List<QueueItem> get pending => List.unmodifiable(_pending);
  QueueItem? get current => _current;
  bool get sudoUnlocked => _sudoUnlocked;
  List<String> get log => _logView;
  List<PendingRestart> get pendingRestarts => List.unmodifiable(_restarts);

  CardStatus status(String id) => _statuses[id] ?? const CardStatus();

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  Future<void> whenIdle() async {
    while (_loop != null) {
      await _loop;
    }
  }

  Future<void> refresh() async {
    try {
      catalog = await cli.catalog();
      catalogError = null;
    } catch (e) {
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
    _statuses[id] = const CardStatus();
    notifyListeners();
  }

  Future<bool> enqueue(
    List<QueueItem> items, {
    required PasswordPrompt askPassword,
  }) {
    _enqueuing++;
    final result = _enqueueTail.then((_) => _enqueue(items, askPassword));
    _enqueueTail = result.then<void>((_) {}, onError: (_) {}).whenComplete(() {
      _enqueuing--;
    });
    return result;
  }

  List<QueueItem> _fresh(List<QueueItem> items) {
    final fresh = <QueueItem>[];
    for (final i in items) {
      final known =
          _current?.id == i.id ||
          _pending.any((p) => p.id == i.id) ||
          fresh.any((p) => p.id == i.id);
      if (!known) fresh.add(i);
    }
    return fresh;
  }

  bool _needsSudo(List<QueueItem> fresh) =>
      fresh.any((i) => catalog?.byId(i.id)?.sudo == true);

  Future<bool> _enqueue(
    List<QueueItem> items,
    PasswordPrompt askPassword,
  ) async {
    if (_disposed) return false;
    var fresh = _fresh(items);
    if (fresh.isEmpty) return true;
    if (_needsSudo(fresh) && !_sudoUnlocked) {
      final bool unlocked;
      try {
        unlocked = await _unlock(askPassword);
      } catch (_) {
        await _closeIfIdle();
        rethrow;
      }
      if (!unlocked) {
        await _closeIfIdle();
        return false;
      }
      fresh = _fresh(items);
    }
    if (_disposed) return false;
    for (final i in fresh) {
      _statuses[i.id] = CardStatus(phase: CardPhase.queued, kind: i.kind);
      _pending.add(i);
    }
    notifyListeners();
    _loop ??= _runLoop();
    return true;
  }

  Future<bool> _unlock(PasswordPrompt askPassword) async {
    String? error;
    while (true) {
      final ShellSession session;
      try {
        session = await _ensureSession();
      } catch (e) {
        _addLog('[launcher] Não foi possível abrir o shell: $e');
        return false;
      }
      final password = await askPassword(error: error);
      if (password == null) return false;
      final SudoResult result;
      try {
        result = await session.unlockSudo(password);
      } catch (e) {
        _addLog('[launcher] Falha ao liberar o sudo: $e');
        if (e is StateError) _dropSession();
        return false;
      }
      switch (result) {
        case SudoResult.ok:
          if (!identical(_session, session)) {
            error = null;
            continue;
          }
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

  Future<ShellSession> _ensureSession() {
    if (_disposed) return Future.error(StateError(_closedMsg));
    return _sessionFuture ??= _createSession();
  }

  Future<ShellSession> _createSession() async {
    final generation = _generation;
    try {
      final session = await shellFactory();
      if (generation != _generation || _disposed) {
        try {
          await session.close();
        } catch (_) {}
        throw StateError(_closedMsg);
      }
      _session = session;
      _outputSub = session.output.listen(_addLog);
      return session;
    } catch (_) {
      if (generation == _generation) _sessionFuture = null;
      rethrow;
    }
  }

  Future<void> _closeIfIdle() async {
    if (_loop != null || _pending.isNotEmpty || _enqueuing > 1) return;
    await _closeSession();
  }

  (ShellSession?, StreamSubscription<String>?) _detachSession() {
    final taken = (_session, _outputSub);
    _generation++;
    _session = null;
    _sessionFuture = null;
    _outputSub = null;
    _sudoUnlocked = false;
    return taken;
  }

  void _dropSession() {
    final (session, sub) = _detachSession();
    unawaited(sub?.cancel());
    if (session != null) {
      unawaited(session.close().catchError((Object _) {}));
    }
    notifyListeners();
  }

  Future<void> _closeSession() async {
    final (session, sub) = _detachSession();
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
      while (!_disposed) {
        while (_pending.isNotEmpty && !_disposed) {
          final item = _pending.removeAt(0);
          _current = item;
          notifyListeners();
          await _runItem(item);
          _current = null;
          if (_disposed) break;
          try {
            await refresh();
          } catch (e) {
            _addLog('[launcher] Erro ao atualizar o catálogo: $e');
          }
        }
        while (_enqueuing > 0 && !_disposed) {
          await _enqueueTail;
        }
        if (_pending.isNotEmpty && !_disposed) continue;
        await _closeSession();
        if (_pending.isEmpty || _disposed) break;
      }
    } finally {
      _current = null;
      _loop = null;
      notifyListeners();
    }
  }

  Future<void> _runItem(QueueItem item) async {
    void setStatus(CardStatus s) {
      _statuses[item.id] = s;
      notifyListeners();
    }

    setStatus(CardStatus(phase: CardPhase.running, kind: item.kind));
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
            setStatus(
              CardStatus(
                phase: CardPhase.running,
                kind: item.kind,
                step: text,
                progress: (n != null && m != null && m > 0) ? n / m : null,
              ),
            );
          case SessionRestart(:final module, :final reason):
            _restarts.add(PendingRestart(module, reason));
            notifyListeners();
          case ModuleEnd(:final ok) when !ok:
            failed = true;
          default:
        }
      });
      final RunResult result;
      try {
        result = await session.run(
          actionCommandLine(
            repoDir: repoDir,
            args: Cli.actionArgs(item.kind, [
              item.id,
            ], purgeData: item.purgeData),
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
      if (e is StateError) _dropSession();
    } finally {
      try {
        await file?.delete();
      } catch (_) {}
    }
    setStatus(
      failed
          ? CardStatus(phase: CardPhase.failed, kind: item.kind, error: error)
          : CardStatus(kind: item.kind),
    );
  }

  String _verb(OpKind k) => switch (k) {
    OpKind.install => 'instalar',
    OpKind.update => 'atualizar',
    OpKind.remove => 'remover',
  };

  void _addLog(String line) {
    _log.add(line);
    if (_log.length > _maxLog) _log.removeRange(0, _log.length - _maxLog);
    if (_logNotifyScheduled) return;
    _logNotifyScheduled = true;
    scheduleMicrotask(() {
      _logNotifyScheduled = false;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _pending.clear();
    unawaited(_closeSession());
    super.dispose();
  }
}
