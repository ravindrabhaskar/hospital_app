import 'dart:convert';

import 'package:care_companion_patient/core/api/api_exception.dart';
import 'package:care_companion_patient/core/push/push_service.dart';
import 'package:care_companion_patient/data/repositories.dart';
import 'package:care_companion_patient/features/care/video_join.dart';
import 'package:care_companion_patient/features/misc/force_update_screen.dart';
import 'package:care_companion_patient/features/payments/checkout_launcher.dart';
import 'package:care_companion_patient/features/payments/payment_sheet.dart';
import 'package:care_companion_patient/features/profile/delete_account_screen.dart';
import 'package:care_companion_patient/models/auth.dart';
import 'package:care_companion_patient/models/care.dart';
import 'package:care_companion_patient/models/config.dart';
import 'package:care_companion_patient/models/json.dart';
import 'package:care_companion_patient/router.dart';
import 'package:care_companion_patient/state/core_providers.dart';
import 'package:flutter/material.dart' hide Page;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

// ------------------------------------------------------------------ fixtures

Json configJson({String gateway = 'mock', String minAndroid = '1.0.0', String minIos = '1.0.0'}) => {
      'flags': {
        'ai_assistant': true,
        'wound_ai_analysis': false,
        'fall_detection': true,
        'wearables': false,
        'pharmacy_orders': true,
        'mental_wellness': true,
        'govt_schemes': true,
        'voice_input': false,
      },
      'payment': {'gateway': gateway, 'razorpayKeyId': gateway == 'razorpay' ? 'rzp_test_x' : null},
      'video': {'provider': 'jitsi'},
      'push': {'enabled': false},
      'support': {'phone': '+911800000000', 'email': 'care@example.com', 'whatsapp': null},
      'legal': {
        'privacyUrl': 'https://example.com/privacy',
        'termsUrl': 'https://example.com/terms',
        'accountDeletionUrl': 'https://example.com/delete',
      },
      'minAppVersion': {
        'patientAndroid': minAndroid,
        'patientIos': minIos,
        'providerAndroid': '1.0.0',
        'providerIos': '1.0.0',
      },
    };

Payment payment({
  String status = 'pending',
  String gateway = 'mock',
  bool withCheckout = false,
  String orderId = 'order_1',
}) =>
    Payment.fromJson({
      'id': 'pay1',
      'purpose': 'appointment',
      'refId': 'a1',
      'patientId': 'p-self',
      'amount': 499,
      'currency': 'INR',
      'status': status,
      'gateway': gateway,
      'gatewayOrderId': orderId,
      'refundedAmount': 0,
      'createdAt': '2026-09-26T09:30:00.000Z',
      'checkout': withCheckout
          ? {
              'gateway': 'razorpay',
              'keyId': 'rzp_test_x',
              'orderId': orderId,
              'amountPaise': 49900,
              'currency': 'INR',
              'name': 'CareCompanion',
              'description': 'Consultation',
              'prefill': {'contact': '+919800000001', 'name': 'Vaibhav'},
            }
          : null,
    });

class FakeConfigRepository extends ConfigRepository {
  FakeConfigRepository(this.json) : super(deadApiClient());
  Json? json;
  @override
  Future<Json> publicConfigJson() async {
    final j = json;
    if (j == null) throw ApiException(code: ApiException.network, message: 'offline');
    return j;
  }
}

class FakePaymentRepository extends PaymentRepository {
  FakePaymentRepository() : super(deadApiClient());
  final calls = <String>[];
  Payment Function(String id)? onVerify;

  @override
  Future<Payment> retry(String id) async {
    calls.add('retry');
    return payment(gateway: 'razorpay', withCheckout: true, orderId: 'order_retry');
  }

  @override
  Future<Payment> verify(String id,
      {required String razorpayPaymentId,
      required String razorpayOrderId,
      required String razorpaySignature}) async {
    calls.add('verify:$razorpayPaymentId:$razorpayOrderId:$razorpaySignature');
    return payment(status: 'succeeded', gateway: 'razorpay');
  }

