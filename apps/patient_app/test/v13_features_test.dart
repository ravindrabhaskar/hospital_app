import 'package:care_companion_patient/core/theme/app_theme.dart';
import 'package:care_companion_patient/core/widgets/branding.dart';
import 'package:care_companion_patient/data/v13_repositories.dart';
import 'package:care_companion_patient/features/abdm/abdm.dart';
import 'package:care_companion_patient/features/ambulance/ambulance.dart';
import 'package:care_companion_patient/features/checkin/checkin.dart';
import 'package:care_companion_patient/features/lab/lab_screens.dart';
import 'package:care_companion_patient/features/offers/checkout_offers.dart';
import 'package:care_companion_patient/features/programs/programs.dart';
import 'package:care_companion_patient/features/safety/safety.dart';
import 'package:care_companion_patient/features/support/support.dart';
import 'package:care_companion_patient/features/wallet/wallet.dart';
import 'package:care_companion_patient/models/care.dart';
import 'package:care_companion_patient/models/config.dart';
import 'package:care_companion_patient/models/engagement_v13.dart';
import 'package:care_companion_patient/models/monitoring.dart';
import 'package:care_companion_patient/models/patient.dart';
import 'package:care_companion_patient/models/services.dart';
import 'package:care_companion_patient/state/core_providers.dart';
import 'package:care_companion_patient/state/v13_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

// ---------------------------------------------------------------- fakes

class FakeCheckinRepo extends CheckinRepository {
  FakeCheckinRepo() : super(deadApiClient());
  int calls = 0;
  int? lastMood;
  @override
  Future<CheckIn> checkIn(String patientId, {int? mood, String? note}) async {
    calls++;
    lastMood = mood;
    return CheckIn(
        id: 'c1', patientId: patientId, date: ymdToday(), status: 'ok', checkedInAt: DateTime.now(), mood: mood, note: null);
  }
}

