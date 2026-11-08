import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'prefs.dart';
import 'version.dart';

final _releaseUrl = Uri.parse(
  'https://api.github.com/repos/uesleinasch/OnePowerTerminal/releases/latest',
);

const _checkInterval = Duration(hours: 24);

class ReleaseInfo {
  const ReleaseInfo({
    required this.version,
    required this.tag,
    required this.htmlUrl,
    required this.appImageUrl,
    required this.sumsUrl,
  });

  final String version;
  final String tag;
  final Uri htmlUrl;
  final Uri appImageUrl;
  final Uri sumsUrl;

  String get appImageName => 'PowerTerminal-$version-x86_64.AppImage';
}

Future<String> defaultFetch(Uri url) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
  try {
    final req = await client.getUrl(url).timeout(const Duration(seconds: 10));
    req.headers
      ..set('Accept', 'application/vnd.github+json')
      ..set('User-Agent', 'PowerTerminal-launcher');
    final res = await req.close().timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) {
      throw HttpException('HTTP ${res.statusCode}', uri: url);
    }
    return await res
        .transform(utf8.decoder)
        .join()
        .timeout(const Duration(seconds: 10));
  } finally {
    client.close(force: true);
  }
}

class UpdateChecker {
  UpdateChecker({Future<String> Function(Uri)? fetch})
    : fetch = fetch ?? defaultFetch;

  final Future<String> Function(Uri) fetch;

  Future<ReleaseInfo?> check({required String current}) async {
    try {
      final json = jsonDecode(await fetch(_releaseUrl));
      if (json is! Map) return null;
      final tag = json['tag_name'];
      if (tag is! String) return null;
      final version = tag.startsWith('v') ? tag.substring(1) : tag;
      if (!RegExp(r'^\d+(\.\d+)*$').hasMatch(version)) return null;
      if (!isNewerVersion(version, current)) return null;
      final assets = json['assets'];
      if (assets is! List) return null;
      Uri? urlOf(String name) {
        for (final a in assets) {
          if (a is Map && a['name'] == name) {
            final u = a['browser_download_url'];
            if (u is String) return Uri.tryParse(u);
          }
        }
        return null;
      }

      final appImage = urlOf('PowerTerminal-$version-x86_64.AppImage');
      final sums = urlOf('SHA256SUMS');
      final html = json['html_url'];
      if (appImage == null || sums == null || html is! String) return null;
      return ReleaseInfo(
        version: version,
        tag: tag,
        htmlUrl: Uri.parse(html),
        appImageUrl: appImage,
        sumsUrl: sums,
      );
    } on Object catch (_) {
      return null;
    }
  }

  Future<ReleaseInfo?> checkDue({
    required String current,
    required File prefsFile,
    DateTime? now,
  }) async {
    final when = now ?? DateTime.now();
    final prefs = Prefs.load(prefsFile);
    final last = prefs.lastUpdateCheck;
    if (last != null && when.difference(last) < _checkInterval) return null;
    final release = await check(current: current);
    Prefs.load(prefsFile).copyWith(lastUpdateCheck: when).save(prefsFile);
    if (release == null || release.version == prefs.dismissedVersion) {
      return null;
    }
    return release;
  }
}
