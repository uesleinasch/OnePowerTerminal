final _csi = RegExp(r'\x1B\[[0-9;?]*[ -/]*[@-~]');
final _osc = RegExp(r'\x1B\][^\x07]*\x07');
final _control = RegExp(r'[\x00-\x08\x0B-\x1F\x7F]');

String cleanTerminalText(String raw) =>
    raw.replaceAll(_osc, '').replaceAll(_csi, '').replaceAll(_control, '');

String shQuote(String s) => "'${s.replaceAll("'", r"'\''")}'";
