import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:powerterminal_launcher/model/catalog.dart';

Map<String, dynamic> fixture() =>
    jsonDecode(File('test/fixtures/catalog.json').readAsStringSync())
        as Map<String, dynamic>;

void main() {
  test('fixture carrega', () {
    final c = Catalog.fromJson(fixture());
    expect(c.modules.length, 23);
    expect(c.modules.first.id, 'apt');
    expect(c.modules.first.canRemove, isFalse);
    expect(c.byId('container')!.dataMb, 2048);
    expect(c.byId('zsh')!.origin, 'deduced');
    expect(c.byId('vscode')!.isPresent, isTrue);
    expect(c.byId('nvim')!.isPresent, isFalse);
    expect(c.byId('astronvim')!.needs, ['nvim']);
    expect(c.byId('nada'), isNull);
  });

  test('campos de detalhe são lidos', () {
    final c = Catalog.fromJson(fixture());
    final zsh = c.byId('zsh')!;
    expect(zsh.about, isNotEmpty);
    expect(zsh.requires, ['git', 'curl']);
    expect(zsh.receipt.first.kind, 'dir');
    expect(zsh.receipt.first.value, '~/.oh-my-zsh');
    expect(c.byId('apt')!.provides.first.kind, 'apt');
    expect(c.byId('apt')!.provides.first.value, 'ca-certificates');
  });

  test('campos de detalhe ausentes assumem o padrão', () {
    final j = fixture();
    final m = (j['modules'] as List).first as Map<String, dynamic>
      ..remove('about')
      ..remove('provides')
      ..remove('receipt')
      ..remove('requires');
    final info = Catalog.fromJson(j).modules.first;
    expect(info.about, m['description']);
    expect(info.provides, isEmpty);
    expect(info.receipt, isEmpty);
    expect(info.requires, isEmpty);
  });

  test('item de provides inválido lança FormatException', () {
    final j = fixture();
    (j['modules'] as List).first['provides'] = [
      {'kind': 'apt'},
    ];
    expect(() => Catalog.fromJson(j), throwsFormatException);
  });

  test('sem modules lança FormatException', () {
    final j = fixture()..remove('modules');
    expect(() => Catalog.fromJson(j), throwsFormatException);
  });

  test('state desconhecido lança FormatException', () {
    final j = fixture();
    (j['modules'] as List).first['state'] = 'weird';
    expect(() => Catalog.fromJson(j), throwsFormatException);
  });

  test('campo de tipo errado lança FormatException', () {
    final j = fixture();
    (j['modules'] as List).first['mb'] = 'x';
    expect(() => Catalog.fromJson(j), throwsFormatException);
  });
}
