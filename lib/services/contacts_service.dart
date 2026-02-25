import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'database_service.dart';

class ContactsService {
  final DatabaseService _db;

  ContactsService(this._db);

  /// Check if a phone number matches any device contact in real-time.
  /// Returns true if the number belongs to a known contact.
  Future<bool> isDeviceContact(String phoneNumber) async {
    final status = await Permission.contacts.status;
    if (!status.isGranted) return false;

    final normalized = _normalizePhone(phoneNumber);
    if (normalized.isEmpty) return false;

    final contacts = await FlutterContacts.getContacts(
      withProperties: true,
      withPhoto: false,
      withThumbnail: false,
    );

    for (final contact in contacts) {
      for (final phone in contact.phones) {
        final contactNumber = _normalizePhone(phone.number);
        if (contactNumber.isNotEmpty && _numbersMatch(normalized, contactNumber)) {
          return true;
        }
      }
    }
    return false;
  }

  /// Check if two normalized phone numbers match.
  /// Compares the last 10 digits to handle country code differences.
  bool _numbersMatch(String a, String b) {
    if (a == b) return true;
    // Compare last 10 digits to handle +27 vs 0 prefix differences
    final aDigits = a.replaceAll(RegExp(r'[^\d]'), '');
    final bDigits = b.replaceAll(RegExp(r'[^\d]'), '');
    if (aDigits.length >= 10 && bDigits.length >= 10) {
      return aDigits.substring(aDigits.length - 10) ==
          bDigits.substring(bDigits.length - 10);
    }
    return aDigits == bDigits;
  }

  /// Request contacts permission and sync all phone contacts to whitelist.
  Future<bool> syncContacts() async {
    final status = await Permission.contacts.request();
    if (!status.isGranted) return false;

    final contacts = await FlutterContacts.getContacts(
      withProperties: true,
      withPhoto: false,
      withThumbnail: false,
    );

    final entries = <Map<String, String>>[];
    for (final contact in contacts) {
      for (final phone in contact.phones) {
        final number = _normalizePhone(phone.number);
        if (number.isNotEmpty) {
          entries.add({
            'phone': number,
            'name': contact.displayName,
          });
        }
      }
    }

    await _db.syncContactsToWhitelist(entries);
    return true;
  }

  /// Normalize phone number by stripping non-digit chars (keeping leading +).
  String _normalizePhone(String raw) {
    final cleaned = raw.replaceAll(RegExp(r'[^\d+]'), '');
    return cleaned.length >= 7 ? cleaned : '';
  }
}
