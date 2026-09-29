import 'dart:convert';

import 'package:care_companion_provider/app.dart';
import 'package:care_companion_provider/core/connectivity.dart';
import 'package:care_companion_provider/core/providers.dart';
import 'package:care_companion_provider/core/storage/key_value_store.dart';
import 'package:care_companion_provider/core/theme.dart';
import 'package:care_companion_provider/features/care_plans/care_plan_repository.dart';
import 'package:care_companion_provider/features/care_plans/diet_plan_screen.dart';
import 'package:care_companion_provider/features/care_plans/exercise_plan_screen.dart';
import 'package:care_companion_provider/features/visits/domain/visit_lifecycle.dart';
import 'package:care_companion_provider/features/visits/ui/lifecycle_panel.dart';
import 'package:care_companion_provider/features/visits/ui/sample_collection.dart';
import 'package:care_companion_provider/models/care_plans.dart';
import 'package:care_companion_provider/models/home_visit.dart';
import 'package:care_companion_provider/models/provider_application.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'field_ops_test.dart' show apiWith, jsonRes;
import 'helpers.dart';
import 'verification_gate_test.dart' show me, providerMe;

final today = DateTime(2026, 9, 29, 10);

Map<String, dynamic> sampleVisitJson({String status = VisitStatus.inProgress, List<Map<String, dynamic>>? tests}) =>
    visitJson(status: status)
      ..['serviceCode'] = 'sample_collection'
      ..['serviceName'] = 'Sample Collection'
      ..addAll({'labTests': ?tests});

const exercise = Exercise(id: 'ex-1', title: 'Quad sets', bodyArea: 'knee');

final library = [
  {'id': 'ex-1', 'title': 'Quad sets', 'bodyArea': 'knee', 'level': 'beginner', 'instructions': [], 'precautions': []},
  {'id': 'ex-2', 'title': 'Shoulder rolls', 'bodyArea': 'shoulder', 'level': 'beginner', 'instructions': [], 'precautions': []},
];

