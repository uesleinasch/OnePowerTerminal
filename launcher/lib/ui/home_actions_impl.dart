import 'dart:async';

import 'package:flutter/material.dart';

import '../model/catalog.dart';
import '../model/deps.dart';
import '../queue/queue_controller.dart';
import '../system/session_ender.dart';
import 'dialogs/adopt_dialog.dart';
import 'dialogs/dependency_dialog.dart';
import 'dialogs/editor_dialog.dart';
import 'dialogs/password_dialog.dart';
import 'dialogs/remove_dialog.dart';
import 'dialogs/session_restart_dialog.dart';
import 'home_actions.dart';

class HomeActionsImpl implements HomeActions {
  HomeActionsImpl({
    required this.controller,
    required this.navigatorKey,
    required this.sessionEnder,
    required this.onShowLog,
  }) {
    controller.addListener(_watchRestarts);
  }

  final QueueController controller;
  final GlobalKey<NavigatorState> navigatorKey;
  final SessionEnder sessionEnder;
  final VoidCallback onShowLog;

  var _restartDialogOpen = false;

  void dispose() => controller.removeListener(_watchRestarts);

  BuildContext? get _context => navigatorKey.currentState?.overlay?.context;

  Future<String?> _askPassword({String? error}) async {
    final ctx = _context;
    if (ctx == null) return null;
    return showPasswordDialog(ctx, error: error);
  }

  void _enqueue(List<QueueItem> items) {
    if (items.isEmpty) return;
    unawaited(
      controller.enqueue(items, askPassword: _askPassword).catchError((
        Object e,
      ) {
        controller.note('[launcher] Não foi possível enfileirar: $e');
        return false;
      }),
    );
  }

  List<QueueItem> _items(Iterable<String> ids, OpKind kind) => [
    for (final id in ids) QueueItem(id, kind),
  ];

  @override
  void install(String id) => unawaited(_install(id));

  Future<void> _install(String id) async {
    final c = controller.catalog;
    final ctx = _context;
    final target = c?.byId(id);
    if (c == null || ctx == null || target == null) return;
    final plan = installPlan(c, [id]);
    if (plan.isEmpty) return;
    final deps = [
      for (final d in plan)
        if (d != id) c.byId(d)!,
    ];
    if (deps.isNotEmpty) {
      final ok = await showDependencyDialog(ctx, target: target, deps: deps);
      if (!ok) return;
    }
    _enqueue(_items(plan, OpKind.install));
  }

  @override
  void update(String id) => _enqueue(_items([id], OpKind.update));

  @override
  void remove(String id) => unawaited(_remove(id));

  Future<void> _remove(String id) async {
    final c = controller.catalog;
    final ctx = _context;
    final module = c?.byId(id);
    if (c == null || ctx == null || module == null) return;
    final dependents = [for (final d in installedDependents(c, id)) c.byId(d)!];
    final choice = await showRemoveDialog(
      ctx,
      module: module,
      dependents: dependents,
    );
    if (choice == null) return;
    _enqueue([QueueItem(id, OpKind.remove, purgeData: choice.purgeData)]);
  }

  @override
  void adopt(String id) => unawaited(_adopt(id));

  Future<void> _adopt(String id) async {
    final ctx = _context;
    final module = controller.catalog?.byId(id);
    if (ctx == null || module == null) return;
    if (!await showAdoptDialog(ctx, module: module)) return;
    _enqueue([QueueItem(id, OpKind.adopt)]);
  }

  @override
  void installProfile(String profile) => unawaited(_installProfile(profile));

  Future<void> _installProfile(String profile) async {
    final c = controller.catalog;
    final ctx = _context;
    if (c == null || ctx == null) return;
    var editor = profileEditor(c, profile);
    if (profileNeedsEditorChoice(c, profile)) {
      editor = await showEditorDialog(ctx);
      if (editor == null) return;
    }
    final plan = installPlan(c, profileTargets(c, profile, editor: editor));
    _enqueue(_items(plan, OpKind.install));
  }

  @override
  void updateProfile(String profile) {
    final c = controller.catalog;
    if (c == null) return;
    final ids = profileTargets(c, profile, editor: profileEditor(c, profile));
    _enqueue(
      _items([
        for (final m in c.modules)
          if (ids.contains(m.id) && m.isPresent && m.canUpdate) m.id,
      ], OpKind.update),
    );
  }

  @override
  void showLog() => onShowLog();

  void _watchRestarts() {
    if (_restartDialogOpen ||
        controller.isBusy ||
        controller.pendingRestarts.isEmpty) {
      return;
    }
    _restartDialogOpen = true;
    unawaited(_showRestart());
  }

  Future<void> _showRestart() async {
    var shown = const <PendingRestart>[];
    try {
      final ctx = _context;
      if (ctx == null) return;
      shown = controller.pendingRestarts;
      final c = controller.catalog;
      final restarts = [
        for (final r in shown)
          PendingRestart(c?.byId(r.module)?.name ?? r.module, r.reason),
      ];
      final end = await showSessionRestartDialog(ctx, restarts);
      if (end) {
        final ok = await sessionEnder.logout();
        final after = _context;
        if (!ok && after != null && after.mounted) {
          ScaffoldMessenger.maybeOf(after)?.showSnackBar(
            const SnackBar(
              content: Text(
                'Não consegui encerrar a sessão. Saia e entre de novo pelo menu do sistema.',
              ),
            ),
          );
        }
      }
    } finally {
      if (shown.isNotEmpty) controller.clearPendingRestarts(shown);
      _restartDialogOpen = false;
      if (shown.isNotEmpty) _watchRestarts();
    }
  }
}
