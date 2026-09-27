// Verifies assetUrl() absolutizes relative backend image paths against the
// configured API origin, and passes absolute/data URIs through unchanged. Under
// a plain `flutter test`, config.apiBaseUrl resolves to the README default
// (http://localhost:5050), so the expected origins below are deterministic.

import 'package:flutter_test/flutter_test.dart';
import 'package:microcare/src/core/network/asset_url.dart';

void main() {
  group('assetUrl', () {
    test('prepends the API origin to a relative path', () {
      expect(
        assetUrl('/images/services/ac.jpg'),
        'http://localhost:5050/images/services/ac.jpg',
      );
    });

    test('tolerates a missing leading slash', () {
      expect(
        assetUrl('images/ac.jpg'),
        'http://localhost:5050/images/ac.jpg',
      );
    });

    test('passes absolute http/https URLs through unchanged', () {
      expect(assetUrl('https://cdn.example.com/x.jpg'),
          'https://cdn.example.com/x.jpg');
      expect(assetUrl('http://cdn.example.com/x.jpg'),
          'http://cdn.example.com/x.jpg');
    });

    test('passes protocol-relative and data URIs through unchanged', () {
      expect(assetUrl('//cdn.example.com/x.jpg'), '//cdn.example.com/x.jpg');
      expect(assetUrl('data:image/png;base64,AAAA'),
          'data:image/png;base64,AAAA');
    });

    test('returns null for null or empty input', () {
      expect(assetUrl(null), isNull);
      expect(assetUrl(''), isNull);
    });
  });
}
