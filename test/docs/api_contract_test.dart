import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final openApi = File('docs/openapi.yaml');

  test('OpenAPI documents chat quick actions endpoint', () {
    final text = openApi.readAsStringSync();

    expect(text, contains('  /chat/quick-actions:'));
    expect(text, contains(r"$ref: '#/components/schemas/QuickActionsRequest'"));
    expect(text, contains(r"$ref: '#/components/schemas/QuickActionsEnvelope'"));
  });

  test('protected endpoints declare bearer and cookie security', () {
    final text = openApi.readAsStringSync();

    for (final path in [
      '/recommendations/mentors',
      '/chat/quick-actions',
      '/profile',
      '/favorites',
      '/history',
      '/preparation-plans/generate',
    ]) {
      final index = text.indexOf('  $path:');
      expect(index, isNonNegative, reason: '$path missing from OpenAPI');
      final next = text.indexOf('\n  /', index + 1);
      final block = text.substring(index, next == -1 ? text.length : next);
      expect(block, contains('security:'), reason: '$path lacks security');
      expect(block, contains('bearerAuth: []'));
      expect(block, contains('cookieAuth: []'));
    }
  });
}
