import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:newtronic_banking/data/model/money.dart';

void main() {
  setUpAll(() async => initializeDateFormatting('id_ID', null));

  group('parsing', () {
    test('reads a plain int', () {
      expect(Money.parse(5000000).rupiah, 5000000);
    });

    test('rounds a num rather than truncating', () {
      expect(Money.parse(1500.6).rupiah, 1501);
    });

    test('reads the formats the seed data and the amount field produce', () {
      // The old asset shape, trailing space included.
      expect(Money.parse('5,000,000 ').rupiah, 5000000);
      // What the thousands formatter puts in the field.
      expect(Money.parse('5.000.000').rupiah, 5000000);
      expect(Money.parse('Rp 250.000').rupiah, 250000);
    });

    test('falls back to zero for anything unreadable', () {
      expect(Money.parse(null), const Money.zero());
      expect(Money.parse(''), const Money.zero());
      expect(Money.parse('abc'), const Money.zero());
    });
  });

  group('formatting', () {
    test('groups with Indonesian separators', () {
      expect(const Money(5000000).formatted, '5.000.000');
      expect(const Money(2500).formattedWithSymbol, 'Rp 2.500');
    });

    test('toString is the human form', () {
      expect(const Money(250000).toString(), 'Rp 250.000');
    });
  });

  group('arithmetic', () {
    test('adds and subtracts', () {
      expect(const Money(250000) + const Money(2500), const Money(252500));
      expect(const Money(5000000) - const Money(252500),
          const Money(4747500));
    });

    test('multiplies by a count', () {
      expect(const Money(2500) * 4, const Money(10000));
    });

    test('negates', () {
      expect(-const Money(2500), const Money(-2500));
    });

    test('can go negative, which is how an overdraw is detectable', () {
      final remaining = const Money(1000) - const Money(2500);
      expect(remaining.isNegative, isTrue);
      expect(remaining.rupiah, -1500);
    });
  });

  group('comparison', () {
    test('orders by amount', () {
      expect(const Money(100) < const Money(200), isTrue);
      expect(const Money(200) <= const Money(200), isTrue);
      expect(const Money(300) > const Money(200), isTrue);
      expect(const Money(200) >= const Money(300), isFalse);
    });

    test('sorts', () {
      final amounts = [const Money(300), const Money(100), const Money(200)]
        ..sort();
      expect(amounts.map((m) => m.rupiah), [100, 200, 300]);
    });

    test('equality is by value, so it works as a map key', () {
      expect(const Money(2500), const Money(2500));
      expect({const Money(2500): 'fee'}[const Money(2500)], 'fee');
    });
  });

  group('serialisation', () {
    test('writes a number, never a formatted string', () {
      expect(const Money(5000000).toJson(), 5000000);
      expect(const Money(5000000).toJson(), isA<int>());
    });

    test('round-trips', () {
      const original = Money(4747500);
      expect(Money.parse(original.toJson()), original);
    });
  });
}
