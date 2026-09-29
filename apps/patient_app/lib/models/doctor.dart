import 'json.dart';

class Specialty {
  Specialty({required this.code, required this.name, required this.icon});
  final String code;
  final String name;
  final String icon;

  factory Specialty.fromJson(Json j) => Specialty(
        code: str(j, 'code'),
        name: str(j, 'name'),
        icon: str(j, 'icon'),
      );
}

class DoctorFees {
  DoctorFees({
    required this.video,
    required this.audio,
    required this.chat,
    required this.inClinic,
  });
  final int video;
  final int audio;
  final int chat;
  final int inClinic;

  int forMode(String mode) {
    switch (mode) {
      case 'audio':
        return audio;
      case 'chat':
        return chat;
      case 'in_clinic':
        return inClinic;
      default:
        return video;
    }
  }

  factory DoctorFees.fromJson(Json j) => DoctorFees(
        video: intOf(j, 'video'),
        audio: intOf(j, 'audio'),
        chat: intOf(j, 'chat'),
        inClinic: intOf(j, 'inClinic'),
      );
}

class FacilityRef {
  FacilityRef({required this.id, required this.name, required this.area});
  final String id;
  final String name;
  final String area;

  factory FacilityRef.fromJson(Json j) =>
      FacilityRef(id: str(j, 'id'), name: str(j, 'name'), area: str(j, 'area'));
}

class Doctor {
  Doctor({
    required this.id,
    required this.name,
    required this.specialty,
    required this.specialtyName,
    required this.qualifications,
    required this.experienceYears,
    required this.rating,
    required this.ratingCount,
    required this.languages,
    required this.fees,
    required this.photoUrl,
    required this.verified,
    required this.nextAvailableAt,
    required this.availableNow,
    required this.facility,
    required this.rankingFactors,
  });

  final String id;
  final String name;
  final String specialty;
  final String specialtyName;
  final String qualifications;
  final int experienceYears;
  final double rating;
  final int ratingCount;
  final List<String> languages;
  final DoctorFees fees;
  final String? photoUrl;
  final bool verified;
  final DateTime? nextAvailableAt;
  final bool availableNow;
  final FacilityRef? facility;
  final List<String> rankingFactors;

  factory Doctor.fromJson(Json j) => Doctor(
        id: str(j, 'id'),
        name: str(j, 'name'),
        specialty: str(j, 'specialty'),
        specialtyName: str(j, 'specialtyName'),
        qualifications: str(j, 'qualifications'),
        experienceYears: intOf(j, 'experienceYears'),
        rating: dbl(j, 'rating'),
        ratingCount: intOf(j, 'ratingCount'),
        languages: strList(j, 'languages'),
        fees: DoctorFees.fromJson(asJson(j['fees'])),
        photoUrl: strOrNull(j, 'photoUrl'),
        verified: boolOf(j, 'verified', true),
        nextAvailableAt: dateOrNull(j, 'nextAvailableAt'),
        availableNow: boolOf(j, 'availableNow'),
        facility:
            j['facility'] is Map ? FacilityRef.fromJson(asJson(j['facility'])) : null,
        rankingFactors: strList(j, 'rankingFactors'),
      );
}

class Review {
  Review({
    required this.id,
    required this.rating,
    required this.text,
    required this.authorLabel,
    required this.source,
    required this.createdAt,
  });
  final String id;
  final double rating;
  final String text;
  final String authorLabel;
  final String source;
  final DateTime? createdAt;

  factory Review.fromJson(Json j) => Review(
        id: str(j, 'id'),
        rating: dbl(j, 'rating'),
        text: str(j, 'text'),
        authorLabel: str(j, 'authorLabel'),
        source: str(j, 'source'),
        createdAt: dateOrNull(j, 'createdAt'),
      );
}

class DoctorDetail {
  DoctorDetail({
    required this.doctor,
    required this.bio,
    required this.registrationNumber,
    required this.reviews,
  });
  final Doctor doctor;
  final String bio;
  final String registrationNumber;
  final List<Review> reviews;

  factory DoctorDetail.fromJson(Json j) => DoctorDetail(
        doctor: Doctor.fromJson(j),
        bio: str(j, 'bio'),
        registrationNumber: str(j, 'registrationNumber'),
        reviews: listOf(j['reviews'], Review.fromJson),
      );
}

class Slot {
  Slot({
    required this.id,
    required this.startAt,
    required this.endAt,
    required this.status,
  });
  final String id;
  final DateTime startAt;
  final DateTime endAt;
  final String status;

  bool get isAvailable => status == 'available';

  factory Slot.fromJson(Json j) => Slot(
        id: str(j, 'id'),
        startAt: dateOf(j, 'startAt'),
        endAt: dateOf(j, 'endAt'),
        status: str(j, 'status'),
      );
}

class Facility {
  Facility({
    required this.id,
    required this.name,
    required this.type,
    required this.address,
    required this.area,
    required this.city,
    required this.phone,
    required this.lat,
    required this.lng,
    required this.distanceKm,
    required this.services,
    required this.emergency24x7,
    required this.verified,
    this.cashlessInsurers = const [],
  });

  /// Insurer codes with cashless tie-ups (§51).
  final List<String> cashlessInsurers;
  final String id;
  final String name;
  final String type;
  final String address;
  final String area;
  final String city;
  final String phone;
  final double? lat;
  final double? lng;
  final double? distanceKm;
  final List<String> services;
  final bool emergency24x7;
  final bool verified;

  factory Facility.fromJson(Json j) => Facility(
        id: str(j, 'id'),
        name: str(j, 'name'),
        type: str(j, 'type'),
        address: str(j, 'address'),
        area: str(j, 'area'),
        city: str(j, 'city'),
        phone: str(j, 'phone'),
        lat: dblOrNull(j, 'lat'),
        lng: dblOrNull(j, 'lng'),
        distanceKm: dblOrNull(j, 'distanceKm'),
        services: strList(j, 'services'),
        emergency24x7: boolOf(j, 'emergency24x7'),
        verified: boolOf(j, 'verified'),
        cashlessInsurers: strList(j, 'cashlessInsurers'),
      );
}
