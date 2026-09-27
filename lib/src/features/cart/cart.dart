// lib/src/features/cart — the cart feature's PUBLIC API (barrel).
//
// STUB for now: Module 9's Home shows a cart icon with a live count badge, but the
// real persisted cart store lands in Module 13. Until then [cartCountProvider]
// returns 0 (so the badge is hidden). Module 13 repoints this at the cart store's
// count selector — the Home never changes, only the provider's body.

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Total number of items across all cart lines — drives the Home cart badge.
///
/// TODO(Module 13): replace the stub body with a selector over the real persisted
/// cart store (Σ line quantities).
final cartCountProvider = Provider<int>((ref) => 0);
