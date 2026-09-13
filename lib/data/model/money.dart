import 'package:newtronic_banking/data/utils/formatted.dart';

/// An amount of Indonesian rupiah.
///
/// Held as a whole-rupiah [int] because the currency has no minor unit in
/// everyday use, and because the seed data previously stored amounts as strings
/// like `"5,000,000 "` — trailing space included — which made arithmetic on a
/// balance impossible without re-parsing at every call site.
///
/// Wrapping the int rather than passing one around keeps a balance from being
/// added to, say, an account number by accident, and gives formatting one home.
class Money implements Comparable<Money> {
  const Money(this.rupiah);

  const Money.zero() : rupiah = 0;

  /// Reads an amount from seed data or user input.
  ///
  /// Accepts a JSON number, or a string in any of the shapes the bundled data
  /// and the amount field produce: `5000000`, `"5.000.000"`, `"5,000,000 "`.
  /// Returns [Money.zero] when there is nothing numeric to read.
  factory Money.parse(Object? source) {
    if (source == null) return const Money.zero();
    if (source is int) return Money(source);
    if (source is num) return Money(source.round());
    return Money(parseRupiah(source.toString()) ?? 0);
  }

  final int rupiah;

  bool get isZero => rupiah == 0;
  bool get isNegative => rupiah < 0;

  /// `5.000.000`
  String get formatted => formatRupiah(rupiah);

  /// `Rp 5.000.000`
  String get formattedWithSymbol => formatRupiahWithSymbol(rupiah);

  Money operator +(Money other) => Money(rupiah + other.rupiah);
  Money operator -(Money other) => Money(rupiah - other.rupiah);
  Money operator *(int factor) => Money(rupiah * factor);
  Money operator -() => Money(-rupiah);

  bool operator <(Money other) => rupiah < other.rupiah;
  bool operator <=(Money other) => rupiah <= other.rupiah;
  bool operator >(Money other) => rupiah > other.rupiah;
  bool operator >=(Money other) => rupiah >= other.rupiah;

  @override
  int compareTo(Money other) => rupiah.compareTo(other.rupiah);

  @override
  bool operator ==(Object other) => other is Money && other.rupiah == rupiah;

  @override
  int get hashCode => rupiah.hashCode;

  /// Serialised as a plain number, so stored data never regains the string
  /// formatting this type exists to remove.
  int toJson() => rupiah;

  @override
  String toString() => formattedWithSymbol;
}
