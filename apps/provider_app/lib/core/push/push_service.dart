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
        iosBundleId: String.fromEnvironment('FIREBASE_IOS_BUNDLE_ID', defaultValue: 'com.carecompanion.provider'),
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

/// High-importance Android channel for new assignments. Also declared as the
/// FCM default channel in AndroidManifest.xml so background pushes use it.
const visitAssignedChannel = AndroidNotificationChannel(
  'visit_assigned',
  'New visit assigned',
  description: 'Alerts when a home visit is assigned to you.',
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

/// FCM push for providers (contract §12 / §24).
///
/// Initialised ONLY when the Firebase dart-defines are present; otherwise
/// every method is a silent no-op, so dev, web and test builds need no
/// credentials.
class PushService {
  PushService({required this.api, FirebaseSettings? settings})
      : settings = settings ?? FirebaseSettings.fromEnvironment();

  final ApiClient api;
  final FirebaseSettings settings;

  final _openVisit = StreamController<String>.broadcast();
  final _local = FlutterLocalNotificationsPlugin();
  bool _active = false;
  bool _signedIn = false;
  String? _registeredToken;
  StreamSubscription<String>? _tokenSub;

  /// True once Firebase initialised successfully.
  bool get isActive => _active;
  String? get registeredToken => _registeredToken;

  /// Visit ids to open (notification taps).
  Stream<String> get openVisit => _openVisit.stream;

  static bool get _supportedPlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  /// Extracts a visit id from a push deep link such as
  /// `/provider/visits/<id>` or `/home-visits/<id>`.
  static String? visitIdFromDeepLink(String? deepLink) {
    if (deepLink == null) return null;
    final m = RegExp(r'(?:^|/)(?:home-visits|visits)/([A-Za-z0-9_\-]+)').firstMatch(deepLink);
    return m?.group(1);
  }

  /// Returns true when push is active. Never throws.
  Future<bool> init() async {
    if (_active) return true;
    if (!settings.isConfigured || !_supportedPlatform) return false;
    try {
      await Firebase.initializeApp(options: settings.toOptions());
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
          ?.createNotificationChannel(visitAssignedChannel);

      final messaging = FirebaseMessaging.instance;
      await messaging.setForegroundNotificationPresentationOptions(alert: true, badge: true, sound: true);
      FirebaseMessaging.onMessage.listen(_showForeground);
      FirebaseMessaging.onMessageOpenedApp.listen((m) => _openDeepLink(_deepLinkOf(m)));
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
      await api.post('/devices', body: {
        'pushToken': token,
        'platform': defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
      });
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
    final id = visitIdFromDeepLink(deepLink);
    if (id != null && !_openVisit.isClosed) _openVisit.add(id);
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
            visitAssignedChannel.id,
            visitAssignedChannel.name,
            channelDescription: visitAssignedChannel.description,
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
    _openVisit.close();
  }
}
