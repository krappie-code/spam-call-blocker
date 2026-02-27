import 'package:flutter_test/flutter_test.dart';
import 'package:spam_call_blocker/services/challenge_service.dart';

void main() {
  group('ChallengeService', () {
    // Note: issueChallenge() requires FlutterTts which needs a platform,
    // so we test the verify/reset logic directly.

    test('verify returns false when no challenge issued', () {
      final service = ChallengeService();
      expect(service.verify('5'), false);
    });

    test('currentChallenge is null initially', () {
      final service = ChallengeService();
      expect(service.currentChallenge, isNull);
    });

    test('reset clears currentChallenge', () {
      final service = ChallengeService();
      service.reset();
      expect(service.currentChallenge, isNull);
    });

    test('verify handles non-numeric input', () {
      final service = ChallengeService();
      expect(service.verify('abc'), false);
      expect(service.verify(''), false);
    });
  });
}
