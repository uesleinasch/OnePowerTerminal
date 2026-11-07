import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';

import '../cli/cli.dart';

const kMinContract = 1;

const _originFile = '.powerterminal-origin';
const _versionFile = 'VERSION';
const _dotfilesPrefix = 'home/';

enum RepoKind { absent, gitClone, extracted, foreign }

class RepoCopy {
  RepoCopy({
    required this.home,
    this.snapshotDir,
    String? dir,
    ProcessRunner? runner,
  }) : dir = dir ?? '$home/PowerTerminal',
       _runner = runner ?? defaultProcessRunner;

  final String home;
  final String dir;
  final String? snapshotDir;
  final ProcessRunner _runner;

  List<String> skipped = const [];

  RepoKind inspect() {
    if (FileSystemEntity.typeSync(dir, followLinks: false) ==
        FileSystemEntityType.notFound) {
      return RepoKind.absent;
    }
    if (!File('$dir/bin/powerterminal').existsSync()) return RepoKind.foreign;
    if (FileSystemEntity.typeSync('$dir/.git') !=
        FileSystemEntityType.notFound) {
      return RepoKind.gitClone;
    }
    if (File('$dir/$_versionFile').existsSync()) return RepoKind.extracted;
    return RepoKind.foreign;
  }

  String? snapshotVersion() => _version(snapshotDir);

  String? copyVersion() => _version(dir);

  bool get needsUpgrade =>
      snapshotDir != null &&
      inspect() == RepoKind.extracted &&
      snapshotVersion() != (_manifestVersion() ?? copyVersion());

  Future<void> extract() async {
    final snap = _requireSnapshot();
    final target = Directory(dir);
    target.parent.createSync(recursive: true);
    final tmp = Directory(
      '${target.parent.path}/.PowerTerminal.pnextract-'
      '${Random().nextInt(1 << 32).toRadixString(36)}',
    )..createSync();
    try {
      final files = <String, String>{};
      for (final rel in _list(snap)) {
        await _install('$snap/$rel', '${tmp.path}/$rel');
        files[rel] = _fingerprint('${tmp.path}/$rel')!;
      }
      _writeManifest(tmp.path, files, snapshotVersion() ?? '');
      if (target.existsSync()) target.deleteSync();
      tmp.renameSync(dir);
    } on Object {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
      rethrow;
    }
  }

  Future<List<String>> upgrade() async {
    final snap = _requireSnapshot();
    final snapVersion = snapshotVersion() ?? '';
    _cleanStray();
    final old = _readManifest();
    final completed = old != null && _manifestVersion() == snapVersion;
    final next = <String, String>{};
    final pnnew = <String>[];
    final skip = <String>[];
    final fresh = _list(snap);

    for (final rel in fresh) {
      if (rel == _versionFile) continue;
      final src = '$snap/$rel';
      final dst = '$dir/$rel';
      if (_blocked(dst)) {
        skip.add(rel);
        continue;
      }
      final want = _fingerprint(src)!;
      final cur = _fingerprint(dst);
      next[rel] = want;
      if (cur == null || cur == want) {
        if (cur == null) await _install(src, dst);
        continue;
      }
      final edited = old != null
          ? cur != old[rel]
          : rel.startsWith(_dotfilesPrefix);
      if (!edited) {
        await _install(src, dst);
        continue;
      }
      final sidecar = '$dst.pnnew';
      final already = _fingerprint(sidecar) == want;
      if (!already) await _install(src, sidecar);
      if (!(already && completed)) pnnew.add(rel);
    }

    if (old != null) {
      final keep = fresh.toSet();
      for (final entry in old.entries) {
        if (keep.contains(entry.key)) continue;
        final dst = '$dir/${entry.key}';
        if (_blocked(dst)) {
          skip.add(entry.key);
          continue;
        }
        if (_fingerprint(dst) == entry.value) {
          FileSystemEntity.typeSync(dst, followLinks: false) ==
                  FileSystemEntityType.link
              ? Link(dst).deleteSync()
              : File(dst).deleteSync();
        }
      }
    }

    await _install('$snap/$_versionFile', '$dir/$_versionFile');
    next[_versionFile] = _fingerprint('$dir/$_versionFile')!;
    _writeManifest(dir, next, snapVersion);
    skipped = skip;
    return pnnew;
  }

