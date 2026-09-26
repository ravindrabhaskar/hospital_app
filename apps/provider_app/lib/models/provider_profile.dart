import 'json.dart';

/// `GET /provider/me` (API contract §17).
class ProviderProfile {
  const ProviderProfile({
    required this.id,
    required this.name,
    required this.type,
    required this.qualification,
    required this.verificationStatus,
    required this.credentialExpiresAt,
    required this.onDuty,
    required this.zones,
    required this.capabilities,
    this.photoUrl,
    this.rating,
    this.ratingCount,
  });

  final String id;
  final String name;

  /// nurse | technician | intern | physiotherapist
  final String type;
  final String qualification;

  /// pending | verified | rejected | suspended | expired
  final String verificationStatus;
  final DateTime? credentialExpiresAt;
  final bool onDuty;
  final List<ProviderZone> zones;
  final List<String> capabilities;

  /// Not part of the §17 `/provider/me` shape. Read only if the server sends
  /// them (photo via §29, rating recalculated by §33 moderation); otherwise
  /// null and the UI hides them.
  final String? photoUrl;
  final num? rating;
  final int? ratingCount;

  bool get isVerified => verificationStatus == 'verified';

  /// Days until the credential expires (negative once expired), or null.
  int? daysUntilCredentialExpiry(DateTime now) {
    final exp = credentialExpiresAt;
    if (exp == null) return null;
    return exp.difference(now).inHours ~/ 24;
  }

  /// Warn when fewer than 30 days remain.
  bool credentialExpiringSoon(DateTime now) {
    final days = daysUntilCredentialExpiry(now);
    return days != null && days >= 0 && days < 30;
  }

  ProviderProfile copyWith({bool? onDuty}) => ProviderProfile(
        id: id,
        name: name,
        type: type,
        qualification: qualification,
        verificationStatus: verificationStatus,
        credentialExpiresAt: credentialExpiresAt,
        onDuty: onDuty ?? this.onDuty,
        zones: zones,
        capabilities: capabilities,
        photoUrl: photoUrl,
        rating: rating,
        ratingCount: ratingCount,
      );

  factory ProviderProfile.fromJson(Json json) => ProviderProfile(
        id: strOr(json['id']),
        name: strOr(json['name']),
        type: strOr(json['type']),
        qualification: strOr(json['qualification']),
        verificationStatus: strOr(json['verificationStatus'], 'pending'),
        credentialExpiresAt: dateOrNull(json['credentialExpiresAt']),
        onDuty: boolOr(json['onDuty']),
        zones: jsonList(json['zones']).map(ProviderZone.fromJson).toList(),
        capabilities: stringList(json['capabilities']),
        photoUrl: str(json['photoUrl']),
        rating: numOrNull(json['rating']),
        ratingCount: intOrNull(json['ratingCount']),
      );

  Json toJson() => {
        'id': id,
        'name': name,
        'type': type,
        'qualification': qualification,
        'verificationStatus': verificationStatus,
        'credentialExpiresAt': credentialExpiresAt?.toUtc().toIso8601String(),
        'onDuty': onDuty,
        'zones': zones.map((z) => z.toJson()).toList(),
        'capabilities': capabilities,
        'photoUrl': photoUrl,
        'rating': rating,
        'ratingCount': ratingCount,
      };
}

class ProviderZone {
  const ProviderZone({required this.id, required this.name});
  final String id;
  final String name;

  factory ProviderZone.fromJson(Json json) =>
      ProviderZone(id: strOr(json['id']), name: strOr(json['name']));

  Json toJson() => {'id': id, 'name': name};
}
