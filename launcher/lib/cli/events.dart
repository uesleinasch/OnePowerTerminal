import 'dart:convert';

sealed class CliEvent {
  const CliEvent();

  static CliEvent? parse(String line) {
    final Object? decoded;
    try {
      decoded = jsonDecode(line);
    } on FormatException {
      return null;
    }
    if (decoded is! Map<String, dynamic>) return null;
    final j = decoded;
    String? s(String k) => j[k] is String ? j[k] as String : null;
    int? i(String k) => j[k] is int ? j[k] as int : null;
    List<String> l(String k) => [
      if (j[k] is List)
        for (final x in j[k] as List)
          if (x is String) x,
    ];
    final module = s('module');
    switch (s('event')) {
      case 'module_begin':
        final action = s('action'), index = i('index'), total = i('total');
        if (module == null ||
            action == null ||
            index == null ||
            total == null) {
          return null;
        }
        return ModuleBegin(module, action, index, total);
      case 'step':
        final text = s('text');
        if (module == null || text == null) return null;
        return Step(module, text, i('n'), i('m'));
      case 'note':
        final text = s('text');
        if (module == null || text == null) return null;
        return Note(module, text);
      case 'session_restart':
        final reason = s('reason');
        if (module == null || reason == null) return null;
        return SessionRestart(module, reason);
      case 'module_end':
        final action = s('action');
        final ok = j['ok'];
        if (module == null || action == null || ok is! bool) return null;
        return ModuleEnd(module, action, ok);
      case 'done':
        if (j['ok'] is! List || j['failed'] is! List) return null;
        return Done(l('ok'), l('failed'));
    }
    return null;
  }
}

class ModuleBegin extends CliEvent {
  const ModuleBegin(this.module, this.action, this.index, this.total);
  final String module, action;
  final int index, total;
}

class Step extends CliEvent {
  const Step(this.module, this.text, this.n, this.m);
  final String module, text;
  final int? n, m;
}

class Note extends CliEvent {
  const Note(this.module, this.text);
  final String module, text;
}

class SessionRestart extends CliEvent {
  const SessionRestart(this.module, this.reason);
  final String module, reason;
}

class ModuleEnd extends CliEvent {
  const ModuleEnd(this.module, this.action, this.ok);
  final String module, action;
  final bool ok;
}

class Done extends CliEvent {
  const Done(this.ok, this.failed);
  final List<String> ok, failed;
}
