import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scho_navi/core/haptics/haptics.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Haptics.selection triggers HapticFeedback platform call', () async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          calls.add(call);
          return null;
        });

    Haptics.selection();
    await Future<void>.delayed(Duration.zero);

    expect(
      calls.where((call) => call.method == 'HapticFeedback.vibrate'),
      isNotEmpty,
    );

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });
}
