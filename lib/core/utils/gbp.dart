int poundsToPence(num pounds) => (pounds * 100).round();

String formatGbp(int pence) =>
    '£${pence ~/ 100}.${(pence % 100).toString().padLeft(2, '0')}';

final _cashPattern = RegExp(r'^([0-9]{1,9})(?:[.,]([0-9]{1,2}))?$');

int? parseCashPence(String input) {
  final match = _cashPattern.firstMatch(input.trim());
  if (match == null) return null;
  final pounds = int.parse(match[1]!);
  final pence = int.parse((match[2] ?? '').padRight(2, '0'));
  return pounds * 100 + pence;
}
