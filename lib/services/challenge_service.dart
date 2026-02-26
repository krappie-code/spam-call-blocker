/// Legacy challenge service — kept for API compatibility.
/// The actual screening logic now lives in the native SpamInCallService
/// which uses a "wait-and-connect" approach instead of DTMF challenges.
class ChallengeService {
  // No-op — screening is handled natively
  void reset() {}
  bool verify(String dtmfDigit) => false;
  int? get currentChallenge => null;
  Future<void> dispose() async {}
}
