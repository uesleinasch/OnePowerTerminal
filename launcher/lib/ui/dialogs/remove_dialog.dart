import 'package:flutter/material.dart';

import '../../model/catalog.dart';
import '../format.dart';
import 'dependency_dialog.dart';

class RemoveChoice {
  RemoveChoice({this.purgeData = false});

  final bool purgeData;
}

Future<RemoveChoice?> showRemoveDialog(
  BuildContext context, {
  required ModuleInfo module,
  required List<ModuleInfo> dependents,
}) {
  return showDialog<RemoveChoice>(
    context: context,
    builder: (_) => _RemoveDialog(module: module, dependents: dependents),
  );
}

class _RemoveDialog extends StatefulWidget {
  const _RemoveDialog({required this.module, required this.dependents});

  final ModuleInfo module;
  final List<ModuleInfo> dependents;

  @override
  State<_RemoveDialog> createState() => _RemoveDialogState();
}

class _RemoveDialogState extends State<_RemoveDialog> {
  var _purge = false;

  Future<void> _confirm() async {
    if (_purge) {
      final sure = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: Icon(
            Icons.delete_forever_rounded,
            color: Theme.of(ctx).colorScheme.error,
          ),
          title: const Text('Apagar também os dados?'),
          content: Text(
            'Imagens, containers e volumes de ${widget.module.name} '
            '(${formatMb(widget.module.dataMb ?? 0)}) serão apagados e não '
            'dá para desfazer.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Voltar'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error,
                foregroundColor: Theme.of(ctx).colorScheme.onError,
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Apagar tudo'),
            ),
          ],
        ),
      );
      if (sure != true || !mounted) return;
    }
    Navigator.of(context).pop(RemoveChoice(purgeData: _purge));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final m = widget.module;
    final deps = widget.dependents;
    final many = deps.length > 1;
    final hasData = m.dataMb != null;
    return AlertDialog(
      icon: Icon(Icons.delete_rounded, color: cs.error),
      title: Text('Remover ${m.name}?'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                m.origin == 'deduced'
                    ? 'Instalado antes do controle de remoção: só os links e '
                          'arquivos do PowerTerminal saem. Configurações '
                          'pessoais em ~/.config e backups .pnbak ficam onde '
                          'estão.'
                    : 'Sai o que o PowerTerminal instalou. Configurações '
                          'pessoais em ~/.config e backups .pnbak ficam onde '
                          'estão.',
                style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              ),
              if (deps.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cs.errorContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.warning_rounded,
                        color: cs.onErrorContainer,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${joinNames([for (final d in deps) d.name])} '
                              '${many ? 'dependem' : 'depende'} de ${m.name}',
                              style: tt.titleSmall?.copyWith(
                                color: cs.onErrorContainer,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${many ? 'Eles continuam instalados, mas param' : 'Continua instalado, mas para'}'
                              ' de funcionar até ${m.name} voltar.',
                              style: tt.bodySmall?.copyWith(
                                color: cs.onErrorContainer,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (hasData)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: _purge,
                  onChanged: (v) => setState(() => _purge = v ?? false),
                  title: Text(
                    'Apagar também imagens, containers e volumes '
                    '(${formatMb(m.dataMb!)})',
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: cs.error,
            foregroundColor: cs.onError,
          ),
          onPressed: _confirm,
          child: Text(deps.isEmpty ? 'Remover' : 'Remover mesmo assim'),
        ),
      ],
    );
  }
}
