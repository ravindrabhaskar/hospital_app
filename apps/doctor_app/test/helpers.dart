import 'dart:convert';

import 'package:care_companion_doctor/core/api/api_client.dart';
import 'package:care_companion_doctor/core/api/token_store.dart';
import 'package:care_companion_doctor/core/connectivity.dart';
import 'package:care_companion_doctor/core/providers.dart';
import 'package:care_companion_doctor/core/storage/key_value_store.dart';
import 'package:care_companion_doctor/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Wraps [child] in a localized MaterialApp (no Google Fonts fetching).
Widget testApp(Widget child, {List overrides = const [], bool scaffold = true}) => ProviderScope(
  retry: (_, _) => null,
  overrides: [...overrides],
  child: MaterialApp(
    locale: const Locale('en'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: scaffold ? Scaffold(body: child) : child,
  ),
);

typedef Handler = Object? Function(http.Request req, String path);

http.Response jsonResponse(Object? body, [int status = 200]) =>
    http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json'});

http.Response errorResponse(int status, String code, [String message = 'err', Map<String, dynamic>? details]) =>
    jsonResponse({
      'error': {'code': code, 'message': message, 'details': details ?? {}, 'correlationId': 'c-1'},
    }, status);

/// A mock backend: [handler] returns a body (-> 200 JSON), an http.Response,
/// or null (-> 404). Every request is recorded.
({MockClient client, List<http.Request> requests}) mockBackend(Handler handler) {
  final requests = <http.Request>[];
  final client = MockClient((req) async {
    requests.add(req);
    final path = req.url.path.replaceFirst('/api/v1', '');
    final res = handler(req, path);
    if (res is http.Response) return res;
    if (res == null) return errorResponse(404, 'NOT_FOUND', 'nf');
    return jsonResponse(res);
  });
  return (client: client, requests: requests);
}

Future<ApiClient> apiWith(http.Client client, {bool session = true}) async {
  final store = MemoryKeyValueStore();
  final tokens = TokenStore(store);
  if (session) await tokens.save('access-1', 'refresh-1');
  return ApiClient(baseUrl: 'http://test/api/v1', tokens: tokens, httpClient: client);
}

/// Standard overrides for widget tests that talk to a mock backend.
List commonOverrides(http.Client client, {MemoryKeyValueStore? store}) => [
  keyValueStoreProvider.overrideWithValue(store ?? MemoryKeyValueStore()),
  httpClientProvider.overrideWithValue(client),
  connectivityProvider.overrideWithValue(FakeConnectivityService(online: true)),
  appVersionReaderProvider.overrideWithValue(() async => '1.0.0'),
  clockProvider.overrideWithValue(() => DateTime(2026, 9, 29, 9)),
];

Map<String, dynamic> meJson({List<String> roles = const ['doctor'], bool enrolled = false, bool verified = false}) => {
  'id': 'user-1',
  'phone': '+919800000101',
  'name': 'Ananya Rao',
  'email': null,
  'roles': roles,
  'language': 'en',
  'selfPatientId': null,
  'onboardingComplete': true,
  'mfaRequired': true,
  'mfaEnrolled': enrolled,
  'mfaVerified': verified,
  'providerId': 'doc-1',
};

Map<String, dynamic> sessionJson({bool verified = true, String access = 'access-2'}) => {
  'accessToken': access,
  'refreshToken': 'refresh-2',
  'expiresIn': 900,
  'user': meJson(enrolled: true, verified: verified),
};

Map<String, dynamic> profileJson() => {
  'id': 'doc-1',
  'name': 'Dr. Ananya Rao',
  'specialty': 'general_physician',
  'specialtyName': 'General Physician',
  'qualifications': 'MBBS, MD',
  'experienceYears': 8,
  'rating': 4.8,
  'ratingCount': 320,
  'languages': ['English', 'Hindi'],
  'fees': {'video': 499, 'audio': 499, 'chat': 399, 'inClinic': 499},
  'photoUrl': null,
  'verified': true,
  'bio': 'GP',
  'registrationNumber': 'TSMC-1234',
  'reviews': [],
  'acceptingBookings': true,
};

Map<String, dynamic> queueItem({
  String id = 'appt-1',
  String status = 'confirmed',
  String priority = 'routine',
  String patient = 'Ramesh Kumar',
  String mode = 'video',
  String start = '2026-09-29T04:30:00.000Z',
}) => {
  'id': id,
  'patientId': 'pat-1',
  'patientName': patient,
  'doctorId': 'doc-1',
  'doctorName': 'Dr. Ananya Rao',
  'doctorSpecialty': 'general_physician',
  'doctorPhotoUrl': null,
  'startAt': start,
  'endAt': '2026-09-29T05:00:00.000Z',
  'mode': mode,
  'status': status,
  'reason': 'BP follow-up',
  'fee': 499,
  'careEpisodeId': 'ep-1',
  'videoRoomUrl': null,
  'clinicianNotes': null,
  'createdAt': '2026-09-28T10:00:00.000Z',
  'patientAge': 68,
  'patientGender': 'male',
  'episodeStatus': 'CARE_SCHEDULED',
  'priority': priority,
};

Map<String, dynamic> snapshotJson() => {
  'patient': {
    'id': 'pat-1',
    'name': 'Ramesh Kumar',
    'age': 68,
    'gender': 'male',
    'allergies': [
      {'id': 'a1', 'substance': 'Penicillin', 'reaction': 'Rash', 'severity': 'severe', 'source': 'patient_entered'},
    ],
    'conditions': [
      {'id': 'c1', 'name': 'Hypertension', 'since': '2019'},
    ],
  },
  'activeEpisodes': [],
  'activeMedications': [
    {
      'id': 'm1',
      'name': 'Amlodipine',
      'dose': '5mg',
      'frequency': 'once daily',
      'times': ['08:00'],
      'active': true,
    },
  ],
  'recentVitals': [
    {
      'id': 'v1',
      'type': 'bp_systolic',
      'value': 150,
      'unit': 'mmHg',
      'measuredAt': '2026-09-28T08:00:00.000Z',
      'source': 'device',
    },
  ],
  'recentRecords': [],
  'homeVisitFindings': [],
  'moodTrend': null,
  'aiSummary': {
    'interactionId': 'ai-1',
    'text': 'BP trending high.',
    'advisory': true,
    'model': 'test-model',
    'generatedAt': '2026-09-28T09:00:00.000Z',
    'claims': [
      {
        'text': 'Systolic BP above 140 on recent readings',
        'sources': [
          {'kind': 'vital', 'refId': 'v1', 'label': 'BP 150/95'},
        ],
      },
    ],
  },
  'intake': null,
};
