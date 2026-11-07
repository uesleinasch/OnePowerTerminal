import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../model/catalog.dart';
import '../queue/queue_controller.dart';
import '../theme/app_theme.dart';
import 'format.dart';
import 'home_actions.dart';
import 'module_icons.dart';
import 'module_parts.dart';

IconData itemIcon(String kind) => switch (kind) {
  'bin' || 'shell' || 'login_shell' => Icons.terminal_rounded,
  'apt' => Icons.inventory_2_rounded,
  'dir' => Icons.folder_rounded,
  'config' => Icons.settings_rounded,
  'file' => Icons.insert_drive_file_rounded,
  'link' => Icons.link_rounded,
  'repo' || 'apt_repo' => Icons.cloud_download_rounded,
  'font' => Icons.font_download_rounded,
  'group' || 'subids' => Icons.group_rounded,
  'service' || 'user_unit' => Icons.settings_applications_rounded,
  'pipx' => Icons.extension_rounded,
  _ => Icons.label_outline_rounded,
};

class ModuleDetail extends StatelessWidget {
  const ModuleDetail({
    super.key,
    required this.module,
    required this.status,
    required this.catalog,
    required this.actions,
    required this.onClose,
    this.onDequeue,
    this.waitingFor,
    this.asPage = false,
  });

  final ModuleInfo module;
  final CardStatus status;
  final Catalog catalog;
  final HomeActions actions;
  final VoidCallback onClose;
  final VoidCallback? onDequeue;
  final String? waitingFor;
  final bool asPage;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final m = module;
    final busy = status.phase == CardPhase.running;
    final needs = [for (final n in m.needs) catalog.byId(n)?.name ?? n];
    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): onClose},
      child: Focus(
        autofocus: true,
        child: Material(
          color: cs.surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                child: Row(
                  children: [
                    if (asPage)
                      IconButton(
                        tooltip: 'Voltar',
                        onPressed: onClose,
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                    Padding(
                      padding: EdgeInsets.only(left: asPage ? 0 : 8),
                      child: Icon(moduleIcon(m.id), color: cs.primary),
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
                    if (!asPage)
                      IconButton(
                        tooltip: 'Fechar detalhe',
                        onPressed: onClose,
                        icon: const Icon(Icons.close_rounded),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          categoryTitles[m.category] ?? m.category,
                          style: tt.labelLarge?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                        ModuleStatusChip(module: m, status: status),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SelectableText(m.about, style: tt.bodyMedium),
                    if (m.provides.isNotEmpty)
                      _section(context, 'O que instala', [
                        for (final i in m.provides) _item(context, i),
                      ]),
                    if (needs.isNotEmpty)
                      _section(context, 'Depende de', [
                        for (final n in needs)
                          _row(context, Icons.link_rounded, Text(n)),
                      ]),
                    if (m.requires.isNotEmpty)
                      _section(context, 'Pré-requisitos', [
                        for (final r in m.requires)
                          _row(
                            context,
                            Icons.build_rounded,
                            Text(r, style: _mono(context)),
                          ),
                      ]),
                    if (m.state == ModuleState.preexisting)
                      _section(context, 'Registrado pelo PowerTerminal', [
                        Text(
                          'Instalado fora do PowerTerminal: nada para remover aqui.',
                          style: tt.bodyMedium?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ])
                    else if (m.receipt.isNotEmpty)
                      _section(context, 'Registrado pelo PowerTerminal', [
                        for (final i in m.receipt) _item(context, i),
                      ]),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        ModuleTag(Icons.schedule_rounded, '~${m.minutes} min'),
                        ModuleTag(Icons.storage_rounded, formatMb(m.mb)),
                        if (m.sudo)
                          const ModuleTag(
                            Icons.security_rounded,
                            'sudo',
                            accent: true,
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
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
            ],
          ),
        ),
      ),
    );
  }

  TextStyle? _mono(BuildContext context) =>
      Theme.of(context).textTheme.bodyMedium
          ?.copyWith(fontFamily: kMonoFont, fontSize: 12.5);

  Widget _section(BuildContext context, String title, List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }

  Widget _row(BuildContext context, IconData icon, Widget child) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 16,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(child: child),
        ],
      ),
    );
  }

  Widget _item(BuildContext context, ModuleItem i) => _row(
    context,
    itemIcon(i.kind),
    SelectableText(i.value, style: _mono(context)),
  );
}