void main() {
  setUp(() {
    useGoogleFonts = false;
    SharedPreferences.setMockInitialValues({});
  });

  group('sample collection (§44)', () {
    Future<List<(VisitActionType, Map<String, dynamic>)>> pumpPanel(WidgetTester tester, HomeVisit v) async {
      final calls = <(VisitActionType, Map<String, dynamic>)>[];
      tester.view.physicalSize = const Size(1080, 2600);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(testApp(NextActionPanel(
        visit: v,
        onNavigate: () {},
        onAction: (type, body) async => calls.add((type, body)),
      )));
      return calls;
    }

    test('checklist is complete only when every item is confirmed', () {
      final c = SampleChecklist();
      expect(c.isComplete, isFalse);
      c
        ..tubesLabelled = true
        ..patientIdVerified = true
        ..fastingConfirmed = true
        ..samplesCollected = true;
      expect(c.isComplete, isFalse, reason: 'sample count missing');
      c.sampleCount = 0;
      expect(c.isComplete, isFalse);
      c.sampleCount = 2;
      expect(c.isComplete, isTrue);
      c.patientIdVerified = false;
      expect(c.isComplete, isFalse);
    });

    testWidgets('complete stays disabled until the checklist is done', (tester) async {
      final calls = await pumpPanel(tester, HomeVisit.fromJson(sampleVisitJson()));
      FilledButton complete() => tester.widget<FilledButton>(find.byKey(const Key('action.complete')));
      expect(find.byKey(const Key('sampleChecklist')), findsOneWidget);
      expect(complete().onPressed, isNull);

      for (final k in ['sample.patientId', 'sample.fasting', 'sample.tubes']) {
        await tester.tap(find.byKey(Key(k)));
        await tester.pump();
      }
      await tester.enterText(find.byKey(const Key('sample.count')), '3');
      await tester.pump();
      expect(complete().onPressed, isNull, reason: '"Samples collected" not confirmed yet');

      await tester.tap(find.byKey(const Key('sample.collected')));
      await tester.pump();
      expect(complete().onPressed, isNotNull);

      await tester.tap(find.byKey(const Key('action.complete')));
      await tester.pumpAndSettle();
      final summary = tester.widget<TextFormField>(find.byKey(const Key('summaryField'))).controller!.text;
      expect(summary, startsWith('3 samples collected.'));
      await tester.tap(find.byKey(const Key('completeConfirm')));
      await tester.pumpAndSettle();
      expect(calls.single.$1, VisitActionType.complete);
      expect(calls.single.$2['summary'], summary);
    });

    testWidgets('other services complete without the checklist', (tester) async {
      await pumpPanel(tester, visit(status: VisitStatus.inProgress));
      expect(find.byKey(const Key('sampleChecklist')), findsNothing);
      expect(tester.widget<FilledButton>(find.byKey(const Key('action.complete'))).onPressed, isNotNull);
    });

    testWidgets('lab tests card: ordered tests with fasting, or the generic instruction', (tester) async {
      final withTests = HomeVisit.fromJson(sampleVisitJson(tests: [
        {'name': 'Fasting blood sugar', 'sampleType': 'blood', 'fastingRequired': true, 'fastingHours': 10},
        {'name': 'Urine routine', 'sampleType': 'urine', 'fastingRequired': false},
      ]));
      expect(withTests.fastingRequired, isTrue);
      expect(withTests.fastingHours, 10);
      expect(HomeVisit.fromJson(withTests.toJson()).labTests, hasLength(2), reason: 'survives the offline cache');
      await tester.pumpWidget(testApp(LabTestsCard(visit: withTests)));
      expect(find.text('Fasting blood sugar (blood)'), findsOneWidget);
      expect(find.byKey(const Key('fastingBanner')), findsOneWidget);
      expect(find.textContaining('10 h'), findsOneWidget);

      await tester.pumpWidget(testApp(LabTestsCard(visit: HomeVisit.fromJson(sampleVisitJson()))));
      expect(find.byKey(const Key('sampleGeneric')), findsOneWidget);
      expect(find.byKey(const Key('fastingBanner')), findsNothing);
    });
  });

  group('exercise plans (§53)', () {
    test('draft validation', () {
      final d = ExercisePlanDraft(patientId: 'p1', startDate: DateTime(2026, 9, 29));
      expect(d.validate(today), {ExercisePlanError.noExercises});
      d.items.add(ExercisePlanItemDraft(exercise));
      expect(d.validate(today), isEmpty);
      d.items.first
        ..sets = 0
        ..reps = 51
        ..holdSecs = 301
        ..perDay = 7;
      expect(d.validate(today), {
        ExercisePlanError.sets,
        ExercisePlanError.reps,
        ExercisePlanError.hold,
        ExercisePlanError.perDay,
      });
      d.items.first
        ..sets = 3
        ..reps = 10
        ..holdSecs = null
        ..perDay = 2;
      d.weeks = 0;
      d.startDate = DateTime(2026, 9, 28);
      expect(d.validate(today), {ExercisePlanError.weeks, ExercisePlanError.startDate});
      d
        ..weeks = 6
        ..startDate = DateTime(2026, 10, 1);
      expect(d.validate(today), isEmpty);
      expect(d.toJson(), {
        'patientId': 'p1',
        'items': [
          {'exerciseId': 'ex-1', 'sets': 3, 'reps': 10, 'perDay': 2},
        ],
        'startDate': '2026-10-01',
        'weeks': 6,
      });
    });

    testWidgets('form: body-area filter, validation, then POST /exercise-plans', (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);
      final log = <http.Request>[];
      final api = apiWith((req, path) async {
        if (path == '/exercise-library') {
          final area = req.url.queryParameters['bodyArea'];
          return jsonRes({'items': library.where((e) => area == null || e['bodyArea'] == area).toList(), 'nextCursor': null});
        }
        if (path == '/exercise-plans' && req.method == 'POST') return jsonRes({'id': 'plan-1'}, 201);
        return jsonRes({'items': []});
      }, log: log);
      await tester.pumpWidget(ProviderScope(
        overrides: [carePlanRepositoryProvider.overrideWithValue(CarePlanRepository(api))],
        child: testApp(
            ExercisePlanScreen(patientId: 'patient-1', careEpisodeId: 'ep-1', patientName: 'Ramesh', now: today),
            wrap: false),
      ));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('exPick.ex-2')), findsOneWidget);

      await tester.tap(find.byKey(const Key('exArea.knee')));
      await tester.pumpAndSettle();
      expect(log.any((r) => r.url.queryParameters['bodyArea'] == 'knee'), isTrue);
      expect(find.byKey(const Key('exPick.ex-2')), findsNothing);

      await tester.tap(find.byKey(const Key('exSave')));
      await tester.pumpAndSettle();
      expect(find.text('• Choose at least one exercise.'), findsOneWidget);
      expect(log.where((r) => r.method == 'POST'), isEmpty);

      await tester.tap(find.byKey(const Key('exPick.ex-1')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('exReps.ex-1')), '0');
      await tester.tap(find.byKey(const Key('exSave')));
      await tester.pumpAndSettle();
      expect(find.text('• Reps must be between 1 and 50.'), findsOneWidget);
      expect(log.where((r) => r.method == 'POST'), isEmpty);

      await tester.enterText(find.byKey(const Key('exReps.ex-1')), '12');
      await tester.enterText(find.byKey(const Key('exHold.ex-1')), '5');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('exErrors')), findsNothing);
      await tester.tap(find.byKey(const Key('exSave')));
      await tester.pumpAndSettle();
      final post = log.singleWhere((r) => r.method == 'POST');
      expect(post.headers['Idempotency-Key'], isNotEmpty);
      expect(jsonDecode(post.body), {
        'patientId': 'patient-1',
        'careEpisodeId': 'ep-1',
        'items': [
          {'exerciseId': 'ex-1', 'sets': 2, 'reps': 12, 'holdSecs': 5, 'perDay': 1},
        ],
        'startDate': '2026-09-29',
        'weeks': 4,
      });
    });
  });

  group('diet plans (§54)', () {
    test('draft validation', () {
      final d = DietPlanDraft(patientId: 'p1', validUntil: DateTime(2026, 9, 29));
      expect(d.validate(today), {DietPlanError.noMeals, DietPlanError.noConditions, DietPlanError.validUntil});
      d
        ..conditions.add('Type 2 diabetes')
        ..meals['breakfast'] = ['Idli', 'Sambar']
        ..calorieTarget = 500
        ..validUntil = DateTime(2026, 10, 29);
      expect(d.validate(today), {DietPlanError.calories});
      d.calorieTarget = 1600;
      expect(d.validate(today), isEmpty);
      expect(d.toJson()['meals'], [
        {'slot': 'breakfast', 'items': ['Idli', 'Sambar']},
      ]);
      expect(splitList(' rice, sugar ,,\njaggery '), ['rice', 'sugar', 'jaggery']);
    });

    testWidgets('form: template prefills conditions, validation, then POST /diet-plans', (tester) async {
      tester.view.physicalSize = const Size(1080, 5000);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);
      final log = <http.Request>[];
      final api = apiWith((req, path) async {
        if (path == '/diet-templates') {
          return jsonRes({
            'items': [
              {'code': 'diabetic', 'name': 'Diabetic', 'conditions': ['Type 2 diabetes'], 'status': 'fixture_unapproved'},
            ],
          });
        }
        return jsonRes({'id': 'diet-1'}, 201);
      }, log: log);
      await tester.pumpWidget(ProviderScope(
        overrides: [carePlanRepositoryProvider.overrideWithValue(CarePlanRepository(api))],
        child: testApp(DietPlanScreen(patientId: 'patient-1', now: today), wrap: false),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('dietSave')));
      await tester.pumpAndSettle();
      expect(find.text('• Add food items to at least one meal.'), findsOneWidget);
      expect(find.text('• Add at least one condition.'), findsOneWidget);
      expect(log.where((r) => r.method == 'POST'), isEmpty);

      await tester.tap(find.byKey(const Key('dietTemplate')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Diabetic').last);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('dietCond.Type 2 diabetes')), findsOneWidget);
      expect(find.byKey(const Key('dietGovernance')), findsOneWidget);

      await tester.enterText(find.byKey(const Key('dietConditionField')), 'Hypertension');
      await tester.tap(find.byKey(const Key('dietConditionAdd')));
      await tester.enterText(find.byKey(const Key('dietCalories')), '300');
      await tester.enterText(find.byKey(const Key('dietMeal.breakfast')), 'Ragi dosa, chutney');
      await tester.enterText(find.byKey(const Key('dietMeal.dinner')), 'Chapati, dal');
      await tester.enterText(find.byKey(const Key('dietAvoid')), 'sugar, fried snacks');
      await tester.pumpAndSettle();
      expect(find.text('• Calorie target must be between 800 and 4000.'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('dietCalories')), '1600');
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('dietSave')));
      await tester.pumpAndSettle();
      final post = log.singleWhere((r) => r.method == 'POST');
      expect(post.url.path, '/api/v1/diet-plans');
      expect(jsonDecode(post.body), {
        'patientId': 'patient-1',
        'templateCode': 'diabetic',
        'conditions': ['Type 2 diabetes', 'Hypertension'],
        'calorieTarget': 1600,
        'meals': [
          {'slot': 'breakfast', 'items': ['Ragi dosa', 'chutney']},
          {'slot': 'dinner', 'items': ['Chapati', 'dal']},
        ],
        'avoid': ['sugar', 'fried snacks'],
        'validUntil': '2026-10-29',
      });
    });
  });

  group('type-based visibility', () {
    test('only physiotherapists create exercise plans, only dietitians diet plans', () {
      expect(canCreateExercisePlan('physiotherapist'), isTrue);
      expect(canCreateExercisePlan('nurse'), isFalse);
      expect(canCreateExercisePlan('dietitian'), isFalse);
      expect(canCreateDietPlan('dietitian'), isTrue);
      expect(canCreateDietPlan('physiotherapist'), isFalse);
      expect(canCreateDietPlan(null), isFalse);
      expect(applicationTypes, contains('dietitian'));
    });

    Future<void> openVisit(WidgetTester tester, String type) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);
      final store = MemoryKeyValueStore();
      await store.write(StoreKeys.accessToken, 'a');
      await store.write(StoreKeys.refreshToken, 'r');
      final client = MockClient((req) async {
        final path = req.url.path.replaceFirst('/api/v1', '');
        Object? body;
        if (path == '/me') body = me(['provider']);
        if (path == '/provider/me') body = providerMe('verified')..['type'] = type;
        if (path == '/provider/visits') {
          body = {
            'items': req.url.queryParameters['scope'] == 'today' ? [visitJson(status: VisitStatus.inProgress)] : [],
            'nextCursor': null,
          };
        }
        if (path == '/home-visits/visit-1') body = visitJson(status: VisitStatus.inProgress);
        if (path == '/exercise-plans') {
          body = {
            'items': [
              {'id': 'plan-1', 'authorName': 'Priya', 'items': [{}, {}], 'startDate': '2026-09-01', 'endDate': '2026-09-29', 'status': 'active'},
            ],
          };
        }
        if (path == '/exercise-plans/plan-1/progress') {
          body = {
            'sessionsPlanned': 20,
            'sessionsDone': 15,
            'adherencePct': 75,
            'painTrend': [
              {'date': '2026-09-28', 'painScore': 3},
            ],
          };
        }
        if (body == null) return http.Response('{"error":{"code":"NOT_FOUND","message":"nf"}}', 404);
        return http.Response(jsonEncode(body), 200, headers: {'content-type': 'application/json'});
      });
      await tester.pumpWidget(ProviderScope(
        retry: (_, _) => null,
        overrides: [
          keyValueStoreProvider.overrideWithValue(store),
          httpClientProvider.overrideWithValue(client),
          connectivityProvider.overrideWithValue(FakeConnectivityService(online: true)),
          positionReaderProvider.overrideWithValue(() async => null),
        ],
        child: const ProviderApp(),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Vitals Check'));
      await tester.pumpAndSettle();
    }

    Future<void> teardown(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    }

    testWidgets('a nurse sees supplies but no plan actions', (tester) async {
      await openVisit(tester, 'nurse');
      expect(find.byKey(const Key('recordSupplies')), findsOneWidget);
      expect(find.byKey(const Key('exercisePlanCard')), findsNothing);
      expect(find.byKey(const Key('createExercisePlan')), findsNothing);
      expect(find.byKey(const Key('createDietPlan')), findsNothing);
      await teardown(tester);
    });

    testWidgets('a physiotherapist sees plan progress and "Create exercise plan"', (tester) async {
      await openVisit(tester, 'physiotherapist');
      expect(find.byKey(const Key('createExercisePlan')), findsOneWidget);
      expect(find.text('15/20 sessions · 75% adherence · latest pain 3/10'), findsOneWidget);
      expect(find.byKey(const Key('createDietPlan')), findsNothing);
      await tester.tap(find.byKey(const Key('createExercisePlan')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('exSave')), findsOneWidget);
      expect(find.text('For Ramesh Kumar'), findsOneWidget);
      await teardown(tester);
    });

    testWidgets('a dietitian sees "Create diet plan" only', (tester) async {
      await openVisit(tester, 'dietitian');
      expect(find.byKey(const Key('createDietPlan')), findsOneWidget);
      expect(find.byKey(const Key('exercisePlanCard')), findsNothing);
      await teardown(tester);
    });
  });
}
