import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:powerterminal_launcher/model/catalog.dart';
import 'package:powerterminal_launcher/queue/queue_controller.dart';
import 'package:powerterminal_launcher/theme/app_theme.dart';
import 'package:powerterminal_launcher/ui/dialogs/dependency_dialog.dart';
import 'package:powerterminal_launcher/ui/dialogs/editor_dialog.dart';
import 'package:powerterminal_launcher/ui/dialogs/password_dialog.dart';
import 'package:powerterminal_launcher/ui/dialogs/remove_dialog.dart';
import 'package:powerterminal_launcher/ui/dialogs/session_restart_dialog.dart';
import 'package:powerterminal_launcher/ui/dashed_border.dart';
import 'package:powerterminal_launcher/ui/format.dart';
import 'package:powerterminal_launcher/ui/module_parts.dart';

final _catalog = Catalog.fromJson(
  jsonDecode(File('test/fixtures/catalog.json').readAsStringSync())
      as Map<String, dynamic>,
);

Future<BuildContext> _host(WidgetTester t) async {
  late BuildContext ctx;
  await t.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Builder(
        builder: (c) {
          ctx = c;
          return const Scaffold();
        },
      ),
    ),
  );
  return ctx;
}

double _dialogWidth(WidgetTester t) => t
    .getSize(
      find
          .descendant(of: find.byType(Dialog), matching: find.byType(Material))
          .first,
    )
    .width;