  @override
  Future<Payment> confirmMock(String id, {required bool success, required String idempotencyKey}) async {
    calls.add('mock:$success');
    return payment(status: success ? 'succeeded' : 'failed');
  }
}

class FakeLauncher implements CheckoutLauncher {
  FakeLauncher(this.outcomes);
  final List<CheckoutOutcome> outcomes;
  final opened = <String>[];
  @override
  Future<CheckoutOutcome> open(RazorpayCheckout checkout) async {
    opened.add(checkout.orderId);
    return outcomes.removeAt(0);
  }
}

class FakeAccountRepository extends AccountRepository {
  FakeAccountRepository(this.current) : super(deadApiClient());
  DeletionRequest? current;
  final calls = <String>[];

  DeletionRequest _req(String status) => DeletionRequest.fromJson({
        'id': 'd1',
        'status': status,
        'reason': null,
        'requestedAt': '2026-09-26T09:30:00.000Z',
        'scheduledFor': '2026-10-03T09:30:00.000Z',
        'completedAt': null,
      });

  @override
  Future<DeletionRequest?> deletionRequest() async => current;

  @override
  Future<DeletionRequest> requestDeletion({String? reason}) async {
    calls.add('request');
    return current = _req('scheduled');
  }

  @override
  Future<DeletionRequest> cancelDeletion() async {
    calls.add('cancel');
    return current = _req('cancelled');
  }
}

Future<ProviderContainer> containerWith({
  Json? cachedConfig,
  String version = '1.0.0',
  String platform = 'android',
  ConfigRepository? configRepo,
}) async {
  SharedPreferences.setMockInitialValues({
    if (cachedConfig != null) PublicConfigNotifier.cacheKey: jsonEncode(cachedConfig),
  });
  final prefs = await SharedPreferences.getInstance();
  final c = ProviderContainer(overrides: [
    sharedPrefsProvider.overrideWithValue(prefs),
    apiClientProvider.overrideWithValue(deadApiClient()),
    appVersionProvider.overrideWithValue(version),
    appPlatformProvider.overrideWithValue(platform),
    if (configRepo != null) configRepositoryProvider.overrideWithValue(configRepo),
  ]);
  addTearDown(c.dispose);
  return c;
}

// ------------------------------------------------------------------ tests

