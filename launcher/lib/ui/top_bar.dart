import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

const _kWideBar = 900.0;

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
    final brand = Row(
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
                style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ],
    );
    final search = SizedBox(
      height: 48,
      child: TextField(
        onChanged: onQuery,
        decoration: InputDecoration(
          hintText: 'Buscar módulo, ferramenta…',
          prefixIcon: const Icon(Icons.search_rounded),
          filled: true,
          fillColor: cs.surfaceContainerHigh,
          contentPadding: EdgeInsets.zero,
          border: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(28)),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
    final actions = Row(
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
          icon: Icon(
            Theme.of(context).brightness == Brightness.dark
                ? Icons.light_mode_rounded
                : Icons.dark_mode_rounded,
          ),
        ),
        IconButton(
          tooltip: 'Atividade',
          onPressed: onOpenActivity,
          icon: Badge(
            isLabelVisible: activityCount > 0,
            backgroundColor: cs.error,
            textColor: cs.onError,
            label: Text('$activityCount'),
            child: const Icon(Icons.receipt_long_rounded),
          ),
        ),
      ],
    );
    final width = MediaQuery.sizeOf(context).width;
    return Padding(
      padding: EdgeInsets.fromLTRB(width < 560 ? 16 : 24, 12, 24, 12),
      child: width >= _kWideBar
          ? Row(
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 300),
                  child: brand,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        minWidth: 240,
                        maxWidth: 420,
                      ),
                      child: search,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                actions,
              ],
            )
          : Wrap(
              spacing: 16,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                brand,
                ConstrainedBox(
                  constraints: const BoxConstraints(
                    minWidth: 240,
                    maxWidth: 420,
                  ),
                  child: search,
                ),
                actions,
              ],
            ),
    );
  }
}
