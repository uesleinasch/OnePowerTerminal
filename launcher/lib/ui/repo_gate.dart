import 'dart:io';

import 'package:flutter/material.dart';

import '../cli/cli.dart';
import '../repo/repo_copy.dart';
import '../theme/app_theme.dart';

const kInstallCommand =
    'curl -fsSL https://raw.githubusercontent.com/uesleinasch/OnePowerTerminal/main/install.sh | bash';
const kPullCommand = 'git -C ~/PowerTerminal pull --ff-only';

enum _Stage {
  loading,
  notFound,
  foreign,
  oldGit,
  pullFailed,
  pullStale,
  error,
  ready,
}

class RepoGate extends StatefulWidget {
  const RepoGate({
    super.key,
    required this.repo,
    required this.builder,
    this.onReady,
    this.runner,
  });

  final RepoCopy repo;
  final Widget Function(String repoDir) builder;
  final void Function(String repoDir)? onReady;
  final ProcessRunner? runner;

  @override
  State<RepoGate> createState() => _RepoGateState();
}

class _RepoGateState extends State<RepoGate> {
  _Stage _stage = _Stage.loading;
  String _detail = '';
  bool _pulling = false;

  RepoCopy get _repo => widget.repo;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  Cli get _cli => Cli(_repo.dir, runner: widget.runner);

  Future<void> _resolve() async {
    try {
      switch (_repo.inspect()) {
        case RepoKind.absent:
          if (_repo.snapshotDir == null) return _go(_Stage.notFound);
          await _repo.extract();
          return _go(_Stage.ready);
        case RepoKind.foreign:
          return _go(_Stage.foreign);
        case RepoKind.extracted:
          if (_repo.needsUpgrade) {
            final pnnew = await _repo.upgrade();
            if (pnnew.isNotEmpty) _announce(pnnew);
          }
          return _go(_Stage.ready);
        case RepoKind.gitClone:
          return _go(await _checkGit() ? _Stage.ready : _Stage.oldGit);
      }
    } on Object catch (e) {
      _go(
        _Stage.error,
        detail: e is FileSystemException
            ? '${e.message} ${e.path ?? ''}'.trim()
            : '$e',
      );
    }
  }

  Future<bool> _checkGit() async {
    try {
      final c = await _cli.catalog();
      return c.contractVersion >= kMinContract;
    } on CatalogError catch (e) {
      final text = '${e.message} ${e.stderr ?? ''}'.toLowerCase();
      return !text.contains('comando desconhecido: catalog');
    } on Object {
      return true;
    }
  }

  void _go(_Stage s, {String detail = ''}) {
    if (!mounted) return;
    setState(() {
      _stage = s;
      _detail = detail;
    });
    if (s == _Stage.ready) widget.onReady?.call(_repo.dir);
  }

  void _announce(List<String> pnnew) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog<void>(
        context: context,
        builder: (_) => _PnnewDialog(paths: pnnew),
      );
    });
  }

  Future<void> _pull() async {
    setState(() => _pulling = true);
    var ok = false;
    var err = '';
    try {
      final r = await (widget.runner ?? defaultProcessRunner)('git', [
        '-C',
        _repo.dir,
        'pull',
        '--ff-only',
      ]);
      ok = r.exitCode == 0;
      err = '${r.stderr}'.trim();
    } on Object catch (e) {
      err = '$e';
    }
    if (!mounted) return;
    setState(() => _pulling = false);
    if (!ok) return _go(_Stage.pullFailed, detail: err);
    if (await _checkGit()) return _go(_Stage.ready);
    _go(_Stage.pullStale);
  }

  @override
  Widget build(BuildContext context) {
    switch (_stage) {
      case _Stage.loading:
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      case _Stage.ready:
        return widget.builder(_repo.dir);
      case _Stage.notFound:
        return _Notice(
          icon: Icons.search_off_rounded,
          title: 'PowerTerminal não encontrado em ~/PowerTerminal',
          body: 'Instale com o comando abaixo e abra o launcher de novo.',
          command: kInstallCommand,
        );
      case _Stage.foreign:
        return const _Notice(
          icon: Icons.folder_off_rounded,
          title: '~/PowerTerminal existe e não é o PowerTerminal',
          body: 'Renomeie ou remova essa pasta e abra o launcher de novo.',
        );
      case _Stage.error:
        return _Notice(
          icon: Icons.error_outline_rounded,
          title: 'Não foi possível preparar ~/PowerTerminal',
          body: _detail,
        );
      case _Stage.oldGit:
        return _Notice(
          icon: Icons.update_rounded,
          title:
              'Sua cópia (git) está na versão ${_repo.copyVersion() ?? 'desconhecida'}',
          body: 'Ela é antiga demais para este launcher. Atualize para continuar.',
          action: FilledButton.icon(
            onPressed: _pulling ? null : _pull,
            icon: const Icon(Icons.download_rounded),
            label: const Text('Atualizar com git pull'),
          ),
        );
      case _Stage.pullStale:
        return const _Notice(
          icon: Icons.update_disabled_rounded,
          title: 'A cópia ainda é antiga',
          body:
              'A cópia foi atualizada, mas ainda é antiga para este launcher. '
              'Atualize o launcher ou rode git pull de novo mais tarde.',
        );
      case _Stage.pullFailed:
        return _Notice(
          icon: Icons.terminal_rounded,
          title: 'Não foi possível atualizar a cópia',
          body: _detail.isEmpty
              ? 'Rode no terminal:'
              : '$_detail\n\nRode no terminal:',
          command: kPullCommand,
        );
    }
  }
}

class _Notice extends StatelessWidget {
  const _Notice({
    required this.icon,
    required this.title,
    required this.body,
    this.command,
    this.action,
  });

  final IconData icon;
  final String title;
  final String body;
  final String? command;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 40, color: cs.primary),
                const SizedBox(height: 16),
                Text(title, style: tt.titleLarge),
                const SizedBox(height: 8),
                Text(
                  body,
                  style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
                if (command != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: SelectableText(
                      command!,
                      style: tt.bodyMedium?.copyWith(fontFamily: kMonoFont),
                    ),
                  ),
                ],
                if (action != null) ...[const SizedBox(height: 16), action!],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PnnewDialog extends StatelessWidget {
  const _PnnewDialog({required this.paths});

  final List<String> paths;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return AlertDialog(
      icon: const Icon(Icons.edit_note_rounded),
      title: const Text('Arquivos que você editou'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Você editou estes arquivos; a versão nova ficou ao lado '
                'com .pnnew.',
              ),
              const SizedBox(height: 12),
              for (final p in paths)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: SelectableText(
                    p,
                    style: tt.bodyMedium?.copyWith(fontFamily: kMonoFont),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Entendi'),
        ),
      ],
    );
  }
}
