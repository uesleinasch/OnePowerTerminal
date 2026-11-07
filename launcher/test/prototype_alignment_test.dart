import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:powerterminal_launcher/queue/queue_controller.dart';
import 'package:powerterminal_launcher/theme/app_theme.dart';
import 'package:powerterminal_launcher/ui/activity_panel.dart';
import 'package:powerterminal_launcher/ui/home_page.dart';
import 'package:powerterminal_launcher/ui/top_bar.dart';

import 'home_page_test.dart' show controller, pickProfile;
import 'module_card_test.dart' show RecordingActions;

Future<void> home(
  WidgetTester t,
  QueueController q, {
  double width = 1280,
  File? prefs,
  Key? key,
  ThemeData? theme,
}) async {
  t.view.physicalSize = Size(width, 4000);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    MaterialApp(
      theme: theme ?? AppTheme.light(),
      home: HomePage(
        key: key,
        controller: q,
        actions: RecordingActions(),
        prefsFile: prefs,
      ),
    ),
  );
}

Finder get _activityBtn =>
    find.widgetWithIcon(IconButton, Icons.receipt_long_rounded);

void main() {
  testWidgets('barra: ações a 24 px da borda e busca de 420 px à direita', (
    t,
  ) async {
    await home(t, await controller());
    expect(t.getRect(_activityBtn).right, 1280 - 24);
    final search = t.getRect(find.byType(TextField));
    expect(search.width, 420);
    expect(search.height, 48);
    expect(
      t.getRect(find.widgetWithIcon(IconButton, Icons.dark_mode_rounded)).left,
      search.right + 16,
    );
    expect(find.text('Buscar módulo, ferramenta…'), findsOneWidget);
  });

  testWidgets('barra: a busca encolhe até 240 px antes de quebrar linha', (
    t,
  ) async {
    t.view.physicalSize = const Size(900, 600);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: TopBar(
            version: '0.2.0',
            distro: null,
            arch: 'x86_64',
            onQuery: (_) {},
            sudoUnlocked: true,
            activityCount: 0,
          ),
        ),
      ),
    );
    expect(t.takeException(), isNull);
    final w = t.getSize(find.byType(TextField)).width;
    expect(w, inInclusiveRange(240, 420));
    expect(w, lessThan(420));
  });

  testWidgets('badge de atividade é vermelho', (t) async {
    final q = await controller();
    await home(t, q);
    final theme = AppTheme.light();
    final badge = t.widget<Badge>(find.byType(Badge));
    expect(badge.backgroundColor, theme.colorScheme.error);
    expect(badge.textColor, theme.colorScheme.onError);
  });

  testWidgets('segmento do perfil e chip ativo mostram check', (t) async {
    await home(t, await controller());
    final seg = find.descendant(
      of: find.byType(SegmentedButton<String>),
      matching: find.byIcon(Icons.check),
    );
    expect(seg, findsOneWidget);
    await pickProfile(t, 'dev');
    await t.pumpAndSettle();
    expect(seg, findsOneWidget);
    expect(
      t.getCenter(seg).dx,
      lessThan(
        t
            .getCenter(
              find.descendant(
                of: find.byType(SegmentedButton<String>),
                matching: find.text('dev'),
              ),
            )
            .dx,
      ),
    );
    final chip = find.descendant(
      of: find.byType(FilterChip),
      matching: find.byIcon(Icons.check_rounded),
    );
    expect(chip, findsNothing);
    await t.tap(find.text('Só instalados'));
    await t.pumpAndSettle();
    expect(chip, findsOneWidget);
  });

  testWidgets('resumo: fatos e botão à direita do texto em tela larga', (
    t,
  ) async {
    await home(t, await controller());
    await pickProfile(t, 'dev');
    final title = t.getRect(find.text('Perfil dev'));
    final facts = t.getRect(find.textContaining('instalados').first);
    final button = t.getRect(find.byType(FilledButton).first);
    expect(facts.left, greaterThan(title.right));
    expect(button.left, greaterThan(facts.right));
    final summary = t.getRect(
      find
          .ancestor(
            of: find.text('Perfil dev'),
            matching: find.byType(Container),
          )
          .first,
    );
    expect(button.right, summary.right - 20);
  });

  testWidgets('botão Atividade abre e fecha o painel', (t) async {
    await home(t, await controller());
    expect(find.byType(ActivityPanel), findsNothing);
    await t.tap(_activityBtn);
    await t.pumpAndSettle();
    expect(find.byType(ActivityPanel), findsOneWidget);
    await t.tap(_activityBtn);
    await t.pumpAndSettle();
    expect(find.byType(ActivityPanel), findsNothing);
  });

  testWidgets('estado vazio usa bodyLarge', (t) async {
    await home(t, await controller());
    await t.enterText(find.byType(TextField), 'zzzzzz');
    await t.pump();
    final text = t.widget<Text>(find.text('Nenhum módulo com esse filtro.'));
    expect(text.style?.fontSize, 16);
  });

  group('perfil lembrado', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('pn-home-prefs'));
    tearDown(() => dir.deleteSync(recursive: true));

    testWidgets('sobrevive a recriar a HomePage com o mesmo arquivo', (
      t,
    ) async {
      final f = File('${dir.path}/powerterminal/launcher.json');
      final q = await controller();
      await home(t, q, prefs: f, key: UniqueKey());
      await pickProfile(t, 'minimal');
      await t.pumpWidget(const SizedBox());
      await home(t, q, prefs: f, key: UniqueKey());
      expect(find.text('Perfil minimal'), findsOneWidget);
      expect(find.byType(Card), findsNWidgets(4));
    });

    testWidgets('perfil que não existe no catálogo volta para Todos', (
      t,
    ) async {
      final f = File('${dir.path}/launcher.json')
        ..writeAsStringSync('{"profile":"inexistente"}');
      await home(t, await controller(), prefs: f);
      expect(find.text('Todos os módulos'), findsOneWidget);
    });

    testWidgets('arquivo com lixo vira o padrão', (t) async {
      final f = File('${dir.path}/launcher.json')..writeAsStringSync('}{');
      await home(t, await controller(), prefs: f);
      expect(find.text('Todos os módulos'), findsOneWidget);
    });
  });
}
