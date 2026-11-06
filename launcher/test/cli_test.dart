import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:powerterminal_launcher/cli/cli.dart';
import 'package:powerterminal_launcher/model/catalog.dart';

Cli cliWith(int rc, String out, [String err = '']) => Cli(
  '/repo',
  runner: (exe, args, {workingDirectory, environment}) async =>
      ProcessResult(1, rc, out, err),
);

void main() {
  test('catalog() devolve o Catalog e chama a CLI certa', () async {
    String? exe;
    List<String>? args;
    Map<String, String>? env;
    final cli = Cli(
      '/repo',
      runner: (e, a, {workingDirectory, environment}) async {
        exe = e;
        args = a;
        env = environment;
        return ProcessResult(
          1,
          0,
          File('test/fixtures/catalog.json').readAsStringSync(),
          '',
        );
      },
    );
    final c = await cli.catalog();
    expect(c.modules.length, 15);
    expect(exe, '/repo/bin/powerterminal');
    expect(cli.executable, '/repo/bin/powerterminal');
    expect(args, ['catalog', '--json']);
    expect(env, {'POWERTERMINAL_UI': 'text'});
  });

  test('rc 1 vira CatalogError com stderr', () async {
    await expectLater(
      cliWith(1, '', 'boom').catalog(),
      throwsA(
        isA<CatalogError>()
            .having((e) => e.stderr, 'stderr', 'boom')
            .having(
              (e) => e.message,
              'message',
              'Não foi possível ler o catálogo da CLI.',
            ),
      ),
    );
  });

  test('stdout que não é JSON vira CatalogError', () async {
    await expectLater(
      cliWith(0, 'not json').catalog(),
      throwsA(isA<CatalogError>()),
    );
  });

  test('JSON de formato errado vira CatalogError', () async {
    await expectLater(
      cliWith(0, '{"modules":[]}').catalog(),
      throwsA(isA<CatalogError>()),
    );
  });

  test('actionArgs', () {
    expect(Cli.actionArgs(OpKind.install, ['a', 'b']), [
      'install',
      '--module',
      'a,b',
      '--yes',
    ]);
    expect(Cli.actionArgs(OpKind.update, ['a']), [
      'update',
      '--module',
      'a',
      '--yes',
    ]);
    expect(Cli.actionArgs(OpKind.remove, ['a']), [
      'remove',
      '--module',
      'a',
      '--yes',
    ]);
    expect(Cli.actionArgs(OpKind.remove, ['container'], purgeData: true), [
      'remove',
      '--module',
      'container',
      '--yes',
      '--purge-data',
    ]);
  });
}
