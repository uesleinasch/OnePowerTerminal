import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class TopBar extends StatelessWidget {
  const TopBar({
    super.key,
    required this.version,
    required this.distro,
    required this.arch,
    required this.onQuery,
    required this.sudoUnlocked,
    required this.activityCount,
    this.onToggleTheme,
    this.onOpenActivity,
  });

  final String version, arch;
  final String? distro;
  final ValueChanged<String> onQuery;
  final bool sudoUnlocked;
  final int activityCount;
  final VoidCallback? onToggleTheme, onOpenActivity;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final info = ['v$version', ?distro, arch].join(' · ');
    return Padding(
      padding: EdgeInsets.fromLTRB(
        MediaQuery.sizeOf(context).width < 560 ? 16 : 24,
        12,
        16,
        12,
      ),
      child: Wrap(
        spacing: 16,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '>_',
                  style: tt.labelLarge?.copyWith(
                    fontFamily: kMonoFont,
                    color: cs.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PowerTerminal',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tt.titleMedium,
                    ),
                    Text(
                      info,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tt.labelMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 240, maxWidth: 420),
            child: TextField(
              onChanged: onQuery,
              decoration: InputDecoration(
                hintText: 'Buscar módulos',
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: cs.surfaceContainerHigh,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                border: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(28)),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (sudoUnlocked)
                Container(
                  height: 32,
                  padding: const EdgeInsets.only(left: 8, right: 12),
                  margin: const EdgeInsets.only(right: 4),
                  decoration: BoxDecoration(
                    color: cs.tertiaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.lock_open_rounded,
                        size: 18,
                        color: cs.onTertiaryContainer,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'sudo liberado',
                        style: tt.labelMedium?.copyWith(
                          color: cs.onTertiaryContainer,
                        ),
                      ),
                    ],
                  ),
                ),
              IconButton(
                tooltip: 'Alternar tema',
                onPressed: onToggleTheme,
                icon: const Icon(Icons.contrast_rounded),
              ),
              IconButton(
                tooltip: 'Atividade',
                onPressed: onOpenActivity,
                icon: Badge(
                  isLabelVisible: activityCount > 0,
                  label: Text('$activityCount'),
                  child: const Icon(Icons.list_alt_rounded),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
