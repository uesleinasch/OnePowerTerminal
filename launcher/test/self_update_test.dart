import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:powerterminal_launcher/system/self_update.dart';
import 'package:powerterminal_launcher/system/update_check.dart';

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('pn-selfupdate'));
  tearDown(() => dir.deleteSync(recursive: true));

  final release = ReleaseInfo(
    version: '0.3.0',
    tag: 'v0.3.0',
    htmlUrl: Uri.parse('https://example.test/r'),
    appImageUrl: Uri.parse('https://example.test/app'),
    sumsUrl: Uri.parse('https://example.test/sums'),
  );
  final bytes = 'novo conteudo'.codeUnits;

  SelfUpdater updater(String sums, List<String> started) {
    final appImage = File('${dir.path}/PowerTerminal.AppImage')
      ..writeAsStringSync('antigo');
    return SelfUpdater(
      appImagePath: appImage.path,
      downloadsDir: '${dir.path}/Downloads',
      fetch: (_) async => sums,
      download: (url, dest, onProgress) async {
        dest.writeAsBytesSync(bytes);
        onProgress(1);
      },
      start: (exe) async => started.add(exe),
      exit: () async {},
    );
  }

  test('troca o AppImage, deixa executável e inicia o novo', () async {
    final started = <String>[];
    final sum = sha256.convert(bytes);
    final u = updater('$sum  PowerTerminal-0.3.0-x86_64.AppImage\n', started);
    final result = await u.run(release);
    final target = File(u.appImagePath);
    expect(result.replaced, isTrue);
    expect(target.readAsStringSync(), 'novo conteudo');
    expect(target.statSync().mode & 0x40, isNot(0));
    expect(started, [target.path]);
  });

  test('SHA errado falha e preserva o original', () async {
    final started = <String>[];
    final u = updater(
      '${'0' * 64}  PowerTerminal-0.3.0-x86_64.AppImage\n',
      started,
    );
    await expectLater(
      u.run(release),
      throwsA(
        isA<SelfUpdateException>().having(
          (e) => e.message,
          'message',
          'O arquivo baixado não confere com o SHA256SUMS.',
        ),
      ),
    );
    expect(File(u.appImagePath).readAsStringSync(), 'antigo');
    expect(started, isEmpty);
  });
}
