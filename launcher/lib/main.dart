import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';

import 'cli/cli.dart';
import 'queue/queue_controller.dart';
import 'repo/repo_copy.dart';
import 'session/pty_shell.dart';
import 'system/prefs.dart';
import 'system/self_update.dart';
import 'system/session_ender.dart';
import 'system/update_check.dart';
import 'theme/app_theme.dart';
import 'theme/theme_mode.dart';
import 'ui/home_actions_impl.dart';
import 'ui/home_page.dart';
import 'ui/repo_gate.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final home = Platform.environment['HOME'] ?? '';
  final override = Platform.environment['POWERTERMINAL_HOME'];
  final appDir = Platform.environment['APPDIR'];
  final repo = RepoCopy(
    home: home,
    dir: override,
    snapshotDir: override == null && appDir != null
        ? '$appDir/usr/share/powerterminal/repo'
        : null,
  );
  final repoDir = repo.dir;
  final appImage = Platform.environment['APPIMAGE'];
  final currentVersion = repo.snapshotVersion();
  final selfUpdate =
      appImage != null && appImage.isNotEmpty && currentVersion != null;
  final update = ValueNotifier<ReleaseInfo?>(null);
  final prefsFile = Prefs.defaultFile(Platform.environment);
  final eventsDir = Directory.systemTemp.createTempSync('powerterminal-events');
  final controller = QueueController(
    cli: Cli(repoDir),
    shellFactory: () => PtyShell.start(workingDirectory: repoDir),
    repoDir: repoDir,
    eventsDir: eventsDir,
  );
  final navigatorKey = GlobalKey<NavigatorState>();
  final activityOpen = ValueNotifier(false);
  runApp(
    PowerTerminalApp(
      themeMode: themeModeFromFlavor(home),
      controller: controller,
      navigatorKey: navigatorKey,
      activityOpen: activityOpen,
      prefsFile: prefsFile,
      update: selfUpdate ? update : null,
      updater: selfUpdate
          ? SelfUpdater(appImagePath: appImage, downloadsDir: '$home/Downloads')
          : null,
      eventsDir: eventsDir,
      gate: (home) => RepoGate(
        repo: repo,
        builder: (_) => home,
        onReady: (_) {
          unawaited(controller.refresh());
          if (selfUpdate) {
            unawaited(
              UpdateChecker()
                  .checkDue(current: currentVersion, prefsFile: prefsFile)
                  .then((r) => update.value = r),
            );
          }
        },
      ),
      actions: HomeActionsImpl(
        controller: controller,
        navigatorKey: navigatorKey,
        sessionEnder: SessionEnder(),
        onShowLog: () => activityOpen.value = true,
      ),
    ),
  );
}

class PowerTerminalApp extends StatefulWidget {
  const PowerTerminalApp({
    super.key,
    required this.controller,
    required this.actions,
    this.navigatorKey,
    this.themeMode = ThemeMode.system,
    this.activityOpen,
    this.prefsFile,
    this.update,
    this.updater,
    this.eventsDir,
    this.gate,
  });

  final QueueController controller;
  final HomeActions actions;
  final GlobalKey<NavigatorState>? navigatorKey;
  final ThemeMode themeMode;
  final ValueNotifier<bool>? activityOpen;
  final File? prefsFile;
  final ValueNotifier<ReleaseInfo?>? update;
  final SelfUpdater? updater;
  final Directory? eventsDir;
  final Widget Function(Widget home)? gate;

  @override
  State<PowerTerminalApp> createState() => _PowerTerminalAppState();
}

class _PowerTerminalAppState extends State<PowerTerminalApp> {
  late ThemeMode _mode = widget.themeMode;
  late final _navigatorKey = widget.navigatorKey ?? GlobalKey<NavigatorState>();
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onExitRequested: _onExitRequested);
  }

  Future<AppExitResponse> _onExitRequested() async {
    if (widget.controller.isBusy && !await _confirmExit()) {
      return AppExitResponse.cancel;
    }
    await widget.controller.shutdown();
    try {
      widget.eventsDir?.deleteSync(recursive: true);
    } on FileSystemException catch (_) {}
    return AppExitResponse.exit;
  }

  Future<bool> _confirmExit() async {
    final ctx = _navigatorKey.currentState?.overlay?.context;
    if (ctx == null) return true;
    final close = await showDialog<bool>(
      context: ctx,
      builder: (context) => AlertDialog(
        content: const Text(
          'Há uma operação em andamento. Fechar mesmo assim?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
    return close ?? false;
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  void _toggleTheme() {
    final dark = switch (_mode) {
      ThemeMode.dark => true,
      ThemeMode.light => false,
      ThemeMode.system =>
        (MediaQuery.maybePlatformBrightnessOf(context) ?? Brightness.light) ==
            Brightness.dark,
    };
    setState(() => _mode = dark ? ThemeMode.light : ThemeMode.dark);
  }

  Widget _wrap(Widget home) => widget.gate?.call(home) ?? home;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'PowerTerminal',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: _mode,
      home: _wrap(
        HomePage(
          controller: widget.controller,
          actions: widget.actions,
          activityOpen: widget.activityOpen,
          prefsFile: widget.prefsFile,
          update: widget.update,
          updater: widget.updater,
          onToggleTheme: _toggleTheme,
        ),
      ),
    );
  }
}
