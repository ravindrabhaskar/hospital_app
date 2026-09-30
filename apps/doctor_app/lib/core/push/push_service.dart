import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../api/api_client.dart';

/// Firebase options supplied at build time with `--dart-define`. No
/// google-services.json / GoogleService-Info.plist or Gradle plugin is needed:
/// the options are built by hand.
class FirebaseSettings {
  const FirebaseSettings({
    this.apiKey = '',
    this.appId = '',
    this.messagingSenderId = '',
    this.projectId = '',
    this.iosBundleId = '',
  });

  factory FirebaseSettings.fromEnvironment() => const FirebaseSettings(
    apiKey: String.fromEnvironment('FIREBASE_API_KEY'),
    appId: String.fromEnvironment('FIREBASE_APP_ID'),
    messagingSenderId: String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID'),
    projectId: String.fromEnvironment('FIREBASE_PROJECT_ID'),
    iosBundleId: String.fromEnvironment('FIREBASE_IOS_BUNDLE_ID', defaultValue: 'com.carecompanion.doctor'),
  );

  final String apiKey;
  final String appId;
  final String messagingSenderId;
  final String projectId;
  final String iosBundleId;

  bool get isConfigured =>
      apiKey.isNotEmpty && appId.isNotEmpty && messagingSenderId.isNotEmpty && projectId.isNotEmpty;

  FirebaseOptions toOptions() => FirebaseOptions(
    apiKey: apiKey,
    appId: appId,
    messagingSenderId: messagingSenderId,
    projectId: projectId,
    iosBundleId: iosBundleId.isEmpty ? null : iosBundleId,
  );
}

/// High-importance Android channel for care updates (new bookings, messages,
/// escalations). Also declared as the FCM default channel in
/// AndroidManifest.xml so background pushes use it. Push text never carries
/// health details (contract §12).
const careUpdatesChannel = AndroidNotificationChannel(
  'care_updates',
  'Care updates',
  description: 'New bookings, care-team messages and escalations.',
  importance: Importance.high,
);

@pragma('vm:entry-point')
Future<void> _onBackgroundMessage(RemoteMessage message) async {
  // Notification messages are displayed by the OS; nothing else to do.
  // (Firebase must be initialised in this isolate for the plugin contract.)
  final settings = FirebaseSettings.fromEnvironment();
  if (!settings.isConfigured) return;
  try {
    await Firebase.initializeApp(options: settings.toOptions());
  } catch (_) {}
}

/// FCM push for doctors (contract §12 / §24).
///
/// Initialised ONLY when the Firebase dart-defines are present; otherwise
/// every method is a silent no-op, so dev, web and test builds need no
/// credentials.
class PushService {
  PushService({required this.api, FirebaseSettings? settings})
    : settings = settings ?? FirebaseSettings.fromEnvironment();

  final ApiClient api;
  final FirebaseSettings settings;

  final _openRoute = StreamController<String>.broadcast();
  final _local = FlutterLocalNotificationsPlugin();
  bool _active = false;
  bool _signedIn = false;
  String? _registeredToken;
  StreamSubscription<String>? _tokenSub;
  final _messageSubs = <StreamSubscription<RemoteMessage>>[];

  /// True once Firebase initialised successfully.
  bool get isActive => _active;
  String? get registeredToken => _registeredToken;

  /// In-app routes to open (notification taps).
  Stream<String> get openRoute => _openRoute.stream;

  static bool get _supportedPlatform =>
      !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  /// Maps a push deep link (contract §24 `deepLink`) to an in-app route:
  /// `/appointments/<id>` -> the consultation, `/care-episodes/<id>...` -> the
  /// care-team thread, second opinions / escalations -> their lists.
  static String? routeForDeepLink(String? deepLink) {
    if (deepLink == null || deepLink.isEmpty) return null;
    final appt = RegExp(r'(?:^|/)appointments/([A-Za-z0-9_\-]+)').firstMatch(deepLink);
    if (appt != null) return '/consultation/${appt.group(1)}';
    final ep = RegExp(r'(?:^|/)care-episodes/([A-Za-z0-9_\-]+)').firstMatch(deepLink);
    if (ep != null) return '/messages/${ep.group(1)}';
    if (deepLink.contains('second-opinions')) return '/more/second-opinions';
    if (deepLink.contains('escalation') || deepLink.contains('safety')) return '/more/escalations';
    final patient = RegExp(r'(?:^|/)patients/([A-Za-z0-9_\-]+)').firstMatch(deepLink);
    if (patient != null) return '/patients/${patient.group(1)}';
    return null;
  }

