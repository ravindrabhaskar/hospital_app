import 'dart:convert';

import 'package:care_companion_provider/core/api/api_client.dart';
import 'package:care_companion_provider/core/api/token_store.dart';
import 'package:care_companion_provider/core/storage/key_value_store.dart';
import 'package:care_companion_provider/features/auth/auth_controller.dart';
import 'package:care_companion_provider/features/onboarding/application_controller.dart';
import 'package:care_companion_provider/features/onboarding/application_documents.dart';
import 'package:care_companion_provider/features/onboarding/application_repository.dart';
import 'package:care_companion_provider/features/onboarding/document_picker.dart';
import 'package:care_companion_provider/features/onboarding/onboarding_screen.dart';
import 'package:care_companion_provider/models/provider_application.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'helpers.dart';
import 'verification_gate_test.dart' show controllerFor, me, providerMe;

Map<String, dynamic> applicationJson({
  String status = 'submitted',
  String type = 'nurse',
  List<Map<String, dynamic>> documents = const [],
  String? note,
}) =>
    {
      'id': 'app-1',
      'userId': 'u1',
      'phone': '+919800000001',
      'fullName': 'Lakshmi Rao',
      'type': type,
      'qualification': 'GNM',
      'registrationNumber': 'TSNC-12345',
      'registrationCouncil': 'Telangana Nursing Council',
      'specialty': null,
      'experienceYears': 4,
      'languages': ['English', 'Telugu'],
      'preferredZoneIds': ['z1'],
      'status': status,
      'documents': documents,
      'decisionNote': note,
      'decidedByName': note == null ? null : 'Ops Admin',
      'createdAt': '2026-09-20T09:00:00.000Z',
      'updatedAt': '2026-09-21T09:00:00.000Z',
      'decidedAt': null,
    };

/// Minimal stateful fake of the §30 endpoints.
class FakeApplicationsApi {
  FakeApplicationsApi({this.application, this.failUploads = false});

  Map<String, dynamic>? application;
  bool failUploads;
  final requests = <http.Request>[];
  var _docSeq = 0;

  http.Client get client => MockClient((req) async {
        requests.add(req);
        final path = req.url.path.replaceFirst('/api/v1', '');
        http.Response json(Object body, [int status = 200]) =>
            http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json'});
        final notFound = json({'error': {'code': 'NOT_FOUND', 'message': 'nf'}}, 404);

        if (path == '/provider-applications/me' && req.method == 'GET') {
          return application == null ? notFound : json(application!);
        }
        if (path == '/provider-applications' && req.method == 'POST') {
          final body = jsonDecode(req.body) as Map<String, dynamic>;
          application = {...applicationJson(), ...body, 'status': 'submitted', 'documents': []};
          return json(application!, 201);
        }
        if (path == '/provider-applications/me' && req.method == 'PATCH') {
          final body = jsonDecode(req.body) as Map<String, dynamic>;
          application = {...application!, ...body, 'status': 'submitted'};
          return json(application!);
        }
        if (path == '/provider-applications/me/documents' && req.method == 'POST') {
          if (failUploads) return json({'error': {'code': 'FILE_REJECTED', 'message': 'Rejected'}}, 422);
          final text = latin1.decode(req.bodyBytes);
          final docType = RegExp(r'name="docType"\r\n\r\n([a-z_]+)').firstMatch(text)!.group(1)!;
          final fileName = RegExp(r'filename="([^"]+)"').firstMatch(text)!.group(1)!;
          _docSeq++;
          application = {
            ...application!,
            'documents': [
              ...(application!['documents'] as List),
              {
                'id': 'doc-$_docSeq',
                'docType': docType,
                'fileName': fileName,
                'mimeType': 'application/pdf',
                'sizeBytes': 2048,
                'uploadedAt': '2026-09-26T09:00:00.000Z',
              },
            ],
          };
          return json(application!);
        }
        if (path.startsWith('/provider-applications/me/documents/') && req.method == 'DELETE') {
          final id = path.split('/').last;
          application = {
            ...application!,
            'documents': [for (final d in application!['documents'] as List) if ((d as Map)['id'] != id) d],
          };
          return json(application!);
        }
        if (path == '/home-visit/serviceability') {
          final pin = (jsonDecode(req.body) as Map)['pincode'];
          return pin == '500001'
              ? json({'serviceable': true, 'zoneId': 'z1', 'zoneName': 'Hyderabad-Central', 'message': 'ok'})
              : json({'serviceable': false, 'zoneId': null, 'zoneName': null, 'message': 'no'});
        }
        return notFound;
      });

