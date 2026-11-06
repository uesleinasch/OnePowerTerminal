import 'catalog.dart';

const _editorIds = ['nvim', 'astronvim', 'vscode'];

List<String> installPlan(Catalog c, List<String> targets) {
  final wanted = <String>{};
  void visit(String id) {
    final m = c.byId(id);
    if (m == null || !wanted.add(id)) return;
    m.needs.forEach(visit);
  }

  targets.forEach(visit);
  return [
    for (final m in c.modules)
      if (wanted.contains(m.id) && m.state == ModuleState.available) m.id,
  ];
}

List<String> installedDependents(Catalog c, String id) => [
  for (final m in c.modules)
    if (m.isPresent && m.needs.contains(id)) m.id,
];

List<String> editorModules(String choice) => switch (choice) {
  'nvim' => ['nvim', 'astronvim'],
  'vscode' => ['vscode'],
  'both' => ['nvim', 'astronvim', 'vscode'],
  _ => throw ArgumentError.value(choice, 'choice', 'Editor desconhecido'),
};

List<String> profileTargets(Catalog c, String profile, {String? editor}) {
  final base = c.profiles[profile] ?? const <String>[];
  if (editor == null) return List.of(base);
  final chosen = editorModules(editor).toSet();
  final inBase = base.toSet();
  return [
    for (final m in c.modules)
      if (chosen.contains(m.id) ||
          (inBase.contains(m.id) && !_editorIds.contains(m.id)))
        m.id,
  ];
}

bool profileNeedsEditorChoice(Catalog c, String profile) {
  if (profile != 'dev' && profile != 'full') return false;
  return !(c.byId('nvim')?.isPresent ?? false) &&
      !(c.byId('vscode')?.isPresent ?? false);
}
