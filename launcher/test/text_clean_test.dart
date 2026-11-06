import 'package:flutter_test/flutter_test.dart';
import 'package:powerterminal_launcher/session/text_clean.dart';

void main() {
  test('remove cores ANSI e \\r', () {
    expect(cleanTerminalText('\x1B[1;32mOK\x1B[0m\r'), 'OK');
  });

  test('remove OSC de título', () {
    expect(cleanTerminalText('\x1B]0;PowerTerminal\x07pronto'), 'pronto');
  });

  test('remove controles mas mantém \\n e \\t', () {
    expect(cleanTerminalText('a\tb\x08\x00\x7F\nc\x1B[?2004h'), 'a\tb\nc');
  });

  test('shQuote', () {
    expect(shQuote("a'b"), "'a'\\''b'");
    expect(shQuote(r'$x "y" \z'), r"""'$x "y" \z'""");
  });
}
