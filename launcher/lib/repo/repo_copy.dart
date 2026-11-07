import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import '../cli/cli.dart';

const kMinContract = 1;

const _originFile = '.powerterminal-origin';

enum RepoKind { absent, gitClone, extracted, foreign }

Future<ProcessResult> _run(
  String exe,
  List<String> args, {
  String? workingDirectory,
  Map<String, String>? environment,
}) => Process.run(exe, args);

class RepoCopy {
  RepoCopy({
    required String home,
    this.snapshotDir,
    String? dir,
    ProcessRunner? runner,
  }) : dir = dir ?? '$home/PowerTerminal',
       _runner = runner ?? _run;

  final String dir;
  final String? snapshotDir;
  final ProcessRunner _runner;

  RepoKind inspect() {
    if (FileSystemEntity.typeSync(dir, followLinks: false) ==
        FileSystemEntityType.notFound) {
      return RepoKind.absent;
    }
    if (FileSystemEntity.typeSync('$dir/.git') !=
        FileSystemEntityType.notFound) {
      return RepoKind.gitClone;
    }
    if (File('$dir/bin/powerterminal').existsSync() &&
        File('$dir/VERSION').existsSync()) {
      return RepoKind.extracted;
    }
    return RepoKind.foreign;
  }

  String? snapshotVersion() => _version(snapshotDir);

  String? copyVersion() => _version(dir);

  bool get needsUpgrade =>
      snapshotDir != null &&
      inspect() == RepoKind.extracted &&
      snapshotVersion() != copyVersion();

  Future<void> extract() async {
    final snap = _requireSnapshot();
    Directory(dir).createSync(recursive: true);
    final files = <String, String>{};
    for (final rel in _list(snap)) {
      await _install('$snap/$rel', '$dir/$rel');
      files[rel] = _fingerprint('$dir/$rel')!;
    }
    _writeManifest(files);
  }

  Future<List<String>> upgrade() async {
    final snap = _requireSnapshot();
    final old = _readManifest();
    final next = <String, String>{};
    final pnnew = <String>[];
    final fresh = _list(snap);
    for (final rel in fresh) {
      final src = '$snap/$rel';
      final dst = '$dir/$rel';
      final want = _fingerprint(src)!;
      final cur = _fingerprint(dst);
      next[rel] = want;
      if (cur == null) {
        await _install(src, dst);
        continue;
      }
      if (cur == want) continue;
      final base = old?[rel] ?? want;
      if (cur == base) {
        await _install(src, dst);
      } else {
        await _install(src, '$dst.pnnew');
        pnnew.add(rel);
      }
    }
    if (old != null) {
      final keep = fresh.toSet();
      for (final entry in old.entries) {
        if (keep.contains(entry.key)) continue;
        final dst = '$dir/${entry.key}';
        if (_fingerprint(dst) == entry.value) {
          FileSystemEntity.typeSync(dst, followLinks: false) ==
                  FileSystemEntityType.link
              ? Link(dst).deleteSync()
              : File(dst).deleteSync();
        }
      }
    }
    _writeManifest(next, version: snapshotVersion());
    return pnnew;
  }

  String _requireSnapshot() {
    final s = snapshotDir;
    if (s == null) throw StateError('Sem instantâneo do repositório.');
    return s;
  }

  String? _version(String? base) {
    if (base == null) return null;
    final f = File('$base/VERSION');
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
          rel.endsWith('.pnnew')) {
        continue;
      }
      out.add(rel);
    }
    out.sort();
    return out;
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
    if (FileSystemEntity.typeSync(src, followLinks: false) ==
        FileSystemEntityType.link) {
      Link(tmp).createSync(Link(src).targetSync());
    } else {
      File(src).copySync(tmp);
      final r = await _runner('chmod', ['--reference=$src', tmp]);
      if (r.exitCode != 0) {
        File(tmp).deleteSync();
        throw FileSystemException('chmod falhou: ${r.stderr}', tmp);
      }
    }
    final dstType = FileSystemEntity.typeSync(dst, followLinks: false);
    if (dstType == FileSystemEntityType.link) Link(dst).deleteSync();
    if (FileSystemEntity.typeSync(tmp, followLinks: false) ==
        FileSystemEntityType.link) {
      Link(tmp).renameSync(dst);
    } else {
      File(tmp).renameSync(dst);
    }
  }

  Map<String, String>? _readManifest() {
    final f = File('$dir/$_originFile');
    if (!f.existsSync()) return null;
    try {
      final j = jsonDecode(f.readAsStringSync());
      final files = (j as Map)['files'] as Map;
      return {for (final e in files.entries) '${e.key}': '${e.value}'};
    } on Object {
      return null;
    }
  }

  void _writeManifest(Map<String, String> files, {String? version}) {
    final tmp = File('$dir/$_originFile.pntmp');
    tmp.writeAsStringSync(
      jsonEncode({
        'source': 'launcher',
        'version': version ?? snapshotVersion() ?? '',
        'files': files,
      }),
    );
    tmp.renameSync('$dir/$_originFile');
  }
}
