import 'package:flutter_test/flutter_test.dart';
import 'package:spam_call_blocker/models/call_log.dart';

void main() {
  group('CallLogEntry', () {
    test('creates with required fields', () {
      final entry = CallLogEntry(
        phoneNumber: '+27123456789',
        timestamp: DateTime(2026, 1, 1),
        result: CallResult.allowed,
      );
      expect(entry.phoneNumber, '+27123456789');
      expect(entry.result, CallResult.allowed);
      expect(entry.markedAsSpam, isNull);
    });

    test('toMap includes all fields', () {
      final entry = CallLogEntry(
        id: 1,
        phoneNumber: '+27111111111',
        timestamp: DateTime(2026, 6, 15, 10, 30),
        result: CallResult.blocked,
        markedAsSpam: true,
      );
      final map = entry.toMap();
      expect(map['id'], 1);
      expect(map['phone_number'], '+27111111111');
      expect(map['result'], 'blocked');
      expect(map['marked_as_spam'], 1);
    });

    test('toMap handles null markedAsSpam', () {
      final entry = CallLogEntry(
        phoneNumber: '+27222222222',
        timestamp: DateTime(2026, 1, 1),
        result: CallResult.challengePassed,
      );
      final map = entry.toMap();
      expect(map['marked_as_spam'], isNull);
    });

    test('toMap encodes markedAsSpam false as 0', () {
      final entry = CallLogEntry(
        phoneNumber: '+27333333333',
        timestamp: DateTime(2026, 1, 1),
        result: CallResult.allowed,
        markedAsSpam: false,
      );
      expect(entry.toMap()['marked_as_spam'], 0);
    });

    test('fromMap round-trips correctly', () {
      final original = CallLogEntry(
        id: 5,
        phoneNumber: '+27444444444',
        timestamp: DateTime(2026, 3, 20, 14, 30),
        result: CallResult.challengeFailed,
        markedAsSpam: true,
      );
      final restored = CallLogEntry.fromMap(original.toMap());
      expect(restored.id, original.id);
      expect(restored.phoneNumber, original.phoneNumber);
      expect(restored.result, original.result);
      expect(restored.markedAsSpam, original.markedAsSpam);
    });
  });

  group('CallResult', () {
    test('has all expected values', () {
      expect(CallResult.values, contains(CallResult.allowed));
      expect(CallResult.values, contains(CallResult.blocked));
      expect(CallResult.values, contains(CallResult.challengePassed));
      expect(CallResult.values, contains(CallResult.challengeFailed));
      expect(CallResult.values.length, 4);
    });
  });
}
