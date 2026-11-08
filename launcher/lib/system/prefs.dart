import 'dart:convert';
import 'dart:io';

class Prefs {
  const Prefs({this.profile, this.lastUpdateCheck, this.dismissedVersion});

  final String? profile;
  final DateTime? lastUpdateCheck;
  final String? dismissedVersion;

  Prefs copyWith({
    String? profile,
    DateTime? lastUpdateCheck,
    String? dismissedVersion,
  }) => Prefs(
    profile: profile ?? this.profile,
    lastUpdateCheck: lastUpdateCheck ?? this.lastUpdateCheck,
    dismissedVersion: dismissedVersion ?? this.dismissedVersion,
  );

  static File defaultFile(Map<String, String> env) {
    final xdg = env['XDG_CONFIG_HOME'];
    final base = xdg != null && xdg.isNotEmpty
        ? xdg
        : '${env['HOME'] ?? ''}/.config';
    return File('$base/powerterminal-launcher/launcher.json');
  }

  static Prefs load(File file) {
    try {
      final json = jsonDecode(file.readAsStringSync());
      if (json is Map) {
        final check = json['lastUpdateCheck'];
        final profile = json['profile'];
        final dismissed = json['dismissedVersion'];
        return Prefs(
          profile: profile is String ? profile : null,
          lastUpdateCheck: check is String ? DateTime.tryParse(check) : null,
          dismissedVersion: dismissed is String ? dismissed : null,
        );
      }
    } on Object catch (_) {}
    return const Prefs();
  }

  void save(File file) {
    try {
      file.parent.createSync(recursive: true);
      final tmp = File('${file.path}.tmp');
      tmp.writeAsStringSync(
        jsonEncode({
          if (profile != null) 'profile': profile,
          if (lastUpdateCheck != null)
            'lastUpdateCheck': lastUpdateCheck!.toUtc().toIso8601String(),
          if (dismissedVersion != null) 'dismissedVersion': dismissedVersion,
        }),
      );
      tmp.renameSync(file.path);
    } on FileSystemException catch (_) {}
  }
}
