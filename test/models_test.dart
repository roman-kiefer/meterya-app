import 'package:flutter_test/flutter_test.dart';
import 'package:meterya_app/models.dart';

void main() {
  test('decimal input stays exact and accepts German separator', () {
    expect(normalizeReading('99999999999999,999999'), '99999999999999.999999');
    expect(normalizeReading('0'), '0');
    for (final bad in ['-1', 'NaN', '1e3', '1.1234567', '1.000,2']) {
      expect(normalizeReading(bad), isNull);
    }
  });
  test('calendar dates reject normalized invalid days', () {
    expect(validDate('2024-02-29'), isTrue);
    expect(validDate('2025-02-29'), isFalse);
    expect(validDate('2026-13-01'), isFalse);
    expect(validDate('04.10.2026'), isFalse);
  });
}
