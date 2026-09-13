import 'package:flutter_test/flutter_test.dart';
import 'package:newtronic_banking/data/utils/password_strength.dart';

void main() {
  group('evaluatePasswordStrength', () {
    test('an empty password has no strength', () {
      expect(evaluatePasswordStrength(''), PasswordStrength.none);
    });

    test('rates a password that meets almost nothing as weak', () {
      expect(evaluatePasswordStrength('abc'), PasswordStrength.weak);
      expect(evaluatePasswordStrength('abcdefgh'), PasswordStrength.weak);
    });

    test('a password meeting every rule is at least good', () {
      expect(evaluatePasswordStrength('Passw0rd!'), PasswordStrength.good);
      expect(evaluatePasswordStrength('Passw0rd!12'), PasswordStrength.good);
    });

    test('real length lifts a complete password to strong', () {
      expect(
        evaluatePasswordStrength('Passw0rd!1234567'),
        PasswordStrength.strong,
      );
    });

    test('fair means incomplete, so it is never acceptable', () {
      // Three rules of five: long enough, has uppercase and a digit, but no
      // lowercase and no symbol.
      final strength = evaluatePasswordStrength('ABCDEFGH1');
      expect(strength, PasswordStrength.fair);
      expect(strength.isAcceptable, isFalse);
    });

    test('a long password still missing a rule never reaches good', () {
      // 20 lowercase characters: long, but no uppercase, digit or symbol.
      final strength = evaluatePasswordStrength('abcdefghijklmnopqrst');
      expect(strength.index, lessThan(PasswordStrength.good.index));
    });
  });

  group('requirements', () {
    test('firstUnmetRequirement reports rules in order', () {
      expect(firstUnmetRequirement('abc')?.failureMessage,
          'Password must be at least 8 characters');
      expect(firstUnmetRequirement('abcdefgh')?.failureMessage,
          'Password needs an uppercase letter');
      expect(firstUnmetRequirement('Abcdefgh')?.failureMessage,
          'Password needs a number');
      expect(firstUnmetRequirement('Abcdefg1')?.failureMessage,
          'Password needs a symbol');
    });

    test('returns null once every rule is met', () {
      expect(firstUnmetRequirement('Passw0rd!'), isNull);
    });

    test('accepts the symbols a keyboard actually produces', () {
      for (final symbol in ['!', '@', '#', r'$', '-', '_', '+', '=', '?']) {
        expect(
          firstUnmetRequirement('Passw0rd$symbol'),
          isNull,
          reason: 'symbol "$symbol" should satisfy the symbol rule',
        );
      }
    });
  });

  group('the meter and the validator agree', () {
    // The meter saying "Strong" about a password the form rejects would be a
    // trap, so the two share one requirement list.
    test('anything acceptable to the meter also passes validation', () {
      const candidates = [
        'Passw0rd!',
        'Passw0rd!123',
        'Str0ng&Passphrase',
        'abc',
        'abcdefgh',
        'ABCDEFGH1',
      ];

      for (final candidate in candidates) {
        final isValid = firstUnmetRequirement(candidate) == null;
        final meterSaysOk = evaluatePasswordStrength(candidate).isAcceptable;
        expect(meterSaysOk, isValid, reason: 'disagreement on "$candidate"');
      }
    });
  });
}
