// The auth form rules.
//
// Pure functions, so they are tested here rather than by pumping a form —
// which is the reason they live in core/utils/ instead of inside a widget.

import 'package:flutter_test/flutter_test.dart';
import 'package:novaride/core/utils/validators.dart';

void main() {
  group('password', () {
    test('accepts 8 or more characters with a letter and a number', () {
      expect(Validators.password('rider123'), isNull);
      expect(Validators.password('Sup3rSecret!'), isNull);
    });

    test('refuses short, letter-only and digit-only passwords', () {
      expect(Validators.password('ride12'), isNotNull);
      expect(Validators.password('riderrider'), isNotNull);
      expect(Validators.password('12345678'), isNotNull);
      expect(Validators.password(''), isNotNull);
    });

    // A form that reveals one rule per attempt is the most irritating
    // kind, so all three failures share a sentence that states them all.
    test('states every rule in one sentence', () {
      const message = 'Use at least 8 characters, with a letter and a number.';
      expect(Validators.password('abc'), message);
      expect(Validators.password('abcdefgh'), message);
      expect(Validators.password('12345678'), message);
    });
  });

  // Sign-in must not apply the sign-up rules: an older account may hold a
  // password that would now fail them, and refusing to submit it would
  // lock someone out of their own account.
  group('passwordPresent', () {
    test('accepts anything non-empty, including a weak password', () {
      expect(Validators.passwordPresent('abc'), isNull);
      expect(Validators.passwordPresent('admin123'), isNull);
    });

    test('refuses an empty password', () {
      expect(Validators.passwordPresent(''), isNotNull);
      expect(Validators.passwordPresent(null), isNotNull);
    });
  });

  group('email', () {
    test('accepts ordinary addresses', () {
      expect(Validators.email('rider@example.com'), isNull);
      expect(Validators.email('  rider@tip.edu.ph  '), isNull);
      expect(Validators.email('first.last+tag@sub.domain.ph'), isNull);
    });

    test('refuses what is obviously not an address', () {
      expect(Validators.email(''), isNotNull);
      expect(Validators.email('rider'), isNotNull);
      expect(Validators.email('@example.com'), isNotNull);
      expect(Validators.email('rider@example'), isNotNull);
      expect(Validators.email('rider@example.'), isNotNull);
      expect(Validators.email('two words@example.com'), isNotNull);
    });
  });

  group('emailOrUsername', () {
    test('applies the email rules only when there is an @', () {
      expect(Validators.emailOrUsername('admin'), isNull);
      expect(Validators.emailOrUsername('rider@example.com'), isNull);
      expect(Validators.emailOrUsername('rider@nope'), isNotNull);
      expect(Validators.emailOrUsername('  '), isNotNull);
    });
  });

  group('username', () {
    test('accepts 3 to 20 letters, digits and underscores', () {
      expect(Validators.username('ruw'), isNull);
      expect(Validators.username('rider_01'), isNull);
      expect(Validators.username('a' * 20), isNull);
    });

    test('refuses lengths and characters a Firestore key cannot hold', () {
      expect(Validators.username('ab'), isNotNull);
      expect(Validators.username('a' * 21), isNotNull);
      expect(Validators.username('rider 01'), isNotNull);
      expect(Validators.username('rider/01'), isNotNull);
      expect(Validators.username(''), isNotNull);
    });
  });

  group('confirmPassword', () {
    test('accepts a match and refuses anything else', () {
      expect(Validators.confirmPassword('rider123', 'rider123'), isNull);
      expect(Validators.confirmPassword('rider124', 'rider123'), isNotNull);
      expect(Validators.confirmPassword('', 'rider123'), isNotNull);
    });
  });

  group('phoneNumber', () {
    // Optional: blank is fine, and the field says so.
    test('accepts an empty value', () {
      expect(Validators.phoneNumber(''), isNull);
      expect(Validators.phoneNumber(null), isNull);
    });

    test('accepts the shapes a PH mobile number is written in', () {
      expect(Validators.phoneNumber('09171234567'), isNull);
      expect(Validators.phoneNumber('+639171234567'), isNull);
      expect(Validators.phoneNumber('639171234567'), isNull);
      expect(Validators.phoneNumber('0917 123 4567'), isNull);
      expect(Validators.phoneNumber('0917-123-4567'), isNull);
    });

    test('refuses landlines and wrong lengths', () {
      expect(Validators.phoneNumber('0281234567'), isNotNull);
      expect(Validators.phoneNumber('0917123456'), isNotNull);
      expect(Validators.phoneNumber('091712345678'), isNotNull);
    });
  });

  group('fullName', () {
    test('needs at least two characters', () {
      expect(Validators.fullName('Jo'), isNull);
      expect(Validators.fullName('  Juan Dela Cruz '), isNull);
      expect(Validators.fullName('J'), isNotNull);
      expect(Validators.fullName('   '), isNotNull);
    });
  });
}
