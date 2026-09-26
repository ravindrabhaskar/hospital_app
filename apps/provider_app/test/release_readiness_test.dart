import 'dart:convert';
import 'dart:io';

import 'package:care_companion_provider/app.dart';
import 'package:care_companion_provider/core/api/api_client.dart';
import 'package:care_companion_provider/core/api/api_exception.dart';
import 'package:care_companion_provider/core/api/token_store.dart';
import 'package:care_companion_provider/core/connectivity.dart';
import 'package:care_companion_provider/core/providers.dart';
import 'package:care_companion_provider/core/push/push_service.dart';
import 'package:care_companion_provider/core/storage/key_value_store.dart';
import 'package:care_companion_provider/core/theme.dart';
import 'package:care_companion_provider/features/offline/offline_queue.dart';
import 'package:care_companion_provider/features/offline/visit_action_service.dart';
import 'package:care_companion_provider/features/offline/visit_cache.dart';
import 'package:care_companion_provider/features/visits/data/photo_store.dart';
import 'package:care_companion_provider/features/visits/data/provider_repository.dart';
import 'package:care_companion_provider/features/visits/domain/visit_lifecycle.dart';
import 'package:care_companion_provider/features/visits/ui/photo_capture.dart';
import 'package:care_companion_provider/models/home_visit.dart';
import 'package:care_companion_provider/models/public_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';
import 'verification_gate_test.dart' show me, providerMe;

Map<String, dynamic> publicConfigJson({String minAndroid = '1.0.0', String minIos = '1.0.0'}) => {
      'flags': {'ai_assistant': true},
      'payment': {'gateway': 'mock', 'razorpayKeyId': null},
      'video': {'provider': 'placeholder'},
      'push': {'enabled': false},
      'support': {'phone': '+914012345678', 'email': 'support@example.com', 'whatsapp': null},
      'legal': {
        'privacyUrl': 'https://example.com/privacy',
        'termsUrl': 'https://example.com/terms',
        'accountDeletionUrl': 'https://example.com/delete',
      },
      'minAppVersion': {
        'patientAndroid': '1.0.0',
        'patientIos': '1.0.0',
        'providerAndroid': minAndroid,
        'providerIos': minIos,
      },
    };

