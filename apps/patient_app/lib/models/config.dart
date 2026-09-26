import 'json.dart';

/// Feature flags served by `GET /config/public` (API_CONTRACT §21).
///
/// The defaults mirror the seeded server values and are only used until the
/// first successful load (after that the last cached copy is used offline).
class FeatureFlags {
  const FeatureFlags({
    this.aiAssistant = true,
    this.woundAiAnalysis = false,
    this.fallDetection = true,
    this.wearables = true,
    this.pharmacyOrders = true,
    this.mentalWellness = true,
    this.govtSchemes = true, // §38: defaults on
    this.voiceInput = true,
  });

  final bool aiAssistant;
  final bool woundAiAnalysis;
  final bool fallDetection;
  final bool wearables;
  final bool pharmacyOrders;
  final bool mentalWellness;
  final bool govtSchemes;
  final bool voiceInput;

  static const defaults = FeatureFlags();

  factory FeatureFlags.fromJson(Json j) => FeatureFlags(
        aiAssistant: boolOf(j, 'ai_assistant', defaults.aiAssistant),
        woundAiAnalysis: boolOf(j, 'wound_ai_analysis', defaults.woundAiAnalysis),
        fallDetection: boolOf(j, 'fall_detection', defaults.fallDetection),
        wearables: boolOf(j, 'wearables', defaults.wearables),
        pharmacyOrders: boolOf(j, 'pharmacy_orders', defaults.pharmacyOrders),
        mentalWellness: boolOf(j, 'mental_wellness', defaults.mentalWellness),
        govtSchemes: boolOf(j, 'govt_schemes', defaults.govtSchemes),
        voiceInput: boolOf(j, 'voice_input', defaults.voiceInput),
      );

  Json toJson() => {
        'ai_assistant': aiAssistant,
        'wound_ai_analysis': woundAiAnalysis,
        'fall_detection': fallDetection,
        'wearables': wearables,
        'pharmacy_orders': pharmacyOrders,
        'mental_wellness': mentalWellness,
        'govt_schemes': govtSchemes,
        'voice_input': voiceInput,
      };
}

class SupportContact {
  const SupportContact({required this.phone, required this.email, this.whatsapp});
  final String phone;
  final String email;
  final String? whatsapp;

  bool get hasPhone => phone.trim().isNotEmpty;
  bool get hasEmail => email.trim().isNotEmpty;
  bool get hasWhatsapp => (whatsapp ?? '').trim().isNotEmpty;
}

class LegalLinks {
  const LegalLinks({required this.privacyUrl, required this.termsUrl, required this.accountDeletionUrl});
  final String privacyUrl;
  final String termsUrl;
  final String accountDeletionUrl;
}

class MinAppVersion {
  const MinAppVersion({this.patientAndroid = '0.0.0', this.patientIos = '0.0.0'});
  final String patientAndroid;
  final String patientIos;
}

/// `GET /config/public` (no auth). Clients read flags, payment gateway, push,
/// support/legal info and the minimum supported app version from here.
class PublicConfig {
  const PublicConfig({
    this.flags = FeatureFlags.defaults,
    this.paymentGateway = 'mock',
    this.razorpayKeyId,
    this.videoProvider = 'placeholder',
    this.pushEnabled = false,
    this.support = const SupportContact(phone: '', email: ''),
    this.legal = const LegalLinks(privacyUrl: '', termsUrl: '', accountDeletionUrl: ''),
    this.minAppVersion = const MinAppVersion(),
    this.raw = const {},
  });

  final FeatureFlags flags;
  final String paymentGateway;
  final String? razorpayKeyId;
  final String videoProvider;
  final bool pushEnabled;
  final SupportContact support;
  final LegalLinks legal;
  final MinAppVersion minAppVersion;

  /// The JSON this config was parsed from (cached as-is for offline use).
  final Json raw;

  static const defaults = PublicConfig();

  bool get isRazorpay => paymentGateway == 'razorpay';

  factory PublicConfig.fromJson(Json j) {
    final payment = asJson(j['payment']);
    final video = asJson(j['video']);
    final push = asJson(j['push']);
    final support = asJson(j['support']);
    final legal = asJson(j['legal']);
    final minV = asJson(j['minAppVersion']);
    return PublicConfig(
      flags: FeatureFlags.fromJson(asJson(j['flags'])),
      paymentGateway: str(payment, 'gateway', 'mock'),
      razorpayKeyId: strOrNull(payment, 'razorpayKeyId'),
      videoProvider: str(video, 'provider', 'placeholder'),
      pushEnabled: boolOf(push, 'enabled'),
      support: SupportContact(
        phone: str(support, 'phone'),
        email: str(support, 'email'),
        whatsapp: strOrNull(support, 'whatsapp'),
      ),
      legal: LegalLinks(
        privacyUrl: str(legal, 'privacyUrl'),
        termsUrl: str(legal, 'termsUrl'),
        accountDeletionUrl: str(legal, 'accountDeletionUrl'),
      ),
      minAppVersion: MinAppVersion(
        patientAndroid: str(minV, 'patientAndroid', '0.0.0'),
        patientIos: str(minV, 'patientIos', '0.0.0'),
      ),
      raw: j,
    );
  }
}

/// Compares dotted versions ("1.2.10" vs "1.2.9"). Build suffixes after `+`
/// or `-` are ignored; missing parts count as 0. Returns <0, 0 or >0.
int compareVersions(String a, String b) {
  List<int> parts(String v) => v
      .split(RegExp(r'[+\-]'))
      .first
      .split('.')
      .map((p) => int.tryParse(p.trim()) ?? 0)
      .toList();
  final x = parts(a), y = parts(b);
  final n = x.length > y.length ? x.length : y.length;
  for (var i = 0; i < n; i++) {
    final d = (i < x.length ? x[i] : 0) - (i < y.length ? y[i] : 0);
    if (d != 0) return d;
  }
  return 0;
}

/// True when [current] is older than [minimum] (blocking update required).
bool isUpdateRequired(String current, String minimum) =>
    minimum.trim().isNotEmpty && compareVersions(current, minimum) < 0;
