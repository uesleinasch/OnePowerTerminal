import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';

import 'cli/cli.dart';
import 'queue/queue_controller.dart';
import 'session/pty_shell.dart';
import 'system/session_ender.dart';
import 'theme/app_theme.dart';
import 'theme/theme_mode.dart';
import 'ui/home_actions_impl.dart';
import 'ui/home_page.dart';

void main() {
  final home = Platform.environment['HOME'] ?? '';
  final repoDir =
      Platform.environment['POWERTERMINAL_HOME'] ?? '$home/PowerTerminal';
  final eventsDir = Directory.systemTemp.createTempSync('powerterminal-events');
  final controller = QueueController(
    cli: Cli(repoDir),
    shellFactory: () => PtyShell.start(workingDirectory: repoDir),
    repoDir: repoDir,
    eventsDir: eventsDir,
  )..refresh();
  AppLifecycleListener(
    onExitRequested: () async {
      try {
        eventsDir.deleteSync(recursive: true);
      } on FileSystemException {
        // melhor esforço
      }
      return AppExitResponse.exit;
    },
  );
  final navigatorKey = GlobalKey<NavigatorState>();
  final activityOpen = ValueNotifier(false);
  runApp(
    PowerTerminalApp(
      themeMode: themeModeFromFlavor(home),
      controller: controller,
      navigatorKey: navigatorKey,
      activityOpen: activityOpen,
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
  });

  final QueueController controller;
  final HomeActions actions;
  final GlobalKey<NavigatorState>? navigatorKey;
  final ThemeMode themeMode;
  final ValueNotifier<bool>? activityOpen;

  @override
  State<PowerTerminalApp> createState() => _PowerTerminalAppState();
}

class _PowerTerminalAppState extends State<PowerTerminalApp> {
  late ThemeMode _mode = widget.themeMode;

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

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: widget.navigatorKey,
      title: 'PowerTerminal',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: _mode,
      home: HomePage(
        controller: widget.controller,
        actions: widget.actions,
        activityOpen: widget.activityOpen,
        onToggleTheme: _toggleTheme,
      ),
    );
  }
}
