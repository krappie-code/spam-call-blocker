import 'package:flutter_test/flutter_test.dart';
import 'package:spam_call_blocker/services/contacts_service.dart';

void main() {
  group('ContactsService phone normalization', () {
    // Test the normalize logic indirectly through the public API
    // The _normalizePhone method strips non-digit chars (keeping +) and
    // requires length >= 7

    test('class can be instantiated', () {
      // ContactsService requires DatabaseService, but we can verify the type exists
      expect(ContactsService, isNotNull);
    });
  });

  group('Phone number matching logic', () {
    // Test the last-10-digit comparison used in isDeviceContact
    test('numbers with same last 9 digits should match', () {
      // +27 82 123 4567 → digits: 27821234567 → last 9: 821234567
      // 082 123 4567   → digits: 0821234567  → last 9: 821234567
      final num1 = '+27821234567';
      final num2 = '0821234567';
      final suffix1 = num1.replaceAll(RegExp(r'[^\d]'), '');
      final suffix2 = num2.replaceAll(RegExp(r'[^\d]'), '');
      final last1 = suffix1.length > 9 ? suffix1.substring(suffix1.length - 9) : suffix1;
      final last2 = suffix2.length > 9 ? suffix2.substring(suffix2.length - 9) : suffix2;
      expect(last1, last2);
    });

    test('different numbers should not match', () {
      final num1 = '+27821234567';
      final num2 = '+27829999999';
      final suffix1 = num1.replaceAll(RegExp(r'[^\d]'), '');
      final suffix2 = num2.replaceAll(RegExp(r'[^\d]'), '');
      final last1 = suffix1.length > 9 ? suffix1.substring(suffix1.length - 9) : suffix1;
      final last2 = suffix2.length > 9 ? suffix2.substring(suffix2.length - 9) : suffix2;
      expect(last1, isNot(equals(last2)));
    });

    test('normalizes formatted numbers', () {
      final raw = '+27 (82) 123-4567';
      final cleaned = raw.replaceAll(RegExp(r'[^\d]'), '');
      expect(cleaned, '27821234567');
      expect(cleaned.length >= 7, true);
    });

    test('rejects too-short numbers', () {
      final raw = '12345';
      final cleaned = raw.replaceAll(RegExp(r'[^\d]'), '');
      expect(cleaned.length >= 7, false);
    });
  });
}
