import 'dart:io';

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
  final controller = QueueController(
    cli: Cli(repoDir),
    shellFactory: () => PtyShell.start(workingDirectory: repoDir),
    repoDir: repoDir,
    eventsDir: Directory.systemTemp.createTempSync('powerterminal-events'),
  )..refresh();
  final navigatorKey = GlobalKey<NavigatorState>();
  runApp(
    PowerTerminalApp(
      themeMode: themeModeFromFlavor(home),
      controller: controller,
      navigatorKey: navigatorKey,
      actions: HomeActionsImpl(
        controller: controller,
        navigatorKey: navigatorKey,
        sessionEnder: SessionEnder(),
        onShowLog: () {},
      ),
    ),
  );
}

class PowerTerminalApp extends StatelessWidget {
  const PowerTerminalApp({
    super.key,
    required this.controller,
    required this.actions,
    this.navigatorKey,
    this.themeMode = ThemeMode.system,
  });

  final QueueController controller;
  final HomeActions actions;
  final GlobalKey<NavigatorState>? navigatorKey;
  final ThemeMode themeMode;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'PowerTerminal',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      home: HomePage(controller: controller, actions: actions),
    );
  }
}
