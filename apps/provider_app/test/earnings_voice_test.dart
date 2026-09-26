import 'dart:convert';

import 'package:care_companion_provider/core/providers.dart';
import 'package:care_companion_provider/core/storage/key_value_store.dart';
import 'package:care_companion_provider/core/theme.dart';
import 'package:care_companion_provider/features/earnings/earnings_screen.dart';
import 'package:care_companion_provider/features/visits/ui/observations_form.dart';
import 'package:care_companion_provider/features/visits/voice/voice_dictation.dart';
import 'package:care_companion_provider/models/earnings.dart';
import 'package:care_companion_provider/models/provider_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'helpers.dart';
import 'verification_gate_test.dart' show providerMe;

Map<String, dynamic> earningsJson({List<Map<String, dynamic>>? lines}) => {
      'providerId': 'prov-1',
      'providerName': 'Sunita Devi',
      'role': 'provider',
      'from': '2026-09-01',
      'to': '2026-09-30',
      'completedServices': 3,
      'grossAmount': 12450,
      'platformFee': 2490,
      'refunds': 499,
      'payable': 9461,
      'lines': lines ??
          [
            {
              'date': '2026-09-12',
              'description': 'Vitals Check · Ramesh Kumar',
              'refType': 'home_visit',
              'refId': 'hv-1',
              'amount': 499,
              'platformFee': 100,
              'payable': 399,
            },
          ],
    };

class FakeDictation implements VoiceDictation {
  bool available = true;
  String? language;
  void Function(String)? onFinal;
  void Function()? onDone;
  int stops = 0;

  @override
  Future<bool> initialize() async => available;

  @override
  Future<void> start({
    required String appLanguage,
    required void Function(String text) onFinal,
    required void Function() onDone,
  }) async {
    language = appLanguage;
    this.onFinal = onFinal;
    this.onDone = onDone;
  }

  @override
  Future<void> stop() async {
    stops++;
    onDone?.call();
  }
}

