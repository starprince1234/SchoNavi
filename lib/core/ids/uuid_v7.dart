import 'dart:math';
import 'dart:typed_data';

/// Generates opaque, time-sortable UUIDv7 identifiers without embedding
/// domain meaning in the identifier itself.
class UuidV7 {
  UuidV7({Random? random}) : _random = random ?? Random.secure();

  final Random _random;
  int _lastMillis = -1;
  int _sequence = 0;

  String generate() {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now == _lastMillis) {
      _sequence = (_sequence + 1) & 0x0fff;
    } else {
      _lastMillis = now;
      _sequence = _random.nextInt(0x1000);
    }

    final bytes = Uint8List(16);
    var timestamp = now;
    for (var i = 5; i >= 0; i--) {
      bytes[i] = timestamp & 0xff;
      timestamp >>= 8;
    }
    bytes[6] = 0x70 | ((_sequence >> 8) & 0x0f);
    bytes[7] = _sequence & 0xff;
    for (var i = 8; i < bytes.length; i++) {
      bytes[i] = _random.nextInt(256);
    }
    bytes[8] = (bytes[8] & 0x3f) | 0x80;

    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }
}