  /// Returns true when push is active. Never throws.
  Future<bool> init() async {
    if (_active) return true;
    if (!settings.isConfigured || !_supportedPlatform) return false;
    try {
      // Already initialised once per process (e.g. by the all-in-one demo build).
      if (Firebase.apps.isEmpty) await Firebase.initializeApp(options: settings.toOptions());
      FirebaseMessaging.onBackgroundMessage(_onBackgroundMessage);

      await _local.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@drawable/ic_stat_notify'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
        onDidReceiveNotificationResponse: (r) => _openDeepLink(r.payload),
      );
      await _local
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(careUpdatesChannel);

      final messaging = FirebaseMessaging.instance;
      await messaging.setForegroundNotificationPresentationOptions(alert: true, badge: true, sound: true);
      _messageSubs.add(FirebaseMessaging.onMessage.listen(_showForeground));
      _messageSubs.add(FirebaseMessaging.onMessageOpenedApp.listen((m) => _openDeepLink(_deepLinkOf(m))));
      _tokenSub = messaging.onTokenRefresh.listen((token) {
        if (_signedIn) unawaited(_register(token));
      });

      _active = true;

      final initial = await messaging.getInitialMessage();
      if (initial != null) _openDeepLink(_deepLinkOf(initial));
      final launch = await _local.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp ?? false) {
        _openDeepLink(launch!.notificationResponse?.payload);
      }
      return true;
    } catch (e) {
      debugPrint('Push disabled: $e');
      _active = false;
      return false;
    }
  }

  /// After login / session restore: asks for permission and `POST /devices`.
  Future<void> registerDevice() async {
    _signedIn = true;
    if (!_active || _registeredToken != null) return;
    try {
      final messaging = FirebaseMessaging.instance;
      final perm = await messaging.requestPermission(alert: true, badge: true, sound: true);
      if (perm.authorizationStatus == AuthorizationStatus.denied) return;
      await _local
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      final token = await messaging.getToken();
      if (token != null) await _register(token);
    } catch (e) {
      debugPrint('Push registration skipped: $e');
    }
  }

  Future<void> _register(String token) async {
    try {
      await api.post(
        '/devices',
        body: {'pushToken': token, 'platform': defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android'},
      );
      _registeredToken = token;
    } catch (_) {
      // Retried on the next sign-in / token refresh.
    }
  }

  /// On logout (while the session is still valid): `DELETE /devices`.
  Future<void> unregisterDevice() async {
    _signedIn = false;
    final token = _registeredToken;
    _registeredToken = null;
    if (!_active || token == null) return;
    try {
      await api.delete('/devices', body: {'pushToken': token});
    } catch (_) {}
    try {
      await FirebaseMessaging.instance.deleteToken();
    } catch (_) {}
  }

  /// Session expired: the server already revoked device tokens with it.
  void forgetSession() {
    _signedIn = false;
    _registeredToken = null;
  }

  static String? _deepLinkOf(RemoteMessage m) => m.data['deepLink']?.toString();

  void _openDeepLink(String? deepLink) {
    final route = routeForDeepLink(deepLink);
    if (route != null && !_openRoute.isClosed) _openRoute.add(route);
  }

  /// Android does not display FCM notifications while the app is in the
  /// foreground, so show them on the high-importance channel. iOS presents
  /// them natively (see setForegroundNotificationPresentationOptions).
  Future<void> _showForeground(RemoteMessage m) async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    final title = m.notification?.title ?? m.data['title']?.toString();
    final body = m.notification?.body ?? m.data['body']?.toString();
    if (title == null && body == null) return;
    try {
      await _local.show(
        id: (m.data['notificationId'] ?? m.messageId ?? DateTime.now().toIso8601String()).hashCode & 0x7fffffff,
        title: title,
        body: body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            careUpdatesChannel.id,
            careUpdatesChannel.name,
            channelDescription: careUpdatesChannel.description,
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
        payload: _deepLinkOf(m),
      );
    } catch (_) {}
  }

  void dispose() {
    _tokenSub?.cancel();
    for (final s in _messageSubs) {
      s.cancel();
    }
    _messageSubs.clear();
    _openRoute.close();
  }
}
