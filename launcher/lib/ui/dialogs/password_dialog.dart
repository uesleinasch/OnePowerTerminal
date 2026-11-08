import 'package:flutter/material.dart';

import 'dialog_layout.dart';

final _control = RegExp(r'[\x00-\x1f\x7f]');

Future<String?> showPasswordDialog(BuildContext context, {String? error}) {
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _PasswordDialog(error: error),
  );
}

class _PasswordDialog extends StatefulWidget {
  const _PasswordDialog({this.error});

  final String? error;

  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  final _controller = TextEditingController();
  late String? _error = widget.error;
  var _visible = false;

  @override
  void dispose() {
    _controller.clear();
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text;
    if (text.isEmpty) {
      setState(() => _error = 'Digite a senha para continuar.');
      return;
    }
    if (_control.hasMatch(text)) {
      setState(() => _error = 'A senha não pode ter quebra de linha.');
      return;
    }
    Navigator.of(context).pop(text);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      constraints: kDialogConstraints,
      icon: const Icon(Icons.lock_rounded),
      title: const Text('Senha de administrador'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Alguns módulos instalam pacotes do sistema. A senha libera o '
            'sudo durante esta fila e é descartada em seguida; o '
            'PowerTerminal não a salva.',
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            maxLines: 1,
            obscureText: !_visible,
            autofillHints: const [AutofillHints.password],
            enableSuggestions: false,
            autocorrect: false,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              labelText: 'Senha',
              floatingLabelBehavior: FloatingLabelBehavior.always,
              errorText: _error,
              suffixIcon: IconButton(
                tooltip: _visible ? 'Ocultar senha' : 'Mostrar senha',
                icon: Icon(
                  _visible
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                ),
                onPressed: () => setState(() => _visible = !_visible),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Liberar')),
      ],
    );
  }
}
