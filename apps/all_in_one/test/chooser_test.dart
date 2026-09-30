import 'package:care_companion_all_in_one/chooser_screen.dart';
import 'package:care_companion_all_in_one/launcher.dart';
import 'package:care_companion_all_in_one/role_store.dart';
import 'package:care_companion_all_in_one/roles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stand-ins for the three apps: they show which app and storage prefix were
/// launched and expose the "Switch app" callback like the real Profile/More.
Map<DemoRole, AppBuilder> fakeBuilders(List<String> launches) => {
  for (final role in DemoRole.values)
    role: ({required storagePrefix, required onSwitchApp}) async {
      launches.add('${role.id}:$storagePrefix');
      return MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              Text('APP ${role.appName} [$storagePrefix]'),
              TextButton(key: const Key('switchApp'), onPressed: onSwitchApp, child: const Text('Switch app')),
            ],
          ),
        ),
      );
    },
};

/// A typical phone (360x800 dp).
void phoneSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

Future<RoleStore> freshStore([Map<String, Object> values = const {}]) async {
  SharedPreferences.setMockInitialValues(values);
  return RoleStore(await SharedPreferences.getInstance());
}

void main() {
  testWidgets('the chooser shows the three roles with their apps', (tester) async {
    phoneSize(tester);
    final store = await freshStore();
    await tester.pumpWidget(AllInOneRoot(store: store, builders: fakeBuilders([])));

    expect(find.byType(RoleCard), findsNWidgets(3));
    expect(find.text("I'm a patient / family member"), findsOneWidget);
    expect(find.text('CareCompanion'), findsOneWidget);
    expect(find.text("I'm a home-care nurse / technician"), findsOneWidget);
    expect(find.text('CareCompanion Pro'), findsOneWidget);
    expect(find.text("I'm a doctor"), findsOneWidget);
    expect(find.text('CareCompanion Doctor'), findsOneWidget);
    expect(find.text('Remember my choice'), findsOneWidget);
  });

  testWidgets('choosing a role opens that app with its own storage prefix; not remembered by default', (tester) async {
    phoneSize(tester);
    final store = await freshStore();
    final launches = <String>[];
    await tester.pumpWidget(AllInOneRoot(store: store, builders: fakeBuilders(launches)));

    await tester.tap(find.byKey(const Key('role.provider')));
    await tester.pumpAndSettle();

    expect(find.text('APP CareCompanion Pro [provider.]'), findsOneWidget);
    expect(launches, ['provider:provider.']);
    expect(store.rememberedRole, isNull);
  });

  testWidgets('"Remember my choice" is persisted and the app opens directly next time', (tester) async {
    phoneSize(tester);
    final store = await freshStore();
    await tester.pumpWidget(AllInOneRoot(store: store, builders: fakeBuilders([])));

    await tester.ensureVisible(find.byKey(const Key('rememberChoice')));
    await tester.tap(find.byKey(const Key('rememberChoice')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('role.doctor')));
    await tester.tap(find.byKey(const Key('role.doctor')));
    await tester.pumpAndSettle();

    expect(find.text('APP CareCompanion Doctor [doctor.]'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(RoleStore.rememberedRoleKey), 'doctor');

    // "Next launch": main() passes the remembered role; no chooser is shown.
    final next = RoleStore(prefs);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(AllInOneRoot(store: next, initialRole: next.rememberedRole, builders: fakeBuilders([])));
    await tester.pumpAndSettle();
    expect(find.byType(RoleChooserScreen), findsNothing);
    expect(find.text('APP CareCompanion Doctor [doctor.]'), findsOneWidget);
  });

  testWidgets('"Switch app" returns to the chooser and clears the remembered choice', (tester) async {
    phoneSize(tester);
    final store = await freshStore({RoleStore.rememberedRoleKey: 'patient'});
    final launches = <String>[];
    await tester.pumpWidget(
      AllInOneRoot(store: store, initialRole: store.rememberedRole, builders: fakeBuilders(launches)),
    );
    await tester.pumpAndSettle();
    expect(find.text('APP CareCompanion [patient.]'), findsOneWidget);

    await tester.tap(find.byKey(const Key('switchApp')));
    await tester.pumpAndSettle();

    expect(find.byType(RoleChooserScreen), findsOneWidget);
    expect(find.byType(RoleCard), findsNWidgets(3));
    expect(store.rememberedRole, isNull);
    expect((await SharedPreferences.getInstance()).containsKey(RoleStore.rememberedRoleKey), isFalse);

    // Re-opening launches a fresh instance of the app.
    await tester.tap(find.byKey(const Key('role.patient')));
    await tester.pumpAndSettle();
    expect(find.text('APP CareCompanion [patient.]'), findsOneWidget);
    expect(launches, ['patient:patient.', 'patient:patient.']);
  });

  test('each role has a distinct, non-empty storage namespace', () {
    final prefixes = DemoRole.values.map((r) => r.storagePrefix).toList();
    expect(prefixes, ['patient.', 'provider.', 'doctor.']);
    for (final a in prefixes) {
      for (final b in prefixes) {
        if (a != b) expect(a.startsWith(b), isFalse, reason: '$a must not be inside $b');
      }
    }
    expect(RoleStore.rememberedRoleKey.startsWith('patient.'), isFalse);
    expect(RoleStore.rememberedRoleKey.startsWith('provider.'), isFalse);
    expect(RoleStore.rememberedRoleKey.startsWith('doctor.'), isFalse);
  });
}
