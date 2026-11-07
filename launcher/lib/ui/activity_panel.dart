import 'package:flutter/material.dart';

import '../model/catalog.dart';
import '../queue/queue_controller.dart';
import '../theme/app_theme.dart';

const kActivityPanelWidth = 340.0;
const kActivityWideBreakpoint = 900.0;

String _kindLabel(OpKind k) => switch (k) {
  OpKind.install => 'instalar',
  OpKind.update => 'atualizar',
  OpKind.remove => 'remover',
};

enum LogLineKind { plain, launcher, success, dryRun }

final _successLine = RegExp(
  r'^\[powerterminal\] (OK: |Tema: |.*(conclu[ií]d[ao]\.|atualizados\.|'
  r'Pacote criado: |adicionado ao grupo|configurados para|habilitado para|'
  r'(Neovim|VS Code) instalado: |definido como shell padrão))',
);

LogLineKind classifyLogLine(String line) {
  if (line.startsWith('[launcher]')) return LogLineKind.launcher;
  if (line.startsWith('[dry-run]')) return LogLineKind.dryRun;
  if (_successLine.hasMatch(line)) return LogLineKind.success;
  return LogLineKind.plain;
}

class ActivityPanel extends StatefulWidget {
  const ActivityPanel({
    super.key,
    required this.controller,
    this.onClose,
    this.compact = false,
  });

  final QueueController controller;
  final VoidCallback? onClose;
  final bool compact;

  @override
  State<ActivityPanel> createState() => _ActivityPanelState();
}

class _ActivityPanelState extends State<ActivityPanel> {
  final _scroll = ScrollController();
  var _follow = true;
  var _lastCount = 0;

  bool _atBottom(ScrollMetrics m) => m.maxScrollExtent - m.pixels <= 24;

  void _followEnd(int count) {
    if (count == _lastCount) return;
    _lastCount = count;
    if (!_follow) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients && _follow) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Material(
      color: cs.surfaceContainerLow,
      child: ListenableBuilder(
        listenable: widget.controller,
        builder: (context, _) {
          final ctl = widget.controller;
          final log = ctl.log;
          _followEnd(ctl.logAppended);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 12, 0),
                child: Row(
                  children: [
                    Expanded(child: Text('Atividade', style: tt.titleMedium)),
                    IconButton(
                      tooltip: 'Fechar atividade',
                      onPressed: widget.onClose,
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              _label(context, 'Fila'),
              Flexible(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: widget.compact ? 72 : 160,
                  ),
                  child: ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    children: _queue(context),
                  ),
                ),
              ),
              _label(context, 'Log · ~/.local/state/powerterminal/install.log'),
              Expanded(
                child: Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: NotificationListener<ScrollNotification>(
                    onNotification: (n) {
                      if (n.depth == 0) _follow = _atBottom(n.metrics);
                      return false;
                    },
                    child: SelectionArea(
                      child: ListView.builder(
                        controller: _scroll,
                        padding: const EdgeInsets.all(12),
                        itemCount: log.length,
                        itemBuilder: (context, i) => Text(
                          log[i],
                          style: tt.bodySmall?.copyWith(
                            fontFamily: kMonoFont,
                            fontSize: 12,
                            height: 18 / 12,
                            color: switch (classifyLogLine(log[i])) {
                              LogLineKind.launcher => cs.primary,
                              LogLineKind.success =>
                                Theme.of(context)
                                        .extension<PnColors>()
                                        ?.success ??
                                    cs.onSurface,
                              LogLineKind.dryRun => cs.onSurfaceVariant,
                              LogLineKind.plain => cs.onSurface,
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _label(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
    child: Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.labelMedium
          ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
    ),
  );

  List<Widget> _queue(BuildContext context) {
    final ctl = widget.controller;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    String name(String id) => ctl.catalog?.byId(id)?.name ?? id;
    final current = ctl.current;
    final pending = ctl.pending;
    if (current == null && pending.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
          child: Text(
            'Nada na fila.',
            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
        ),
      ];
    }
    Widget row({
      required Widget leading,
      required String title,
      required Widget trailing,
      bool active = false,
    }) {
      final fg = active ? cs.onSecondaryContainer : cs.onSurface;
      return Container(
        padding: const EdgeInsets.all(8),
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: active ? cs.secondaryContainer : null,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            SizedBox(width: 24, height: 24, child: Center(child: leading)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: (active ? tt.labelLarge : tt.bodyMedium)?.copyWith(
                  color: fg,
                ),
              ),
            ),
            const SizedBox(width: 12),
            trailing,
          ],
        ),
      );
    }

    return [
      if (current != null)
        row(
          active: true,
          leading: const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          title: name(current.id),
          trailing: Builder(
            builder: (context) {
              final p = ctl.status(current.id).progress;
              return p == null
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      '${(p * 100).round()}%',
                      style: tt.bodySmall?.copyWith(
                        color: cs.onSecondaryContainer,
                      ),
                    );
            },
          ),
        ),
      for (final p in pending)
        row(
          leading: Icon(
            Icons.schedule_rounded,
            size: 20,
            color: cs.onSurfaceVariant,
          ),
          title: name(p.id),
          trailing: Text(
            _kindLabel(p.kind),
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ),
    ];
  }
}
