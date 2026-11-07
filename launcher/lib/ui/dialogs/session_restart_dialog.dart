import 'package:flutter/material.dart';

import '../../queue/queue_controller.dart';
import '../../theme/app_theme.dart';

Future<bool> showSessionRestartDialog(
  BuildContext context,
  List<PendingRestart> restarts,
) async {
  final cs = Theme.of(context).colorScheme;
  final tt = Theme.of(context).textTheme;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: const Icon(Icons.logout_rounded),
      title: const Text('Para concluir, encerre a sessão'),
      content: SizedBox(
        width: 380,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Estas mudanças só valem em uma sessão nova:',
                style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              for (final r in restarts)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: r.module,
                          style: tt.bodyMedium?.copyWith(fontFamily: kMonoFont),
                        ),
                        TextSpan(text: ' · ${r.reason}'),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Depois'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Encerrar sessão agora'),
        ),
      ],
    ),
  );
  return ok ?? false;
}
