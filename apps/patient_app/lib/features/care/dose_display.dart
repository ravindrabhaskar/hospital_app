import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/care.dart';
import '../../state/core_providers.dart';

/// When each medication was added on this device (medication id -> time),
/// so doses scheduled before it existed are not shown as "Missed" (B18).
/// The server's `createdAt` wins when it sends one.
class MedicationAddedLog extends Notifier<Map<String, DateTime>> {
  static const key = 'cc_med_added_at';
  static const _max = 100;

  @override
  Map<String, DateTime> build() {
    try {
      final raw = ref.read(sharedPrefsProvider).getString(key);
      if (raw == null) return const {};
      final m = jsonDecode(raw) as Map<String, dynamic>;
      return {for (final e in m.entries) e.key: DateTime.fromMillisecondsSinceEpoch(e.value as int)};
    } catch (_) {
      return const {};
    }
  }

  Future<void> record(String medicationId, DateTime at) async {
    final next = {...state, medicationId: at};
    final entries = next.entries.toList()..sort((a, b) => a.value.compareTo(b.value));
    state = Map.fromEntries(entries.length > _max ? entries.sublist(entries.length - _max) : entries);
    try {
      await ref.read(sharedPrefsProvider).setString(
          key, jsonEncode({for (final e in state.entries) e.key: e.value.millisecondsSinceEpoch}));
    } catch (_) {}
  }
}

final medicationAddedLogProvider =
    NotifierProvider<MedicationAddedLog, Map<String, DateTime>>(MedicationAddedLog.new);

/// A dose the server marks "missed" although it was due before the medicine
/// was added: it was never really due, so it is not shown.
bool isPreAddMissedDose(String status, DateTime scheduledAt, DateTime? addedAt) =>
    status == 'missed' && addedAt != null && scheduledAt.isBefore(addedAt);

/// Today's doses worth showing for [m].
List<DoseToday> visibleDoses(Medication m, Map<String, DateTime> addedLog) {
  final addedAt = m.createdAt ?? addedLog[m.id];
  return [
    for (final d in m.today)
      if (!isPreAddMissedDose(d.status, DateTime.tryParse(d.scheduledAt) ?? DateTime.now(), addedAt)) d,
  ];
}

/// Today's reminders without medication doses that predate the medicine.
List<Reminder> visibleReminders(List<Reminder> items, Map<String, DateTime> addedLog) => [
      for (final r in items)
        if (r.kind != 'medication' || !isPreAddMissedDose(r.status, r.at, addedLog[r.refId])) r,
    ];
