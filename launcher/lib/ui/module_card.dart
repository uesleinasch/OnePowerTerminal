import 'package:flutter/material.dart';

import '../model/catalog.dart';
import '../queue/queue_controller.dart';
import '../theme/app_theme.dart';
import 'format.dart';
import 'home_actions.dart';
import 'module_icons.dart';
import 'module_parts.dart';

class ModuleCard extends StatelessWidget {
  const ModuleCard({
    super.key,
    required this.module,
    required this.status,
    required this.actions,
    this.onDequeue,
    this.waitingFor,
    this.onOpen,
  });

  final ModuleInfo module;
  final CardStatus status;
  final HomeActions actions;
  final VoidCallback? onDequeue;
  final String? waitingFor;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final m = module;
    final busy = status.phase == CardPhase.running;
    final present = m.isPresent;
    return Card(
      clipBehavior: Clip.antiAlias,
      color: present ? cs.surfaceContainerLow : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: busy ? cs.primary : cs.outlineVariant),
      ),
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: present
                          ? cs.surfaceContainerHighest
                          : cs.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      moduleIcon(m.id),
                      color: present
                          ? cs.onSurfaceVariant
                          : cs.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          m.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tt.titleMedium,
                        ),
                        Text(
                          m.id,
                          style: tt.bodyMedium?.copyWith(
                            fontFamily: kMonoFont,
                            fontSize: 12.5,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: ModuleStatusChip(module: m, status: status),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                m.description,
                style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              ),
              const Spacer(),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  ModuleTag(Icons.schedule_rounded, '~${m.minutes} min'),
                  ModuleTag(Icons.storage_rounded, formatMb(m.mb)),
                  if (m.sudo)
                    const Tooltip(
                      message: 'O sudo fica liberado enquanto houver instalação na fila',
                      child: ModuleTag(
                        Icons.security_rounded,
                        'sudo',
                        accent: true,
                      ),
                    ),
                  for (final n in m.needs)
                    ModuleTag(Icons.link_rounded, 'requer $n'),
                ],
              ),
              const SizedBox(height: 12),
              if (busy)
                ModuleProgress(status: status)
              else
                ModuleActions(
                  module: m,
                  status: status,
                  actions: actions,
                  onDequeue: onDequeue,
                  waitingFor: waitingFor,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
