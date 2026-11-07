import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:powerterminal_launcher/repo/repo_copy.dart';

void write(String root, String rel, String body, {bool exec = false}) {
  final f = File('$root/$rel')..createSync(recursive: true);
  f.writeAsStringSync(body);
  if (exec) Process.runSync('chmod', ['+x', f.path]);
}

String sha(String body) => sha256.convert(utf8.encode(body)).toString();

Map<String, dynamic> manifest(String dir) =>
    jsonDecode(File('$dir/.powerterminal-origin').readAsStringSync())
        as Map<String, dynamic>;

late Directory tmp;
late String snap;
late RepoCopy repo;

void buildSnapshot(String version, Map<String, String> files) {
  Directory(snap).deleteSync(recursive: true);
  Directory(snap).createSync();
  write(snap, 'VERSION', '$version\n');
  write(snap, 'bin/powerterminal', '#!/bin/bash\necho $version\n', exec: true);
  files.forEach((k, v) => write(snap, k, v));
}

void main() {
  setUp(() {
    tmp = Directory.systemTemp.createTempSync('pn-repo-copy');
    snap = '${tmp.path}/snap';
    Directory(snap).createSync();
    repo = RepoCopy(home: '${tmp.path}/home', snapshotDir: snap);
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  test('dir fica em \$home/PowerTerminal', () {
    expect(repo.dir, '${tmp.path}/home/PowerTerminal');
  });

  group('inspect', () {
    test('absent', () => expect(repo.inspect(), RepoKind.absent));

    test('gitClone', () {
      Directory('${repo.dir}/.git').createSync(recursive: true);
      expect(repo.inspect(), RepoKind.gitClone);
    });

    test('extracted', () {
      write(repo.dir, 'bin/powerterminal', '#!/bin/bash');
      write(repo.dir, 'VERSION', '1.0');
      expect(repo.inspect(), RepoKind.extracted);
    });

    test('foreign', () {
      write(repo.dir, 'qualquer.txt', 'x');
      expect(repo.inspect(), RepoKind.foreign);
    });
  });

  group('extract', () {
    test('copia tudo, mantém o modo e grava o manifesto', () async {
      buildSnapshot('1.0', {'lib/a.sh': 'A', 'home/.zshrc': 'Z'});
      write(snap, '.git/config', 'nao');
      Link('$snap/lib/atalho').createSync('a.sh');
      await repo.extract();

      expect(File('${repo.dir}/lib/a.sh').readAsStringSync(), 'A');
      expect(File('${repo.dir}/.git/config').existsSync(), isFalse);
      expect(
        FileStat.statSync('${repo.dir}/bin/powerterminal').mode & 0x40,
        isNot(0),
      );
      expect(Link('${repo.dir}/lib/atalho').targetSync(), 'a.sh');
      expect(repo.inspect(), RepoKind.extracted);

      final m = manifest(repo.dir);
      expect(m['source'], 'launcher');
      expect(m['version'], '1.0');
      final files = m['files'] as Map<String, dynamic>;
      expect(files['lib/a.sh'], sha('A'));
      expect(files['home/.zshrc'], sha('Z'));
      expect(files['VERSION'], sha('1.0\n'));
      expect(files.containsKey('.powerterminal-origin'), isFalse);
    });
  });

  group('upgrade', () {
    Future<void> extractV1(Map<String, String> files) async {
      buildSnapshot('1.0', files);
      await repo.extract();
    }

    test('needsUpgrade compara o VERSION de cada lado', () async {
      await extractV1({});
      expect(repo.needsUpgrade, isFalse);
      buildSnapshot('1.1', {});
      expect(repo.needsUpgrade, isTrue);
      expect(repo.snapshotVersion(), '1.1');
      expect(repo.copyVersion(), '1.0');
    });

    test('arquivo não editado é trocado e novo é criado', () async {
      await extractV1({'a.txt': 'velho'});
      buildSnapshot('1.1', {'a.txt': 'novo', 'b.txt': 'B'});
      final list = await repo.upgrade();
      expect(list, isEmpty);
      expect(File('${repo.dir}/a.txt').readAsStringSync(), 'novo');
      expect(File('${repo.dir}/b.txt').readAsStringSync(), 'B');
      expect(File('${repo.dir}/a.txt.pnnew').existsSync(), isFalse);
      expect(repo.needsUpgrade, isFalse);
      expect(manifest(repo.dir)['files']['a.txt'], sha('novo'));
    });

    test('arquivo editado fica e ganha .pnnew', () async {
      await extractV1({'a.txt': 'velho'});
      write(repo.dir, 'a.txt', 'meu');
      buildSnapshot('1.1', {'a.txt': 'novo'});
      final list = await repo.upgrade();
      expect(list, ['a.txt']);
      expect(File('${repo.dir}/a.txt').readAsStringSync(), 'meu');
      expect(File('${repo.dir}/a.txt.pnnew').readAsStringSync(), 'novo');
      expect(manifest(repo.dir)['files'].containsKey('a.txt.pnnew'), isFalse);
    });

    test('removido no novo e não editado some', () async {
      await extractV1({'a.txt': 'velho'});
      buildSnapshot('1.1', {});
      await repo.upgrade();
      expect(File('${repo.dir}/a.txt').existsSync(), isFalse);
      expect(manifest(repo.dir)['files'].containsKey('a.txt'), isFalse);
    });

    test('removido no novo e editado fica', () async {
      await extractV1({'a.txt': 'velho'});
      write(repo.dir, 'a.txt', 'meu');
      buildSnapshot('1.1', {});
      await repo.upgrade();
      expect(File('${repo.dir}/a.txt').readAsStringSync(), 'meu');
    });

    test('sem manifesto, diferente do novo vira .pnnew', () async {
      await extractV1({'a.txt': 'velho', 'b.txt': 'igual'});
      File('${repo.dir}/.powerterminal-origin').deleteSync();
      write(repo.dir, 'a.txt', 'meu');
      buildSnapshot('1.1', {'a.txt': 'novo', 'b.txt': 'igual'});
      final list = await repo.upgrade();
      expect(list, containsAll(['a.txt', 'VERSION']));
      expect(list, isNot(contains('b.txt')));
      expect(File('${repo.dir}/a.txt').readAsStringSync(), 'meu');
      expect(File('${repo.dir}/a.txt.pnnew').readAsStringSync(), 'novo');
      expect(File('${repo.dir}/b.txt.pnnew').existsSync(), isFalse);
      expect(manifest(repo.dir)['version'], '1.1');
    });

    test(
      'segunda atualização continua tratando a edição como edição',
      () async {
        await extractV1({'a.txt': 'v1'});
        write(repo.dir, 'a.txt', 'meu');
        buildSnapshot('1.1', {'a.txt': 'v2'});
        await repo.upgrade();
        buildSnapshot('1.2', {'a.txt': 'v3'});
        final list = await repo.upgrade();
        expect(list, ['a.txt']);
        expect(File('${repo.dir}/a.txt').readAsStringSync(), 'meu');
        expect(File('${repo.dir}/a.txt.pnnew').readAsStringSync(), 'v3');
      },
    );

    test('mantém o modo executável ao trocar', () async {
      await extractV1({});
      buildSnapshot('1.1', {});
      await repo.upgrade();
      expect(
        FileStat.statSync('${repo.dir}/bin/powerterminal').mode & 0x40,
        isNot(0),
      );
      expect(
        File('${repo.dir}/bin/powerterminal').readAsStringSync(),
        contains('1.1'),
      );
    });
  });
}
