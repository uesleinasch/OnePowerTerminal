import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../cli/cli.dart';
import '../model/catalog.dart';
import '../queue/queue_controller.dart';
import '../system/prefs.dart';
import '../theme/app_theme.dart';
import 'activity_panel.dart';
import 'format.dart';
import 'home_actions.dart';
import 'module_card.dart';
import 'module_detail.dart';
import 'profile_filter.dart';
import 'profile_summary.dart';
import 'top_bar.dart';

export 'home_actions.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.controller,
    required this.actions,
    this.onToggleTheme,
    this.activityOpen,
    this.prefsFile,
  });

  final QueueController controller;
  final HomeActions actions;
  final VoidCallback? onToggleTheme;
  final ValueNotifier<bool>? activityOpen;
  final File? prefsFile;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  var _profile = 'todos';
  late final String? _savedProfile = widget.prefsFile == null
      ? null
      : Prefs.load(widget.prefsFile!).profile;
  var _restored = false;
  var _onlyInstalled = false;
  var _query = '';
  String? _detailId;
  late final ValueNotifier<bool> _ownOpen = ValueNotifier(false);
  ValueNotifier<bool> get _open => widget.activityOpen ?? _ownOpen;

  @override
  void dispose() {
    _ownOpen.dispose();
    super.dispose();
  }

  bool _visible(Catalog c, ModuleInfo m) {
    if (_profile != 'todos' &&
        !(c.profiles[_profile]?.contains(m.id) ?? false)) {
      return false;
    }
    if (_onlyInstalled && !m.isPresent) return false;
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return m.name.toLowerCase().contains(q) ||
        m.id.toLowerCase().contains(q) ||
        m.description.toLowerCase().contains(q);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final ctl = widget.controller;
        final catalog = ctl.catalog;
        if (catalog == null) {
          if (ctl.catalogError != null) return _errorView(context);
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (!_restored) {
          _restored = true;
          final saved = _savedProfile;
          if (saved != null &&
              (saved == 'todos' || catalog.profiles.containsKey(saved))) {
            _profile = saved;
          }
        }
        final w = MediaQuery.sizeOf(context).width;
        final activity = ctl.pending.length + (ctl.current != null ? 1 : 0);
        return Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                TopBar(
                  version: catalog.version,
                  distro: catalog.distro,
                  arch: catalog.arch,
                  onQuery: (q) => setState(() => _query = q),
                  sudoUnlocked: ctl.sudoUnlocked,
                  activityCount: activity,
                  onToggleTheme: widget.onToggleTheme,
                  onOpenActivity: () {
                    if (_detailId != null) {
                      setState(() => _detailId = null);
                      _open.value = true;
                    } else {
                      _open.value = !_open.value;
                    }
                  },
                ),
                if (ctl.catalogError != null) _errorBanner(context),
                Expanded(
                  child: _withPanel(
                    w,
                    (cw) => ListView(
                      padding: EdgeInsets.fromLTRB(
                        _margin(cw),
                        4,
                        _margin(cw),
                        32,
                      ),
                      children: [
                        ProfileFilter(
                          profile: _profile,
                          onProfile: (p) {
                            setState(() => _profile = p);
                            final f = widget.prefsFile;
                            if (f != null) Prefs(profile: p).save(f);
                          },
                          onlyInstalled: _onlyInstalled,
                          onOnlyInstalled: (v) =>
                              setState(() => _onlyInstalled = v),
                        ),
                        const SizedBox(height: 16),
                        ProfileSummary(
                          catalog: catalog,
                          profile: _profile,
                          actions: widget.actions,
                        ),
                        const SizedBox(height: 20),
                        ..._sections(context, catalog),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  double _margin(double contentWidth) => contentWidth < 560 ? 16.0 : 24.0;

  Widget _withPanel(double width, Widget Function(double) content) {
    return ValueListenableBuilder<bool>(
      valueListenable: _open,
      builder: (context, open, _) {
        final detail = _detailId;
        if (!open && detail == null) return content(width);
        final wide = width >= kActivityWideBreakpoint;
        final panel = detail != null
            ? _detail(detail, asPage: false)
            : ActivityPanel(
                controller: widget.controller,
                onClose: () => _open.value = false,
                compact: !wide,
              );
        if (wide) {
          return Row(
            children: [
              Expanded(child: content(width - kActivityPanelWidth - 1)),
              const VerticalDivider(width: 1),
              SizedBox(width: kActivityPanelWidth, child: panel),
            ],
          );
        }
        return LayoutBuilder(
          builder: (context, box) => Column(
            children: [
              Expanded(child: content(width)),
              const Divider(height: 1),
              SizedBox(
                height: math.min(320, box.maxHeight * 0.5),
                child: panel,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _detail(String id, {required bool asPage}) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final ctl = widget.controller;
        final catalog = ctl.catalog;
        final module = catalog?.byId(id);
        if (catalog == null || module == null) return const SizedBox.shrink();
        final runningId = ctl.current?.id;
        return ModuleDetail(
          module: module,
          status: ctl.status(id),
          catalog: catalog,
          actions: widget.actions,
          onClose: asPage ? () => Navigator.of(context).pop() : _closeDetail,
          onDequeue: () => ctl.dequeue(id),
          waitingFor: runningId == null ? null : catalog.byId(runningId)?.name,
          asPage: asPage,
        );
      },
    );
  }

  void _closeDetail() => setState(() => _detailId = null);

  void _openDetail(String id) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= kActivityWideBreakpoint) {
      setState(() => _detailId = id);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            Scaffold(body: SafeArea(child: _detail(id, asPage: true))),
      ),
    );
  }

  List<Widget> _sections(BuildContext context, Catalog c) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final sections = <Widget>[];
    for (final cat in categoryOrder) {
      final mods = [
        for (final m in c.modules)
          if (m.category == cat && _visible(c, m)) m,
      ];
      if (mods.isEmpty) continue;
      sections.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: 12,
            children: [
              Text(categoryTitles[cat] ?? cat, style: tt.titleMedium),
              if (categoryNotes[cat] != null)
                Text(
                  categoryNotes[cat]!,
                  style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
            ],
          ),
        ),
      );
      sections.add(_grid(mods));
      sections.add(const SizedBox(height: 28));
    }
    if (sections.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Center(
            child: Text(
              'Nenhum módulo com esse filtro.',
              style: tt.bodyLarge?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
        ),
      ];
    }
    return sections;
  }

  Widget _grid(List<ModuleInfo> mods) {
    const minWidth = 272.0;
    const gap = 12.0;
    return LayoutBuilder(
      builder: (context, box) {
        final cols = math.max(1, (box.maxWidth + gap) ~/ (minWidth + gap));
        final runningId = widget.controller.current?.id;
        final waitingFor = runningId == null
            ? null
            : widget.controller.catalog?.byId(runningId)?.name;
        final rows = <Widget>[];
        for (var start = 0; start < mods.length; start += cols) {
          if (rows.isNotEmpty) rows.add(const SizedBox(height: gap));
          rows.add(
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < cols; i++) ...[
                    if (i > 0) const SizedBox(width: gap),
                    Expanded(
                      child: start + i < mods.length
                          ? ModuleCard(
                              module: mods[start + i],
                              status: widget.controller.status(
                                mods[start + i].id,
                              ),
                              actions: widget.actions,
                              onDequeue: () =>
                                  widget.controller.dequeue(mods[start + i].id),
                              waitingFor: waitingFor,
                              onOpen: () => _openDetail(mods[start + i].id),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                ],
              ),
            ),
          );
        }
        return Column(children: rows);
      },
    );
  }

  String _errorMessage() {
    final e = widget.controller.catalogError;
    return e is CatalogError ? e.message : '$e';
  }

  Widget _errorBanner(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return MaterialBanner(
      backgroundColor: cs.errorContainer,
      leading: Icon(Icons.error_rounded, color: cs.onErrorContainer),
      content: Text(
        _errorMessage(),
        style: TextStyle(color: cs.onErrorContainer),
      ),
      actions: [
        TextButton(
          onPressed: widget.controller.refresh,
          child: const Text('Tentar de novo'),
        ),
      ],
    );
  }

  Widget _errorView(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final e = widget.controller.catalogError;
    final message = _errorMessage();
    final stderr = e is CatalogError ? e.stderr : null;
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.error_rounded, size: 40, color: cs.error),
                const SizedBox(height: 12),
                Text(message, style: tt.titleMedium),
                if (stderr != null && stderr.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SelectableText(
                      stderr,
                      style: tt.bodyMedium?.copyWith(
                        fontFamily: kMonoFont,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: widget.controller.refresh,
                  child: const Text('Tentar de novo'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
