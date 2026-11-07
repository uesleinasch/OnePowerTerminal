import 'package:flutter/material.dart';

import '../model/catalog.dart';
import '../queue/queue_controller.dart';
import '../theme/app_theme.dart';
import 'home_actions.dart';

class ModuleStatusChip extends StatelessWidget {
  const ModuleStatusChip({
    super.key,
    required this.module,
    required this.status,
  });

  final ModuleInfo module;
  final CardStatus status;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final pn = Theme.of(context).extension<PnColors>()!;
    final (IconData icon, String text, Color bg, Color fg)? chip =
        switch (status.phase) {
          CardPhase.queued => (
            Icons.schedule_rounded,
            'Na fila',
            cs.surfaceContainerHighest,
            cs.onSurfaceVariant,
          ),
          CardPhase.running => (
            Icons.autorenew_rounded,
            switch (status.kind) {
              OpKind.update => 'Atualizando',
              OpKind.remove => 'Removendo',
              _ => 'Instalando',
            },
            cs.primaryContainer,
            cs.onPrimaryContainer,
          ),
          _ => switch (module.state) {
            ModuleState.installed => (
              Icons.check_circle_rounded,
              'Instalado',
              pn.successContainer,
              pn.onSuccessContainer,
            ),
            ModuleState.preexisting => (
              Icons.check_circle_rounded,
              'Já estava instalado',
              pn.successContainer,
              pn.onSuccessContainer,
            ),
            ModuleState.available => null,
          },
        };
    if (chip == null) return const SizedBox.shrink();
    final (icon, text, bg, fg) = chip;
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (status.phase == CardPhase.running)
            _SpinningIcon(icon, color: fg)
          else
            Icon(icon, size: 16, color: fg),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium
                  ?.copyWith(color: fg),
            ),
          ),
        ],
      ),
    );
  }
}

class ModuleTag extends StatelessWidget {
  const ModuleTag(this.icon, this.text, {super.key, this.accent = false});

  final IconData icon;
  final String text;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = accent ? cs.tertiaryContainer : cs.surfaceContainerHigh;
    final fg = accent ? cs.onTertiaryContainer : cs.onSurfaceVariant;
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium
                  ?.copyWith(color: fg),
            ),
          ),
        ],
      ),
    );
  }
}

class ModuleProgress extends StatelessWidget {
  const ModuleProgress({super.key, required this.status});

  final CardStatus status;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final p = status.progress;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LinearProgressIndicator(
          value: p,
          borderRadius: BorderRadius.circular(2),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: Text(
                status.step ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant),
              ),
            ),
            if (p != null)
              Text(
                '${(p * 100).round()}%',
                style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant),
              ),
          ],
        ),
      ],
    );
  }
}

class ModuleActions extends StatelessWidget {
  const ModuleActions({
    super.key,
    required this.module,
    required this.status,
    required this.actions,
    this.onDequeue,
    this.waitingFor,
  });

  final ModuleInfo module;
  final CardStatus status;
  final HomeActions actions;
  final VoidCallback? onDequeue;
  final String? waitingFor;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final m = module;
    final failed = status.phase == CardPhase.failed;
    final queued = status.phase == CardPhase.queued;
    final note = tt.labelMedium?.copyWith(color: cs.onSurfaceVariant);

    final buttons = <Widget>[];
    if (queued) {
      buttons.add(
        TextButton(onPressed: onDequeue, child: const Text('Tirar da fila')),
      );
    } else {
      if (failed) {
        buttons.add(
          TextButton(onPressed: actions.showLog, child: const Text('Ver log')),
        );
      }
      if (m.state == ModuleState.available) {
        buttons.add(
          FilledButton.icon(
            onPressed: () => actions.install(m.id),
            icon: const Icon(Icons.download_rounded),
            label: const Text('Instalar'),
          ),
        );
      } else {
        if (m.state == ModuleState.preexisting) {
          buttons.add(Text('Instalado fora do PowerTerminal', style: note));
        } else if (!m.canRemove) {
          buttons.add(Text('Base de outros módulos', style: note));
        } else {
          buttons.add(
            TextButton(
              onPressed: () => actions.remove(m.id),
              style: TextButton.styleFrom(foregroundColor: cs.error),
              child: const Text('Remover'),
            ),
          );
        }
        if (m.canUpdate) {
          buttons.add(
            FilledButton.tonalIcon(
              onPressed: () => actions.update(m.id),
              icon: const Icon(Icons.update_rounded),
              label: const Text('Atualizar'),
            ),
          );
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (failed && status.error != null)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: cs.errorContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.error_rounded, size: 16, color: cs.onErrorContainer),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    status.error!,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: tt.labelMedium?.copyWith(color: cs.onErrorContainer),
                  ),
                ),
              ],
            ),
          ),
        if (queued && waitingFor != null)
          Row(
            children: [
              Expanded(
                child: Text(
                  'Aguardando $waitingFor',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: note,
                ),
              ),
              ...buttons,
            ],
          )
        else
          Wrap(
            alignment: WrapAlignment.end,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: buttons,
          ),
      ],
    );
  }
}

class _SpinningIcon extends StatefulWidget {
  const _SpinningIcon(this.icon, {required this.color});

  final IconData icon;
  final Color color;

  @override
  State<_SpinningIcon> createState() => _SpinningIconState();
}

class _SpinningIconState extends State<_SpinningIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RotationTransition(
    turns: _controller,
    child: Icon(widget.icon, size: 16, color: widget.color),
  );
}
