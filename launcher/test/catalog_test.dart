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
    expect(c.modules.length, 15);
    expect(c.modules.first.id, 'apt');
    expect(c.modules.first.canRemove, isFalse);
    expect(c.byId('container')!.dataMb, 2048);
    expect(c.byId('zsh')!.origin, 'deduced');
    expect(c.byId('vscode')!.isPresent, isTrue);
    expect(c.byId('nvim')!.isPresent, isFalse);
    expect(c.byId('astronvim')!.needs, ['nvim']);
    expect(c.byId('nada'), isNull);
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
