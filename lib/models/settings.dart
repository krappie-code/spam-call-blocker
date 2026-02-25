class AppSettings {
  bool callScreeningEnabled;
  bool challengeEnabled;
  bool autoWhitelistContacts;
  bool postCallFeedback;
  int challengeTimeoutSeconds;

  AppSettings({
    this.callScreeningEnabled = true,
    this.challengeEnabled = true,
    this.autoWhitelistContacts = true,
    this.postCallFeedback = true,
    this.challengeTimeoutSeconds = 15,
  });

  Map<String, dynamic> toMap() => {
        'call_screening_enabled': callScreeningEnabled ? 1 : 0,
        'challenge_enabled': challengeEnabled ? 1 : 0,
        'auto_whitelist_contacts': autoWhitelistContacts ? 1 : 0,
        'post_call_feedback': postCallFeedback ? 1 : 0,
        'challenge_timeout_seconds': challengeTimeoutSeconds,
      };

  factory AppSettings.fromMap(Map<String, dynamic> map) => AppSettings(
        callScreeningEnabled: (map['call_screening_enabled'] as int) == 1,
        challengeEnabled: (map['challenge_enabled'] as int) == 1,
        autoWhitelistContacts: (map['auto_whitelist_contacts'] as int) == 1,
        postCallFeedback: (map['post_call_feedback'] as int) == 1,
        challengeTimeoutSeconds: map['challenge_timeout_seconds'] as int,
      );
}
