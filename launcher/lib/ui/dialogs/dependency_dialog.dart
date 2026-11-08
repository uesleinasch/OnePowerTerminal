import 'package:flutter/material.dart';

import '../../model/catalog.dart';
import '../../theme/app_theme.dart';
import '../format.dart';
import '../dashed_border.dart';
import '../module_icons.dart';
import '../module_parts.dart';
import 'dialog_layout.dart';

String joinNames(List<String> names) => names.length > 1
    ? '${names.sublist(0, names.length - 1).join(', ')} e ${names.last}'
    : names.first;

Future<bool> showDependencyDialog(
  BuildContext context, {
  required ModuleInfo target,
  required List<ModuleInfo> deps,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => _DependencyDialog(target: target, deps: deps),
  );
  return ok ?? false;
}

class _DependencyDialog extends StatelessWidget {
  const _DependencyDialog({required this.target, required this.deps});

  final ModuleInfo target;
  final List<ModuleInfo> deps;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final rows = [...deps, target];
    final minutes = rows.fold<int>(0, (a, m) => a + m.minutes);
    final mb = rows.fold<int>(0, (a, m) => a + m.mb);
    final names = joinNames([for (final m in deps) m.name]);
    final many = deps.length > 1;
    return AlertDialog(
      constraints: kDialogConstraints,
      icon: const Icon(Icons.account_tree_rounded),
      title: Text('${target.name} depende de $names'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$names ainda não ${many ? 'estão instalados' : 'está instalado'}'
              ' e ${many ? 'precisam' : 'precisa'} entrar antes na fila. '
              'Sem ${many ? 'eles' : 'ele'}, ${target.name} não funciona.',
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            for (final m in rows)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _DepRow(module: m, isTarget: identical(m, target)),
              ),
            const SizedBox(height: 4),
            Text(
              'Total: ${rows.length} módulos · ~$minutes min · ${formatMb(mb)}',
              style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          autofocus: true,
          onPressed: () => Navigator.of(context).pop(true),
          child: Text('Instalar os ${rows.length}'),
        ),
      ],
    );
  }
}

class _DepRow extends StatelessWidget {
  const _DepRow({required this.module, required this.isTarget});

  final ModuleInfo module;
  final bool isTarget;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final muted = tt.bodySmall?.copyWith(color: cs.onSurfaceVariant);
    final row = Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: cs.secondaryContainer,
            foregroundColor: cs.onSecondaryContainer,
            child: Icon(moduleIcon(module.id), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: module.name, style: tt.titleSmall),
                      TextSpan(
                        text: '  ${module.id}',
                        style: muted?.copyWith(fontFamily: kMonoFont),
                      ),
                      if (isTarget)
                        TextSpan(text: ' · o que você pediu', style: muted),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    ModuleTag(Icons.schedule_rounded, '~${module.minutes} min'),
                    ModuleTag(Icons.storage_rounded, formatMb(module.mb)),
                    if (module.sudo)
                      const ModuleTag(
                        Icons.security_rounded,
                        'sudo',
                        accent: true,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
    return KeyedSubtree(
      key: ValueKey('dep-row-${module.id}'),
      child: isTarget
          ? CustomPaint(
              painter: DashedBorderPainter(
                color: cs.outlineVariant,
                radius: 12,
              ),
              child: row,
            )
          : DecoratedBox(
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: row,
            ),
    );
  }
}
