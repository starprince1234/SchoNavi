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
}
