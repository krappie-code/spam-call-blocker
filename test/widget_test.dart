import 'package:flutter_test/flutter_test.dart';
import 'package:spam_call_blocker/models/call_log.dart';
import 'package:spam_call_blocker/models/block_list.dart';
import 'package:spam_call_blocker/models/settings.dart';

void main() {
  group('CallLogEntry', () {
    test('serializes to and from map', () {
      final entry = CallLogEntry(
        phoneNumber: '+27821234567',
        timestamp: DateTime(2024, 1, 15, 10, 30),
        result: CallResult.blocked,
        markedAsSpam: true,
      );
      final map = entry.toMap();
      final restored = CallLogEntry.fromMap({...map, 'id': 1});
      expect(restored.phoneNumber, '+27821234567');
      expect(restored.result, CallResult.blocked);
      expect(restored.markedAsSpam, true);
    });
  });

  group('BlockListEntry', () {
    test('serializes to and from JSON', () {
      final entry = BlockListEntry(
        phoneNumber: '+27821234567',
        label: 'Spam caller',
      );
      final json = entry.toJson();
      final restored = BlockListEntry.fromJson(json);
      expect(restored.phoneNumber, '+27821234567');
      expect(restored.label, 'Spam caller');
    });
  });

  group('AppSettings', () {
    test('has sensible defaults', () {
      final settings = AppSettings();
      expect(settings.callScreeningEnabled, true);
      expect(settings.challengeEnabled, true);
      expect(settings.autoWhitelistContacts, true);
      expect(settings.postCallFeedback, true);
      expect(settings.challengeTimeoutSeconds, 15);
    });
  });
}
