// An EmergencyContactRepository kept in memory.

import 'dart:async';

import 'package:novaride/features/rider/domain/entities/emergency_contact.dart';
import 'package:novaride/features/rider/domain/repositories/emergency_contact_repository.dart';

class FakeEmergencyContactRepository implements EmergencyContactRepository {
  FakeEmergencyContactRepository({List<EmergencyContact> contacts = const []})
      : _contacts = List.of(contacts);

  final List<EmergencyContact> _contacts;
  final _ctrl = StreamController<List<EmergencyContact>>.broadcast();
  final List<String> calls = [];
  var _nextId = 1;

  void _emit() => _ctrl.add(List.of(_contacts));

  @override
  Stream<List<EmergencyContact>> watch(String riderUid) async* {
    yield List.of(_contacts);
    yield* _ctrl.stream;
  }

  @override
  Future<void> add(String riderUid, EmergencyContact contact) async {
    calls.add('add:${contact.name}|${contact.relationship}|${contact.phone}');
    _contacts.add(EmergencyContact(
      id: 'c${_nextId++}',
      name: contact.name,
      relationship: contact.relationship,
      phone: contact.phone,
    ));
    _emit();
  }

  @override
  Future<void> update(String riderUid, EmergencyContact contact) async {
    calls.add('update:${contact.id}');
    final i = _contacts.indexWhere((c) => c.id == contact.id);
    if (i >= 0) _contacts[i] = contact;
    _emit();
  }

  @override
  Future<void> delete(String riderUid, String contactId) async {
    calls.add('delete:$contactId');
    _contacts.removeWhere((c) => c.id == contactId);
    _emit();
  }
}