  ApplicationRepository get repository {
    final store = MemoryKeyValueStore();
    return ApplicationRepository(ApiClient(baseUrl: 'http://test/api/v1', tokens: TokenStore(store), httpClient: client));
  }
}

Future<PickedDocument?> fakePicker(DocumentSource source, {bool imagesOnly = false}) async =>
    PickedDocument(name: 'id_card.pdf', bytes: List.filled(4096, 1), mimeType: 'application/pdf');

void main() {
  group('applicationPhaseFor (routing rule)', () {
    ProviderApplication app(String status) => ProviderApplication.fromJson(applicationJson(status: status));

    test('not loaded yet → loading, or error on failure', () {
      expect(applicationPhaseFor(loaded: false, hasError: false, application: null, editing: false),
          ApplicationPhase.loading);
      expect(applicationPhaseFor(loaded: false, hasError: true, application: null, editing: false),
          ApplicationPhase.error);
    });

    test('404 (no application) → form', () {
      expect(applicationPhaseFor(loaded: true, hasError: false, application: null, editing: false),
          ApplicationPhase.form);
    });

    test('submitted / rejected → status', () {
      for (final s in ['submitted', 'rejected']) {
        expect(applicationPhaseFor(loaded: true, hasError: false, application: app(s), editing: false),
            ApplicationPhase.status);
      }
    });

    test('changes_requested → status, then edit → form', () {
      final a = app('changes_requested');
      expect(applicationPhaseFor(loaded: true, hasError: false, application: a, editing: false),
          ApplicationPhase.status);
      expect(applicationPhaseFor(loaded: true, hasError: false, application: a, editing: true),
          ApplicationPhase.form);
    });

    test('rejected cannot be edited', () {
      expect(applicationPhaseFor(loaded: true, hasError: false, application: app('rejected'), editing: true),
          ApplicationPhase.status);
    });

    test('approved → approved', () {
      expect(applicationPhaseFor(loaded: true, hasError: false, application: app('approved'), editing: false),
          ApplicationPhase.approved);
    });
  });

  group('ApplicationController', () {
    test('404 → form; submit creates the application → status', () async {
      final api = FakeApplicationsApi();
      final c = ApplicationController(repository: api.repository);
      await c.load();
      expect(c.phase, ApplicationPhase.form);
      await c.submit(ApplicationDraft(
        fullName: 'Lakshmi Rao',
        qualification: 'GNM',
        registrationNumber: 'TSNC-1',
        experienceYears: 3,
        languages: ['Telugu'],
        zones: [const ZoneChoice(id: 'z1', name: 'Hyderabad-Central')],
      ));
      expect(c.phase, ApplicationPhase.status);
      final post = api.requests.singleWhere((r) => r.method == 'POST' && r.url.path.endsWith('/provider-applications'));
      final body = jsonDecode(post.body) as Map<String, dynamic>;
      expect(body['type'], 'nurse');
      expect(body['preferredZoneIds'], ['z1']);
      expect(body.containsKey('specialty'), isFalse);
      expect(body.containsKey('registrationCouncil'), isFalse);
    });

    test('changes_requested → Edit & resubmit sends PATCH and returns to status', () async {
      final api = FakeApplicationsApi(application: applicationJson(status: 'changes_requested', note: 'Blurry ID'));
      final c = ApplicationController(repository: api.repository);
      await c.load();
      expect(c.phase, ApplicationPhase.status);
      c.startEditing();
      expect(c.phase, ApplicationPhase.form);
      await c.submit(ApplicationDraft.fromApplication(c.application!)..qualification = 'B.Sc Nursing');
      expect(api.requests.last.method, 'PATCH');
      expect(c.editing, isFalse);
      expect(c.application!.status, 'submitted');
      expect(c.phase, ApplicationPhase.status);
    });

    test('approved → refreshes the identity exactly once', () async {
      final api = FakeApplicationsApi(application: applicationJson(status: 'approved'));
      var refreshes = 0;
      final c = ApplicationController(repository: api.repository, onApproved: () async => refreshes++);
      await c.load();
      await c.load();
      expect(c.phase, ApplicationPhase.approved);
      expect(refreshes, 1);
    });

    test('approved + /me now has the provider role → auth leaves the onboarding gate', () async {
      final auth = await controllerFor({'/me': (200, me(['patient']))});
      await auth.init();
      expect(auth.status, AuthStatus.restricted);

      // The ops decision added the role server-side.
      final approvedAuth = await controllerFor({
        '/me': (200, me(['patient', 'provider'])),
        '/provider/me': (200, providerMe('verified', expiresAt: '2027-09-01T00:00:00.000Z')),
      });
      final api = FakeApplicationsApi(application: applicationJson(status: 'approved'));
      final c = ApplicationController(repository: api.repository, onApproved: approvedAuth.loadIdentity);
      await c.load();
      expect(approvedAuth.status, AuthStatus.ready);
    });

    test('network error → error phase, retry recovers', () async {
      var fail = true;
      final client = MockClient((req) async {
        if (fail) throw Exception('offline');
        return http.Response('{"error":{"code":"NOT_FOUND","message":"nf"}}', 404);
      });
      final repo = ApplicationRepository(
          ApiClient(baseUrl: 'http://test/api/v1', tokens: TokenStore(MemoryKeyValueStore()), httpClient: client));
      final c = ApplicationController(repository: repo);
      await c.load();
      expect(c.phase, ApplicationPhase.error);
      fail = false;
      await c.load();
      expect(c.phase, ApplicationPhase.form);
    });
  });

  group('Documents (mock API)', () {
    Future<(FakeApplicationsApi, ApplicationController)> pump(WidgetTester tester, {bool failUploads = false}) async {
      final api = FakeApplicationsApi(application: applicationJson(), failUploads: failUploads);
      final c = ApplicationController(repository: api.repository);
      await c.load();
      await tester.pumpWidget(testApp(ApplicationDocumentsCard(controller: c, picker: fakePicker)));
      await tester.pumpAndSettle();
      return (api, c);
    }

    Future<void> addDoc(WidgetTester tester, String type) async {
      await tester.tap(find.byKey(const Key('addDocument')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(Key('docType.$type')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('source.files')));
      await tester.pumpAndSettle();
    }

    testWidgets('upload adds to the list, required-docs hint updates, delete removes', (tester) async {
      final (api, c) = await pump(tester);
      expect(find.text('No documents uploaded yet.'), findsOneWidget);
      expect(find.textContaining('Still needed: Registration certificate, ID proof'), findsOneWidget);

      await addDoc(tester, 'id_proof');
      final upload = api.requests.last;
      expect(upload.url.path, endsWith('/provider-applications/me/documents'));
      expect(upload.headers['content-type'], startsWith('multipart/form-data'));
      expect(find.text('id_card.pdf'), findsOneWidget);
      expect(find.textContaining('Still needed: Registration certificate'), findsOneWidget);
      expect(c.uploads, isEmpty);

      await addDoc(tester, 'registration_certificate');
      expect(c.application!.documents, hasLength(2));
      expect(find.text('All required documents are uploaded.'), findsOneWidget);

      await tester.tap(find.byKey(const Key('deleteDoc.doc-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirmDeleteDoc')));
      await tester.pumpAndSettle();
      expect(api.requests.last.method, 'DELETE');
      expect(api.requests.last.url.path, endsWith('/documents/doc-1'));
      expect(c.application!.documents.map((d) => d.id), ['doc-2']);
      expect(find.textContaining('Still needed: ID proof'), findsOneWidget);
    });

    testWidgets('a failed upload stays in the list with retry', (tester) async {
      final (api, c) = await pump(tester, failUploads: true);
      await addDoc(tester, 'degree');
      expect(find.textContaining('Upload failed: Rejected'), findsOneWidget);
      expect(c.uploads.single.state, UploadState.failed);

      api.failUploads = false;
      await tester.tap(find.byTooltip('Retry'));
      await tester.pumpAndSettle();
      expect(c.uploads, isEmpty);
      expect(c.application!.documents.single.docType, 'degree');
    });

    test('files over 10 MB are refused without calling the API', () async {
      final api = FakeApplicationsApi(application: applicationJson());
      final c = ApplicationController(repository: api.repository);
      await c.load();
      final before = api.requests.length;
      await c.uploadDocument(
          'other', PickedDocument(name: 'big.pdf', bytes: List.filled(maxDocumentBytes + 1, 0), mimeType: 'application/pdf'));
      expect(api.requests.length, before);
      expect(c.uploads.single.error!.code, 'FILE_TOO_LARGE');
      expect(c.uploads.single.canRetry, isFalse, reason: 'retrying an oversized file can never succeed');
    });

    testWidgets('B29: an oversized file offers remove but no Retry', (tester) async {
      final api = FakeApplicationsApi(application: applicationJson());
      final c = ApplicationController(repository: api.repository);
      await c.load();
      await tester.pumpWidget(testApp(ApplicationDocumentsCard(
        controller: c,
        picker: (source, {imagesOnly = false}) async =>
            PickedDocument(name: 'big.pdf', bytes: List.filled(maxDocumentBytes + 1, 0), mimeType: 'application/pdf'),
      )));
      await tester.pumpAndSettle();
      await addDoc(tester, 'other');
      expect(find.textContaining('larger than 10 MB'), findsOneWidget);
      expect(find.byTooltip('Retry'), findsNothing);
      expect(find.byTooltip('Cancel'), findsOneWidget);
    });
  });

  group('B29: apply form details', () {
    Future<ApplicationController> pumpForm(WidgetTester tester, FakeApplicationsApi api, KeyValueStore store) async {
      final c = ApplicationController(repository: api.repository, store: store);
      await c.load();
      await tester.pumpWidget(testApp(
        OnboardingView(controller: c, picker: fakePicker, onLogout: () {}, onCheckApproved: () async {}),
        wrap: false,
      ));
      await tester.pumpAndSettle();
      return c;
    }

    testWidgets('full name is limited to 100 characters (API max)', (tester) async {
      await pumpForm(tester, FakeApplicationsApi(), MemoryKeyValueStore());
      await tester.tap(find.byKey(const Key('onbNext.0')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('onbFullName')), 'x' * 130);
      await tester.pump();
      final field = tester.widget<TextField>(
          find.descendant(of: find.byKey(const Key('onbFullName')), matching: find.byType(TextField)));
      expect(field.maxLength, 100);
      expect(field.controller!.text.length, 100);
    });

    testWidgets('the draft survives a reload and is cleared once submitted', (tester) async {
      final store = MemoryKeyValueStore();
      final api = FakeApplicationsApi();
      await pumpForm(tester, api, store);
      await tester.tap(find.byKey(const Key('onbType.technician')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('onbNext.0')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('onbFullName')), 'Ravi Kumar');
      await tester.enterText(find.byKey(const Key('onbExperience')), '6');
      await tester.pump(const Duration(seconds: 1));
      expect(store.data[StoreKeys.applicationDraft], contains('Ravi Kumar'));

      // "Reload": a fresh controller + form on the same storage.
      await tester.pumpWidget(const SizedBox());
      await pumpForm(tester, api, store);
      expect(find.text('Ravi Kumar'), findsOneWidget);
      expect(find.text('6'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('onbQualification')), 'DMLT');
      await tester.enterText(find.byKey(const Key('onbRegNumber')), 'PMC-778');
      await tester.ensureVisible(find.byKey(const Key('onbNext.1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('onbNext.1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('onbLang.Hindi')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('onbNext.2')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('onbNext.2')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('onbSubmit')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('onbSubmit')));
      await tester.pumpAndSettle();

      final post = api.requests.singleWhere((r) => r.method == 'POST' && r.url.path.endsWith('/provider-applications'));
      expect((jsonDecode(post.body) as Map)['type'], 'technician');
      expect(store.data.containsKey(StoreKeys.applicationDraft), isFalse);
      expect(StoreKeys.all, contains(StoreKeys.applicationDraft), reason: 'wiped on logout');
    });

    testWidgets('editing shows the zone name, not "Saved area"', (tester) async {
      final store = MemoryKeyValueStore()
        ..data[ApplicationController.zoneNamesKey] = jsonEncode({'z1': 'Hyderabad-Central'});
      final api = FakeApplicationsApi(application: applicationJson(status: 'changes_requested', note: 'Fix'));
      await pumpForm(tester, api, store);
      await tester.tap(find.byKey(const Key('onbEditResubmit')));
      await tester.pumpAndSettle();
      for (final step in [0, 1, 2]) {
        await tester.ensureVisible(find.byKey(Key('onbNext.$step')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(Key('onbNext.$step')));
        await tester.pumpAndSettle();
      }
      expect(find.text('Hyderabad-Central'), findsWidgets);
      expect(find.text('Saved area'), findsNothing);
    });

    test('zone names from the server (preferredZones) are used too', () {
      final app = ProviderApplication.fromJson({
        ...applicationJson(),
        'preferredZones': [
          {'id': 'z1', 'name': 'Hyderabad-Central'},
        ],
      });
      expect(ApplicationDraft.fromApplication(app).zones.single.name, 'Hyderabad-Central');
    });
  });

  group('OnboardingView', () {
    Future<ApplicationController> pump(WidgetTester tester, FakeApplicationsApi api) async {
      final c = ApplicationController(repository: api.repository);
      await c.load();
      await tester.pumpWidget(testApp(
        OnboardingView(controller: c, picker: fakePicker, onLogout: () {}, onCheckApproved: () async {}),
        wrap: false,
      ));
      await tester.pumpAndSettle();
      return c;
    }

    testWidgets('no application: full form flow submits and shows the status', (tester) async {
      final api = FakeApplicationsApi();
      await pump(tester, api);
      expect(find.byKey(const Key('onbIntro')), findsOneWidget);

      await tester.tap(find.byKey(const Key('onbType.doctor')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('onbDoctorNote')), findsOneWidget);
      await tester.tap(find.byKey(const Key('onbType.technician')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('onbNext.0')));
      await tester.pumpAndSettle();

      // Details are validated before moving on.
      await tester.ensureVisible(find.byKey(const Key('onbNext.1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('onbNext.1')));
      await tester.pumpAndSettle();
      expect(find.text('Required'), findsWidgets);
      await tester.enterText(find.byKey(const Key('onbFullName')), 'Ravi Kumar');
      await tester.enterText(find.byKey(const Key('onbQualification')), 'DMLT');
      await tester.enterText(find.byKey(const Key('onbRegNumber')), 'PMC-778');
      await tester.enterText(find.byKey(const Key('onbExperience')), '6');
      await tester.ensureVisible(find.byKey(const Key('onbNext.1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('onbNext.1')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('onbLang.Hindi')));
      await tester.enterText(find.byKey(const Key('onbPincode')), '500001');
      await tester.tap(find.byKey(const Key('onbAddArea')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('onbZone.z1')), findsOneWidget);
      await tester.enterText(find.byKey(const Key('onbPincode')), '999999');
      await tester.tap(find.byKey(const Key('onbAddArea')));
      await tester.pumpAndSettle();
      expect(find.textContaining("We don't serve pincode 999999"), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('onbNext.2')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('onbNext.2')));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const Key('onbSubmit')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('onbSubmit')));
      await tester.pumpAndSettle();

      final post = api.requests.singleWhere((r) => r.method == 'POST' && r.url.path.endsWith('/provider-applications'));
      final body = jsonDecode(post.body) as Map<String, dynamic>;
      expect(body['type'], 'technician');
      expect(body['fullName'], 'Ravi Kumar');
      expect(body['experienceYears'], 6);
      expect(body['languages'], ['Hindi']);
      expect(body['preferredZoneIds'], ['z1']);
      expect(find.byKey(const Key('status.submitted')), findsOneWidget);
      expect(find.byKey(const Key('documentsCard')), findsOneWidget);
    });

    testWidgets('changes requested: shows the reviewer note, Edit & resubmit opens the prefilled form',
        (tester) async {
      final api = FakeApplicationsApi(application: applicationJson(status: 'changes_requested', note: 'ID photo is blurry'));
      await pump(tester, api);
      expect(find.byKey(const Key('status.changes_requested')), findsOneWidget);
      expect(find.text('ID photo is blurry'), findsOneWidget);
      expect(find.text('Note from Ops Admin'), findsOneWidget);

      await tester.tap(find.byKey(const Key('onbEditResubmit')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('applicationStepper')), findsOneWidget);
      expect(find.text('Edit your application'), findsOneWidget);
    });

    testWidgets('rejected: shows the note, no edit or upload', (tester) async {
      final api = FakeApplicationsApi(application: applicationJson(status: 'rejected', note: 'Registration not found'));
      await pump(tester, api);
      expect(find.text('Application not approved'), findsOneWidget);
      expect(find.text('Registration not found'), findsOneWidget);
      expect(find.byKey(const Key('onbEditResubmit')), findsNothing);
      expect(find.byKey(const Key('addDocument')), findsNothing);
    });

    testWidgets('approved: sign out and in again (doctor: web portal)', (tester) async {
      await pump(tester, FakeApplicationsApi(application: applicationJson(status: 'approved')));
      expect(find.text('Your application has been approved. Sign out and sign in again to start.'), findsOneWidget);
      expect(find.byKey(const Key('onbSignOutAndIn')), findsOneWidget);

      await pump(tester, FakeApplicationsApi(application: applicationJson(status: 'approved', type: 'doctor')));
      expect(find.textContaining('web portal'), findsOneWidget);
    });

    testWidgets('renders localized (Telugu)', (tester) async {
      final c = ApplicationController(repository: FakeApplicationsApi().repository);
      await c.load();
      await tester.pumpWidget(testApp(
        OnboardingView(controller: c, picker: fakePicker, onLogout: () {}, onCheckApproved: () async {}),
        locale: const Locale('te'),
        wrap: false,
      ));
      await tester.pumpAndSettle();
      expect(find.text('కేర్ ప్రొవైడర్‌గా చేరడానికి దరఖాస్తు చేయండి'), findsOneWidget);
    });
  });
}
