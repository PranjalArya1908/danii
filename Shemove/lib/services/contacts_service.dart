import 'package:flutter/foundation.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

class DeviceContactInfo {
  final String id;
  final String name;
  final String phone;

  const DeviceContactInfo({
    required this.id,
    required this.name,
    required this.phone,
  });
}

class ContactsService {
  /// Check whether read contacts permission is granted
  Future<bool> hasPermission() async {
    try {
      return await FlutterContacts.permissions.has(PermissionType.read);
    } catch (e) {
      debugPrint('ContactsService.hasPermission error: $e');
      return false;
    }
  }

  /// Request runtime contacts permission
  Future<bool> requestPermission() async {
    try {
      final status = await FlutterContacts.permissions.request(PermissionType.read);
      return status == PermissionStatus.granted;
    } catch (e) {
      debugPrint('ContactsService.requestPermission error: $e');
      return false;
    }
  }

  /// Open device native contact picker and return selected contact
  Future<DeviceContactInfo?> pickContact() async {
    try {
      final contact = await FlutterContacts.native.showPicker(
        properties: {ContactProperty.name, ContactProperty.phone},
      );
      if (contact != null) {
        String name = contact.displayName?.trim() ?? '';
        if (name.isEmpty && contact.name != null) {
          final first = contact.name?.first ?? '';
          final last = contact.name?.last ?? '';
          name = '$first $last'.trim();
        }
        final phone = contact.phones.isNotEmpty
            ? contact.phones.first.number.trim()
            : '';
        if (name.isNotEmpty && phone.isNotEmpty) {
          return DeviceContactInfo(
            id: contact.id ?? UniqueKey().toString(),
            name: name,
            phone: phone,
          );
        }
      }
    } catch (e) {
      debugPrint('ContactsService.pickContact error: $e');
    }
    return null;
  }

  /// Fetch list of phone contacts matching optional query
  Future<List<DeviceContactInfo>> getDeviceContacts({String? query}) async {
    try {
      final hasPerm = await hasPermission();
      if (!hasPerm) {
        final granted = await requestPermission();
        if (!granted) return [];
      }

      final contacts = await FlutterContacts.getAll(
        properties: {ContactProperty.name, ContactProperty.phone},
      );

      final result = <DeviceContactInfo>[];
      for (final c in contacts) {
        String name = c.displayName?.trim() ?? '';
        if (name.isEmpty && c.name != null) {
          final first = c.name?.first ?? '';
          final last = c.name?.last ?? '';
          name = '$first $last'.trim();
        }
        if (name.isEmpty || c.phones.isEmpty) continue;

        final phone = c.phones.first.number.trim();
        if (phone.isEmpty) continue;

        if (query != null && query.trim().isNotEmpty) {
          final q = query.trim().toLowerCase();
          if (!name.toLowerCase().contains(q) && !phone.contains(q)) {
            continue;
          }
        }

        result.add(DeviceContactInfo(
          id: c.id ?? UniqueKey().toString(),
          name: name,
          phone: phone,
        ));
      }

      return result;
    } catch (e) {
      debugPrint('ContactsService.getDeviceContacts error: $e');
      return [];
    }
  }
}