String ymdToday() {
  final d = DateTime.now();
  return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

const enabledSettings = CheckinSettings(
  patientId: 'p-self',
  enabled: true,
  windowStart: '08:00',
  windowEnd: '10:00',
  escalateAfterMins: 60,
  notifyFamily: true,
  notifyCoordinator: true,
);

class FakeOffersRepo extends OffersRepository {
  FakeOffersRepo({this.balance = 150}) : super(deadApiClient());
  final int balance;
  String? redeemed;
  @override
  Future<CouponValidation> validateCoupon(String code, {required String purpose, required int amount}) async =>
      code.toUpperCase() == 'CARE10'
          ? CouponValidation(valid: true, discount: 100, finalAmount: amount - 100, message: '10% off')
          : const CouponValidation(valid: false, discount: 0, finalAmount: 0, message: 'Invalid coupon');
  @override
  Future<Wallet> wallet() async => Wallet(balance: balance, transactions: const []);
  @override
  Future<void> redeemInvite(String code) async {
    if (code == 'EXPIRED1') throw Exception('expired');
    redeemed = code;
  }
}

class FakeAmbulanceRepo extends AmbulanceRepository {
  FakeAmbulanceRepo(this.sequence) : super(deadApiClient());
  final List<AmbulanceRequest> sequence;
  int gets = 0;
  @override
  Future<AmbulanceRequest> get(String id) async {
    final r = sequence[gets.clamp(0, sequence.length - 1)];
    gets++;
    return r;
  }
}

AmbulanceRequest amb(String status, {bool vehicle = false, int? eta}) => AmbulanceRequest.fromJson({
      'id': 'a1',
      'patientId': 'p-self',
      'patientName': 'Vaibhav',
      'type': 'bls',
      'status': status,
      'vehicle': vehicle ? {'number': 'TS09 AB 1234', 'driverName': 'Ravi', 'phoneMasked': '98xxxxxx10'} : null,
      'etaMinutes': eta,
      'location': vehicle ? {'lat': 17.4, 'lng': 78.4, 'updatedAt': '2026-09-29T10:00:00.000Z'} : null,
      'pickup': {'lat': 17.41, 'lng': 78.41, 'address': 'Home'},
      'destination': null,
      'partnerName': 'Mock Ambulance',
      'timeline': [
        {'status': 'searching', 'at': '2026-09-29T09:59:00.000Z'},
        if (vehicle) {'status': 'assigned', 'at': '2026-09-29T09:59:20.000Z'},
      ],
      'createdAt': '2026-09-29T09:59:00.000Z',
    });

class FakeSupportRepo extends SupportRepository {
  FakeSupportRepo(this.ticket) : super(deadApiClient());
  Ticket ticket;
  final sent = <String>[];
  @override
  Future<Ticket> get(String id) async => ticket;
  @override
  Future<TicketMessage> send(String id, String text) async {
    sent.add(text);
    final m = TicketMessage(
        id: 'm${sent.length + 10}', ticketId: id, authorName: 'Vaibhav', authorRole: 'customer', text: text, internal: false, at: DateTime.now());
    ticket = Ticket.fromJson({
      'id': ticket.id,
      'number': ticket.number,
      'subject': ticket.subject,
      'category': ticket.category,
      'status': ticket.status,
      'messages': [
        for (final x in ticket.messages)
          {'id': x.id, 'ticketId': id, 'authorName': x.authorName, 'authorRole': x.authorRole, 'text': x.text, 'internal': x.internal},
        {'id': m.id, 'ticketId': id, 'authorName': m.authorName, 'authorRole': m.authorRole, 'text': m.text, 'internal': false},
      ],
    });
    return m;
  }
}

Ticket sampleTicket({String status = 'open', String category = 'payment'}) => Ticket.fromJson({
      'id': 't1',
      'number': 'T-000123',
      'subject': 'Refund not received',
      'category': category,
      'status': status,
      'priority': 'normal',
      'messages': [
        {'id': 'm1', 'ticketId': 't1', 'authorName': 'Vaibhav', 'authorRole': 'customer', 'text': 'Where is my refund?', 'internal': false},
        {'id': 'm2', 'ticketId': 't1', 'authorName': 'Support Desk', 'authorRole': 'agent', 'text': 'Processing, 3 days.', 'internal': false},
        {'id': 'm3', 'ticketId': 't1', 'authorName': 'Support Desk', 'authorRole': 'agent', 'text': 'INTERNAL NOTE', 'internal': true},
      ],
      'rating': null,
    });

LabTest labTest(String id, int price, {bool fasting = false, int? hours}) => LabTest.fromJson({
      'id': id,
      'code': id,
      'name': 'Test $id',
      'category': 'diabetes',
      'sampleType': 'blood',
      'fastingRequired': fasting,
      'fastingHours': hours,
      'turnaroundHours': 24,
      'price': price,
      'mrp': price + 100,
    });

void main() {
  // ---------------------------------------------------------------- §41
  group('Daily check-in', () {
    test('card state from settings and today\'s entry', () {
      expect(checkinCardState(null, null), CheckinCardState.hidden);
      expect(checkinCardState(CheckinSettings.defaults, null), CheckinCardState.hidden);
      expect(checkinCardState(enabledSettings, null), CheckinCardState.pending);
      CheckIn c(String s) => CheckIn(id: 'x', patientId: 'p', date: ymdToday(), status: s, checkedInAt: null, mood: null, note: null);
      expect(checkinCardState(enabledSettings, c('pending')), CheckinCardState.pending);
      expect(checkinCardState(enabledSettings, c('ok')), CheckinCardState.done);
      expect(checkinCardState(enabledSettings, c('late')), CheckinCardState.done);
      expect(checkinCardState(enabledSettings, c('missed')), CheckinCardState.missed);
      expect(todaysCheckin([c('ok')], DateTime.now())?.status, 'ok');
      expect(hhmmToMinutes('08:30'), 510);
      expect(hhmmToMinutes('25:00'), isNull);
    });

    Future<FakeCheckinRepo> pump(WidgetTester tester, {CheckinSettings? settings, List<CheckIn> history = const [], PatientSummary? patient}) async {
      useTallPhone(tester, height: 1400);
      final repo = FakeCheckinRepo();
      final o = await baseOverrides(patient: patient);
      await tester.pumpWidget(testApp(const Scaffold(body: SingleChildScrollView(child: DailyCheckinCard())), overrides: [
        ...o,
        checkinRepositoryProvider.overrideWithValue(repo),
        checkinSettingsProvider.overrideWith((ref) async => settings),
        checkinHistoryProvider.overrideWith((ref) async => history),
      ]));
      await tester.pumpAndSettle();
      return repo;
    }

    testWidgets('pending: one tap with an optional mood checks in and shows the thanks state', (tester) async {
      final repo = await pump(tester, settings: enabledSettings);
      expect(find.byKey(const Key('checkin-pending')), findsOneWidget);
      expect(find.text("I'm OK today"), findsOneWidget);
      await tester.tap(find.byKey(const Key('checkin-mood-4')));
      await tester.tap(find.byKey(const Key('checkin-ok')));
      await tester.pumpAndSettle();
      expect(repo.calls, 1);
      expect(repo.lastMood, 4);
      expect(find.byKey(const Key('checkin-done')), findsOneWidget);
    });

    testWidgets('hidden when disabled; missed state still allows checking in', (tester) async {
      await pump(tester, settings: CheckinSettings.defaults);
      expect(find.byKey(const Key('checkin-pending')), findsNothing);
      expect(find.byKey(const Key('checkin-done')), findsNothing);
      await tester.pumpWidget(const SizedBox());

      await pump(tester, settings: enabledSettings, history: [
        CheckIn(id: 'x', patientId: 'p', date: ymdToday(), status: 'missed', checkedInAt: null, mood: null, note: null),
      ]);
      expect(find.byKey(const Key('checkin-missed')), findsOneWidget);
      expect(find.byKey(const Key('checkin-ok')), findsOneWidget);
    });

    testWidgets('family view shows status only', (tester) async {
      final ramesh = PatientSummary(
          id: 'p-r', name: 'Ramesh', dob: null, age: 72, gender: 'male', relation: 'father', isSelf: false, permissions: const ['manage_care'], avatarUrl: null);
      await pump(tester, settings: enabledSettings, patient: ramesh);
      expect(find.byKey(const Key('checkin-family-card')), findsOneWidget);
      expect(find.textContaining('Ramesh has not checked in yet'), findsOneWidget);
      expect(find.byKey(const Key('checkin-ok')), findsNothing);
    });
  });

  // ---------------------------------------------------------------- §42
  group('Care programs', () {
    test('reading validation', () {
      expect(validateReading(ReadingKind.bp, '138', '88'), isNull);
      expect(validateReading(ReadingKind.bp, '', '88'), ReadingError.missing);
      expect(validateReading(ReadingKind.bp, 'abc', '88'), ReadingError.notNumber);
      expect(validateReading(ReadingKind.bp, '300', '88'), ReadingError.outOfRange);
      expect(validateReading(ReadingKind.bp, '80', '90'), ReadingError.systolicNotAboveDiastolic);
      expect(validateReading(ReadingKind.glucose, '142'), isNull);
      expect(validateReading(ReadingKind.glucose, '5'), ReadingError.outOfRange);
      expect(validateReading(ReadingKind.weight, '72.5'), isNull);
      expect(readingToVitals(ReadingKind.bp, '138', '88').map((v) => v.$1), ['bp_systolic', 'bp_diastolic']);
    });

    test('trend points per type and readings due today', () {
      final s = ProgramSummary.fromJson({
        'enrollmentId': 'e1',
        'adherencePct': 80,
        'trend': [
          {'date': '2026-09-28', 'type': 'bp_systolic', 'avg': 140, 'min': 132, 'max': 150},
          {'date': '2026-09-27', 'type': 'bp_systolic', 'avg': 136},
          {'date': '2026-09-28', 'type': 'bp_diastolic', 'avg': 88},
        ],
      });
      expect(s.trendTypes, ['bp_systolic', 'bp_diastolic']);
      final sys = s.trendFor('bp_systolic');
      expect(sys.first.avg, 136); // sorted oldest first
      expect(sys.first.min, 136); // min/max default to avg
      final now = DateTime(2026, 9, 29, 12);
      final due = readingsDueToday(const [
        ProgramMetric(type: 'bp_systolic', frequency: 'twice_daily', unit: 'mmHg'),
        ProgramMetric(type: 'bp_diastolic', frequency: 'twice_daily', unit: 'mmHg'),
        ProgramMetric(type: 'weight', frequency: 'weekly', unit: 'kg'),
      ], [
        VitalMeasurement(id: 'v', patientId: 'p', type: 'bp_systolic', value: 130, unit: 'mmHg', measuredAt: DateTime(2026, 9, 29, 8), source: 'patient_entered', recordedByName: null),
      ], now);
      expect(due.length, 2); // diastolic folded into BP
      expect(due.first.remaining, 1);
      expect(due.last.remaining, 1);
    });

    testWidgets('trend chart and log-reading validation render', (tester) async {
      final o = await baseOverrides();
      await tester.pumpWidget(testApp(
        Scaffold(
          body: Column(children: [
            ProgramTrendChart(type: 'bp_systolic', points: [
              TrendPoint(date: DateTime(2026, 9, 27), type: 'bp_systolic', avg: 136, min: 130, max: 140),
              TrendPoint(date: DateTime(2026, 9, 28), type: 'bp_systolic', avg: 142, min: 138, max: 150),
            ]),
            const Expanded(child: LogReadingSheet()),
          ]),
        ),
        overrides: o,
      ));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel(RegExp(r'trend: 2 days')), findsOneWidget);
      await tester.enterText(find.byKey(const Key('reading-a')), '80');
      await tester.enterText(find.byKey(const Key('reading-b')), '95');
      await tester.tap(find.byKey(const Key('reading-save')));
      await tester.pump();
      expect(find.text('The upper (systolic) number must be higher than the lower one.'), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------- §44
  group('Lab tests', () {
    test('cart totals skip tests covered by a package; fasting uses package tests', () {
      final a = labTest('a', 300), b = labTest('b', 400, fasting: true, hours: 10), c = labTest('c', 200, fasting: true);
      final pkg = LabPackage.fromJson({'id': 'pk', 'name': 'Diabetes', 'testIds': ['b', 'c'], 'price': 500, 'mrp': 800});
      var cart = const LabCart().toggleTest(a).toggleTest(b);
      expect(cart.total, 700);
      expect(cart.fastingHours({}), 10);
      cart = cart.togglePackage(pkg);
      expect(cart.coveredByPackage('b'), isTrue);
      expect(cart.total, 300 + 500);
      expect(cart.testIds, ['a']);
      expect(cart.packageIds, ['pk']);
      final noFast = const LabCart().toggleTest(a);
      expect(noFast.fastingHours({}), isNull);
      final onlyPkg = const LabCart().togglePackage(pkg);
      expect(onlyPkg.fastingHours({'b': b, 'c': c}), 10);
      expect(cart.toggleTest(a).tests.containsKey('a'), isFalse); // toggles off
    });

    testWidgets('checkout shows the fasting notice for fasting tests', (tester) async {
      useTallPhone(tester);
      final o = await baseOverrides();
      await tester.pumpWidget(testApp(const LabCheckoutScreen(), overrides: [
        ...o,
        labCatalogProvider.overrideWith((ref) async => {}),
        labCartProvider.overrideWith(() => _PreloadedCart(labTest('b', 400, fasting: true, hours: 12))),
      ]));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('fasting-notice')), findsOneWidget);
      expect(find.textContaining('12 hours'), findsOneWidget);
      expect(find.text('Test b'), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------- §60 checkout
  group('Checkout offers', () {
    test('breakdown math', () {
      final plain = CheckoutBreakdown.compute(subtotal: 699);
      expect([plain.discount, plain.walletUsed, plain.payable], [0, 0, 699]);
      final both = CheckoutBreakdown.compute(subtotal: 699, couponDiscount: 100, walletBalance: 150, useWallet: true);
      expect([both.discount, both.walletUsed, both.payable], [100, 150, 449]);
      final notUsing = CheckoutBreakdown.compute(subtotal: 699, couponDiscount: 100, walletBalance: 150);
      expect(notUsing.walletUsed, 0);
      final covered = CheckoutBreakdown.compute(subtotal: 200, couponDiscount: 150, walletBalance: 500, useWallet: true);
      expect([covered.walletUsed, covered.payable, covered.fullyCovered], [50, 0, true]);
      final capped = CheckoutBreakdown.compute(subtotal: 80, couponDiscount: 100);
      expect([capped.discount, capped.payable], [80, 0]);
    });

    testWidgets('applying a coupon and the wallet updates the lines', (tester) async {
      useTallPhone(tester, height: 1400);
      final o = await baseOverrides();
      final c = CheckoutOffersController();
      await tester.pumpWidget(testApp(
        Scaffold(body: SingleChildScrollView(child: CheckoutOffersCard(controller: c, purpose: 'lab_order', amount: 699))),
        overrides: [...o, offersRepositoryProvider.overrideWithValue(FakeOffersRepo())],
      ));
      await tester.pumpAndSettle();
      Text line(String key) => tester.widgetList<Text>(find.descendant(of: find.byKey(Key(key)), matching: find.byType(Text))).last;
      expect(line('line-payable').data, '₹699');
      expect(find.byKey(const Key('line-discount')), findsNothing);

      await tester.enterText(find.byKey(const Key('coupon-field')), 'nope');
      await tester.pump();
      await tester.tap(find.byKey(const Key('coupon-apply')));
      await tester.pumpAndSettle();
      expect(find.text('Invalid coupon'), findsOneWidget);
      expect(c.couponCode, isNull);

      await tester.enterText(find.byKey(const Key('coupon-field')), 'care10');
      await tester.pump();
      await tester.tap(find.byKey(const Key('coupon-apply')));
      await tester.pumpAndSettle();
      expect(c.couponCode, 'CARE10');
      expect(find.text('CARE10 applied'), findsOneWidget);
      expect(line('line-discount').data, '−₹100');
      expect(line('line-payable').data, '₹599');

      await tester.tap(find.byKey(const Key('use-wallet')));
      await tester.pumpAndSettle();
      expect(c.useWallet, isTrue);
      expect(line('line-wallet').data, '−₹150');
      expect(line('line-payable').data, '₹449');
    });
  });

  // ---------------------------------------------------------------- §50
  group('ABHA create flow', () {
    test('OTP flow state machine', () async {
      String? startedWith;
      final c = AbhaFlowController(
        start: (id) async {
          startedWith = id;
          return 'txn-1';
        },
        verify: (txn, otp) async {
          if (otp != '123456') throw Exception('wrong otp');
          return const AbhaInfo(number: '12345678901234', address: 'v@sbx', status: 'verified');
        },
      );
      expect(c.step, AbhaStep.enterId);
      expect(AbhaFlowController.validMobile('9800000001'), isTrue);
      expect(AbhaFlowController.validMobile('12345'), isFalse);
      expect(AbhaFlowController.validOtp('123456'), isTrue);
      expect(AbhaFlowController.validOtp('12a456'), isFalse);
      await c.sendOtp('9800000001');
      expect(startedWith, '9800000001');
      expect(c.step, AbhaStep.enterOtp);
      expect(c.txnId, 'txn-1');
      await c.submitOtp('000000');
      expect(c.step, AbhaStep.enterOtp);
      expect(c.error, isNotNull);
      await c.submitOtp('123456');
      expect(c.step, AbhaStep.done);
      expect(c.error, isNull);
      expect(c.result!.verified, isTrue);
      c.restart();
      expect(c.step, AbhaStep.enterId);
    });
  });

  // ---------------------------------------------------------------- §56
  group('Dementia safety', () {
    test('safe-zone radius validation', () {
      expect(validateSafeZoneRadius(500), isNull);
      expect(validateSafeZoneRadius(100), isNull);
      expect(validateSafeZoneRadius(5000), isNull);
      expect(validateSafeZoneRadius(99), 'too_small');
      expect(validateSafeZoneRadius(5001), 'too_large');
      expect(validateSafeZoneRadius(null), 'missing');
    });

    test('companion mode cannot be enabled without consent', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final c = ProviderContainer(overrides: [sharedPrefsProvider.overrideWithValue(prefs)]);
      addTearDown(c.dispose);
      final n = c.read(companionModeProvider.notifier);
      expect(await n.enable(), isFalse);
      expect(c.read(companionModeProvider).enabled, isFalse);
      await n.giveConsent();
      expect(await n.enable(), isTrue);
      expect(c.read(companionModeProvider).enabled, isTrue);
      expect(prefs.getBool(CompanionModeNotifier.enabledKey), isTrue);
      await n.withdraw();
      expect(c.read(companionModeProvider).enabled, isFalse);
      expect(c.read(companionModeProvider).consented, isFalse);
    });

    testWidgets('turning companion mode on opens the consent screen first', (tester) async {
      useTallPhone(tester, height: 1600);
      final o = await baseOverrides();
      await tester.pumpWidget(testApp(const CompanionModeScreen(), overrides: o));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('companion-toggle')));
      await tester.pumpAndSettle();
      expect(find.text('Share your location?'), findsOneWidget);
      final accept = tester.widget<FilledButton>(
          find.descendant(of: find.byKey(const Key('companion-accept')), matching: find.byType(FilledButton)));
      expect(accept.onPressed, isNull); // gated on the checkbox
      await tester.tap(find.byKey(const Key('companion-agree')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('companion-accept')));
      await tester.pumpAndSettle();
      final toggle = tester.widget<SwitchListTile>(find.byKey(const Key('companion-toggle')));
      expect(toggle.value, isTrue);
    });
  });

  // ---------------------------------------------------------------- §55
  group('Ambulance tracking', () {
    testWidgets('polls and renders status, vehicle, ETA and 108', (tester) async {
      useTallPhone(tester, height: 2000);
      final repo = FakeAmbulanceRepo([amb('searching'), amb('en_route', vehicle: true, eta: 7)]);
      final o = await baseOverrides();
      await tester.pumpWidget(testApp(const AmbulanceTrackingScreen(id: 'a1'), overrides: [
        ...o,
        ambulanceRepositoryProvider.overrideWithValue(repo),
        ambulancePollIntervalProvider.overrideWithValue(const Duration(seconds: 5)),
      ]));
      await tester.pump();
      await tester.pump();
      expect(find.text('Finding an ambulance'), findsWidgets);
      expect(find.byKey(const Key('call-108')), findsOneWidget);
      expect(find.byKey(const Key('amb-eta')), findsNothing);

      await tester.pump(const Duration(seconds: 5));
      await tester.pump();
      expect(repo.gets, greaterThanOrEqualTo(2));
      expect(find.byKey(const Key('amb-eta')), findsOneWidget);
      expect(find.text('Arriving in about 7 min'), findsOneWidget);
      expect(find.text('TS09 AB 1234'), findsOneWidget);
      expect(find.byKey(const Key('amb-map')), findsOneWidget);
      expect(find.byKey(const Key('amb-cancel')), findsOneWidget);
      await tester.pumpWidget(const SizedBox()); // dispose → timer cancelled
    });
  });

  // ---------------------------------------------------------------- §58
  group('White-label branding', () {
    test('parses branding and seeds the theme; default unchanged', () {
      final cfg = PublicConfig.fromJson({
        'branding': {
          'tenantCode': 'deccan',
          'displayName': 'Deccan Sunrise Care',
          'primaryColor': '#1E4FA0',
          'logoUrl': null,
          'supportPhone': '+914000000000',
        },
        'support': {'phone': '+911800000000', 'email': 'help@cc.in'},
      });
      expect(cfg.branding!.displayName, 'Deccan Sunrise Care');
      expect(cfg.support.phone, '+914000000000');
      expect(cfg.support.email, 'help@cc.in');
      final seed = brandSeedColor(cfg.branding);
      expect(seed, const Color(0xFF1E4FA0));
      AppTheme.useGoogleFonts = false;
      expect(AppTheme.light(seed: seed).colorScheme.primary, const Color(0xFF1E4FA0));
      expect(AppTheme.light().colorScheme.primary, const Color(0xFF0B5D45));
      expect(PublicConfig.fromJson({}).branding, isNull);
      expect(parseHexColor('#12ZZ00'), isNull);
    });

    testWidgets('Powered by CareCompanion footer only for a tenant', (tester) async {
      final o = await baseOverrides();
      await tester.pumpWidget(testApp(const Scaffold(body: PoweredByFooter()), overrides: [
        ...o,
        brandingProvider.overrideWithValue(const Branding(
            tenantCode: 'deccan', displayName: 'Deccan Sunrise Care', logoUrl: null, primaryColor: '#1E4FA0', supportPhone: null, supportEmail: null)),
      ]));
      await tester.pumpAndSettle();
      expect(find.text('Powered by CareCompanion'), findsOneWidget);
      expect(find.text('Deccan Sunrise Care'), findsOneWidget);

      await tester.pumpWidget(testApp(const Scaffold(body: PoweredByFooter()), overrides: [
        ...o,
        brandingProvider.overrideWithValue(null),
      ]));
      await tester.pumpAndSettle();
      expect(find.text('Powered by CareCompanion'), findsNothing);
    });
  });

  // ---------------------------------------------------------------- §61
  group('Support tickets', () {
    testWidgets('conversation hides internal notes, sends, and polls', (tester) async {
      useTallPhone(tester, height: 1600);
      final repo = FakeSupportRepo(sampleTicket());
      final o = await baseOverrides();
      await tester.pumpWidget(testApp(const TicketScreen(id: 't1'), overrides: [
        ...o,
        supportRepositoryProvider.overrideWithValue(repo),
        ticketPollIntervalProvider.overrideWithValue(const Duration(seconds: 15)),
      ]));
      await tester.pumpAndSettle();
      expect(find.text('Refund not received'), findsOneWidget);
      expect(find.text('Processing, 3 days.'), findsOneWidget);
      expect(find.text('INTERNAL NOTE'), findsNothing);
      expect(find.byKey(const Key('ticket-rate')), findsNothing);

      await tester.enterText(find.byKey(const Key('ticket-input')), 'Thanks, any update?');
      await tester.pump();
      await tester.tap(find.byKey(const Key('ticket-send')));
      await tester.pumpAndSettle();
      expect(repo.sent, ['Thanks, any update?']);
      expect(find.text('Thanks, any update?'), findsOneWidget);

      // The agent resolves it; the next poll shows "Rate".
      repo.ticket = sampleTicket(status: 'resolved');
      await tester.pump(const Duration(seconds: 15));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('ticket-rate')), findsOneWidget);
      expect(find.byKey(const Key('ticket-input')), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('clinical concern shows the care-team note and 108', (tester) async {
      useTallPhone(tester, height: 1600);
      final o = await baseOverrides();
      await tester.pumpWidget(testApp(const NewTicketScreen(), overrides: o));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('clinical-note')), findsNothing);
      await tester.tap(find.byKey(const Key('tc-clinical_concern')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('clinical-note')), findsOneWidget);
      expect(find.text('Call 108'), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------- §60 invites
  group('Invite code', () {
    test('normalisation', () {
      expect(normalizeInviteCode(' vai bh100 '), 'VAIBH100');
      expect(normalizeInviteCode('ab'), isNull);
      expect(normalizeInviteCode('bad!code'), isNull);
    });

    testWidgets('redeem sends the normalised code', (tester) async {
      final repo = FakeOffersRepo();
      var done = false;
      final o = await baseOverrides();
      await tester.pumpWidget(testApp(
        Scaffold(body: RedeemInviteForm(onDone: () => done = true)),
        overrides: [...o, offersRepositoryProvider.overrideWithValue(repo)],
      ));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('invite-redeem-field')), 'x');
      await tester.pump();
      await tester.tap(find.byKey(const Key('invite-redeem')));
      await tester.pumpAndSettle();
      expect(find.text('That code does not look right'), findsOneWidget);
      expect(repo.redeemed, isNull);

      await tester.enterText(find.byKey(const Key('invite-redeem-field')), 'ravi 2026');
      await tester.pump();
      await tester.tap(find.byKey(const Key('invite-redeem')));
      await tester.pumpAndSettle();
      expect(repo.redeemed, 'RAVI2026');
      expect(done, isTrue);
    });
  });

  test('payment fully covered by offers skips the sheet', () {
    final p = Payment.fromJson({'id': 'x', 'status': 'succeeded', 'amount': 0, 'discount': 100, 'walletUsed': 50});
    expect(p.succeeded, isTrue);
    expect([p.discount, p.walletUsed], [100, 50]);
  });
}

class _PreloadedCart extends LabCartNotifier {
  _PreloadedCart(this.test);
  final LabTest test;
  @override
  LabCart build() => const LabCart().toggleTest(test);
}