void main() {
  group('senha', () {
    testWidgets('vazio mostra o erro e não fecha; com texto devolve a senha', (
      t,
    ) async {
      final ctx = await _host(t);
      String? result = 'pendente';
      final f = showPasswordDialog(ctx).then((v) => result = v);
      await t.pumpAndSettle();
      expect(find.text('Senha de administrador'), findsOneWidget);
      await t.tap(find.text('Liberar'));
      await t.pumpAndSettle();
      expect(find.text('Digite a senha para continuar.'), findsOneWidget);
      expect(result, 'pendente');
      await t.enterText(find.byType(TextField), 'se nha"\$\\é');
      await t.tap(find.text('Liberar'));
      await t.pumpAndSettle();
      await f;
      expect(result, 'se nha"\$\\é');
      expect(find.text('Senha de administrador'), findsNothing);
    });

    testWidgets('Enter envia', (t) async {
      final ctx = await _host(t);
      String? result;
      final f = showPasswordDialog(ctx).then((v) => result = v);
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField), 'abc');
      await t.testTextInput.receiveAction(TextInputAction.done);
      await t.pumpAndSettle();
      await f;
      expect(result, 'abc');
    });

    testWidgets('error passado aparece e Cancelar devolve null', (t) async {
      final ctx = await _host(t);
      String? result = 'pendente';
      final f = showPasswordDialog(
        ctx,
        error: 'Senha incorreta. Tente de novo.',
      ).then((v) => result = v);
      await t.pumpAndSettle();
      expect(find.text('Senha incorreta. Tente de novo.'), findsOneWidget);
      await t.tap(find.text('Cancelar'));
      await t.pumpAndSettle();
      await f;
      expect(result, isNull);
    });

    testWidgets('quebra de linha é recusada', (t) async {
      final ctx = await _host(t);
      var done = false;
      final f = showPasswordDialog(ctx).then((_) => done = true);
      await t.pumpAndSettle();
      final field = t.widget<TextField>(find.byType(TextField));
      expect(field.maxLines, 1);
      expect(field.obscureText, isTrue);
      field.controller!.text = 'a\nb';
      await t.tap(find.text('Liberar'));
      await t.pumpAndSettle();
      expect(
        find.text('A senha não pode ter quebra de linha.'),
        findsOneWidget,
      );
      expect(done, isFalse);
      await t.tap(find.text('Cancelar'));
      await t.pumpAndSettle();
      await f;
    });

    testWidgets('campo outlined com rótulo flutuante e largura 420', (t) async {
      final ctx = await _host(t);
      final f = showPasswordDialog(ctx);
      await t.pumpAndSettle();
      final d = t.widget<TextField>(find.byType(TextField)).decoration!;
      expect(d.border, isA<OutlineInputBorder>());
      expect(d.labelText, 'Senha');
      expect(d.floatingLabelBehavior, FloatingLabelBehavior.always);
      expect(_dialogWidth(t), 420);
      await t.tap(find.text('Cancelar'));
      await t.pumpAndSettle();
      await f;
    });

    testWidgets('botão mostra e oculta a senha', (t) async {
      final ctx = await _host(t);
      final f = showPasswordDialog(ctx);
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('Mostrar senha'));
      await t.pump();
      expect(t.widget<TextField>(find.byType(TextField)).obscureText, isFalse);
      await t.tap(find.text('Cancelar'));
      await t.pumpAndSettle();
      await f;
    });
  });

  group('dependência', () {
    testWidgets('título, total e botão; Cancelar devolve false', (t) async {
      final ctx = await _host(t);
      bool? result;
      final f = showDependencyDialog(
        ctx,
        target: _catalog.byId('astronvim')!,
        deps: [_catalog.byId('nvim')!],
      ).then((v) => result = v);
      await t.pumpAndSettle();
      expect(find.text('AstroNvim depende de Neovim'), findsOneWidget);
      expect(find.text('Instalar os 2'), findsOneWidget);
      expect(find.textContaining('o que você pediu'), findsOneWidget);
      final nv = _catalog.byId('nvim')!;
      final ast = _catalog.byId('astronvim')!;
      expect(
        find.text(
          'Total: 2 módulos · ~${nv.minutes + ast.minutes} min · '
          '${formatMb(nv.mb + ast.mb)}',
        ),
        findsOneWidget,
      );
      await t.tap(find.text('Cancelar'));
      await t.pumpAndSettle();
      await f;
      expect(result, isFalse);
    });

    testWidgets('linhas com avatar de 40, tags, alvo tracejado e total', (
      t,
    ) async {
      final ctx = await _host(t);
      final nv = _catalog.byId('nvim')!;
      final ast = _catalog.byId('astronvim')!;
      final f = showDependencyDialog(ctx, target: ast, deps: [nv]);
      await t.pumpAndSettle();
      expect(_dialogWidth(t), 420);
      expect(find.byType(CircleAvatar), findsNWidgets(2));
      for (final a in find.byType(CircleAvatar).evaluate()) {
        expect(
          t.getSize(find.byElementPredicate((e) => e == a)),
          const Size(40, 40),
        );
      }
      final depRow = find.byKey(const ValueKey('dep-row-nvim'));
      final targetRow = find.byKey(const ValueKey('dep-row-astronvim'));
      expect(
        find.descendant(of: depRow, matching: find.text('~${nv.minutes} min')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: depRow, matching: find.text(formatMb(nv.mb))),
        findsOneWidget,
      );
      expect(
        find.descendant(of: depRow, matching: find.text('sudo')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: depRow, matching: find.byType(ModuleTag)),
        findsNWidgets(nv.sudo ? 3 : 2),
      );
      bool dashed(Finder row) => find
          .descendant(of: row, matching: find.byType(CustomPaint))
          .evaluate()
          .any((e) => (e.widget as CustomPaint).painter is DashedBorderPainter);
      expect(dashed(targetRow), isTrue);
      expect(dashed(depRow), isFalse);
      expect(
        find.text(
          'Total: 2 módulos · ~${nv.minutes + ast.minutes} min · '
          '${formatMb(nv.mb + ast.mb)}',
        ),
        findsOneWidget,
      );
      await t.tap(find.text('Cancelar'));
      await t.pumpAndSettle();
      await f;
    });

    testWidgets('Instalar devolve true', (t) async {
      final ctx = await _host(t);
      bool? result;
      final f = showDependencyDialog(
        ctx,
        target: _catalog.byId('astronvim')!,
        deps: [_catalog.byId('nvim')!],
      ).then((v) => result = v);
      await t.pumpAndSettle();
      await t.tap(find.text('Instalar os 2'));
      await t.pumpAndSettle();
      await f;
      expect(result, isTrue);
    });

    test('joinNames', () {
      expect(joinNames(['A']), 'A');
      expect(joinNames(['A', 'B', 'C']), 'A, B e C');
    });
  });

  group('editor', () {
    testWidgets('escolher Visual Studio Code devolve vscode', (t) async {
      final ctx = await _host(t);
      String? result;
      final f = showEditorDialog(ctx).then((v) => result = v);
      await t.pumpAndSettle();
      await t.tap(find.text('Visual Studio Code'));
      await t.pump();
      await t.tap(find.text('Continuar'));
      await t.pumpAndSettle();
      await f;
      expect(result, 'vscode');
    });

    testWidgets('padrão é nvim', (t) async {
      final ctx = await _host(t);
      String? result;
      final f = showEditorDialog(ctx).then((v) => result = v);
      await t.pumpAndSettle();
      await t.tap(find.text('Continuar'));
      await t.pumpAndSettle();
      await f;
      expect(result, 'nvim');
    });
  });

  group('remover', () {
    Future<(Future<RemoveChoice?>, RemoveChoice? Function())> open(
      WidgetTester t,
      String id,
      List<String> dependents,
    ) async {
      final ctx = await _host(t);
      RemoveChoice? result;
      final f = showRemoveDialog(
        ctx,
        module: _catalog.byId(id)!,
        dependents: [for (final d in dependents) _catalog.byId(d)!],
      ).then((v) => result = v);
      await t.pumpAndSettle();
      return (f, () => result);
    }

    testWidgets('com dependente mostra alerta e Remover mesmo assim', (
      t,
    ) async {
      await open(t, 'nvim', ['astronvim']);
      expect(find.text('AstroNvim depende de Neovim'), findsOneWidget);
      expect(find.text('Remover mesmo assim'), findsOneWidget);
      final alert = t.widget<Container>(
        find
            .ancestor(
              of: find.byIcon(Icons.warning_rounded),
              matching: find.byType(Container),
            )
            .first,
      );
      final cs = Theme.of(t.element(find.byType(AlertDialog))).colorScheme;
      expect((alert.decoration as BoxDecoration).color, cs.errorContainer);
    });

    testWidgets('sem dependentes mostra Remover', (t) async {
      await open(t, 'helpers', []);
      expect(find.text('Remover'), findsOneWidget);
      expect(find.text('Remover mesmo assim'), findsNothing);
      expect(find.textContaining('backups .pnbak ficam'), findsOneWidget);
    });

    testWidgets('adotado avisa que desinstala e vira Remover mesmo assim', (
      t,
    ) async {
      final ctx = await _host(t);
      final base = _catalog.byId('zsh')!;
      final adopted = ModuleInfo.fromJson({
        ...jsonDecode(
              File('test/fixtures/catalog.json').readAsStringSync(),
            )['modules'].firstWhere((m) => m['id'] == base.id)
            as Map<String, dynamic>,
        'origin': 'adopted',
      });
      unawaited(showRemoveDialog(ctx, module: adopted, dependents: []));
      await t.pumpAndSettle();
      expect(
        find.text(
          '${adopted.name} já existia antes do PowerTerminal: remover '
          'desinstala o programa também.',
        ),
        findsOneWidget,
      );
      expect(find.text('Remover mesmo assim'), findsOneWidget);
    });

    testWidgets('origin deduced mostra a frase do recibo', (t) async {
      await open(t, 'zsh', []);
      expect(
        find.textContaining(
          'Instalado antes do controle de remoção: só os links e arquivos do '
          'PowerTerminal saem.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('sem marcar o checkbox confirma sem purgar', (t) async {
      final (f, result) = await open(t, 'container', []);
      expect(find.textContaining('Apagar também imagens'), findsOneWidget);
      await t.tap(find.text('Remover'));
      await t.pumpAndSettle();
      await f;
      expect(result()!.purgeData, isFalse);
    });

    testWidgets('purgar exige a segunda confirmação', (t) async {
      final (f, result) = await open(t, 'container', []);
      await t.tap(find.byType(CheckboxListTile));
      await t.pump();
      await t.tap(find.text('Remover'));
      await t.pumpAndSettle();
      expect(find.text('Apagar também os dados?'), findsOneWidget);
      expect(result(), isNull);
      await t.tap(find.text('Voltar'));
      await t.pumpAndSettle();
      expect(find.text('Apagar também os dados?'), findsNothing);
      expect(
        find.text('Remover ${_catalog.byId('container')!.name}?'),
        findsOneWidget,
      );
      await t.tap(find.text('Remover'));
      await t.pumpAndSettle();
      await t.tap(find.text('Apagar tudo'));
      await t.pumpAndSettle();
      await f;
      expect(result()!.purgeData, isTrue);
    });

    testWidgets('lista o que sai pelo recibo, até 6 itens e "e mais N"', (
      t,
    ) async {
      final base = _catalog.byId('helpers')!;
      ModuleInfo withReceipt(int n) => ModuleInfo(
        id: base.id,
        name: base.name,
        category: base.category,
        description: base.description,
        minutes: base.minutes,
        mb: base.mb,
        sudo: base.sudo,
        editor: base.editor,
        canUpdate: base.canUpdate,
        canRemove: true,
        needs: base.needs,
        state: base.state,
        receipt: [
          for (var i = 0; i < n; i++)
            ModuleItem(kind: 'link', value: '~/.local/bin/item$i'),
        ],
      );
      final ctx = await _host(t);
      final f = showRemoveDialog(ctx, module: withReceipt(9), dependents: []);
      await t.pumpAndSettle();
      expect(_dialogWidth(t), 420);
      expect(find.text('~/.local/bin/item0'), findsOneWidget);
      expect(find.text('~/.local/bin/item5'), findsOneWidget);
      expect(find.text('~/.local/bin/item6'), findsNothing);
      expect(find.text('e mais 3'), findsOneWidget);
      await t.tap(find.text('Cancelar'));
      await t.pumpAndSettle();
      await f;

      final f2 = showRemoveDialog(ctx, module: withReceipt(6), dependents: []);
      await t.pumpAndSettle();
      expect(find.text('~/.local/bin/item5'), findsOneWidget);
      expect(find.textContaining('e mais'), findsNothing);
      await t.tap(find.text('Cancelar'));
      await t.pumpAndSettle();
      await f2;
    });

    testWidgets('módulo sem dados não mostra o checkbox', (t) async {
      await open(t, 'helpers', []);
      expect(find.byType(CheckboxListTile), findsNothing);
    });
  });

  group('sessão', () {
    testWidgets('lista os motivos; só Encerrar devolve true', (t) async {
      final ctx = await _host(t);
      bool? result;
      final f = showSessionRestartDialog(ctx, const [
        PendingRestart('container', 'grupo docker'),
      ]).then((v) => result = v);
      await t.pumpAndSettle();
      expect(find.text('Para concluir, encerre a sessão'), findsOneWidget);
      expect(find.textContaining('grupo docker'), findsOneWidget);
      await t.tap(find.text('Depois'));
      await t.pumpAndSettle();
      await f;
      expect(result, isFalse);

      final f2 = showSessionRestartDialog(ctx, const [
        PendingRestart('container', 'grupo docker'),
      ]).then((v) => result = v);
      await t.pumpAndSettle();
      await t.tap(find.text('Encerrar sessão agora'));
      await t.pumpAndSettle();
      await f2;
      expect(result, isTrue);
    });
  });
}
