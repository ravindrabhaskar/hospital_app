import 'package:care_companion_provider/l10n/gen/app_localizations.dart';
import 'package:care_companion_provider/models/home_visit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

/// Wraps [child] in a localized MaterialApp (no Google Fonts fetching).
Widget testApp(Widget child, {Locale locale = const Locale('en'), bool wrap = true}) => MaterialApp(
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: wrap ? Scaffold(body: SingleChildScrollView(child: child)) : child,
    );

Map<String, dynamic> visitJson({
  String id = 'visit-1',
  String status = VisitStatus.assigned,
  DateTime? completedAt,
}) =>
    {
      'id': id,
      'status': status,
      'serviceCode': 'vitals_check',
      'serviceName': 'Vitals Check',
      'price': 499,
      'patientId': 'patient-1',
      'patientName': 'Ramesh Kumar',
      'reason': 'Routine BP check',
      'address': {
        'line1': '12 MG Road',
        'city': 'Hyderabad',
        'pincode': '500001',
        'lat': 17.385,
        'lng': 78.4867,
      },
      'preferredStart': '2026-09-26T09:30:00.000Z',
      'preferredEnd': '2026-09-26T10:30:00.000Z',
      'careEpisodeId': 'ep-1',
      'visitCode': null,
      'provider': {'id': 'prov-1', 'name': 'Sunita Devi', 'qualification': 'GNM', 'photoUrl': null, 'phoneMasked': '98XXXXXX01'},
      'etaMinutes': null,
      'timeline': [
        {'status': 'assigned', 'at': '2026-09-26T08:00:00.000Z', 'note': null},
        if (completedAt != null) {'status': 'completed', 'at': completedAt.toUtc().toIso8601String(), 'note': null},
      ],
      'patientContext': {
        'age': 68,
        'gender': 'male',
        'allergies': ['Penicillin'],
        'conditions': ['Hypertension', 'Type 2 diabetes'],
        'activeMedications': ['Metformin 500mg', 'Amlodipine 5mg'],
      },
      'vitals': [],
      'observations': null,
      'summary': null,
      'escalation': null,
      'createdAt': '2026-09-26T07:55:00.000Z',
    };

HomeVisit visit({String id = 'visit-1', String status = VisitStatus.assigned, DateTime? completedAt}) =>
    HomeVisit.fromJson(visitJson(id: id, status: status, completedAt: completedAt));
