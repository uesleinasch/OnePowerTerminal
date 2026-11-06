import 'dart:convert';
import 'dart:io';

import '../cli/events.dart';

Stream<CliEvent> tailEvents(File file, Future<void> stop) async* {
  var stopped = false;
  final stopSignal = stop.then((_) {}, onError: (_) {});
  stopSignal.then((_) => stopped = true);
  var offset = 0;
  var pending = <int>[];
  while (true) {
    final last = stopped;
    if (await file.exists()) {
      final raf = await file.open();
      try {
        final length = await raf.length();
        if (length > offset) {
          await raf.setPosition(offset);
          final bytes = await raf.read(length - offset);
          offset += bytes.length;
          pending = [...pending, ...bytes];
        }
      } finally {
        await raf.close();
      }
      var nl = pending.indexOf(10);
      while (nl >= 0) {
        final line = utf8.decode(pending.sublist(0, nl), allowMalformed: true);
        pending = pending.sublist(nl + 1);
        final event = CliEvent.parse(line);
        if (event != null) yield event;
        nl = pending.indexOf(10);
      }
    }
    if (last) return;
    await Future.any([
      Future<void>.delayed(const Duration(milliseconds: 100)),
      stopSignal,
    ]);
  }
}
