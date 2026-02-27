import 'package:flutter_test/flutter_test.dart';
import 'package:spam_call_blocker/models/block_list.dart';

void main() {
  group('BlockListEntry', () {
    test('creates with required fields', () {
      final entry = BlockListEntry(phoneNumber: '+27123456789');
      expect(entry.phoneNumber, '+27123456789');
      expect(entry.id, isNull);
      expect(entry.label, isNull);
      expect(entry.createdAt, isNotNull);
    });

    test('creates with all fields', () {
      final now = DateTime(2026, 1, 1);
      final entry = BlockListEntry(
        id: 1,
        phoneNumber: '+27123456789',
        label: 'Spammer',
        createdAt: now,
      );
      expect(entry.id, 1);
      expect(entry.phoneNumber, '+27123456789');
      expect(entry.label, 'Spammer');
      expect(entry.createdAt, now);
    });

    test('toMap includes all fields', () {
      final entry = BlockListEntry(
        id: 5,
        phoneNumber: '+27111111111',
        label: 'Telemarketer',
        createdAt: DateTime(2026, 6, 15),
      );
      final map = entry.toMap();
      expect(map['id'], 5);
      expect(map['phone_number'], '+27111111111');
      expect(map['label'], 'Telemarketer');
      expect(map['created_at'], '2026-06-15T00:00:00.000');
    });

    test('toMap excludes null id', () {
      final entry = BlockListEntry(phoneNumber: '+27000000000');
      final map = entry.toMap();
      expect(map.containsKey('id'), false);
    });

    test('fromMap round-trips correctly', () {
      final original = BlockListEntry(
        id: 3,
        phoneNumber: '+27999999999',
        label: 'Scam',
        createdAt: DateTime(2026, 3, 20, 14, 30),
      );
      final restored = BlockListEntry.fromMap(original.toMap());
      expect(restored.id, original.id);
      expect(restored.phoneNumber, original.phoneNumber);
      expect(restored.label, original.label);
      expect(restored.createdAt, original.createdAt);
    });

    test('toJson excludes id', () {
      final entry = BlockListEntry(
        id: 10,
        phoneNumber: '+27555555555',
        label: 'Export test',
      );
      final json = entry.toJson();
      expect(json.containsKey('id'), false);
      expect(json['phone_number'], '+27555555555');
    });

    test('fromJson round-trips correctly', () {
      final entry = BlockListEntry(
        phoneNumber: '+27444444444',
        label: 'Import test',
      );
      final restored = BlockListEntry.fromJson(entry.toJson());
      expect(restored.phoneNumber, entry.phoneNumber);
      expect(restored.label, entry.label);
    });
  });
}
