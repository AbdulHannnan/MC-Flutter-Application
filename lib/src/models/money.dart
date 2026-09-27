// lib/src/models/money.dart — the money value type. Dart port of the RN app's
// `Money` (src/types/common.ts) plus the money helpers from `src/utils`
// (`aedToMoney`, `formatMoney`).
//
// MONEY IS NEVER A FLOAT (README rule #4). Floating-point can't represent 0.10
// exactly, so we store the amount in the currency's MINOR unit (fils for AED,
// cents for USD) as an INTEGER, plus the currency. e.g. AED 120.00 →
// Money(amountMinor: 12000, currency: aed). All money arithmetic is integer
// arithmetic; conversion to/from the major unit happens only at the edges — the
// API boundary ([Money.fromAed]) and display ([format]).

/// Currencies the app supports. A closed set (not a free string) so a bad code
/// can't silently flow through. AED (UAE Dirham) is the app's currency — the
/// business operates in Dubai; USD exists for completeness.
enum CurrencyCode {
  aed,
  usd;

  /// The ISO-style uppercase code as the backend/UI use it, e.g. `'AED'`.
  String get code => name.toUpperCase();

  /// Parse a currency code, defaulting to [aed] (the app's currency) for any
  /// unrecognised value rather than throwing.
  static CurrencyCode fromCode(String value) =>
      value.toUpperCase() == 'USD' ? CurrencyCode.usd : CurrencyCode.aed;
}

class Money {
  /// Integer amount in the minor unit (fils / cents). Never fractional.
  final int amountMinor;
  final CurrencyCode currency;

  const Money({required this.amountMinor, required this.currency});

  /// Zero in the given currency (defaults to AED) — a convenient identity for
  /// summing line totals.
  const Money.zero([this.currency = CurrencyCode.aed]) : amountMinor = 0;

  /// ADAPTER (README rule #4 / spec §"Money"): the backend serialises catalog &
  /// booking money as MAJOR-unit AED *strings* (Prisma `Decimal`), e.g. "40.00",
  /// "135.00". Every price crossing the API boundary passes through here:
  /// "135.00" → Money(amountMinor: 13500, currency: aed). We parse to a double
  /// THEN round to whole fils, which avoids binary-float drift (135 * 100 can
  /// land at 13499.999…). Currency is always AED — the only one the backend
  /// emits. An unparseable value falls back to 0 rather than throwing.
  ///
  /// (The N-Genius *payment* amount is already in fils; build that with the
  /// plain constructor, not this.)
  factory Money.fromAed(Object? aed) {
    final double major = aed is num
        ? aed.toDouble()
        : (double.tryParse(aed?.toString().trim() ?? '') ?? double.nan);
    final amountMinor = major.isFinite ? (major * 100).round() : 0;
    return Money(amountMinor: amountMinor, currency: CurrencyCode.aed);
  }

  factory Money.fromJson(Map<String, dynamic> json) => Money(
        amountMinor: (json['amountMinor'] as num).toInt(),
        currency: CurrencyCode.fromCode(json['currency'] as String),
      );

  Map<String, dynamic> toJson() => {
        'amountMinor': amountMinor,
        'currency': currency.code,
      };

  /// Display string with the amount FIRST and the currency code after, always
  /// two decimals, e.g. Money(9900, aed) → "99.00 AED". Mirrors the RN
  /// `formatMoney`. Every price in the app renders through this one method.
  String format() => '${(amountMinor / 100).toStringAsFixed(2)} ${currency.code}';

  /// Add two amounts of the SAME currency (integer arithmetic).
  Money operator +(Money other) {
    assert(currency == other.currency,
        'Cannot add ${other.currency.code} to ${currency.code}');
    return Money(amountMinor: amountMinor + other.amountMinor, currency: currency);
  }

  /// Scale by a whole quantity, e.g. a unit price × line quantity.
  Money operator *(int quantity) =>
      Money(amountMinor: amountMinor * quantity, currency: currency);

  @override
  bool operator ==(Object other) =>
      other is Money &&
      other.amountMinor == amountMinor &&
      other.currency == currency;

  @override
  int get hashCode => Object.hash(amountMinor, currency);

  @override
  String toString() => 'Money(${format()})';
}
