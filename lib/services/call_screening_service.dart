import 'dart:async';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/call_log.dart';
import '../models/block_list.dart';
import 'database_service.dart';
import 'challenge_service.dart';
import 'contacts_service.dart';

/// Bridges to the native Android call services.
/// Listens for call events and manages the blocklist.
class CallScreeningService {
  static const _channel = MethodChannel('com.spamcallblocker.app/screening');
  static const _eventChannel = EventChannel('com.spamcallblocker.app/call_events');

  final DatabaseService _db;
  final ChallengeService _challenge;
  final ContactsService _contacts;

  StreamSubscription? _eventSubscription;

  /// Callback for UI updates when a call is processed
  void Function(String phoneNumber, CallResult result)? onCallProcessed;

  CallScreeningService(this._db, this._challenge, this._contacts);

  /// Start listening for call events and sync blocklist to native.
  void init() {
    _eventSubscription = _eventChannel
        .receiveBroadcastStream()
        .listen(_handleCallEvent, onError: (error) {});
    // Sync blocklist to SharedPreferences for native access
    syncBlocklistToNative();
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
      case 'blocklist_rejected':
        await _logCall(phoneNumber, CallResult.blocked);
        onCallProcessed?.call(phoneNumber, CallResult.blocked);
        break;
      case 'spam_detected':
        // Caller hung up during hold — likely spam
        await _logCall(phoneNumber, CallResult.blocked);
        onCallProcessed?.call(phoneNumber, CallResult.blocked);
        break;
      case 'screened_connected':
        // Caller waited through hold — connected
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

  /// Add a number to the blocklist and sync to native SharedPreferences.
  Future<void> blockNumber(String phoneNumber, {String? label}) async {
    await _db.addToBlockList(BlockListEntry(
      phoneNumber: phoneNumber,
      label: label,
    ));
    await syncBlocklistToNative();
  }

  /// Remove a number from the blocklist and sync to native.
  Future<void> unblockNumber(int id) async {
    await _db.removeFromBlockList(id);
    await syncBlocklistToNative();
  }

  /// Sync the full blocklist to native SharedPreferences so the
  /// InCallService can access it without a DB connection.
  Future<void> syncBlocklistToNative() async {
    final blocklist = await _db.getBlockList();
    final numbers = blocklist.map((e) => e.phoneNumber).toSet();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('blocklist_numbers', numbers.toList());
    // Also write to the native SharedPreferences file
    try {
      await _channel.invokeMethod('syncBlocklist', {'numbers': numbers.toList()});
    } on MissingPluginException {
      // Native method not available, blocklist synced via SharedPreferences
    }
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
