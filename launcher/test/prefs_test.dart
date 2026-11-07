import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:powerterminal_launcher/system/prefs.dart';

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('pn-prefs'));
  tearDown(() => dir.deleteSync(recursive: true));

  test('salva e lê o perfil, criando a pasta', () {
    final f = File('${dir.path}/powerterminal/launcher.json');
    const Prefs(profile: 'dev').save(f);
    expect(Prefs.load(f).profile, 'dev');
    expect(f.readAsStringSync(), '{"profile":"dev"}');
    expect(dir.listSync(recursive: true).whereType<File>().map((e) => e.path), [
      f.path,
    ], reason: 'sem arquivo temporário sobrando');
  });

  test('arquivo ausente, ilegível ou de outro formato vira default', () {
    final f = File('${dir.path}/launcher.json');
    expect(Prefs.load(f).profile, isNull);
    for (final body in ['', 'lixo{', '[1]', '{"profile": 3}']) {
      f.writeAsStringSync(body);
      expect(Prefs.load(f).profile, isNull, reason: body);
    }
  });

  test('defaultFile respeita XDG_CONFIG_HOME e cai em ~/.config', () {
    expect(
      Prefs.defaultFile({'XDG_CONFIG_HOME': '/x', 'HOME': '/h'}).path,
      '/x/powerterminal/launcher.json',
    );
    expect(
      Prefs.defaultFile({'HOME': '/h'}).path,
      '/h/.config/powerterminal/launcher.json',
    );
    expect(
      Prefs.defaultFile({'XDG_CONFIG_HOME': '', 'HOME': '/h'}).path,
      '/h/.config/powerterminal/launcher.json',
    );
  });
}
