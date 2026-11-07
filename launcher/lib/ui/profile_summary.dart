import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../model/catalog.dart';
import '../model/deps.dart';
import 'format.dart';
import 'home_actions.dart';

class ProfileSummary extends StatelessWidget {
  const ProfileSummary({
    super.key,
    required this.catalog,
    required this.profile,
    required this.actions,
  });

  final Catalog catalog;
  final String profile;
  final HomeActions actions;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final all = profile == 'todos';
    final ids = all
        ? [for (final m in catalog.modules) m.id]
        : profileTargets(
            catalog,
            profile,
            editor: profileEditor(catalog, profile) ?? defaultEditor(profile),
          );
    final mods = [for (final id in ids) ?catalog.byId(id)];
    final missing = [
      for (final id in installPlan(catalog, ids)) ?catalog.byId(id),
    ];
    final installed = mods.where((m) => m.isPresent).length;
    final minutes = missing.fold<int>(0, (a, m) => a + m.minutes);
    final mb = missing.fold<int>(0, (a, m) => a + m.mb);
    final fact = tt.labelLarge?.copyWith(color: cs.onSurfaceVariant);

    Widget factChip(IconData icon, String text) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: cs.onSurfaceVariant),
        const SizedBox(width: 6),
        Text(text, style: fact),
      ],
    );

    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          all ? 'Todos os módulos' : 'Perfil $profile',
          style: tt.titleMedium,
        ),
        Text(
          profileSubtitles[profile] ?? '',
          style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
        ),
      ],
    );
    final facts = Wrap(
      spacing: 20,
      runSpacing: 4,
      children: [
        factChip(
          Icons.check_circle_rounded,
          '$installed de ${mods.length} instalados',
        ),
        factChip(Icons.schedule_rounded, '~$minutes min'),
        factChip(Icons.storage_rounded, formatMb(mb)),
      ],
    );
    final Widget? action = all
        ? null
        : missing.isNotEmpty
        ? FilledButton.icon(
            onPressed: () => actions.installProfile(profile),
            icon: const Icon(Icons.download_rounded),
            label: Text(
              'Instalar ${missing.length} '
              'restante${missing.length > 1 ? 's' : ''}',
            ),
          )
        : FilledButton.tonalIcon(
            onPressed: () => actions.updateProfile(profile),
            icon: const Icon(Icons.update_rounded),
            label: const Text('Atualizar perfil'),
          );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: LayoutBuilder(
        builder: (context, box) {
          final scale = MediaQuery.textScalerOf(context).scale(1);
          final wide = box.maxWidth >= 820 * math.max(1.0, scale);
          if (wide) {
            return Row(
              children: [
                Expanded(child: heading),
                const SizedBox(width: 24),
                facts,
                if (action != null) ...[const SizedBox(width: 24), action],
              ],
            );
          }
          return Wrap(
            spacing: 24,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 200, maxWidth: 520),
                child: heading,
              ),
              facts,
              ?action,
            ],
          );
        },
      ),
    );
  }
}