  String _requireSnapshot() {
    final s = snapshotDir;
    if (s == null) throw StateError('Sem instantâneo do repositório.');
    return s;
  }

  String? _version(String? base) {
    if (base == null) return null;
    final f = File('$base/$_versionFile');
    return f.existsSync() ? f.readAsStringSync().trim() : null;
  }

  List<String> _list(String root) {
    final out = <String>[];
    final prefix = '$root/';
    for (final e in Directory(
      root,
    ).listSync(recursive: true, followLinks: false)) {
      if (e is Directory) continue;
      final rel = e.path.substring(prefix.length);
      if (rel == _originFile ||
          rel == '.git' ||
          rel.startsWith('.git/') ||
          rel.endsWith('.pnnew') ||
          rel.endsWith('.pntmp')) {
        continue;
      }
      out.add(rel);
    }
    out.sort();
    return out;
  }

  void _cleanStray() {
    for (final e in Directory(
      dir,
    ).listSync(recursive: true, followLinks: false)) {
      if (e is! Directory && e.path.endsWith('.pntmp')) {
        e.deleteSync();
      }
    }
  }

  bool _blocked(String path) {
    var p = File(path).parent.path;
    while (p.length > dir.length && p.startsWith('$dir/')) {
      if (FileSystemEntity.typeSync(p, followLinks: false) ==
          FileSystemEntityType.link) {
        return true;
      }
      p = Directory(p).parent.path;
    }
    return false;
  }

  String? _fingerprint(String path) {
    switch (FileSystemEntity.typeSync(path, followLinks: false)) {
      case FileSystemEntityType.link:
        return 'link:${Link(path).targetSync()}';
      case FileSystemEntityType.file:
        return sha256.convert(File(path).readAsBytesSync()).toString();
      default:
        return null;
    }
  }

  Future<void> _install(String src, String dst) async {
    final parent = File(dst).parent;
    if (!parent.existsSync()) parent.createSync(recursive: true);
    final tmp = '$dst.pntmp';
    final tmpType = FileSystemEntity.typeSync(tmp, followLinks: false);
    if (tmpType == FileSystemEntityType.link) {
      Link(tmp).deleteSync();
    } else if (tmpType == FileSystemEntityType.file) {
      File(tmp).deleteSync();
    }
    final isLink =
        FileSystemEntity.typeSync(src, followLinks: false) ==
        FileSystemEntityType.link;
    if (isLink) {
      Link(tmp).createSync(Link(src).targetSync());
    } else {
      File(src).copySync(tmp);
      final ProcessResult r;
      try {
        r = await _runner('chmod', ['--reference=$src', tmp]);
      } on Object {
        File(tmp).deleteSync();
        rethrow;
      }
      if (r.exitCode != 0) {
        File(tmp).deleteSync();
        throw FileSystemException('chmod falhou: ${r.stderr}', tmp);
      }
    }
    if (FileSystemEntity.typeSync(dst, followLinks: false) ==
        FileSystemEntityType.link) {
      Link(dst).deleteSync();
    }
    isLink ? Link(tmp).renameSync(dst) : File(tmp).renameSync(dst);
  }

  Map<String, dynamic>? _readRaw() {
    final f = File('$dir/$_originFile');
    if (!f.existsSync()) return null;
    try {
      final j = jsonDecode(f.readAsStringSync());
      if (j is! Map<String, dynamic> || j['files'] is! Map) return null;
      return j;
    } on Object {
      return null;
    }
  }

  String? _manifestVersion() => _readRaw()?['version'] as String?;

  Map<String, String>? _readManifest() {
    final j = _readRaw();
    if (j == null) return null;
    final out = <String, String>{};
    for (final e in (j['files'] as Map).entries) {
      final k = '${e.key}';
      if (k.startsWith('/') || k.split('/').contains('..')) return null;
      out[k] = '${e.value}';
    }
    return out;
  }

  void _writeManifest(String root, Map<String, String> files, String version) {
    final tmp = File('$root/$_originFile.pntmp');
    tmp.writeAsStringSync(
      jsonEncode({'source': 'launcher', 'version': version, 'files': files}),
    );
    tmp.renameSync('$root/$_originFile');
  }
}
