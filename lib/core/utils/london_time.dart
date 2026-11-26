import 'package:timezone/data/latest_10y.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

final _london = (() {
  tz_data.initializeTimeZones();
  return tz.getLocation('Europe/London');
})();

String londonTime(DateTime time) {
  final london = tz.TZDateTime.from(time, _london);
  return '${london.hour.toString().padLeft(2, '0')}:'
      '${london.minute.toString().padLeft(2, '0')}';
}
