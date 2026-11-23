// lib/src/core/util/ids.dart — web-safe unique-id helpers.
//
// WHY THIS EXISTS: `Random().nextInt(1 << 32)` is a trap on the WEB. dart2js
// evaluates a left-shift whose count is >= the int width to 0 (`1 << 32 == 0` in
// the browser), so the call becomes `nextInt(0)` and throws
//   RangeError: max must be in range 0 < max ≤ 2^32, was 0
// On the VM / mobile `1 << 32` is 2^32 and it works, so unit tests (run on the VM)
// never catch it. Centralising the random-id generation here, with a bound well
// under 2^31, keeps client-side ids identical and safe on web AND native.

import 'dart:math';

final Random _rng = Random();

/// The largest random bound that is safe on every target. 2^30 as a hex literal
/// (not a shift) — big enough for a collision-resistant suffix, and never miscomputed
/// by dart2js the way `1 << 32` is.
const int _maxRandomBound = 0x40000000; // 2^30 = 1073741824

/// A short random suffix (base-36), web-safe. Pair with a timestamp for a unique id.
String randomSuffix() => _rng.nextInt(_maxRandomBound).toRadixString(36);

/// A collision-resistant unique id: an optional [prefix], a microsecond timestamp,
/// and a random suffix, joined by [separator]. Microseconds + randomness make
/// same-millisecond collisions negligible. Used for cart line ids, mock
/// references, local user ids, etc.
String uniqueId({String? prefix, String separator = '_'}) {
  final stamp = DateTime.now().microsecondsSinceEpoch;
  final tail = '$stamp$separator${randomSuffix()}';
  return prefix == null ? tail : '$prefix$separator$tail';
}
