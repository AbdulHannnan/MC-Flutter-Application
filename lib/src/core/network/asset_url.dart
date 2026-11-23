// lib/src/core/network/asset_url.dart
//
// Normalise an image URL from the backend into something `Image.network` can load.
// Post-cutover the app has no static-asset origin of its own: viewable images are
// already absolute URLs (Supabase Storage signed/public URLs, or any CDN), so this
// just passes those through. A relative path has no host to resolve against, so it
// yields `null` and callers fall back to a placeholder.

/// Matches `http://`, `https://`, and protocol-relative `//` prefixes.
final RegExp _absoluteUrl = RegExp(r'^(https?:)?//', caseSensitive: false);

/// Return [path] when it's already a usable absolute (or `data:`) URL; `null` for
/// an empty/relative path so callers can show a placeholder.
String? assetUrl(String? path) {
  if (path == null || path.isEmpty) return null;
  if (_absoluteUrl.hasMatch(path) || path.startsWith('data:')) return path;
  // A relative path has no origin to resolve against anymore → placeholder.
  return null;
}
