import 'package:flutter_test/flutter_test.dart';
import 'package:involve/utils/coordinates.dart';

void main() {
  test('accepts real coordinates', () {
    expect(hasValidCoordinates(40.7128, -74.0060), isTrue);
    expect(hasValidCoordinates(-90, 180), isTrue);
  });

  test('rejects missing, non-finite and out-of-range coordinates', () {
    expect(hasValidCoordinates(null, -74.0), isFalse);
    expect(hasValidCoordinates(40.7, null), isFalse);
    expect(hasValidCoordinates(double.nan, -74.0), isFalse);
    expect(hasValidCoordinates(40.7, double.infinity), isFalse);
    expect(hasValidCoordinates(91, 0), isFalse);
    expect(hasValidCoordinates(0, -181), isFalse);
  });
}
