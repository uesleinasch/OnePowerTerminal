import 'dart:convert';
import 'dart:io';

import '../model/catalog.dart';

typedef ProcessRunner = Future<ProcessResult> Function(
  String exe,
  List<String> args, {
  String? workingDirectory,
  Map<String, String>? environment,
});

class CatalogError implements Exception {
  CatalogError(this.message, [this.stderr]);
  final String message;
  final String? stderr;

  @override
  String toString() =>
      stderr == null || stderr!.isEmpty ? message : '$message\n$stderr';
}

Future<ProcessResult> defaultProcessRunner(
  String exe,
  List<String> args, {
  String? workingDirectory,
  Map<String, String>? environment,
}) => Process.run(
  exe,
  args,
  workingDirectory: workingDirectory,
  environment: environment,
);

class Cli {
  Cli(this.repoDir, {ProcessRunner? runner})
    : _runner = runner ?? defaultProcessRunner;

  final String repoDir;
  final ProcessRunner _runner;

  String get executable => '$repoDir/bin/powerterminal';

  Future<Catalog> catalog() async {
    const msg = 'Não foi possível ler o catálogo da CLI.';
    final ProcessResult r;
    try {
      r = await _runner(
        executable,
        const ['catalog', '--json'],
        workingDirectory: repoDir,
        environment: const {'POWERTERMINAL_UI': 'text'},
      );
    } on ProcessException catch (e) {
      throw CatalogError(msg, e.message);
    }
    final err = '${r.stderr}';
    if (r.exitCode != 0) throw CatalogError(msg, err);
    try {
      final j = jsonDecode('${r.stdout}');
      if (j is! Map<String, dynamic>) throw const FormatException('raiz');
      return Catalog.fromJson(j);
    } on FormatException catch (e) {
      throw CatalogError(msg, err.isEmpty ? e.message : err);
    }
  }

  static List<String> actionArgs(
    OpKind k,
    List<String> modules, {
    bool purgeData = false,
  }) => [
    k.name,
    '--module',
    modules.join(','),
    '--yes',
    if (k == OpKind.remove && purgeData) '--purge-data',
  ];
}
