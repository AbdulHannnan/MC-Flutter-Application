// Verifies assetUrl() passes absolute/data URIs through unchanged. Post-cutover
// the app has no static-asset origin, so a relative path yields null (callers show
// a placeholder); viewable images are already absolute (Supabase signed/public
// URLs or any CDN).

import 'package:flutter_test/flutter_test.dart';
import 'package:microcare/src/core/network/asset_url.dart';

void main() {
  group('assetUrl', () {
    test('returns null for a relative path (no origin to resolve against)', () {
      expect(assetUrl('/images/services/ac.jpg'), isNull);
      expect(assetUrl('images/ac.jpg'), isNull);
    });

    test('passes absolute http/https URLs through unchanged', () {
      expect(
        assetUrl('https://cdn.example.com/x.jpg'),
        'https://cdn.example.com/x.jpg',
      );
      expect(
        assetUrl('http://cdn.example.com/x.jpg'),
        'http://cdn.example.com/x.jpg',
      );
    });

    test('passes protocol-relative and data URIs through unchanged', () {
      expect(assetUrl('//cdn.example.com/x.jpg'), '//cdn.example.com/x.jpg');
      expect(
        assetUrl('data:image/png;base64,AAAA'),
        'data:image/png;base64,AAAA',
      );
    });

    test('returns null for null or empty input', () {
      expect(assetUrl(null), isNull);
      expect(assetUrl(''), isNull);
    });
  });
}
