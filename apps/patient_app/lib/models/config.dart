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
    this.labTests = true,
    this.carePrograms = true,
    this.secondOpinion = true,
    this.insurance = true,
    this.preventiveCare = true,
    this.exercisePlans = true,
    this.dietPlans = true,
    this.dailyCheckin = true,
    this.whatsappAssistant = true,
    this.ambulanceBooking = true,
    this.dementiaSafety = true,
    this.walletOffers = true,
    this.supportDesk = true,
    this.abdm = true,
  });

  final bool aiAssistant;
  final bool woundAiAnalysis;
  final bool fallDetection;
  final bool wearables;
  final bool pharmacyOrders;
  final bool mentalWellness;
  final bool govtSchemes;
  final bool voiceInput;

  // v1.3 (§41–§61). The contract defines no flags for these; the app reads
  // optional keys when the server sends them and otherwise treats them as on.
  final bool labTests;
  final bool carePrograms;
  final bool secondOpinion;
  final bool insurance;
  final bool preventiveCare;
  final bool exercisePlans;
  final bool dietPlans;
  final bool dailyCheckin;
  final bool whatsappAssistant;
  final bool ambulanceBooking;
  final bool dementiaSafety;
  final bool walletOffers;
  final bool supportDesk;
  final bool abdm;

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
        labTests: boolOf(j, 'lab_tests', defaults.labTests),
        carePrograms: boolOf(j, 'care_programs', defaults.carePrograms),
        secondOpinion: boolOf(j, 'second_opinion', defaults.secondOpinion),
        insurance: boolOf(j, 'insurance', defaults.insurance),
        preventiveCare: boolOf(j, 'preventive_care', defaults.preventiveCare),
        exercisePlans: boolOf(j, 'exercise_plans', defaults.exercisePlans),
        dietPlans: boolOf(j, 'diet_plans', defaults.dietPlans),
        dailyCheckin: boolOf(j, 'daily_checkin', defaults.dailyCheckin),
        whatsappAssistant: boolOf(j, 'whatsapp_assistant', defaults.whatsappAssistant),
        ambulanceBooking: boolOf(j, 'ambulance_booking', defaults.ambulanceBooking),
        dementiaSafety: boolOf(j, 'dementia_safety', defaults.dementiaSafety),
        walletOffers: boolOf(j, 'wallet_invites', boolOf(j, 'wallet_offers', defaults.walletOffers)),
        supportDesk: boolOf(j, 'support_desk', defaults.supportDesk),
        abdm: boolOf(j, 'abdm', defaults.abdm),
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
        'lab_tests': labTests,
        'care_programs': carePrograms,
        'second_opinion': secondOpinion,
        'insurance': insurance,
        'preventive_care': preventiveCare,
        'exercise_plans': exercisePlans,
        'diet_plans': dietPlans,
        'daily_checkin': dailyCheckin,
        'whatsapp_assistant': whatsappAssistant,
        'ambulance_booking': ambulanceBooking,
        'dementia_safety': dementiaSafety,
        'wallet_invites': walletOffers,
        'support_desk': supportDesk,
        'abdm': abdm,
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

/// Hospital white-label branding (§58), present when the app was built with
/// `--dart-define=TENANT_CODE=...` and the server knows that tenant.
class Branding {
  const Branding({
    required this.tenantCode,
    required this.displayName,
    required this.logoUrl,
    required this.primaryColor,
    required this.supportPhone,
    required this.supportEmail,
  });
  final String tenantCode;
  final String displayName;
  final String? logoUrl;

  /// "#RRGGBB" as sent by the server.
  final String? primaryColor;
  final String? supportPhone;
  final String? supportEmail;

  /// The parsed primary colour (opaque), or null when missing/malformed.
  int? get primaryArgb => parseHexColor(primaryColor);

  static Branding? tryParse(Object? v) {
    if (v is! Map) return null;
    final j = asJson(v);
    final code = str(j, 'tenantCode');
    final name = str(j, 'displayName');
    if (code.isEmpty && name.isEmpty) return null;
    return Branding(
      tenantCode: code,
      displayName: name,
      logoUrl: strOrNull(j, 'logoUrl'),
      primaryColor: strOrNull(j, 'primaryColor'),
      supportPhone: strOrNull(j, 'supportPhone'),
      supportEmail: strOrNull(j, 'supportEmail'),
    );
  }
}

/// Parses "#RRGGBB" (or "RRGGBB") into an opaque ARGB int.
int? parseHexColor(String? hex) {
  if (hex == null) return null;
  final h = hex.trim().replaceFirst('#', '');
  if (!RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(h)) return null;
  return 0xFF000000 | int.parse(h, radix: 16);
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
    this.branding,
  });

  /// White-label branding (§58); null for the default CareCompanion app.
  final Branding? branding;

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
    final branding = Branding.tryParse(j['branding']);
    String? nonEmpty(String? v) => v == null || v.trim().isEmpty ? null : v;
    return PublicConfig(
      branding: branding,
      flags: FeatureFlags.fromJson(asJson(j['flags'])),
      paymentGateway: str(payment, 'gateway', 'mock'),
      razorpayKeyId: strOrNull(payment, 'razorpayKeyId'),
      videoProvider: str(video, 'provider', 'placeholder'),
      pushEnabled: boolOf(push, 'enabled'),
      support: SupportContact(
        // A tenant's own support line wins over the platform default.
        phone: nonEmpty(branding?.supportPhone) ?? str(support, 'phone'),
        email: nonEmpty(branding?.supportEmail) ?? str(support, 'email'),
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
