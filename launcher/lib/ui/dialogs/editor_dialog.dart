import 'package:flutter/material.dart';

Future<String?> showEditorDialog(BuildContext context) {
  return showDialog<String>(
    context: context,
    builder: (_) => const _EditorDialog(),
  );
}

class _EditorDialog extends StatefulWidget {
  const _EditorDialog();

  @override
  State<_EditorDialog> createState() => _EditorDialogState();
}

class _EditorDialogState extends State<_EditorDialog> {
  var _choice = 'nvim';

  static const _options = [
    ('nvim', 'Neovim + AstroNvim', 'Config versionada no repo'),
    ('vscode', 'Visual Studio Code', 'Só o editor'),
    ('both', 'Os dois', null),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      icon: const Icon(Icons.code_rounded),
      title: const Text('Qual editor?'),
      content: SizedBox(
        width: 360,
        child: RadioGroup<String>(
          groupValue: _choice,
          onChanged: (v) => setState(() => _choice = v ?? _choice),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Dá para instalar o outro depois, pelo próprio card.',
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 8),
              for (final (value, title, subtitle) in _options)
                RadioListTile<String>(
                  value: value,
                  title: Text(title),
                  subtitle: subtitle == null ? null : Text(subtitle),
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
          onPressed: () => Navigator.of(context).pop(_choice),
          child: const Text('Continuar'),
        ),
      ],
    );
  }
}
