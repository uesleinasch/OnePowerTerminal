import 'package:flutter/material.dart';

import '../../model/catalog.dart';
import 'dialog_layout.dart';

Future<bool> showAdoptDialog(
  BuildContext context, {
  required ModuleInfo module,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      constraints: kDialogConstraints,
      icon: const Icon(Icons.verified_user_rounded),
      title: Text('Gerenciar ${module.name}?'),
      content: Text(
        'O PowerTerminal aplica a config dele (a sua vira backup) e passa a '
        'cuidar do que reconhecer deste programa. O que ele assumir sai junto '
        'no Remover.',
        style: Theme.of(ctx).textTheme.bodyMedium
            ?.copyWith(color: Theme.of(ctx).colorScheme.onSurfaceVariant),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Gerenciar'),
        ),
      ],
    ),
  );
  return ok ?? false;
}