void main() {
  setUp(() => useGoogleFonts = false);

  group('Earnings', () {
    testWidgets('renders tiles and lines', (tester) async {
      await tester.pumpWidget(testApp(
        Scaffold(body: EarningsView(earnings: Earnings.fromJson(earningsJson()))),
        wrap: false,
      ));
      expect(find.text('₹9,461'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('₹12,450'), findsOneWidget);
      expect(find.text('− ₹2,490'), findsOneWidget);
      expect(find.text('− ₹499'), findsOneWidget);
      expect(find.text('Vitals Check · Ramesh Kumar'), findsOneWidget);
      expect(find.textContaining('Fee ₹100 · Payable ₹399'), findsOneWidget);
      expect(find.text('Payable to you'), findsOneWidget);
    });

    testWidgets('empty month shows the empty state', (tester) async {
      await tester.pumpWidget(testApp(
        Scaffold(body: EarningsView(earnings: Earnings.fromJson(earningsJson(lines: [])))),
        wrap: false,
      ));
      expect(find.byKey(const Key('earnEmpty')), findsOneWidget);
    });

    test('monthRange covers the whole month', () {
      expect(monthRange(DateTime(2026, 2)), (from: '2026-02-01', to: '2026-02-28'));
      expect(monthRange(DateTime(2026, 12)), (from: '2026-12-01', to: '2026-12-31'));
    });

    testWidgets('screen queries the selected month; next is disabled on the current month', (tester) async {
      final queries = <Map<String, String>>[];
      final client = MockClient((req) async {
        if (req.url.path.endsWith('/provider/earnings')) {
          queries.add(req.url.queryParameters);
          return http.Response(jsonEncode(earningsJson()), 200, headers: {'content-type': 'application/json'});
        }
        return http.Response('{}', 404);
      });
      await tester.pumpWidget(ProviderScope(
        retry: (_, _) => null,
        overrides: [
          keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()),
          httpClientProvider.overrideWithValue(client),
        ],
        child: testApp(EarningsScreen(now: DateTime(2026, 9, 26)), wrap: false),
      ));
      await tester.pumpAndSettle();
      expect(queries.last, {'from': '2026-09-01', 'to': '2026-09-30'});
      expect(find.text('September 2026'), findsOneWidget);
      expect(tester.widget<IconButton>(find.byKey(const Key('earnNext'))).onPressed, isNull);

      await tester.tap(find.byKey(const Key('earnPrev')));
      await tester.pumpAndSettle();
      expect(queries.last, {'from': '2026-08-01', 'to': '2026-08-31'});
      expect(find.text('August 2026'), findsOneWidget);

      // Pull to refresh re-fetches.
      final before = queries.length;
      await tester.fling(find.byType(ListView).first, const Offset(0, 400), 1000);
      await tester.pumpAndSettle();
      expect(queries.length, before + 1);
    });
  });

  group('Voice-to-note', () {
    Future<(FakeDictation, List<Map<String, dynamic>>)> pump(WidgetTester tester, {Locale locale = const Locale('en')}) async {
      final dictation = FakeDictation();
      final submitted = <Map<String, dynamic>>[];
      await tester.pumpWidget(testApp(
        ObservationsForm(
          dictation: dictation,
          onSubmit: (body) async {
            submitted.add(body);
            return true;
          },
        ),
        locale: locale,
      ));
      return (dictation, submitted);
    }

    testWidgets('appends dictated text for review and never auto-submits', (tester) async {
      final (dictation, submitted) = await pump(tester);
      await tester.enterText(find.byKey(const Key('obsNotes')), 'Patient alert.');
      await tester.tap(find.byKey(const Key('obsDictate')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('obsListening')), findsOneWidget);

      dictation.onFinal!('BP stable after rest');
      dictation.onFinal!('no swelling');
      dictation.onDone!();
      await tester.pumpAndSettle();

      final field = tester.widget<TextField>(find.byKey(const Key('obsNotes')));
      expect(field.controller!.text, 'Patient alert. BP stable after rest no swelling');
      expect(find.byKey(const Key('obsDictationReview')), findsOneWidget);
      expect(submitted, isEmpty, reason: 'dictation must never submit by itself');

      // The provider corrects the text, then saves explicitly.
      await tester.enterText(find.byKey(const Key('obsNotes')), 'Patient alert. BP stable after rest, no swelling.');
      await tester.tap(find.byKey(const Key('obsSave')));
      await tester.pumpAndSettle();
      expect(submitted.single['notes'], 'Patient alert. BP stable after rest, no swelling.');
    });

    testWidgets('mic toggles off; locale follows the app language', (tester) async {
      final (dictation, _) = await pump(tester, locale: const Locale('te'));
      await tester.tap(find.byKey(const Key('obsDictate')));
      await tester.pumpAndSettle();
      expect(dictation.language, 'te');
      await tester.tap(find.byKey(const Key('obsDictate')));
      await tester.pumpAndSettle();
      expect(dictation.stops, 1);
      expect(find.byKey(const Key('obsListening')), findsNothing);
    });

    testWidgets('unavailable recognizer explains and leaves the notes alone', (tester) async {
      final (dictation, submitted) = await pump(tester);
      dictation.available = false;
      await tester.tap(find.byKey(const Key('obsDictate')));
      await tester.pumpAndSettle();
      expect(find.textContaining("Voice input isn't available"), findsOneWidget);
      expect(dictation.onFinal, isNull);
      expect(submitted, isEmpty);
    });

    test('speech locale: en-IN / hi-IN / te-IN with fallbacks', () {
      const all = ['en_US', 'en_IN', 'hi_IN', 'te_IN'];
      expect(pickSpeechLocale('en', all), 'en_IN');
      expect(pickSpeechLocale('hi', all), 'hi_IN');
      expect(pickSpeechLocale('te', ['te-IN']), 'te-IN');
      expect(pickSpeechLocale('en', ['en_US', 'fr_FR']), 'en_US');
      expect(pickSpeechLocale('te', ['en_US']), isNull);
    });
  });

  test('ProviderProfile reads optional photo/rating only when present', () {
    final plain = ProviderProfile.fromJson(providerMe('verified'));
    expect(plain.rating, isNull);
    expect(plain.photoUrl, isNull);
    final rich = ProviderProfile.fromJson(
        {...providerMe('verified'), 'rating': 4.6, 'ratingCount': 12, 'photoUrl': 'http://x/media/1'});
    expect(rich.rating, 4.6);
    expect(ProviderProfile.fromJson(rich.toJson()).ratingCount, 12);
  });
}
