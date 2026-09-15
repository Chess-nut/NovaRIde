// Rider onboarding rules. These run client-side today and become Firestore
// security rules later, so they are tested as pure functions rather than
// through the dialog that happens to call them.

import 'package:flutter_test/flutter_test.dart';

import 'package:novaride/admin/mock/mock_data.dart';
import 'package:novaride/admin/state/rider_validation.dart';
import 'package:novaride/shared/models/models.dart';

void main() {
  group('full name', () {
    test('is required and at least three characters', () {
      expect(RiderValidation.validateFullName(null), isNotNull);
      expect(RiderValidation.validateFullName(''), isNotNull);
      expect(RiderValidation.validateFullName('   '), isNotNull);
      expect(RiderValidation.validateFullName('Jo'), isNotNull);

      expect(RiderValidation.validateFullName('Jose'), isNull);
      expect(RiderValidation.validateFullName('  Ana  '), isNull);
    });
  });

  group('helmet ID format', () {
    final riders = MockData.riders;

    test('accepts NR-H1-### only', () {
      expect(
        RiderValidation.validateHelmetId('NR-H1-011', existing: riders),
        isNull,
      );
      // Lower case is normalized before the pattern check.
      expect(
        RiderValidation.validateHelmetId('nr-h1-011', existing: riders),
        isNull,
      );
    });

    test('rejects malformed serials', () {
      for (final bad in [
        '',
        'NR-H1-1', // too few digits
        'NR-H1-0011', // too many digits
        'NR-H2-011', // wrong model
        'NRH1011', // no separators
        'NR-H1-ABC', // not digits
        'NR-H1-011X', // trailing junk
      ]) {
        expect(
          RiderValidation.validateHelmetId(bad, existing: riders),
          isNotNull,
          reason: '"$bad" should have been rejected',
        );
      }
    });

    test('matches the documented pattern directly', () {
      expect(RiderValidation.helmetIdPattern.hasMatch('NR-H1-001'), isTrue);
      expect(RiderValidation.helmetIdPattern.hasMatch('NR-H1-01'), isFalse);
    });
  });

  group('helmet ID uniqueness', () {
    final riders = MockData.riders;

    test('rejects a serial already assigned to somebody else', () {
      final error =
          RiderValidation.validateHelmetId('NR-H1-003', existing: riders);
      expect(error, isNotNull);
      expect(error, contains('already assigned'));
    });

    test('is case-insensitive about the clash', () {
      expect(
        RiderValidation.validateHelmetId('nr-h1-003', existing: riders),
        isNotNull,
      );
    });

    test('does not report a rider clashing with themselves when editing', () {
      expect(
        RiderValidation.validateHelmetId(
          'NR-H1-003',
          existing: riders,
          editingRiderId: 'R-003',
        ),
        isNull,
      );
      // ...but still blocks taking a different rider's serial.
      expect(
        RiderValidation.validateHelmetId(
          'NR-H1-001',
          existing: riders,
          editingRiderId: 'R-003',
        ),
        isNotNull,
      );
    });

    test('an empty roster has nothing to clash with', () {
      expect(
        RiderValidation.validateHelmetId('NR-H1-001', existing: const <Rider>[]),
        isNull,
      );
    });
  });

  group('phone normalization', () {
    test('accepts every common Philippine mobile form', () {
      const expected = '+63 917 402 8813';

      for (final input in [
        '09174028813',
        '0917 402 8813',
        '0917-402-8813',
        '+639174028813',
        '+63 917 402 8813',
        '639174028813',
        '(0917) 402 8813',
        '9174028813',
      ]) {
        expect(
          RiderValidation.normalizePhone(input),
          expected,
          reason: '"$input" did not normalize',
        );
      }
    });

    test('output always matches the canonical pattern', () {
      final normalized = RiderValidation.normalizePhone('09991234567')!;
      expect(
        RiderValidation.normalizedPhonePattern.hasMatch(normalized),
        isTrue,
      );
      expect(normalized, '+63 999 123 4567');
    });

    test('rejects anything that is not a PH mobile number', () {
      for (final bad in [
        null,
        '',
        '0917402881', // one digit short
        '091740288130', // one digit long
        '02 8123 4567', // landline
        '08174028813', // does not start 9 after the trunk
        '+1 415 555 0134', // wrong country
        'not a phone',
      ]) {
        expect(
          RiderValidation.normalizePhone(bad),
          isNull,
          reason: '"$bad" should have been rejected',
        );
      }
    });

    test('validatePhone mirrors normalizePhone', () {
      expect(RiderValidation.validatePhone('09174028813'), isNull);
      expect(RiderValidation.validatePhone(''), isNotNull);
      expect(RiderValidation.validatePhone('02 8123 4567'), isNotNull);
    });
  });

  group('sequential IDs', () {
    test('continue past the highest currently in use', () {
      expect(RiderValidation.nextRiderId(MockData.riders), 'R-011');
      expect(RiderValidation.nextHelmetId(MockData.riders), 'NR-H1-011');
    });

    test('are zero-padded to three digits and start at 001 when empty', () {
      expect(RiderValidation.nextRiderId(const <Rider>[]), 'R-001');
      expect(RiderValidation.nextHelmetId(const <Rider>[]), 'NR-H1-001');
    });

    test('ignore ids that do not match the scheme', () {
      final riders = [
        Rider(
          id: 'LEGACY-A',
          fullName: 'Legacy Rider',
          helmetId: 'OLD-HELMET',
          phone: '+63 917 402 8813',
          status: RiderStatus.idle,
        ),
        Rider(
          id: 'R-004',
          fullName: 'Numbered Rider',
          helmetId: 'NR-H1-004',
          phone: '+63 917 402 8814',
          status: RiderStatus.idle,
        ),
      ];

      expect(RiderValidation.nextRiderId(riders), 'R-005');
      expect(RiderValidation.nextHelmetId(riders), 'NR-H1-005');
    });
  });
}
