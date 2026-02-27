import 'package:flutter_test/flutter_test.dart';
import 'package:spam_call_blocker/models/settings.dart';

void main() {
  group('AppSettings', () {
    test('defaults are correct', () {
      final settings = AppSettings();
      expect(settings.callScreeningEnabled, true);
      expect(settings.challengeEnabled, true);
      expect(settings.autoWhitelistContacts, true);
      expect(settings.postCallFeedback, true);
      expect(settings.challengeTimeoutSeconds, 15);
    });

    test('custom values are respected', () {
      final settings = AppSettings(
        callScreeningEnabled: false,
        challengeEnabled: false,
        autoWhitelistContacts: false,
        postCallFeedback: false,
        challengeTimeoutSeconds: 30,
      );
      expect(settings.callScreeningEnabled, false);
      expect(settings.challengeEnabled, false);
      expect(settings.autoWhitelistContacts, false);
      expect(settings.postCallFeedback, false);
      expect(settings.challengeTimeoutSeconds, 30);
    });

    test('toMap encodes booleans as integers', () {
      final settings = AppSettings(
        callScreeningEnabled: true,
        challengeEnabled: false,
      );
      final map = settings.toMap();
      expect(map['call_screening_enabled'], 1);
      expect(map['challenge_enabled'], 0);
    });

    test('fromMap round-trips correctly', () {
      final original = AppSettings(
        callScreeningEnabled: false,
        challengeEnabled: true,
        autoWhitelistContacts: false,
        postCallFeedback: true,
        challengeTimeoutSeconds: 25,
      );
      final restored = AppSettings.fromMap(original.toMap());
      expect(restored.callScreeningEnabled, original.callScreeningEnabled);
      expect(restored.challengeEnabled, original.challengeEnabled);
      expect(restored.autoWhitelistContacts, original.autoWhitelistContacts);
      expect(restored.postCallFeedback, original.postCallFeedback);
      expect(restored.challengeTimeoutSeconds, original.challengeTimeoutSeconds);
    });
  });
}
