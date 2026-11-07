enum ModuleState { installed, preexisting, available }

enum OpKind { install, update, remove }

class ModuleInfo {
  const ModuleInfo({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.minutes,
    required this.mb,
    required this.sudo,
    required this.editor,
    required this.canUpdate,
    required this.canRemove,
    required this.needs,
    required this.state,
    this.origin,
    this.dataMb,
    String? about,
    this.provides = const [],
    this.receipt = const [],
    this.requires = const [],
  }) : about = about ?? description;

  final String id, name, category, description;
  final int minutes, mb;
  final bool sudo, editor, canUpdate, canRemove;
  final List<String> needs;
  final ModuleState state;
  final String? origin;
  final int? dataMb;
  final String about;
  final List<ModuleItem> provides, receipt;
  final List<String> requires;

  bool get isPresent => state != ModuleState.available;

  factory ModuleInfo.fromJson(Map<String, dynamic> j) => ModuleInfo(
    id: _get<String>(j, 'id'),
    name: _get<String>(j, 'name'),
    category: _get<String>(j, 'category'),
    description: _get<String>(j, 'description'),
    minutes: _get<int>(j, 'minutes'),
    mb: _get<int>(j, 'mb'),
    sudo: _get<bool>(j, 'sudo'),
    editor: _get<bool>(j, 'editor'),
    canUpdate: _get<bool>(j, 'can_update'),
    canRemove: _get<bool>(j, 'can_remove'),
    needs: _strings(j, 'needs'),
    state: _state(_get<String>(j, 'state')),
    origin: _opt<String>(j, 'origin'),
    dataMb: _opt<int>(j, 'data_mb'),
    about: _opt<String>(j, 'about'),
    provides: _items(j, 'provides'),
    receipt: _items(j, 'receipt'),
    requires: _optStrings(j, 'requires'),
  );
}

class ModuleItem {
  const ModuleItem({required this.kind, required this.value});

  final String kind, value;
}

class Catalog {
  const Catalog({
    required this.contractVersion,
    required this.version,
    required this.distro,
    required this.arch,
    required this.profiles,
    required this.modules,
  });

  final int contractVersion;
  final String version;
  final String? distro;
  final String arch;
  final Map<String, List<String>> profiles;
  final List<ModuleInfo> modules;

  ModuleInfo? byId(String id) {
    for (final m in modules) {
      if (m.id == id) return m;
    }
    return null;
  }

  static Catalog fromJson(Map<String, dynamic> j) {
    final rawProfiles = _get<Map>(j, 'profiles');
    final profiles = <String, List<String>>{};
    for (final e in rawProfiles.entries) {
      final v = e.value;
      if (e.key is! String || v is! List || v.any((x) => x is! String)) {
        throw const FormatException('Campo "profiles" inválido.');
      }
      profiles[e.key as String] = List<String>.from(v);
    }
    final rawModules = _get<List>(j, 'modules');
    final modules = <ModuleInfo>[
      for (final m in rawModules)
        if (m is Map<String, dynamic>)
          ModuleInfo.fromJson(m)
        else
          throw const FormatException('Módulo inválido no catálogo.'),
    ];
    return Catalog(
      contractVersion: _get<int>(j, 'contract_version'),
      version: _get<String>(j, 'version'),
      distro: _opt<String>(j, 'distro'),
      arch: _get<String>(j, 'arch'),
      profiles: profiles,
      modules: modules,
    );
  }
}

T _get<T>(Map<String, dynamic> j, String key) {
  final v = j[key];
  if (v is! T) throw FormatException('Campo "$key" ausente ou inválido.');
  return v;
}

T? _opt<T>(Map<String, dynamic> j, String key) {
  final v = j[key];
  if (v == null) return null;
  if (v is! T) throw FormatException('Campo "$key" inválido.');
  return v;
}

List<String> _strings(Map<String, dynamic> j, String key) {
  final v = _get<List>(j, key);
  if (v.any((x) => x is! String)) {
    throw FormatException('Campo "$key" inválido.');
  }
  return List<String>.from(v);
}

List<String> _optStrings(Map<String, dynamic> j, String key) =>
    j[key] == null ? const [] : _strings(j, key);

List<ModuleItem> _items(Map<String, dynamic> j, String key) {
  final v = j[key];
  if (v == null) return const [];
  if (v is! List) throw FormatException('Campo "$key" inválido.');
  return [
    for (final x in v)
      if (x is Map<String, dynamic> &&
          x['kind'] is String &&
          x['value'] is String)
        ModuleItem(kind: x['kind'] as String, value: x['value'] as String)
      else
        throw FormatException('Campo "$key" inválido.'),
  ];
}

ModuleState _state(String s) => switch (s) {
  'installed' => ModuleState.installed,
  'preexisting' => ModuleState.preexisting,
  'available' => ModuleState.available,
  _ => throw FormatException('Estado desconhecido: "$s".'),
};
