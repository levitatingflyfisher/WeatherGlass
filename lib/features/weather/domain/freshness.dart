/// How long ago a forecast was fetched, in plain words ("3 hours ago").
///
/// Pure, so the "as of" line on a stale forecast is testable without a
/// clock. Rounds down: a forecast 3 h 50 min old is "3 hours ago".
String describeAge(Duration age) {
  if (age.inMinutes < 1) return 'just now';
  String n(int v, String unit) => '$v $unit${v == 1 ? '' : 's'} ago';
  if (age.inHours < 1) return n(age.inMinutes, 'minute');
  if (age.inDays < 1) return n(age.inHours, 'hour');
  return n(age.inDays, 'day');
}
