import 'package:flutter/services.dart';
import '../models/call_log.dart';
import 'database_service.dart';
import 'challenge_service.dart';
import 'contacts_service.dart';

/// Bridges to the native Android CallScreeningService (API 29+).
/// On Android 8-9, falls back to InCallService via platform channels.
class CallScreeningService {
  static const _channel = MethodChannel('com.spamcallblocker.app/screening');
  final DatabaseService _db;
  final ChallengeService _challenge;
  final ContactsService _contacts;

  CallScreeningService(this._db, this._challenge, this._contacts);

  /// Initialize platform channel handlers for incoming call events.
  void init() {
    _channel.setMethodCallHandler(_handleMethod);
  }

  Future<dynamic> _handleMethod(MethodCall call) async {
    switch (call.method) {
      case 'onIncomingCall':
        final phoneNumber = call.arguments['phoneNumber'] as String;
        return await _handleIncomingCall(phoneNumber);
      case 'onDtmfReceived':
        final digit = call.arguments['digit'] as String;
        return _challenge.verify(digit);
      default:
        throw MissingPluginException('Unknown method: ${call.method}');
    }
  }

  /// Decide how to handle an incoming call.
  /// Returns a map with 'action': 'allow', 'block', or 'challenge'.
  Future<Map<String, String>> _handleIncomingCall(String phoneNumber) async {
    // Check device contacts in real-time first
    if (await _contacts.isDeviceContact(phoneNumber)) {
      await _logCall(phoneNumber, CallResult.allowed);
      return {'action': 'allow'};
    }

    // Check whitelist (manually added numbers)
    if (await _db.isWhitelisted(phoneNumber)) {
      await _logCall(phoneNumber, CallResult.allowed);
      return {'action': 'allow'};
    }

    // Check block list
    if (await _db.isBlocked(phoneNumber)) {
      await _logCall(phoneNumber, CallResult.blocked);
      return {'action': 'block'};
    }

    // Unknown caller → issue challenge
    final digit = await _challenge.issueChallenge();
    return {'action': 'challenge', 'expectedDigit': digit.toString()};
  }

  Future<void> _logCall(String phoneNumber, CallResult result) async {
    await _db.insertCallLog(CallLogEntry(
      phoneNumber: phoneNumber,
      timestamp: DateTime.now(),
      result: result,
    ));
  }

  /// Request the user to set this app as the default call screening app.
  Future<bool> requestRole() async {
    try {
      final result = await _channel.invokeMethod<bool>('requestScreeningRole');
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Check if the app currently has the call screening role.
  Future<bool> hasRole() async {
    try {
      final result = await _channel.invokeMethod<bool>('hasScreeningRole');
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }
}
