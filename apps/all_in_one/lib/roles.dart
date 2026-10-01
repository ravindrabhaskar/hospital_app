import 'package:flutter/material.dart';

/// The three CareCompanion apps bundled in this demo build.
enum DemoRole {
  patient(
    id: 'patient',
    storagePrefix: 'patient.',
    headline: "I'm a patient / family member",
    appName: 'CareCompanion',
    description: 'Appointments, records, medicines, home visits and SOS for you and your family.',
    color: Color(0xFF631D3F),
    asset: 'assets/roles/patient.png',
  ),
  provider(
    id: 'provider',
    storagePrefix: 'provider.',
    headline: "I'm a home-care nurse / technician",
    appName: 'CareCompanion Pro',
    description: "Today's visits and route, the guided visit checklist, attendance and earnings.",
    color: Color(0xFF8A3A62),
    asset: 'assets/roles/provider.png',
  ),
  doctor(
    id: 'doctor',
    storagePrefix: 'doctor.',
    headline: "I'm a doctor",
    appName: 'CareCompanion Doctor',
    description: 'Your queue, consultations, e-prescriptions, care plans and messages.',
    color: Color(0xFF4A142E),
    asset: 'assets/roles/doctor.png',
  );

  const DemoRole({
    required this.id,
    required this.storagePrefix,
    required this.headline,
    required this.appName,
    required this.description,
    required this.color,
    required this.asset,
  });

  /// Persisted id of the remembered choice.
  final String id;

  /// Namespace for the app's secure storage, preferences and files, so the
  /// three apps never share tokens, caches or settings.
  final String storagePrefix;
  final String headline;
  final String appName;
  final String description;
  final Color color;
  final String asset;

  static DemoRole? fromId(String? id) {
    for (final r in values) {
      if (r.id == id) return r;
    }
    return null;
  }
}
