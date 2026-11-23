// The web-safe id helpers. The whole point is that these NEVER call
// Random().nextInt(1 << 32) (which is nextInt(0) → RangeError on dart2js). Run on
// `--platform chrome` to prove they work in the browser.

import 'package:flutter_test/flutter_test.dart';
import 'package:microcare/src/core/util/ids.dart';

void main() {
  test('randomSuffix returns a non-empty base-36 string, no crash', () {
    for (var i = 0; i < 1000; i++) {
      final s = randomSuffix();
      expect(s, isNotEmpty);
      expect(RegExp(r'^[0-9a-z]+$').hasMatch(s), isTrue);
    }
  });

  test('uniqueId embeds the prefix + separator and is highly unique', () {
    final id = uniqueId(prefix: 'svc', separator: '__');
    expect(id, startsWith('svc__'));

    final ids = {for (var i = 0; i < 1000; i++) uniqueId(prefix: 'x')};
    expect(ids.length, 1000); // no collisions across 1000 calls
  });
}
