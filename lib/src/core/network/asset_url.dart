// lib/src/core/network/asset_url.dart
//
// Turn a possibly-relative asset path from the backend (e.g.
// "/images/services/ac.jpg") into an absolute URL an `Image.network` can load,
// by prepending the configured API origin. This is the Dart port of the RN
// `assetUrl()` helper (src/lib/config.ts) — catalog images arrive as relative
// paths with no CDN host (spec §"Image URLs"), so the app absolutizes them.
//
// Rules (matching RN exactly):
//   - Already-absolute URLs (http/https or protocol-relative `//host/...`) and
//     `data:` URIs pass through unchanged.
//   - An empty/null path yields `null`, so a card can fall back to a placeholder.
//   - Otherwise the API origin is prepended, tolerating a trailing slash on the
//     base and a leading slash on the path.

import '../../config/app_config.dart';

// Matches `http://`, `https://`, and protocol-relative `//` prefixes.
final RegExp _absoluteUrl = RegExp(r'^(https?:)?//', caseSensitive: false);
final RegExp _trailingSlashes = RegExp(r'/+$');
final RegExp _leadingSlashes = RegExp(r'^/+');

/// Absolutize a backend image path against [config.apiBaseUrl]. Returns `null`
/// for an empty/null path so callers can show a placeholder.
String? assetUrl(String? path) {
  if (path == null || path.isEmpty) return null;
  if (_absoluteUrl.hasMatch(path) || path.startsWith('data:')) return path;

  final base = config.apiBaseUrl.replaceAll(_trailingSlashes, '');
  final relative = path.replaceAll(_leadingSlashes, '');
  return '$base/$relative';
}
