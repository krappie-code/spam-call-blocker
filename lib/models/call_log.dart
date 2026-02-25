class CallLogEntry {
  final int? id;
  final String phoneNumber;
  final DateTime timestamp;
  final CallResult result;
  final bool? markedAsSpam;

  CallLogEntry({
    this.id,
    required this.phoneNumber,
    required this.timestamp,
    required this.result,
    this.markedAsSpam,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'phone_number': phoneNumber,
        'timestamp': timestamp.toIso8601String(),
        'result': result.name,
        'marked_as_spam': markedAsSpam == null
            ? null
            : (markedAsSpam! ? 1 : 0),
      };

  factory CallLogEntry.fromMap(Map<String, dynamic> map) => CallLogEntry(
        id: map['id'] as int?,
        phoneNumber: map['phone_number'] as String,
        timestamp: DateTime.parse(map['timestamp'] as String),
        result: CallResult.values.byName(map['result'] as String),
        markedAsSpam: map['marked_as_spam'] == null
            ? null
            : (map['marked_as_spam'] as int) == 1,
      );
}

enum CallResult {
  allowed,
  blocked,
  challengePassed,
  challengeFailed,
}
