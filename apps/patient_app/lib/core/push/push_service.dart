import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Firebase options supplied at build time through `--dart-define`:
/// FIREBASE_API_KEY, FIREBASE_APP_ID, FIREBASE_MESSAGING_SENDER_ID,
/// FIREBASE_PROJECT_ID (optional: FIREBASE_IOS_BUNDLE_ID).
///
/// No google-services.json / GoogleService-Info.plist and no Gradle
/// google-services plugin are needed: [FirebaseOptions] is built manually, and
/// when any value is missing push is skipped silently.
class PushConfig {
  const PushConfig({
    required this.apiKey,
    required this.appId,
    required this.messagingSenderId,
    required this.projectId,
    this.iosBundleId = '',
  });

  factory PushConfig.fromEnvironment() => const PushConfig(
        apiKey: String.fromEnvironment('FIREBASE_API_KEY'),
        appId: String.fromEnvironment('FIREBASE_APP_ID'),
        messagingSenderId: String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID'),
        projectId: String.fromEnvironment('FIREBASE_PROJECT_ID'),
        iosBundleId: String.fromEnvironment('FIREBASE_IOS_BUNDLE_ID'),
      );

  static const empty = PushConfig(apiKey: '', appId: '', messagingSenderId: '', projectId: '');

  final String apiKey;
  final String appId;
  final String messagingSenderId;
  final String projectId;
  final String iosBundleId;

  bool get isConfigured =>
      apiKey.isNotEmpty && appId.isNotEmpty && messagingSenderId.isNotEmpty && projectId.isNotEmpty;

  FirebaseOptions get options => FirebaseOptions(
        apiKey: apiKey,
        appId: appId,
        messagingSenderId: messagingSenderId,
        projectId: projectId,
        iosBundleId: iosBundleId.isEmpty ? null : iosBundleId,
      );
}

/// Android channels. Critical items (SOS, fall alerts, safety) get their own
/// high-importance channel so users can tune them separately.
const generalChannel = AndroidNotificationChannel(
  'cc_general',
  'Care updates',
  description: 'Appointments, visits, reminders and other care updates',
  importance: Importance.defaultImportance,
);
const criticalChannel = AndroidNotificationChannel(
  'cc_critical',
  'Critical alerts',
  description: 'Urgent safety alerts such as SOS and fall detection',
  importance: Importance.max,
);

/// Background handler for data-only messages (runs in its own isolate).
@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {
  final config = PushConfig.fromEnvironment();
  if (!config.isConfigured) return;
  try {
    if (Firebase.apps.isEmpty) await Firebase.initializeApp(options: config.options);
    // Notification messages are displayed by the OS; only data-only
    // messages need a local notification.
    if (message.notification != null) return;
    final plugin = FlutterLocalNotificationsPlugin();
    await plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );
    await _showLocal(plugin, message);
  } catch (_) {}
}

Future<void> _showLocal(FlutterLocalNotificationsPlugin plugin, RemoteMessage m) async {
  final data = m.data;
  final title = m.notification?.title ?? data['title']?.toString();
  final body = m.notification?.body ?? data['body']?.toString();
  if (title == null && body == null) return;
  final critical = '${data['critical']}' == 'true';
  final channel = critical ? criticalChannel : generalChannel;
  await plugin.show(
    id: (data['notificationId'] ?? m.messageId ?? DateTime.now().millisecondsSinceEpoch).hashCode,
    title: title,
    body: body,
    notificationDetails: NotificationDetails(
      android: AndroidNotificationDetails(
        channel.id,
        channel.name,
        channelDescription: channel.description,
        importance: channel.importance,
        priority: critical ? Priority.max : Priority.defaultPriority,
        icon: '@mipmap/ic_launcher',
      ),
      iOS: const DarwinNotificationDetails(),
    ),
    payload: data['deepLink']?.toString(),
  );
}

typedef RegisterToken = Future<void> Function(String token, String platform);
typedef UnregisterToken = Future<void> Function(String token);

/// FCM push notifications. Everything is a no-op unless [PushConfig] is
/// complete, so builds without Firebase credentials behave exactly as before.
///
/// * [init] once at startup (Firebase + local notification channels);
/// * [onSignedIn] after login: asks for permission (Android 13+ / iOS) when
///   [askPermission] allows it, then `POST /devices`; re-registers on token
///   refresh;
/// * [unregister] on logout: `DELETE /devices`;
/// * taps on notifications call [onOpenDeepLink] with the payload `deepLink`.
class PushService {
  PushService({
    required this.config,
    required RegisterToken registerToken,
    required UnregisterToken unregisterToken,
  })  : _register = registerToken,
        _unregister = unregisterToken;

