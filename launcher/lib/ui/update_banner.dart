import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../system/self_update.dart';
import '../system/update_check.dart';

class UpdateBanner extends StatefulWidget {
  const UpdateBanner({
    super.key,
    required this.release,
    required this.updater,
    required this.busy,
    required this.onDismiss,
    this.openUrl,
  });

  final ReleaseInfo release;
  final SelfUpdater? updater;
  final bool busy;
  final VoidCallback onDismiss;
  final void Function(Uri url)? openUrl;

  @override
  State<UpdateBanner> createState() => _UpdateBannerState();
}

class _UpdateBannerState extends State<UpdateBanner> {
  double? _progress;
  String? _error;
  String? _savedPath;
  bool _waiting = false;

  void _open(Uri url) {
    final open = widget.openUrl;
    if (open != null) return open(url);
    unawaited(Process.run('xdg-open', [url.toString()]));
  }

  Future<void> _update() async {
    final updater = widget.updater;
    if (updater == null) return;
    setState(() {
      _progress = 0;
      _error = null;
      _waiting = false;
    });
    try {
      final result = await updater.run(
        widget.release,
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
        onWaiting: () {
          if (mounted) setState(() => _waiting = true);
        },
      );
      if (mounted) {
        setState(() {
          _progress = null;
          if (!result.replaced) _savedPath = result.path;
        });
      }
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          _progress = null;
          _waiting = false;
          _error = e is SelfUpdateException ? e.message : 'Falha: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fg = cs.onPrimaryContainer;
    final downloading = _progress != null;
    final String text;
    if (_savedPath != null) {
      text =
          'Salvo em $_savedPath. Feche o PowerTerminal e abra o arquivo novo.';
    } else if (_waiting) {
      text = 'Aguardando a fila terminar…';
    } else if (_error != null) {
      text = _error!;
    } else {
      text = 'PowerTerminal ${widget.release.version} disponível';
    }
    return MaterialBanner(
      backgroundColor: cs.primaryContainer,
      leading: Icon(Icons.system_update_alt_rounded, color: fg),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(text, style: TextStyle(color: fg)),
          if (downloading) ...[
            const SizedBox(height: 8),
            LinearProgressIndicator(value: _progress),
          ],
        ],
      ),
      actions: _savedPath != null
          ? [TextButton(onPressed: widget.onDismiss, child: const Text('Ok'))]
          : [
              TextButton(
                onPressed: () => _open(widget.release.htmlUrl),
                child: const Text('Notas da versão'),
              ),
              TextButton(
                onPressed: downloading ? null : widget.onDismiss,
                child: const Text('Agora não'),
              ),
              Tooltip(
                message: widget.busy ? 'Aguarde a fila terminar' : '',
                child: FilledButton(
                  onPressed:
                      widget.busy || downloading || widget.updater == null
                      ? null
                      : _update,
                  child: Text(
                    _error != null ? 'Tentar de novo' : 'Baixar e reiniciar',
                  ),
                ),
              ),
            ],
    );
  }
}
