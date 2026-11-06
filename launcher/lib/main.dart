import 'dart:io';

import 'package:flutter/material.dart';

import 'theme/app_theme.dart';
import 'theme/theme_mode.dart';

void main() {
  runApp(PowerTerminalApp(
    themeMode: themeModeFromFlavor(Platform.environment['HOME'] ?? ''),
  ));
}

class PowerTerminalApp extends StatelessWidget {
  const PowerTerminalApp({super.key, this.themeMode = ThemeMode.system});

  final ThemeMode themeMode;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PowerTerminal',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      home: const Scaffold(body: Center(child: Text('PowerTerminal'))),
    );
  }
}
