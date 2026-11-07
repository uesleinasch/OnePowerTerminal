import 'dart:convert';
import 'dart:io';

class Prefs {
  const Prefs({this.profile});

  final String? profile;

  static File defaultFile(Map<String, String> env) {
    final xdg = env['XDG_CONFIG_HOME'];
    final base = xdg != null && xdg.isNotEmpty
        ? xdg
        : '${env['HOME'] ?? ''}/.config';
    return File('$base/powerterminal/launcher.json');
  }

  static Prefs load(File file) {
    try {
      final json = jsonDecode(file.readAsStringSync());
      if (json is Map && json['profile'] is String) {
        return Prefs(profile: json['profile'] as String);
      }
    } on Object catch (_) {}
    return const Prefs();
  }

  void save(File file) {
    try {
      file.parent.createSync(recursive: true);
      final tmp = File('${file.path}.tmp');
      tmp.writeAsStringSync(jsonEncode({'profile': profile}));
      tmp.renameSync(file.path);
    } on FileSystemException catch (_) {}
  }
}
