import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:powerterminal_launcher/queue/queue_controller.dart';
import 'package:powerterminal_launcher/theme/app_theme.dart';
import 'package:powerterminal_launcher/ui/top_bar.dart';

import 'module_card_test.dart' show pump;

void main() {
  barTests();
  testWidgets('Instalar tem área de toque de 48dp de altura', (t) async {
    await pump(
      t,
      'helpers',
      const CardStatus(),
      platform: TargetPlatform.linux,
    );
    expect(
      t.getSize(find.byType(FilledButton)).height,
      greaterThanOrEqualTo(48),
    );
  });

  testWidgets('botões de ícone da barra têm 48x48', (t) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    final theme = AppTheme.dark();
    debugDefaultTargetPlatformOverride = null;
    await t.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: TopBar(
            version: '1',
            distro: null,
            arch: 'x',
            onQuery: (_) {},
            sudoUnlocked: false,
            activityCount: 0,
          ),
        ),
      ),
    );
    for (final tip in ['Atividade', 'Alternar tema']) {
      final s = t.getSize(
        find.widgetWithIcon(
          IconButton,
          tip == 'Atividade' ? Icons.list_alt_rounded : Icons.contrast_rounded,
        ),
      );
      expect(s.width, greaterThanOrEqualTo(48), reason: tip);
      expect(s.height, greaterThanOrEqualTo(48), reason: tip);
    }
  });
}

Future<void> _bar(WidgetTester t, {bool sudo = false, int count = 0}) =>
    t.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: TopBar(
            version: '1',
            distro: null,
            arch: 'x',
            onQuery: (_) {},
            sudoUnlocked: sudo,
            activityCount: count,
          ),
        ),
      ),
    );

void barTests() {
  testWidgets('chip sudo só aparece com sudo liberado', (t) async {
    await _bar(t);
    expect(find.text('sudo liberado'), findsNothing);
    await _bar(t, sudo: true);
    expect(find.text('sudo liberado'), findsOneWidget);
  });

  testWidgets('badge de atividade some em 0 e mostra a contagem', (t) async {
    await _bar(t);
    expect(t.widget<Badge>(find.byType(Badge)).isLabelVisible, isFalse);
    await _bar(t, count: 3);
    expect(t.widget<Badge>(find.byType(Badge)).isLabelVisible, isTrue);
    expect(find.text('3'), findsOneWidget);
  });
}
