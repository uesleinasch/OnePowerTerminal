import 'dart:io';

import 'package:flutter/material.dart';

import 'cli/cli.dart';
import 'queue/queue_controller.dart';
import 'session/pty_shell.dart';
import 'theme/app_theme.dart';
import 'theme/theme_mode.dart';
import 'ui/home_page.dart';

class _NoActions implements HomeActions {
  @override
  void install(String id) {}
  @override
  void update(String id) {}
  @override
  void remove(String id) {}
  @override
  void installProfile(String profile) {}
  @override
  void updateProfile(String profile) {}
  @override
  void showLog() {}
}

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
  runApp(
    PowerTerminalApp(
      themeMode: themeModeFromFlavor(home),
      controller: controller,
      actions: _NoActions(),
    ),
  );
}

class PowerTerminalApp extends StatelessWidget {
  const PowerTerminalApp({
    super.key,
    required this.controller,
    required this.actions,
    this.themeMode = ThemeMode.system,
  });

  final QueueController controller;
  final HomeActions actions;
  final ThemeMode themeMode;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PowerTerminal',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      home: HomePage(controller: controller, actions: actions),
    );
  }
}
