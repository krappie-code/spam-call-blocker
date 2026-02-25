import 'dart:async';
import 'package:flutter/services.dart';
import '../models/call_log.dart';
import 'database_service.dart';
import 'challenge_service.dart';
import 'contacts_service.dart';

/// Bridges to the native Android CallScreeningService (API 29+).
/// Listens for call events via EventChannel and logs them to the database.
class CallScreeningService {
  static const _channel = MethodChannel('com.spamcallblocker.app/screening');
  static const _eventChannel = EventChannel('com.spamcallblocker.app/call_events');
  
  final DatabaseService _db;
  final ChallengeService _challenge;
  final ContactsService _contacts;
  
  StreamSubscription? _eventSubscription;
  
  // Callback for UI updates when a call is processed
  void Function(String phoneNumber, CallResult result)? onCallProcessed;

  CallScreeningService(this._db, this._challenge, this._contacts);

  /// Start listening for call events from the native screening service.
  void init() {
    _eventSubscription = _eventChannel
        .receiveBroadcastStream()
        .listen(_handleCallEvent, onError: (error) {
      // EventChannel errors are non-fatal
    });
  }

  void dispose() {
    _eventSubscription?.cancel();
  }

  Future<void> _handleCallEvent(dynamic event) async {
    if (event is! Map) return;
    final action = event['action'] as String?;
    final phoneNumber = event['phoneNumber'] as String?;
    if (action == null || phoneNumber == null) return;

    switch (action) {
      case 'contact_allowed':
        await _logCall(phoneNumber, CallResult.allowed);
        onCallProcessed?.call(phoneNumber, CallResult.allowed);
        break;
      case 'challenge_needed':
        // Unknown caller — challenge is being issued by InCallService
        await _logCall(phoneNumber, CallResult.blocked);
        onCallProcessed?.call(phoneNumber, CallResult.blocked);
        break;
      case 'challenge_failed':
        await _logCall(phoneNumber, CallResult.challengeFailed);
        onCallProcessed?.call(phoneNumber, CallResult.challengeFailed);
        break;
      case 'challenge_passed':
        await _logCall(phoneNumber, CallResult.challengePassed);
        onCallProcessed?.call(phoneNumber, CallResult.challengePassed);
        break;
    }
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
