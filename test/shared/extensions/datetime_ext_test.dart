import 'package:flutter_test/flutter_test.dart';
import 'package:glass/shared/extensions/datetime_ext.dart';

void main() {
  group('DateTimeExt', () {
    test('toDateDay returns YYYY-MM-DD', () {
      final dt = DateTime(2026, 3, 28, 14, 30);
      expect(dt.toDateDay(), '2026-03-28');
    });

    test('toYearMonth returns YYYY-MM', () {
      final dt = DateTime(2026, 3, 28);
      expect(dt.toYearMonth(), '2026-03');
    });

    test('toYear returns YYYY', () {
      final dt = DateTime(2026, 3, 28);
      expect(dt.toYear(), '2026');
    });

    test('dateOnly drops the time component, keeping the calendar day', () {
      final dt = DateTime(2026, 3, 28, 23, 59, 58);
      expect(dt.dateOnly, DateTime(2026, 3, 28));
      expect(dt.dateOnly.hour, 0);
    });

    test('startOfWeek returns the date-only Monday of the same week', () {
      // 2026-03-28 is a Saturday; its week's Monday is 2026-03-23.
      expect(DateTime(2026, 3, 28, 14, 30).startOfWeek, DateTime(2026, 3, 23));
      // A Monday maps to itself (date-only).
      expect(DateTime(2026, 3, 23, 9).startOfWeek, DateTime(2026, 3, 23));
      // A Sunday belongs to the week that started 6 days earlier.
      expect(DateTime(2026, 3, 29).startOfWeek, DateTime(2026, 3, 23));
    });
  });

  group('daysBetweenDates', () {
    test('counts whole calendar days, ignoring times', () {
      expect(
        daysBetweenDates(
            DateTime(2026, 3, 1, 23, 59), DateTime(2026, 3, 8, 0, 1)),
        7,
      );
    });

    test('is zero for the same calendar day', () {
      expect(
        daysBetweenDates(DateTime(2026, 3, 1, 1), DateTime(2026, 3, 1, 22)),
        0,
      );
    });

    test('is negative when the second date is earlier', () {
      expect(daysBetweenDates(DateTime(2026, 3, 8), DateTime(2026, 3, 1)), -7);
    });

    test('spans month and year boundaries', () {
      expect(
          daysBetweenDates(DateTime(2025, 12, 30), DateTime(2026, 1, 2)), 3);
    });
  });

  group('minutesToLabel', () {
    test('midnight is 12:00 AM', () => expect(minutesToLabel(0), '12:00 AM'));
    test('noon is 12:00 PM', () => expect(minutesToLabel(720), '12:00 PM'));
    test('morning pads minutes', () => expect(minutesToLabel(545), '9:05 AM'));
    test('afternoon converts to 12-hour',
        () => expect(minutesToLabel(809), '1:29 PM'));
    test('last minute of the day',
        () => expect(minutesToLabel(1439), '11:59 PM'));
    test('wraps past 24h', () => expect(minutesToLabel(1440), '12:00 AM'));
  });
}
