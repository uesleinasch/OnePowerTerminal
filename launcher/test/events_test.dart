import 'package:flutter_test/flutter_test.dart';
import 'package:powerterminal_launcher/cli/events.dart';

void main() {
  test('module_begin', () {
    final e = CliEvent.parse(
      '{"event":"module_begin","module":"zsh","action":"update","index":1,"total":1}',
    ) as ModuleBegin;
    expect([e.module, e.action, e.index, e.total], ['zsh', 'update', 1, 1]);
  });

  test('step com e sem n/m', () {
    final e = CliEvent.parse(
      '{"event":"step","module":"nvim","text":"Baixando","n":1,"m":3}',
    ) as Step;
    expect([e.module, e.text, e.n, e.m], ['nvim', 'Baixando', 1, 3]);
    final s =
        CliEvent.parse('{"event":"step","module":"nvim","text":"x"}') as Step;
    expect(s.n, isNull);
    expect(s.m, isNull);
  });

  test('note', () {
    final e =
        CliEvent.parse('{"event":"note","module":"a","text":"t"}') as Note;
    expect([e.module, e.text], ['a', 't']);
  });

  test('session_restart', () {
    final e = CliEvent.parse(
      '{"event":"session_restart","module":"zsh","reason":"shell"}',
    ) as SessionRestart;
    expect([e.module, e.reason], ['zsh', 'shell']);
  });

  test('module_end', () {
    final e = CliEvent.parse(
      '{"event":"module_end","module":"a","action":"install","ok":false}',
    ) as ModuleEnd;
    expect([e.module, e.action, e.ok], ['a', 'install', false]);
  });

  test('done', () {
    final e =
        CliEvent.parse('{"event":"done","ok":["a"],"failed":["b"]}') as Done;
    expect(e.ok, ['a']);
    expect(e.failed, ['b']);
  });

  test('done sem ok ou failed como lista é inválido', () {
    expect(CliEvent.parse('{"event":"done"}'), isNull);
    expect(CliEvent.parse('{"event":"done","ok":[],"failed":"x"}'), isNull);
    expect(CliEvent.parse('{"event":"done","ok":null,"failed":[]}'), isNull);
  });

  test('entradas inválidas dão null', () {
    expect(CliEvent.parse('{"event":"x"}'), isNull);
    expect(CliEvent.parse('{"module":"a"}'), isNull);
    expect(CliEvent.parse('lixo'), isNull);
    expect(CliEvent.parse(''), isNull);
    expect(CliEvent.parse('[1]'), isNull);
  });
}
