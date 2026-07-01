import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('main Android manifest declares release internet permission', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();

    expect(
      manifest,
      contains('<uses-permission android:name="android.permission.INTERNET"/>'),
    );
  });

  test('main Android manifest declares preparation reminder integration', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();

    expect(
      manifest,
      contains(
        '<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>',
      ),
    );
    expect(
      manifest,
      contains(
        '<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>',
      ),
    );
    expect(manifest, contains('android:name=".PreparationWidgetProvider"'));
    expect(
      manifest,
      contains(
        '<action android:name="android.appwidget.action.APPWIDGET_UPDATE"/>',
      ),
    );
    expect(manifest, contains('android:resource="@xml/preparation_widget_info"'));
    expect(manifest, contains('android:name=".ReminderReceiver"'));
    expect(manifest, contains('android:name=".ReminderRescheduleReceiver"'));
    expect(
      manifest,
      contains('<action android:name="android.intent.action.BOOT_COMPLETED"/>'),
    );
    expect(
      manifest,
      contains(
        '<action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>',
      ),
    );
    expect(
      manifest,
      contains(
        '<action android:name="android.intent.action.TIMEZONE_CHANGED"/>',
      ),
    );
    expect(
      manifest,
      contains('<action android:name="android.intent.action.DATE_CHANGED"/>'),
    );
  });

  test('values/colors.xml defines widget palette for light mode', () {
    final colors = File(
      'android/app/src/main/res/values/colors.xml',
    ).readAsStringSync();
    for (final name in [
      'widget_surface',
      'widget_border',
      'widget_primary',
      'widget_secondary',
      'widget_accent',
      'widget_text_primary',
      'widget_text_secondary',
      'widget_chip',
      'widget_progress_track',
    ]) {
      expect(colors, contains('name="$name"'), reason: 'missing $name in light colors');
    }
  });
}
