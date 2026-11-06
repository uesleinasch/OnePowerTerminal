import 'dart:io';

import 'package:flutter/material.dart';

ThemeMode themeModeFromFlavor(String home) {
  try {
    final flavor = File('$home/.config/powerterminal/theme')
        .readAsStringSync()
        .trim();
    switch (flavor) {
      case 'latte':
        return ThemeMode.light;
      case 'frappe':
      case 'macchiato':
      case 'mocha':
        return ThemeMode.dark;
    }
  } on FileSystemException {
    return ThemeMode.system;
  }
  return ThemeMode.system;
}
