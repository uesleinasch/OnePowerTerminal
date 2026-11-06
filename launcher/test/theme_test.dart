import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:powerterminal_launcher/theme/app_theme.dart';
import 'package:powerterminal_launcher/theme/theme_mode.dart';

void main() {
  test('esquema claro e escuro usam as cores do protótipo', () {
    final light = AppTheme.light();
    final dark = AppTheme.dark();
    expect(light.colorScheme.primary, const Color(0xFF7343C9));
    expect(light.colorScheme.brightness, Brightness.light);
    expect(light.colorScheme.surfaceContainerLow, const Color(0xFFF8F1FA));
    expect(dark.colorScheme.primary, const Color(0xFFD4BBFF));
    expect(dark.colorScheme.surface, const Color(0xFF141218));
    expect(dark.colorScheme.brightness, Brightness.dark);
  });

  test('PnColors expõe as cores de sucesso por tema', () {
    expect(
      AppTheme.light().extension<PnColors>()!.successContainer,
      const Color(0xFFB5F2A3),
    );
    expect(
      AppTheme.dark().extension<PnColors>()!.success,
      const Color(0xFF9AD688),
    );
  });

  group('themeModeFromFlavor', () {
    late Directory home;

    setUp(() => home = Directory.systemTemp.createTempSync('pn_theme_'));
    tearDown(() => home.deleteSync(recursive: true));

    void write(String content) {
      final dir = Directory('${home.path}/.config/powerterminal')
        ..createSync(recursive: true);
      File('${dir.path}/theme').writeAsStringSync(content);
    }

    test('latte vira claro', () {
      write('latte\n');
      expect(themeModeFromFlavor(home.path), ThemeMode.light);
    });

    test('mocha e frappe viram escuro', () {
      write('mocha');
      expect(themeModeFromFlavor(home.path), ThemeMode.dark);
      write('frappe');
      expect(themeModeFromFlavor(home.path), ThemeMode.dark);
      write('macchiato');
      expect(themeModeFromFlavor(home.path), ThemeMode.dark);
    });

    test('arquivo ausente ou valor desconhecido vira sistema', () {
      expect(themeModeFromFlavor(home.path), ThemeMode.system);
      write('xyz');
      expect(themeModeFromFlavor(home.path), ThemeMode.system);
    });
  });
}
