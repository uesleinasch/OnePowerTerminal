import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:powerterminal_launcher/system/update_check.dart';

String _release() => jsonEncode({
  'tag_name': 'v0.3.0',
  'html_url': 'https://example.test/releases/v0.3.0',
  'assets': [
    {
      'name': 'PowerTerminal-0.3.0-x86_64.AppImage',
      'browser_download_url': 'https://example.test/app.AppImage',
    },
    {
      'name': 'SHA256SUMS',
      'browser_download_url': 'https://example.test/SHA256SUMS',
    },
  ],
});

void main() {
  test('devolve a release mais nova com as URLs dos assets', () async {
    final c = UpdateChecker(fetch: (_) async => _release());
    final r = await c.check(current: '0.2.0');
    expect(r?.version, '0.3.0');
    expect(r?.tag, 'v0.3.0');
    expect(r?.htmlUrl.toString(), 'https://example.test/releases/v0.3.0');
    expect(r?.appImageUrl.toString(), 'https://example.test/app.AppImage');
    expect(r?.sumsUrl.toString(), 'https://example.test/SHA256SUMS');
  });

  test('mesma versão ou erro de rede devolvem null', () async {
    final same = UpdateChecker(fetch: (_) async => _release());
    expect(await same.check(current: '0.3.0'), isNull);
    final broken = UpdateChecker(fetch: (_) async => throw Exception('rede'));
    expect(await broken.check(current: '0.2.0'), isNull);
  });
}
