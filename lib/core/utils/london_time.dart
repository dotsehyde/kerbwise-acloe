import 'package:timezone/data/latest_10y.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

final _london = (() {
  tz_data.initializeTimeZones();
  return tz.getLocation('Europe/London');
})();

DateTime? parseDeliveryTime(Object? value) {
  if (value is! String) return null;
  final parsed = DateTime.tryParse(value);
  if (parsed == null || parsed.isUtc) return parsed;

  // Preserve the original wall-clock fields even if the handset's zone
  // normalizes a nonexistent local time.
  final wall = DateTime.tryParse('${value}Z');
  if (wall == null) return null;
  return tz.TZDateTime(
    _london,
    wall.year,
    wall.month,
    wall.day,
    wall.hour,
    wall.minute,
    wall.second,
    wall.millisecond,
    wall.microsecond,
  );
}

int londonDay(DateTime time) {
  final london = tz.TZDateTime.from(time, _london);
  return london.year * 10000 + london.month * 100 + london.day;
}

String londonDate(DateTime time) {
  final london = tz.TZDateTime.from(time, _london);
  return '${london.day}/${london.month}';
}

String londonTime(DateTime time) {
  final london = tz.TZDateTime.from(time, _london);
  return '${london.hour.toString().padLeft(2, '0')}:'
      '${london.minute.toString().padLeft(2, '0')}';
}