void main() {
  group('force update (public config §21)', () {
    test('version comparison is numeric and ignores build suffixes', () {
      expect(isVersionBelow('1.0.0', '1.0.1'), isTrue);
      expect(isVersionBelow('1.9.0', '1.10.0'), isTrue);
      expect(isVersionBelow('1.10.0', '1.9.9'), isFalse);
      expect(isVersionBelow('1.2', '1.2.0'), isFalse);
      expect(isVersionBelow('1.2.0+7', '1.2.0'), isFalse);
      expect(isVersionBelow('2.0.0', '1.99.99'), isFalse);
    });

    setUp(() {
      useGoogleFonts = false;
      SharedPreferences.setMockInitialValues({});
    });

    Future<List<http.Request>> boot(
      WidgetTester tester, {
      required String installed,
      required String minimum,
      Object? meError,
    }) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);
      final store = MemoryKeyValueStore();
      await store.write(StoreKeys.accessToken, 'a');
      await store.write(StoreKeys.refreshToken, 'r');
      final requests = <http.Request>[];
      final client = MockClient((req) async {
        requests.add(req);
        final path = req.url.path.replaceFirst('/api/v1', '');
        Object? body;
        if (path == '/config/public') body = publicConfigJson(minAndroid: minimum, minIos: minimum);
        if (path == '/me') body = me(['provider']);
        if (path == '/provider/me') {
          if (meError != null) return http.Response(jsonEncode(meError), 403);
          body = providerMe('verified', expiresAt: DateTime.now().add(const Duration(days: 200)).toUtc().toIso8601String());
        }
        if (path == '/provider/visits') body = {'items': [], 'nextCursor': null};
        if (body == null) return http.Response('{"error":{"code":"NOT_FOUND","message":"nf"}}', 404);
        return http.Response(jsonEncode(body), 200, headers: {'content-type': 'application/json'});
      });
      await tester.pumpWidget(ProviderScope(
        retry: (_, _) => null,
        overrides: [
          keyValueStoreProvider.overrideWithValue(store),
          httpClientProvider.overrideWithValue(client),
          connectivityProvider.overrideWithValue(FakeConnectivityService(online: true)),
          appVersionReaderProvider.overrideWithValue(() async => installed),
          firebaseSettingsProvider.overrideWithValue(const FirebaseSettings()),
        ],
        child: const ProviderApp(),
      ));
      await tester.pumpAndSettle();
      return requests;
    }

    Future<void> teardown(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    }

    testWidgets('an outdated build is blocked by the update screen', (tester) async {
      await boot(tester, installed: '1.0.0', minimum: '1.2.0');
      expect(find.byKey(const Key('updateBody')), findsOneWidget);
      expect(find.text('Installed 1.0.0 · Required 1.2.0'), findsOneWidget);
      expect(find.byKey(const Key('updateNow')), findsOneWidget, reason: 'Play Store link on Android');
      expect(find.text('Hello, Anil'), findsNothing);
      await teardown(tester);
    });

    testWidgets('a current build is not gated; profile shows support, legal links and closure',
        (tester) async {
      await boot(tester, installed: '1.2.0', minimum: '1.2.0');
      expect(find.byKey(const Key('updateBody')), findsNothing);
      expect(find.text('Hello, Anil'), findsOneWidget);

      await tester.tap(find.byTooltip('Profile'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.byKey(const Key('closeAccount')), 300);
      expect(find.byKey(const Key('privacyLink')), findsOneWidget);
      expect(find.byKey(const Key('termsLink')), findsOneWidget);
      expect(find.text('support@example.com'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Version 1.2.0'), 300);
      expect(find.text('Version 1.2.0'), findsOneWidget);

      await tester.tap(find.byKey(const Key('closeAccount')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('closeAccountBody')), findsOneWidget);
      expect(find.byKey(const Key('supportEmail')), findsWidgets);
      await teardown(tester);
    });

    testWidgets('MFA_REQUIRED shows a clear explanation instead of "restricted"', (tester) async {
      await boot(tester, installed: '1.2.0', minimum: '1.0.0', meError: {
        'error': {'code': 'MFA_REQUIRED', 'message': 'MFA required'},
      });
      expect(find.byKey(const Key('mfaBody')), findsOneWidget);
      expect(find.text('Extra verification required'), findsOneWidget);
      await teardown(tester);
    });
  });

  group('visit photo upload (offline queue)', () {
    late Directory tmp;
    late MemoryKeyValueStore store;
    late LocalPhotoFileStore photos;
    late FakeConnectivityService connectivity;
    late List<http.Request> requests;
    late int status;
    late OfflineQueue queue;
    late VisitActionService service;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('cc_photo_test');
      store = MemoryKeyValueStore();
      photos = LocalPhotoFileStore(baseDir: () async => tmp);
      connectivity = FakeConnectivityService(online: false);
      requests = [];
      status = 201;
      final client = MockClient((req) async {
        requests.add(req);
        if (status >= 400 && req.url.path.endsWith('/records')) {
          return http.Response(jsonEncode({'error': {'code': 'FORBIDDEN', 'message': 'no'}}), status);
        }
        if (req.url.path.endsWith('/records')) {
          return http.Response(jsonEncode({'id': 'rec-1', 'type': 'other', 'title': 'Home visit photo'}), 201);
        }
        return http.Response(jsonEncode(visitJson(status: VisitStatus.inProgress)), 200);
      });
      final api = ApiClient(baseUrl: 'http://api.test/api/v1', tokens: TokenStore(store), httpClient: client);
      final repo = ProviderRepository(api, photos: photos);
      queue = OfflineQueue(store: store, sender: repo.sendAction);
      service = VisitActionService(
        queue: queue,
        cache: VisitCache(store),
        connectivity: connectivity,
        photos: photos,
      );
    });

    tearDown(() async {
      service.dispose();
      if (await tmp.exists()) await tmp.delete(recursive: true);
    });

    Future<String> capture() async {
      final f = File('${tmp.path}${Platform.pathSeparator}camera_tmp.jpg');
      await f.writeAsBytes(List<int>.generate(64, (i) => i));
      return f.path;
    }

    test('queued offline, persisted encrypted-store side, replayed once as multipart with the same key',
        () async {
      final v = visit(status: VisitStatus.inProgress);
      final outcome = await service.addPhoto(v, await capture());
      expect(outcome.kind, ActionOutcomeKind.pending);
      expect(requests, isEmpty);

      final queued = queue.items.single;
      expect(queued.type, VisitActionType.photo);
      expect(queued.path, '/records');
      final filePath = queued.body['filePath'] as String;
      expect(File(filePath).existsSync(), isTrue, reason: 'copied into private storage');
      expect(store.data[StoreKeys.offlineQueue], contains('filePath'));

      // Restart: the queue restores the photo item with its key.
      final restored = OfflineQueue(
        store: store,
        sender: ProviderRepository(
          ApiClient(baseUrl: 'http://api.test/api/v1', tokens: TokenStore(store), httpClient: MockClient((req) async {
            requests.add(req);
            return http.Response(jsonEncode({'id': 'rec-1'}), 201);
          })),
          photos: photos,
        ).sendAction,
      )..onRemoved = (a) async => photos.delete(a.body['filePath'] as String);
      await restored.load();
      expect(restored.items.single.id, queued.id);

      await restored.flush();
      await restored.flush();
      expect(requests, hasLength(1), reason: 'uploaded exactly once');
      final req = requests.single; // MockClient flattens the multipart body
      expect(req.url.path, '/api/v1/records');
      expect(req.headers['Idempotency-Key'], queued.id);
      expect(req.headers['content-type'], startsWith('multipart/form-data'));
      String field(String name) {
        final m = RegExp('name="$name"\r\n\r\n([^\r]*)').firstMatch(latin1.decode(req.bodyBytes));
        return m?.group(1) ?? '';
      }

      expect(field('patientId'), 'patient-1');
      expect(field('type'), 'other');
      expect(field('title'), 'Home visit photo');
      expect(field('recordDate'), matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));
      expect(latin1.decode(req.bodyBytes), contains('name="file"; filename="'));
      expect(restored.pendingCount, 0);
      expect(File(filePath).existsSync(), isFalse, reason: 'local copy deleted after upload');
    });

    test('lost response replays with the same Idempotency-Key', () async {
      connectivity.online = true;
      status = 503;
      final first = await service.addPhoto(visit(status: VisitStatus.inProgress), await capture());
      expect(first.kind, ActionOutcomeKind.pending);
      status = 201;
      await service.syncNow();
      expect(requests, hasLength(2));
      expect(requests[0].headers['Idempotency-Key'], requests[1].headers['Idempotency-Key']);
      expect(queue.pendingCount, 0);
    });

    test('file gone at replay: dropped with a notice, nothing sent', () async {
      await service.addPhoto(visit(status: VisitStatus.inProgress), await capture());
      await File(queue.items.single.body['filePath'] as String).delete();

      final events = <SyncEvent>[];
      final sub = service.events.listen(events.add);
      connectivity.online = true;
      await service.syncNow();
      await Future<void>.delayed(Duration.zero);

      expect(requests, isEmpty);
      expect(queue.pendingCount, 0);
      final e = events.single;
      expect(e.kind, SyncEventKind.rejected);
      expect(e.type, VisitActionType.photo);
      expect(e.error!.code, ApiException.localFileMissingCode);
      await sub.cancel();
    });

    test('403 on upload drops only the photo; the visit and its other actions are kept', () async {
      final v = visit(status: VisitStatus.inProgress);
      final cache = service.cache;
      await cache.saveVisit(v);
      await service.addPhoto(v, await capture());
      await service.perform(v, VisitActionType.observations, {'notes': 'ok', 'checklist': <String, dynamic>{}});
      expect(queue.pendingCount, 2);

      status = 403;
      connectivity.online = true;
      final outcomes = await queue.flush();
      expect(outcomes.values.map((o) => o.kind), [ActionOutcomeKind.rejected, ActionOutcomeKind.synced],
          reason: 'photo refused, the following observations still sync');
      expect(requests.map((r) => r.url.path), ['/api/v1/records', '/api/v1/home-visits/visit-1/observations']);
      expect(queue.pendingCount, 0);
      expect(await cache.getVisit(v.id), isNotNull, reason: 'no PHI purge for a records permission error');
    });
  });

  testWidgets('photo consent dialog blocks the camera until consent is ticked', (tester) async {
    bool? result;
    await tester.pumpWidget(testApp(
      Builder(
        builder: (context) => TextButton(
          onPressed: () async => result = await showPhotoConsentDialog(context),
          child: const Text('open'),
        ),
      ),
      wrap: false,
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('photoOpenCamera')));
    await tester.pumpAndSettle();
    expect(find.text('Patient consent is required before taking a photo.'), findsOneWidget);
    expect(result, isNull, reason: 'dialog still open');

    await tester.tap(find.byKey(const Key('photoConsentCheckbox')));
    await tester.tap(find.byKey(const Key('photoOpenCamera')));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });

  group('push notifications', () {
    test('initialisation is skipped silently when Firebase is not configured', () async {
      final requests = <http.Request>[];
      final api = ApiClient(
        baseUrl: 'http://api.test/api/v1',
        tokens: TokenStore(MemoryKeyValueStore()),
        httpClient: MockClient((req) async {
          requests.add(req);
          return http.Response('', 204);
        }),
      );
      final push = PushService(api: api, settings: const FirebaseSettings());
      expect(push.settings.isConfigured, isFalse);
      expect(await push.init(), isFalse);
      expect(push.isActive, isFalse);
      await push.registerDevice();
      await push.unregisterDevice();
      expect(requests, isEmpty, reason: 'no /devices calls without push');
      push.dispose();
    });

    test('partial Firebase options count as unconfigured', () {
      expect(const FirebaseSettings(apiKey: 'k', appId: 'a', messagingSenderId: 's').isConfigured, isFalse);
      expect(const FirebaseSettings(apiKey: 'k', appId: 'a', messagingSenderId: 's', projectId: 'p').isConfigured,
          isTrue);
    });

    test('deep links map to the provider visit route', () {
      expect(PushService.visitIdFromDeepLink('/provider/visits/abc-123'), 'abc-123');
      expect(PushService.visitIdFromDeepLink('/home-visits/v1'), 'v1');
      expect(PushService.visitIdFromDeepLink('/appointments/x'), isNull);
      expect(PushService.visitIdFromDeepLink(null), isNull);
    });
  });
}