  final PushConfig config;
  final RegisterToken _register;
  final UnregisterToken _unregister;

  /// Called when the user taps a notification (or the app was launched from one).
  void Function(String deepLink)? onOpenDeepLink;

  /// Asked before the OS permission prompt; return false to skip for now.
  Future<bool> Function()? askPermission;

  bool _initialized = false;
  bool _signedIn = false;
  String? _token;
  StreamSubscription<String>? _refreshSub;
  final _messageSubs = <StreamSubscription<RemoteMessage>>[];
  final _local = FlutterLocalNotificationsPlugin();

  /// Web push would need a VAPID key and service worker; not enabled.
  bool get isSupported => config.isConfigured && !kIsWeb;
  bool get isInitialized => _initialized;

  String get _platform => defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';

  /// Initialises Firebase and notification channels. Returns false (and does
  /// nothing) when push is not configured.
  Future<bool> init() async {
    if (!isSupported) return false;
    if (_initialized) return true;
    try {
      if (Firebase.apps.isEmpty) await Firebase.initializeApp(options: config.options);
      FirebaseMessaging.onBackgroundMessage(firebaseBackgroundHandler);

      await _local.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
        onDidReceiveNotificationResponse: (r) => _open(r.payload),
      );
      final android =
          _local.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await android?.createNotificationChannel(generalChannel);
      await android?.createNotificationChannel(criticalChannel);

      final messaging = FirebaseMessaging.instance;
      // iOS shows foreground notifications natively; Android uses a local one.
      await messaging.setForegroundNotificationPresentationOptions(
          alert: true, badge: true, sound: true);
      _messageSubs.add(FirebaseMessaging.onMessage.listen((m) {
        if (defaultTargetPlatform == TargetPlatform.android) _showLocal(_local, m);
      }));
      _messageSubs.add(
          FirebaseMessaging.onMessageOpenedApp.listen((m) => _open(m.data['deepLink']?.toString())));
      final initial = await messaging.getInitialMessage();
      if (initial != null) _open(initial.data['deepLink']?.toString());
      _initialized = true;
    } catch (e) {
      debugPrint('Push disabled: $e');
      _initialized = false;
    }
    return _initialized;
  }

  String? _pendingDeepLink;

  /// A deep link from a notification tapped before the user was signed in.
  String? takePendingDeepLink() {
    final l = _pendingDeepLink;
    _pendingDeepLink = null;
    return l;
  }

  void _open(String? deepLink) {
    if (deepLink == null || deepLink.isEmpty) return;
    final cb = onOpenDeepLink;
    if (cb == null || !_signedIn) {
      _pendingDeepLink = deepLink;
    } else {
      cb(deepLink);
    }
  }

  /// Registers this device for pushes after login (no-op when unconfigured).
  Future<void> onSignedIn() async {
    _signedIn = true;
    if (!_initialized) return;
    try {
      final messaging = FirebaseMessaging.instance;
      final current = await messaging.getNotificationSettings();
      var status = current.authorizationStatus;
      if (status == AuthorizationStatus.notDetermined) {
        final ok = await (askPermission?.call() ?? Future.value(true));
        if (!ok) return;
        status = (await messaging.requestPermission()).authorizationStatus;
      }
      if (status == AuthorizationStatus.denied) return;
      final token = await messaging.getToken();
      if (token != null) {
        _token = token;
        await _register(token, _platform);
      }
      _refreshSub ??= messaging.onTokenRefresh.listen((t) async {
        _token = t;
        if (_signedIn) {
          try {
            await _register(t, _platform);
          } catch (_) {}
        }
      });
    } catch (e) {
      debugPrint('Push registration failed: $e');
    }
  }

  /// Stops listening to FCM streams (the app was unmounted, e.g. by "Switch
  /// app" in the all-in-one demo build). Standalone, it lives as long as the app.
  void dispose() {
    _refreshSub?.cancel();
    _refreshSub = null;
    for (final s in _messageSubs) {
      s.cancel();
    }
    _messageSubs.clear();
  }

  /// Removes this device's token on logout (no-op when unconfigured).
  Future<void> unregister() async {
    _signedIn = false;
    if (!_initialized) return;
    final token = _token ?? await FirebaseMessaging.instance.getToken();
    if (token == null) return;
    try {
      await _unregister(token);
    } finally {
      _token = null;
    }
  }
}
