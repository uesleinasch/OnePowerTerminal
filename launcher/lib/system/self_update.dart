import 'dart:async';
import 'dart:io';
import 'dart:ui' show AppExitType;

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';

import 'update_check.dart';

typedef DownloadFile = Future<void> Function(
  Uri url,
  File dest,
  void Function(double progress) onProgress,
);

class SelfUpdateException implements Exception {
  SelfUpdateException(this.message);
  final String message;
  @override
  String toString() => message;
}

class SelfUpdateResult {
  const SelfUpdateResult({required this.path, required this.replaced});
  final String path;
  final bool replaced;
}

Future<void> defaultDownload(
  Uri url,
  File dest,
  void Function(double) onProgress,
) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
  final sink = dest.openWrite();
  try {
    final req = await client.getUrl(url);
    req.headers.set('User-Agent', 'PowerTerminal-launcher');
    final res = await req.close();
    if (res.statusCode != 200) {
      throw HttpException('HTTP ${res.statusCode}', uri: url);
    }
    final total = res.contentLength;
    var got = 0;
    await for (final chunk in res) {
      sink.add(chunk);
      got += chunk.length;
      if (total > 0) onProgress(got / total);
    }
    await sink.close();
  } catch (_) {
    await sink.close().catchError((_) {});
    rethrow;
  } finally {
    client.close(force: true);
  }
}

Future<void> defaultExit() =>
    ServicesBinding.instance.exitApplication(AppExitType.required);

class SelfUpdater {
  SelfUpdater({
    required this.appImagePath,
    required this.downloadsDir,
    Future<String> Function(Uri)? fetch,
    DownloadFile? download,
    Future<void> Function(String exe)? start,
    Future<void> Function()? exit,
  }) : fetch = fetch ?? defaultFetch,
       download = download ?? defaultDownload,
       start = start ?? _defaultStart,
       exit = exit ?? defaultExit;

  final String appImagePath;
  final String downloadsDir;
  final Future<String> Function(Uri) fetch;
  final DownloadFile download;
  final Future<void> Function(String exe) start;
  final Future<void> Function() exit;

  static Future<void> _defaultStart(String exe) async {
    await Process.start(exe, const [], mode: ProcessStartMode.detached);
  }

  Future<SelfUpdateResult> run(
    ReleaseInfo release, {
    void Function(double progress)? onProgress,
  }) async {
    final name = release.appImageName;
    final expected = _expectedSum(await fetch(release.sumsUrl), name);
    final target = File(appImagePath);
    final writable = _canWriteBeside(target.parent);
    final File dest;
    if (writable) {
      final base = target.uri.pathSegments.last;
      dest = File('${target.parent.path}/.$base.pntmp');
    } else {
      Directory(downloadsDir).createSync(recursive: true);
      dest = File('$downloadsDir/$name');
    }
    try {
      await download(release.appImageUrl, dest, onProgress ?? (_) {});
      final actual = (await sha256.bind(dest.openRead()).first).toString();
      if (actual != expected) {
        throw SelfUpdateException(
          'O arquivo baixado não confere com o SHA256SUMS.',
        );
      }
      final chmod = await Process.run('chmod', ['+x', dest.path]);
      if (chmod.exitCode != 0) {
        throw SelfUpdateException(
          'Não foi possível tornar o arquivo executável.',
        );
      }
      if (!writable) {
        return SelfUpdateResult(path: dest.path, replaced: false);
      }
      dest.renameSync(target.path);
    } catch (_) {
      if (dest.existsSync()) dest.deleteSync();
      rethrow;
    }
    await start(target.path);
    await exit();
    return SelfUpdateResult(path: target.path, replaced: true);
  }

  static String _expectedSum(String sums, String name) {
    for (final line in sums.split('\n')) {
      final m = RegExp(r'^([0-9a-fA-F]{64})\s+\*?(.+?)\s*$').firstMatch(line);
      if (m != null && m.group(2) == name) return m.group(1)!.toLowerCase();
    }
    throw SelfUpdateException('$name não consta no SHA256SUMS.');
  }

  static bool _canWriteBeside(Directory dir) {
    try {
      final probe = File('${dir.path}/.pnwrite-$pid');
      probe.writeAsStringSync('');
      probe.deleteSync();
      return true;
    } on FileSystemException catch (_) {
      return false;
    }
  }
}
