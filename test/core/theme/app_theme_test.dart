import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/core/theme/app_theme.dart';

void main() {
  test('themes use Material 3 with light/dark brightness', () {
    expect(AppTheme.light().useMaterial3, isTrue);
    expect(AppTheme.light().colorScheme.brightness, Brightness.light);
    expect(AppTheme.dark().colorScheme.brightness, Brightness.dark);
  });
}
