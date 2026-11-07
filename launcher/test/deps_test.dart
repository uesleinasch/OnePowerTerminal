import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:powerterminal_launcher/model/catalog.dart';
import 'package:powerterminal_launcher/model/deps.dart';

Catalog catalog({Map<String, String> states = const {}}) {
  final j = jsonDecode(
    File('test/fixtures/catalog.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  for (final m in j['modules'] as List) {
    final s = states[m['id']];
    if (s != null) m['state'] = s;
  }
  return Catalog.fromJson(j);
}

void main() {
  test('installPlan inclui dependência available', () {
    expect(installPlan(catalog(), ['astronvim']), ['nvim', 'astronvim']);
  });

  test('installPlan não inclui dependência preexisting', () {
    final c = catalog(states: {'nvim': 'preexisting'});
    expect(installPlan(c, ['astronvim']), ['astronvim']);
  });

  test('installPlan sem duplicata e na ordem do catálogo', () {
    expect(installPlan(catalog(), ['astronvim', 'nvim']), [
      'nvim',
      'astronvim',
    ]);
  });

  test('installPlan é transitivo e ignora ids desconhecidos', () {
    expect(installPlan(catalog(), ['fonts', 'nada']), ['apt', 'fonts']);
  });

  test('installPlan não inclui alvo já presente', () {
    expect(installPlan(catalog(), ['zsh']), isEmpty);
  });

  test('installedDependents', () {
    final c = catalog(states: {'astronvim': 'installed'});
    expect(installedDependents(c, 'nvim'), ['astronvim']);
    expect(installedDependents(catalog(), 'nvim'), isEmpty);
  });

  test('editorModules', () {
    expect(editorModules('nvim'), ['nvim', 'astronvim']);
    expect(editorModules('vscode'), ['vscode']);
    expect(editorModules('both'), ['nvim', 'astronvim', 'vscode']);
  });

  test('profileTargets com editor vscode', () {
    final t = profileTargets(catalog(), 'dev', editor: 'vscode');
    expect(t, contains('vscode'));
    expect(t, isNot(contains('nvim')));
    expect(t, isNot(contains('astronvim')));
    expect(t.toSet().length, t.length);
  });

  test('profileTargets com editor nvim mantém ordem do catálogo', () {
    final t = profileTargets(catalog(), 'minimal', editor: 'nvim');
    expect(t, ['apt', 'fonts', 'zsh', 'nvim', 'astronvim', 'helpers']);
  });

  test('profileTargets sem editor devolve o perfil', () {
    expect(profileTargets(catalog(), 'minimal'), [
      'apt',
      'fonts',
      'zsh',
      'helpers',
    ]);
  });

  test('inferEditorChoice', () {
    expect(inferEditorChoice(catalog()), 'vscode');
    expect(
      inferEditorChoice(
        catalog(states: {'nvim': 'installed', 'vscode': 'available'}),
      ),
      'nvim',
    );
    expect(inferEditorChoice(catalog(states: {'nvim': 'preexisting'})), 'both');
    expect(inferEditorChoice(catalog(states: {'vscode': 'available'})), isNull);
  });

  test('profileNeedsEditorChoice', () {
    final none = catalog(states: {'vscode': 'available'});
    expect(profileNeedsEditorChoice(none, 'dev'), isTrue);
    expect(profileNeedsEditorChoice(none, 'full'), isTrue);
    expect(profileNeedsEditorChoice(none, 'minimal'), isFalse);
    expect(
      profileNeedsEditorChoice(catalog(states: {'nvim': 'installed'}), 'dev'),
      isFalse,
    );
    expect(
      profileNeedsEditorChoice(
        catalog(states: {'vscode': 'preexisting'}),
        'dev',
      ),
      isFalse,
    );
  });

  test('defaultEditor segue o padrão da CLI', () {
    expect(defaultEditor('dev'), 'nvim');
    expect(defaultEditor('full'), 'both');
    expect(defaultEditor('minimal'), isNull);
  });
}
