import 'dart:math';

final _numericVersion = RegExp(r'^\d+(\.\d+)*$');

bool isNewerVersion(String? candidate, String? current) {
  if (candidate == current) return false;
  if (candidate == null || current == null) return true;
  if (!_numericVersion.hasMatch(candidate) ||
      !_numericVersion.hasMatch(current)) {
    return true;
  }
  final a = candidate.split('.').map(int.parse).toList();
  final b = current.split('.').map(int.parse).toList();
  for (var i = 0; i < max(a.length, b.length); i++) {
    final x = i < a.length ? a[i] : 0;
    final y = i < b.length ? b[i] : 0;
    if (x != y) return x > y;
  }
  return false;
}
