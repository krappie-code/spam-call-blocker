import 'package:contacts_service/contacts_service.dart' as cs;
import 'package:permission_handler/permission_handler.dart';
import 'database_service.dart';

class ContactsService {
  final DatabaseService _db;

  ContactsService(this._db);

  /// Request contacts permission and sync all phone contacts to whitelist.
  Future<bool> syncContacts() async {
    final status = await Permission.contacts.request();
    if (!status.isGranted) return false;

    final contacts = await cs.ContactsService.getContacts(
      withThumbnails: false,
      photoHighResolution: false,
    );

    final entries = <Map<String, String>>[];
    for (final contact in contacts) {
      if (contact.phones == null) continue;
      for (final phone in contact.phones!) {
        final number = _normalizePhone(phone.value ?? '');
        if (number.isNotEmpty) {
          entries.add({
            'phone': number,
            'name': contact.displayName ?? 'Unknown',
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
