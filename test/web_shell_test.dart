import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The PWA shell is what a search engine, a link preview and a slow first
/// load see before Flutter paints (audit design-for-hackers-01/10): the
/// title leads with what the app is, the description says it plainly, and
/// the boot screen carries real words, not only a spinner.
void main() {
  final html = File('web/index.html').readAsStringSync();

  test('the title says what the app is, not only its name', () {
    final title = RegExp(r'<title>(.*?)</title>').firstMatch(html)!.group(1)!;
    expect(title, isNot('WeatherGlass'));
    expect(title.toLowerCase(), contains('weather'));
    expect(title, contains('WeatherGlass'));
  });

  test('the description is plain and under 200 characters', () {
    final d = RegExp(r'<meta name="description" content="(.*?)">')
        .firstMatch(html)!
        .group(1)!;
    expect(d.length, inInclusiveRange(80, 200));
    expect(d, isNot(contains(' — ')));
  });

  test('the boot screen carries a heading and a sentence', () {
    final boot = RegExp(r'<div id="oh-boot"[^>]*>(.*?)</div>\s*<script',
            dotAll: true)
        .firstMatch(html)!
        .group(1)!;
    expect(boot, contains('<h1'));
    expect(boot, contains('<p'));
  });
}