void main() {
  group('public config & force update', () {
    test('version comparison', () {
      expect(compareVersions('1.2.10', '1.2.9'), greaterThan(0));
      expect(compareVersions('1.0.0+7', '1.0.0'), 0);
      expect(compareVersions('1.0', '1.0.1'), lessThan(0));
      expect(isUpdateRequired('1.0.0', '1.1.0'), isTrue);
      expect(isUpdateRequired('1.1.0', '1.1.0'), isFalse);
      expect(isUpdateRequired('2.0.0', '1.9.9'), isFalse);
    });

    test('defaults mirror seeded flags until the server answers', () async {
      final c = await containerWith();
      final cfg = c.read(publicConfigProvider);
      expect(cfg.paymentGateway, 'mock');
      expect(cfg.flags.govtSchemes, isTrue); // §38: now defaults on
      expect(cfg.flags.aiAssistant, isTrue);
      expect(c.read(updateRequiredProvider), isFalse);
    });

    test('server config replaces flags, is cached, and survives going offline', () async {
      final repo = FakeConfigRepository(configJson(gateway: 'razorpay'));
      final c = await containerWith(configRepo: repo);
      final c2 = c;
      expect(await c2.read(publicConfigProvider.notifier).refresh(), isTrue);
      expect(c2.read(featureFlagsProvider).govtSchemes, isTrue);
      expect(c2.read(featureFlagsProvider).wearables, isFalse);
      expect(c2.read(publicConfigProvider).isRazorpay, isTrue);

      // Offline: the cached copy stays in effect.
      repo.json = null;
      expect(await c2.read(publicConfigProvider.notifier).refresh(), isFalse);
      expect(c2.read(publicConfigProvider).isRazorpay, isTrue);
      final prefs = c.read(sharedPrefsProvider);
      expect(prefs.getString(PublicConfigNotifier.cacheKey), contains('razorpay'));
    });

    test('update is required only below minAppVersion for this platform', () async {
      final cached = configJson(minAndroid: '1.2.0', minIos: '0.9.0');
      expect((await containerWith(cachedConfig: cached)).read(updateRequiredProvider), isTrue);
      expect((await containerWith(cachedConfig: cached, version: '1.2.0')).read(updateRequiredProvider), isFalse);
      expect((await containerWith(cachedConfig: cached, platform: 'ios')).read(updateRequiredProvider), isFalse);
      expect((await containerWith(cachedConfig: cached, platform: 'web')).read(updateRequiredProvider), isFalse);
    });

    test('router blocks every route behind /update when an update is required', () {
      final s = SessionState(AuthStatus.authenticated, testMe);
      expect(appRedirect(session: s, languageChosen: true, location: '/home', updateRequired: true), '/update');
      expect(appRedirect(session: s, languageChosen: true, location: '/update', updateRequired: true), isNull);
      expect(appRedirect(session: s, languageChosen: true, location: '/update'), '/splash');
      expect(appRedirect(session: s, languageChosen: true, location: '/home'), isNull);
    });

    testWidgets('force-update screen explains and shows versions', (tester) async {
      final overrides = await baseOverrides();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(PublicConfigNotifier.cacheKey, jsonEncode(configJson(minAndroid: '3.0.0')));
      await tester.pumpWidget(testApp(const ForceUpdateScreen(), overrides: [
        ...overrides,
        appPlatformProvider.overrideWithValue('android'),
        appVersionProvider.overrideWithValue('1.0.0'),
      ]));
      await tester.pumpAndSettle();
      expect(find.text('Please update CareCompanion'), findsOneWidget);
      expect(find.text('Installed 1.0.0 · required 3.0.0 or newer'), findsOneWidget);
      expect(find.text('Update now'), findsOneWidget);
    });
  });

  group('payment flow', () {
    test('chooses mock vs razorpay vs web-unsupported', () {
      expect(choosePaymentMode(paymentGateway: 'mock', configGateway: 'razorpay', platform: 'android'),
          PaymentMode.mock);
      expect(choosePaymentMode(paymentGateway: 'razorpay', configGateway: 'mock', platform: 'android'),
          PaymentMode.razorpay);
      expect(choosePaymentMode(paymentGateway: 'razorpay', configGateway: 'razorpay', platform: 'ios'),
          PaymentMode.razorpay);
      expect(choosePaymentMode(paymentGateway: 'razorpay', configGateway: 'razorpay', platform: 'web'),
          PaymentMode.webUnsupported);
      expect(choosePaymentMode(paymentGateway: '', configGateway: 'razorpay', platform: 'web'),
          PaymentMode.webUnsupported);
      expect(choosePaymentMode(paymentGateway: '', configGateway: 'mock', platform: 'web'), PaymentMode.mock);
    });

    test('checkout options carry the order, amount in paise and prefill', () {
      final o = payment(gateway: 'razorpay', withCheckout: true).checkout!.toOptions();
      expect(o['key'], 'rzp_test_x');
      expect(o['order_id'], 'order_1');
      expect(o['amount'], 49900);
      expect((o['prefill'] as Map)['contact'], '+919800000001');
      expect(payment().checkout, isNull);
    });

    Future<(FakePaymentRepository, List<Payment?>)> pumpSheet(
      WidgetTester tester, {
      required Payment p,
      required String platform,
      CheckoutLauncher? launcher,
    }) async {
      final repo = FakePaymentRepository();
      final results = <Payment?>[];
      final overrides = await baseOverrides();
      await tester.pumpWidget(testApp(
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () async => results.add(await showPaymentSheet(context, payment: p, title: 'Consult')),
                child: const Text('open'),
              ),
            ),
          ),
        ),
        overrides: [
          ...overrides,
          appPlatformProvider.overrideWithValue(platform),
          paymentRepositoryProvider.overrideWithValue(repo),
          checkoutLauncherProvider.overrideWithValue(launcher ?? FakeLauncher([])),
        ],
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return (repo, results);
    }

    testWidgets('mock gateway keeps the mock sheet', (tester) async {
      final (repo, results) = await pumpSheet(tester, p: payment(), platform: 'android');
      expect(find.byKey(const Key('pay-mock')), findsOneWidget);
      expect(find.text('Simulate failure'), findsOneWidget);
      await tester.tap(find.byKey(const Key('pay-mock')));
      await tester.pumpAndSettle();
      expect(repo.calls, ['mock:true']);
      expect(results.single!.succeeded, isTrue);
    });

    testWidgets('razorpay on web asks to complete payment in the mobile app', (tester) async {
      final (repo, results) =
          await pumpSheet(tester, p: payment(gateway: 'razorpay', withCheckout: true), platform: 'web');
      expect(find.byKey(const Key('payment-web-unsupported')), findsOneWidget);
      expect(find.text('Complete payment in the mobile app'), findsOneWidget);
      expect(find.byKey(const Key('pay-razorpay')), findsNothing);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(repo.calls, isEmpty);
      expect(results.single!.succeeded, isFalse, reason: 'never confirmed without a succeeded payment');
    });

    testWidgets('razorpay success is verified server-side before confirming', (tester) async {
      final launcher = FakeLauncher(
          [const CheckoutSuccess(paymentId: 'pay_rzp', orderId: 'order_1', signature: 'sig')]);
      final (repo, results) = await pumpSheet(tester,
          p: payment(gateway: 'razorpay', withCheckout: true), platform: 'android', launcher: launcher);
      await tester.tap(find.byKey(const Key('pay-razorpay')));
      await tester.pumpAndSettle();
      expect(launcher.opened, ['order_1']);
      expect(repo.calls, ['verify:pay_rzp:order_1:sig']);
      expect(results.single!.succeeded, isTrue);
    });

    testWidgets('razorpay cancel offers a retry with a fresh checkout', (tester) async {
      final launcher = FakeLauncher([
        const CheckoutFailure(cancelled: true),
        const CheckoutSuccess(paymentId: 'pay_2', orderId: 'order_retry', signature: 's2'),
      ]);
      final (repo, results) = await pumpSheet(tester,
          p: payment(gateway: 'razorpay', withCheckout: true), platform: 'android', launcher: launcher);
      await tester.tap(find.byKey(const Key('pay-razorpay')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('payment-failed')), findsOneWidget);
      expect(find.text('Payment was cancelled. Nothing was charged.'), findsOneWidget);
      expect(results, isEmpty, reason: 'sheet stays open, nothing confirmed');

      await tester.tap(find.byKey(const Key('pay-razorpay')));
      await tester.pumpAndSettle();
      expect(repo.calls, ['retry', 'verify:pay_2:order_retry:s2']);
      expect(launcher.opened, ['order_1', 'order_retry']);
      expect(results.single!.succeeded, isTrue);
    });
  });

  group('account deletion screen', () {
    Future<FakeAccountRepository> pumpDelete(WidgetTester tester, DeletionRequest? current) async {
      useTallPhone(tester);
      final repo = FakeAccountRepository(current);
      final overrides = await baseOverrides();
      await tester.pumpWidget(testApp(const DeleteAccountScreen(), overrides: [
        ...overrides,
        accountRepositoryProvider.overrideWithValue(repo),
      ]));
      await tester.pumpAndSettle();
      return repo;
    }

    testWidgets('no request (404): explains, and requires typing DELETE', (tester) async {
      final repo = await pumpDelete(tester, null);
      expect(find.byKey(const Key('deletion-form')), findsOneWidget);
      expect(find.text('What we must keep'), findsOneWidget);
      FilledButton button() => tester.widget<FilledButton>(
          find.descendant(of: find.byKey(const Key('delete-account-button')), matching: find.byType(FilledButton)));
      expect(button().onPressed, isNull);

      await tester.enterText(find.byKey(const Key('delete-confirm-field')), 'delete me');
      await tester.pump();
      expect(button().onPressed, isNull);

      await tester.enterText(find.byKey(const Key('delete-confirm-field')), 'DELETE');
      await tester.pump();
      expect(button().onPressed, isNotNull);

      await tester.tap(find.byKey(const Key('delete-account-button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(repo.calls, ['request']);
      // Confirmation dialog before logging out.
      expect(find.text('Account deletion scheduled'), findsWidgets);
      expect(find.byKey(const Key('deletion-scheduled')), findsOneWidget);
      expect(find.textContaining('You will now be logged out'), findsOneWidget);
    });

    testWidgets('scheduled: shows the date and cancelling returns to the form', (tester) async {
      final repo = await pumpDelete(
          tester,
          DeletionRequest.fromJson({
            'id': 'd1',
            'status': 'scheduled',
            'requestedAt': '2026-09-26T09:30:00.000Z',
            'scheduledFor': '2026-10-03T09:30:00.000Z',
          }));
      expect(find.byKey(const Key('deletion-scheduled')), findsOneWidget);
      expect(find.textContaining('Oct 3, 2026'), findsOneWidget);
      await tester.tap(find.byKey(const Key('cancel-deletion')));
      await tester.pumpAndSettle();
      expect(repo.calls, ['cancel']);
      expect(find.byKey(const Key('deletion-form')), findsOneWidget);
    });

    testWidgets('a cancelled request shows the form again', (tester) async {
      await pumpDelete(tester, DeletionRequest.fromJson({'id': 'd1', 'status': 'cancelled'}));
      expect(find.byKey(const Key('deletion-form')), findsOneWidget);
    });
  });

  group('video join window', () {
    final start = DateTime(2026, 9, 26, 10, 0);
    final end = DateTime(2026, 9, 26, 10, 15);
    final w = JoinWindow.forAppointment(start, end);

    test('opens 10 min before start and closes 60 min after end', () {
      expect(w.stateAt(DateTime(2026, 9, 26, 9, 49, 59)), JoinWindowState.tooEarly);
      expect(w.stateAt(DateTime(2026, 9, 26, 9, 50)), JoinWindowState.open);
      expect(w.stateAt(DateTime(2026, 9, 26, 10, 30)), JoinWindowState.open);
      expect(w.stateAt(DateTime(2026, 9, 26, 11, 15)), JoinWindowState.open);
      expect(w.stateAt(DateTime(2026, 9, 26, 11, 15, 1)), JoinWindowState.closed);
      expect(w.untilOpen(DateTime(2026, 9, 26, 9, 45)), const Duration(minutes: 5));
      expect(fmtCountdown(const Duration(minutes: 5, seconds: 3)), '5m 03s');
      expect(fmtCountdown(const Duration(hours: 2, minutes: 4)), '2h 04m');
    });

    Appointment appt(String mode, String status) => Appointment.fromJson({
          'id': 'a1',
          'doctorName': 'Dr. Rao',
          'startAt': start.toUtc().toIso8601String(),
          'endAt': end.toUtc().toIso8601String(),
          'mode': mode,
          'status': status,
        });

    test('only confirmed video/audio appointments are joinable; audio starts camera-off', () {
      expect(isJoinableAppointment(appt('video', 'confirmed')), isTrue);
      expect(isJoinableAppointment(appt('audio', 'in_progress')), isTrue);
      expect(isJoinableAppointment(appt('in_clinic', 'confirmed')), isFalse);
      expect(isJoinableAppointment(appt('video', 'pending_payment')), isFalse);
      final s = VideoSession.fromJson(
          {'provider': 'jitsi', 'joinUrl': 'https://meet.jit.si/room', 'roomName': 'room'});
      expect(joinUrlForMode(s, 'audio'), 'https://meet.jit.si/room#config.startWithVideoMuted=true');
      expect(joinUrlForMode(s, 'video'), 'https://meet.jit.si/room');
    });

    Future<void> pumpCard(WidgetTester tester, DateTime now) async {
      final overrides = await baseOverrides();
      await tester.pumpWidget(testApp(
        Scaffold(body: VideoJoinCard(appointment: appt('video', 'confirmed'), now: () => now)),
        overrides: overrides,
      ));
      await tester.pump();
    }

    FilledButton joinButton(WidgetTester tester) => tester.widget<FilledButton>(
        find.descendant(of: find.byKey(const Key('join-consultation')), matching: find.byType(FilledButton)));

    testWidgets('before the window: countdown and disabled button', (tester) async {
      await pumpCard(tester, DateTime(2026, 9, 26, 9, 40));
      expect(find.text('You can join in 10m 00s'), findsOneWidget);
      expect(joinButton(tester).onPressed, isNull);
    });

    testWidgets('inside the window: enabled, pre-join checklist first', (tester) async {
      await pumpCard(tester, DateTime(2026, 9, 26, 9, 55));
      expect(joinButton(tester).onPressed, isNotNull);
      await tester.tap(find.byKey(const Key('join-consultation')));
      await tester.pumpAndSettle();
      expect(find.text('Before you join'), findsOneWidget);
      expect(find.text('Allow camera and microphone when asked'), findsOneWidget);
      expect(find.text('Sit in a quiet, private place'), findsOneWidget);
    });

    testWidgets('after the window: ended', (tester) async {
      await pumpCard(tester, DateTime(2026, 9, 26, 12, 0));
      expect(find.text('This consultation has ended.'), findsOneWidget);
      expect(joinButton(tester).onPressed, isNull);
    });
  });

  group('push', () {
    test('is skipped silently when Firebase options are not provided', () async {
      final registered = <String>[];
      final service = PushService(
        config: PushConfig.fromEnvironment(),
        registerToken: (t, p) async => registered.add(t),
        unregisterToken: (t) async => registered.add('-$t'),
      );
      expect(PushConfig.fromEnvironment().isConfigured, isFalse);
      expect(service.isSupported, isFalse);
      expect(await service.init(), isFalse);
      expect(service.isInitialized, isFalse);
      await service.onSignedIn();
      await service.unregister();
      expect(registered, isEmpty);
    });

    test('partial options count as not configured', () {
      const partial = PushConfig(apiKey: 'k', appId: 'a', messagingSenderId: '', projectId: 'p');
      expect(partial.isConfigured, isFalse);
      const full = PushConfig(apiKey: 'k', appId: 'a', messagingSenderId: 's', projectId: 'p');
      expect(full.isConfigured, isTrue);
      expect(full.options.projectId, 'p');
    });
  });

  group('pagination & MFA', () {
    test('list envelope keeps nextCursor', () {
      final p = Page.fromJson({
        'items': [
          {'id': '1'},
        ],
        'nextCursor': 'c2',
      }, (j) => j['id']);
      expect(p.items, ['1']);
      expect(p.nextCursor, 'c2');
    });

    test('MFA_REQUIRED is recognised', () {
      final e = ApiException.fromEnvelope(403, {
        'error': {'code': 'MFA_REQUIRED', 'message': 'MFA required'},
      });
      expect(e.isMfaRequired, isTrue);
    });
  });
}
