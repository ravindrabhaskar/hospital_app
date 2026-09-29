import 'json.dart';

/// `GET /config/public` (contract §21). Only the parts the doctor app uses
/// are modelled; unknown fields are ignored.
class PublicConfig {
  const PublicConfig({
    required this.pushEnabled,
    required this.support,
    required this.legal,
    required this.minDoctorAndroid,
    required this.minDoctorIos,
  });

  final bool pushEnabled;
  final SupportContact support;
  final LegalLinks legal;

  /// Minimum doctor-app versions. The v1.1 contract (§21) only lists patient
  /// and provider keys; the doctor app reads `doctorAndroid`/`doctorIos` when
  /// the server sends them and is otherwise never gated.
  final String? minDoctorAndroid;
  final String? minDoctorIos;

  factory PublicConfig.fromJson(Json json) {
    final min = asJson(json['minAppVersion']);
    return PublicConfig(
      pushEnabled: boolOr(asJson(json['push'])['enabled']),
      support: SupportContact.fromJson(asJson(json['support'])),
      legal: LegalLinks.fromJson(asJson(json['legal'])),
      minDoctorAndroid: _nonEmpty(min['doctorAndroid']),
      minDoctorIos: _nonEmpty(min['doctorIos']),
    );
  }

  Json toJson() => {
    'push': {'enabled': pushEnabled},
    'support': support.toJson(),
    'legal': legal.toJson(),
    'minAppVersion': {'doctorAndroid': minDoctorAndroid, 'doctorIos': minDoctorIos},
  };

  static String? _nonEmpty(Object? v) {
    final s = str(v)?.trim();
    return s == null || s.isEmpty ? null : s;
  }
}

class SupportContact {
  const SupportContact({this.phone, this.email, this.whatsapp});
  final String? phone;
  final String? email;
  final String? whatsapp;

  bool get isEmpty => phone == null && email == null && whatsapp == null;

  factory SupportContact.fromJson(Json json) => SupportContact(
    phone: PublicConfig._nonEmpty(json['phone']),
    email: PublicConfig._nonEmpty(json['email']),
    whatsapp: PublicConfig._nonEmpty(json['whatsapp']),
  );

  Json toJson() => {'phone': phone, 'email': email, 'whatsapp': whatsapp};
}

class LegalLinks {
  const LegalLinks({this.privacyUrl, this.termsUrl});
  final String? privacyUrl;
  final String? termsUrl;

  factory LegalLinks.fromJson(Json json) => LegalLinks(
    privacyUrl: PublicConfig._nonEmpty(json['privacyUrl']),
    termsUrl: PublicConfig._nonEmpty(json['termsUrl']),
  );

  Json toJson() => {'privacyUrl': privacyUrl, 'termsUrl': termsUrl};
}

/// Compares dotted versions numerically ("1.10.0" > "1.9.3"). Build suffixes
/// ("+12", "-beta") are ignored. Returns true when [current] < [minimum].
bool isVersionBelow(String current, String minimum) {
  List<int> parts(String v) =>
      v.split(RegExp(r'[+\-]')).first.split('.').map((p) => int.tryParse(p.trim()) ?? 0).toList();
  final a = parts(current);
  final b = parts(minimum);
  final len = a.length > b.length ? a.length : b.length;
  for (var i = 0; i < len; i++) {
    final x = i < a.length ? a[i] : 0;
    final y = i < b.length ? b[i] : 0;
    if (x != y) return x < y;
  }
  return false;
}
