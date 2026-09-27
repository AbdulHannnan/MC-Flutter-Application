// formatDuration — port of the RN util's rules.

import 'package:flutter_test/flutter_test.dart';
import 'package:microcare/src/core/format/duration.dart';

void main() {
  test('minutes under an hour', () {
    expect(formatDuration(45), '45 min');
    expect(formatDuration(0), '0 min');
    expect(formatDuration(59), '59 min');
  });

  test('whole hours', () {
    expect(formatDuration(60), '1 hr');
    expect(formatDuration(120), '2 hr');
  });

  test('hours with remainder', () {
    expect(formatDuration(90), '1 hr 30 min');
    expect(formatDuration(150), '2 hr 30 min');
  });
}
