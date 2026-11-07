import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:powerterminal_launcher/ui/module_icons.dart';

void main() {
  test('cada módulo por ferramenta tem ícone próprio', () {
    const ids = [
      'eza',
      'starship',
      'lazygit',
      'lazydocker',
      'uv',
      'yazi',
      'btop',
      'ranger',
      'picom',
      'flameshot',
    ];
    final icons = {for (final id in ids) id: moduleIcon(id)};
    for (final e in icons.entries) {
      expect(e.value, isNot(moduleIcon('desconhecido')), reason: e.key);
    }
    expect(icons.values.toSet().length, ids.length);
  });

  test('tools e extras caíram', () {
    expect(moduleIcon('tools'), Icons.extension_rounded);
    expect(moduleIcon('extras'), Icons.extension_rounded);
  });
}
