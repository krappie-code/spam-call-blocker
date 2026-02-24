import 'package:flutter/services.dart';

/// Bridges to the native Android InCallService for Android 8-9 fallback.
/// On Android 10+, the CallScreeningService is used instead.
class InCallServiceBridge {
  static const _channel = MethodChannel('com.spamcallblocker.app/incall');

  /// Register this app as an InCallService handler.
  Future<bool> requestRole() async {
    try {
      final result = await _channel.invokeMethod<bool>('requestInCallRole');
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Disconnect (end) the current call.
  Future<void> endCall() async {
    try {
      await _channel.invokeMethod('endCall');
    } on PlatformException {
      // Silently fail if no active call
    }
  }

  /// Answer the current ringing call.
  Future<void> answerCall() async {
    try {
      await _channel.invokeMethod('answerCall');
    } on PlatformException {
      // Silently fail
    }
  }
}
