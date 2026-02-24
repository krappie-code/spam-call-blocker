import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'database_service.dart';

class ContactsService {
  final DatabaseService _db;

  ContactsService(this._db);

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
