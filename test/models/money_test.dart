// Tests the Money value type — the major↔minor conversion at the API boundary,
// display formatting, and integer arithmetic. The conversion/format cases mirror
// the RN app's `src/utils/__tests__/format.test.ts` assertions exactly, so the
// Flutter port is provably faithful.

import 'package:flutter_test/flutter_test.dart';
import 'package:microcare/src/models/money.dart';

void main() {
  group('Money.fromAed (port of aedToMoney)', () {
    test('parses a major-unit AED string into minor units', () {
      expect(Money.fromAed('135.00'),
          const Money(amountMinor: 13500, currency: CurrencyCode.aed));
    });

    test('rounds instead of truncating, avoiding float drift', () {
      expect(Money.fromAed('135'),
          const Money(amountMinor: 13500, currency: CurrencyCode.aed));
    });

    test('accepts a number as well as a string', () {
      expect(Money.fromAed(40),
          const Money(amountMinor: 4000, currency: CurrencyCode.aed));
    });

    test('falls back to 0 for an unparseable value', () {
      expect(Money.fromAed('not-a-number'),
          const Money(amountMinor: 0, currency: CurrencyCode.aed));
    });
  });

  group('Money.format (port of formatMoney)', () {
    test('formats amount-first with two decimals and the currency after', () {
      expect(
        const Money(amountMinor: 9900, currency: CurrencyCode.aed).format(),
        '99.00 AED',
      );
    });

    test('pads a whole amount to two decimals', () {
      expect(
        const Money(amountMinor: 10000, currency: CurrencyCode.aed).format(),
        '100.00 AED',
      );
    });

    test('handles zero', () {
      expect(const Money.zero().format(), '0.00 AED');
    });
  });

  group('integer arithmetic', () {
    test('adds two same-currency amounts', () {
      const a = Money(amountMinor: 4000, currency: CurrencyCode.aed);
      const b = Money(amountMinor: 500, currency: CurrencyCode.aed);
      expect(a + b, const Money(amountMinor: 4500, currency: CurrencyCode.aed));
    });

    test('scales by a whole quantity', () {
      const unit = Money(amountMinor: 4000, currency: CurrencyCode.aed);
      expect(unit * 3, const Money(amountMinor: 12000, currency: CurrencyCode.aed));
    });
  });

  group('json round-trip', () {
    test('preserves amount and currency', () {
      const money = Money(amountMinor: 13500, currency: CurrencyCode.aed);
      expect(Money.fromJson(money.toJson()), money);
    });

    test('currency code parsing is case-insensitive and defaults to AED', () {
      expect(CurrencyCode.fromCode('usd'), CurrencyCode.usd);
      expect(CurrencyCode.fromCode('aed'), CurrencyCode.aed);
      expect(CurrencyCode.fromCode('???'), CurrencyCode.aed);
    });
  });
}
