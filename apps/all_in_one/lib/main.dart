import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'launcher.dart';
import 'role_store.dart';
import 'roles.dart';
import 'shared_init.dart';

/// CareCompanion All-in-One: a DEMO build bundling the patient, provider and
/// doctor apps behind a role chooser. The stores use the separate apps.
///
/// `API_BASE_URL` and the FIREBASE_* values come from `--dart-define` and are
/// read by each bundled app exactly as in its standalone build.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initSharedServices();
  final store = RoleStore(await SharedPreferences.getInstance());
  // Health Connect opens the app on the patient app's health privacy screen
  // (MainActivity maps its intents to this route): open the patient app.
  final healthLaunch = PlatformDispatcher.instance.defaultRouteName == '/health-privacy';
  runApp(AllInOneRoot(store: store, initialRole: healthLaunch ? DemoRole.patient : store.rememberedRole));
}
