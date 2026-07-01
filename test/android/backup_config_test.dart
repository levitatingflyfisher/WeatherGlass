import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// WeatherGlass promises on-screen that saved places stay on the device. With
/// Android auto-backup left at its default, the OS quietly sweeps the
/// unencrypted SQLite DB (saved locations = where the family lives) and the
/// precision preference into Google cloud backup — an egress no code path of
/// ours ever sees. The sanctioned backup path is the encrypted .ohbk export.
///
/// Static-content pin (same style as offline_fonts_test.dart): the manifest
/// must opt out of every OS-driven copy mechanism, and the extraction-rules
/// file must exclude the database + shared_prefs domains from both cloud
/// backup (Android 12+) and device-to-device transfer.
void main() {
  const manifestPath = 'android/app/src/main/AndroidManifest.xml';
  const rulesPath = 'android/app/src/main/res/xml/data_extraction_rules.xml';

  test('manifest disables Android auto-backup and wires extraction rules', () {
    final manifest = File(manifestPath).readAsStringSync();
    expect(manifest, contains('android:allowBackup="false"'),
        reason: 'auto-backup must be off — the plaintext DB holds home coords');
    expect(
        manifest,
        contains(
            'android:dataExtractionRules="@xml/data_extraction_rules"'),
        reason: 'Android 12+ reads dataExtractionRules, not allowBackup alone');
  });

  test('extraction rules exclude the DB and prefs from cloud + transfer', () {
    final f = File(rulesPath);
    expect(f.existsSync(), isTrue,
        reason: 'the manifest references @xml/data_extraction_rules');
    final rules = f.readAsStringSync();
    expect(rules, contains('<cloud-backup'));
    expect(rules, contains('<device-transfer'));
    for (final domain in ['database', 'sharedpref', 'file']) {
      expect(
          RegExp('<exclude domain="$domain"').allMatches(rules).length,
          greaterThanOrEqualTo(2),
          reason:
              '"$domain" must be excluded from BOTH cloud-backup and transfer');
    }
  });
}
