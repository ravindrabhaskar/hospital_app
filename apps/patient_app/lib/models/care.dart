import 'json.dart';

// ---------- Address / vitals (shared) ----------

class Address {
  Address({
    required this.line1,
    this.line2,
    this.landmark,
    required this.city,
    required this.pincode,
    this.lat,
    this.lng,
  });
  final String line1;
  final String? line2;
  final String? landmark;
  final String city;
  final String pincode;
  final double? lat;
  final double? lng;

  factory Address.fromJson(Json j) => Address(
        line1: str(j, 'line1'),
        line2: strOrNull(j, 'line2'),
        landmark: strOrNull(j, 'landmark'),
        city: str(j, 'city'),
        pincode: str(j, 'pincode'),
        lat: dblOrNull(j, 'lat'),
        lng: dblOrNull(j, 'lng'),
      );

  Json toJson() => {
        'line1': line1,
        if (line2 != null && line2!.isNotEmpty) 'line2': line2,
        if (landmark != null && landmark!.isNotEmpty) 'landmark': landmark,
        'city': city,
        'pincode': pincode,
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
      };

  String get oneLine => [line1, line2, landmark, city, pincode]
      .where((e) => e != null && e.isNotEmpty)
      .join(', ');
}

class VitalType {
  VitalType._();
  static const all = [
    'bp_systolic',
    'bp_diastolic',
    'pulse',
    'spo2',
    'temperature',
    'blood_glucose',
    'weight',
    'respiratory_rate',
  ];
  static const defaultUnits = {
    'bp_systolic': 'mmHg',
    'bp_diastolic': 'mmHg',
    'pulse': 'bpm',
    'spo2': '%',
    'temperature': '°C',
    'blood_glucose': 'mg/dL',
    'weight': 'kg',
    'respiratory_rate': '/min',
  };
}

class VitalMeasurement {
  VitalMeasurement({
    required this.id,
    required this.patientId,
    required this.type,
    required this.value,
    required this.unit,
    required this.measuredAt,
    required this.source,
    required this.recordedByName,
  });
  final String id;
  final String patientId;
  final String type;
  final double value;
  final String unit;
  final DateTime measuredAt;
  final String source;
  final String? recordedByName;

  factory VitalMeasurement.fromJson(Json j) => VitalMeasurement(
        id: str(j, 'id'),
        patientId: str(j, 'patientId'),
        type: str(j, 'type'),
        value: dbl(j, 'value'),
        unit: str(j, 'unit'),
        measuredAt: dateOf(j, 'measuredAt'),
        source: str(j, 'source'),
        recordedByName: strOrNull(j, 'recordedByName'),
      );
}

// ---------- Payments ----------

/// Razorpay Standard Checkout parameters (API_CONTRACT §25). Present only
/// when the server's gateway is `razorpay`.
class RazorpayCheckout {
  RazorpayCheckout({
    required this.keyId,
    required this.orderId,
    required this.amountPaise,
    required this.currency,
    required this.name,
    required this.description,
    this.prefillContact,
    this.prefillName,
  });
  final String keyId;
  final String orderId;
  final int amountPaise;
  final String currency;
  final String name;
  final String description;
  final String? prefillContact;
  final String? prefillName;

  static RazorpayCheckout? tryParse(Object? v) {
    if (v is! Map) return null;
    final j = asJson(v);
    final keyId = str(j, 'keyId'), orderId = str(j, 'orderId');
    if (keyId.isEmpty || orderId.isEmpty) return null;
    final prefill = asJson(j['prefill']);
    return RazorpayCheckout(
      keyId: keyId,
      orderId: orderId,
      amountPaise: intOf(j, 'amountPaise'),
      currency: str(j, 'currency', 'INR'),
      name: str(j, 'name', 'CareCompanion'),
      description: str(j, 'description'),
      prefillContact: strOrNull(prefill, 'contact'),
      prefillName: strOrNull(prefill, 'name'),
    );
  }

  /// Options map for `Razorpay.open`.
  Map<String, dynamic> toOptions() => {
        'key': keyId,
        'order_id': orderId,
        'amount': amountPaise,
        'currency': currency,
        'name': name,
        'description': description,
        'prefill': {
          'contact': ?prefillContact,
          'name': ?prefillName,
        },
        'theme': {'color': '#631D3F'},
        'retry': {'enabled': false},
      };
}

class Payment {
  Payment({
    required this.id,
    required this.purpose,
    required this.refId,
    required this.patientId,
    required this.amount,
    required this.currency,
    required this.status,
    required this.gateway,
    required this.gatewayOrderId,
    required this.refundedAmount,
    required this.createdAt,
    this.checkout,
    this.discount = 0,
    this.walletUsed = 0,
  });

  /// Coupon discount applied to this payment (§60).
  final int discount;

  /// Wallet balance used (§60); [amount] is the remainder charged.
  final int walletUsed;
  final String id;
  final String purpose;
  final String refId;
  final String patientId;
  final int amount;
  final String currency;
  final String status;
  final String gateway;
  final String? gatewayOrderId;
  final int refundedAmount;
  final DateTime createdAt;
  final RazorpayCheckout? checkout;

  bool get succeeded => status == 'succeeded';
  bool get failed => status == 'failed';

  factory Payment.fromJson(Json j) => Payment(
        id: str(j, 'id'),
        purpose: str(j, 'purpose'),
        refId: str(j, 'refId'),
        patientId: str(j, 'patientId'),
        amount: intOf(j, 'amount'),
        currency: str(j, 'currency', 'INR'),
        status: str(j, 'status'),
        gateway: str(j, 'gateway'),
        gatewayOrderId: strOrNull(j, 'gatewayOrderId'),
        refundedAmount: intOf(j, 'refundedAmount'),
        createdAt: dateOf(j, 'createdAt'),
        checkout: RazorpayCheckout.tryParse(j['checkout']),
        discount: intOf(j, 'discount'),
        walletUsed: intOf(j, 'walletUsed'),
      );
}

// ---------- Appointments ----------

class Appointment {
  Appointment({
    required this.id,
    required this.patientId,
    required this.patientName,
    required this.doctorId,
    required this.doctorName,
    required this.doctorSpecialty,
    required this.doctorPhotoUrl,
    required this.startAt,
    required this.endAt,
    required this.mode,
    required this.status,
    required this.reason,
    required this.fee,
    required this.careEpisodeId,
    required this.videoRoomUrl,
    required this.clinicianNotes,
    required this.createdAt,
    this.cancelReason,
  });
  final String id;
  final String patientId;
  final String patientName;
  final String doctorId;
  final String doctorName;
  final String doctorSpecialty;
  final String? doctorPhotoUrl;
  final DateTime startAt;
  final DateTime endAt;
  final String mode;
  final String status;
  final String reason;
  final int fee;
  final String? careEpisodeId;
  final String? videoRoomUrl;
  final String? clinicianNotes;
  final DateTime? createdAt;

  /// Why it was cancelled, when the server sends it (`payment_failed` for an
  /// unpaid booking that can still be paid via a payment retry).
  final String? cancelReason;

  bool get isActive =>
      status == 'pending_payment' || status == 'confirmed' || status == 'in_progress';

  factory Appointment.fromJson(Json j) => Appointment(
        id: str(j, 'id'),
        patientId: str(j, 'patientId'),
        patientName: str(j, 'patientName'),
        doctorId: str(j, 'doctorId'),
        doctorName: str(j, 'doctorName'),
        doctorSpecialty: str(j, 'doctorSpecialty'),
        doctorPhotoUrl: strOrNull(j, 'doctorPhotoUrl'),
        startAt: dateOf(j, 'startAt'),
        endAt: dateOf(j, 'endAt'),
        mode: str(j, 'mode'),
        status: str(j, 'status'),
        reason: str(j, 'reason'),
        fee: intOf(j, 'fee'),
        careEpisodeId: strOrNull(j, 'careEpisodeId'),
        videoRoomUrl: strOrNull(j, 'videoRoomUrl'),
        clinicianNotes: strOrNull(j, 'clinicianNotes'),
        createdAt: dateOrNull(j, 'createdAt'),
        cancelReason: strOrNull(j, 'cancelReason'),
      );
}

class BookingResult<T> {
  BookingResult(this.item, this.payment);
  final T item;
  final Payment payment;
}

// ---------- Home visits ----------

class HomeVisitService {
  HomeVisitService({
    required this.code,
    required this.name,
    required this.description,
    required this.price,
    required this.durationMins,
    required this.icon,
  });
  final String code;
  final String name;
  final String description;
  final int price;
  final int durationMins;
  final String icon;

  factory HomeVisitService.fromJson(Json j) => HomeVisitService(
        code: str(j, 'code'),
        name: str(j, 'name'),
        description: str(j, 'description'),
        price: intOf(j, 'price'),
        durationMins: intOf(j, 'durationMins'),
        icon: str(j, 'icon'),
      );
}

class Serviceability {
  Serviceability({
    required this.serviceable,
    required this.zoneId,
    required this.zoneName,
    required this.message,
  });
  final bool serviceable;
  final String? zoneId;
  final String? zoneName;
  final String message;

  factory Serviceability.fromJson(Json j) => Serviceability(
        serviceable: boolOf(j, 'serviceable'),
        zoneId: strOrNull(j, 'zoneId'),
        zoneName: strOrNull(j, 'zoneName'),
        message: str(j, 'message'),
      );
}

class VisitProvider {
  VisitProvider({
    required this.id,
    required this.name,
    required this.qualification,
    required this.photoUrl,
    required this.phoneMasked,
  });
  final String id;
  final String name;
  final String qualification;
  final String? photoUrl;
  final String phoneMasked;

  factory VisitProvider.fromJson(Json j) => VisitProvider(
        id: str(j, 'id'),
        name: str(j, 'name'),
        qualification: str(j, 'qualification'),
        photoUrl: strOrNull(j, 'photoUrl'),
        phoneMasked: str(j, 'phoneMasked'),
      );
}

class VisitTimelineEntry {
  VisitTimelineEntry({required this.status, required this.at, this.note});
  final String status;
  final DateTime at;
  final String? note;

  factory VisitTimelineEntry.fromJson(Json j) => VisitTimelineEntry(
        status: str(j, 'status'),
        at: dateOf(j, 'at'),
        note: strOrNull(j, 'note'),
      );
}

class HomeVisit {
  HomeVisit({
    required this.id,
    required this.status,
    required this.serviceCode,
    required this.serviceName,
    required this.price,
    required this.patientId,
    required this.patientName,
    required this.reason,
    required this.address,
    required this.preferredStart,
    required this.preferredEnd,
    required this.careEpisodeId,
    required this.visitCode,
    required this.provider,
    required this.etaMinutes,
    required this.timeline,
    required this.vitals,
    required this.observationsNotes,
    required this.summary,
    required this.escalationReason,
    required this.createdAt,
    this.discountApplied = 0,
  });

  /// Family Care Plan discount already included in [price] (§37).
  final int discountApplied;
  final String id;
  final String status;
  final String serviceCode;
  final String serviceName;
  final int price;
  final String patientId;
  final String patientName;
  final String reason;
  final Address address;
  final DateTime preferredStart;
  final DateTime preferredEnd;
  final String? careEpisodeId;
  final String? visitCode;
  final VisitProvider? provider;
  final int? etaMinutes;
  final List<VisitTimelineEntry> timeline;
  final List<VitalMeasurement> vitals;
  final String? observationsNotes;
  final String? summary;
  final String? escalationReason;
  final DateTime? createdAt;

  static const flow = [
    'requested',
    'assigned',
    'accepted',
    'en_route',
    'arrived',
    'in_progress',
    'completed',
  ];

  bool get isTerminal => status == 'completed' || status == 'cancelled';

  factory HomeVisit.fromJson(Json j) {
    final obs = j['observations'];
    final esc = j['escalation'];
    return HomeVisit(
      id: str(j, 'id'),
      status: str(j, 'status'),
      serviceCode: str(j, 'serviceCode'),
      serviceName: str(j, 'serviceName'),
      price: intOf(j, 'price'),
      patientId: str(j, 'patientId'),
      patientName: str(j, 'patientName'),
      reason: str(j, 'reason'),
      address: Address.fromJson(asJson(j['address'])),
      preferredStart: dateOf(j, 'preferredStart'),
      preferredEnd: dateOf(j, 'preferredEnd'),
      careEpisodeId: strOrNull(j, 'careEpisodeId'),
      visitCode: strOrNull(j, 'visitCode'),
      provider: j['provider'] is Map
          ? VisitProvider.fromJson(asJson(j['provider']))
          : null,
      etaMinutes: intOrNull(j, 'etaMinutes'),
      timeline: listOf(j['timeline'], VisitTimelineEntry.fromJson),
      vitals: listOf(j['vitals'], VitalMeasurement.fromJson),
      observationsNotes: obs is Map ? strOrNull(asJson(obs), 'notes') : null,
      summary: strOrNull(j, 'summary'),
      escalationReason: esc is Map ? strOrNull(asJson(esc), 'reason') : null,
      createdAt: dateOrNull(j, 'createdAt'),
      discountApplied: intOf(j, 'discountApplied'),
    );
  }
}

// ---------- Care plans, tasks, medications, reminders ----------

class CareTask {
  CareTask({
    required this.id,
    required this.carePlanId,
    required this.patientId,
    required this.type,
    required this.title,
    required this.description,
    required this.dueAt,
    required this.owner,
    required this.status,
    required this.completedAt,
    required this.completedByName,
  });
  final String id;
  final String carePlanId;
  final String patientId;
  final String type;
  final String title;
  final String? description;
  final DateTime? dueAt;
  final String owner;
  final String status;
  final DateTime? completedAt;
  final String? completedByName;

  bool get isOpen => status == 'open' || status == 'overdue';

  factory CareTask.fromJson(Json j) => CareTask(
        id: str(j, 'id'),
        carePlanId: str(j, 'carePlanId'),
        patientId: str(j, 'patientId'),
        type: str(j, 'type'),
        title: str(j, 'title'),
        description: strOrNull(j, 'description'),
        dueAt: dateOrNull(j, 'dueAt'),
        owner: str(j, 'owner'),
        status: str(j, 'status'),
        completedAt: dateOrNull(j, 'completedAt'),
        completedByName: strOrNull(j, 'completedByName'),
      );
}

class DoseToday {
  DoseToday({required this.time, required this.scheduledAt, required this.status});
  final String time;
  final String scheduledAt;
  final String status;

  factory DoseToday.fromJson(Json j) => DoseToday(
        time: str(j, 'time'),
        scheduledAt: str(j, 'scheduledAt'),
        status: str(j, 'status'),
      );
}

class Medication {
  Medication({
    required this.id,
    required this.patientId,
    required this.name,
    required this.dose,
    required this.frequency,
    required this.times,
    required this.startDate,
    required this.endDate,
    required this.instructions,
    required this.source,
    required this.prescribedByName,
    required this.active,
    required this.today,
    this.createdAt,
  });
  final String id;
  final String patientId;
  final String name;
  final String dose;
  final String frequency;
  final List<String> times;
  final String startDate;
  final String? endDate;
  final String? instructions;
  final String source;
  final String? prescribedByName;
  final bool active;
  final List<DoseToday> today;

  /// When the medicine was added (if the server sends it).
  final DateTime? createdAt;

  factory Medication.fromJson(Json j) => Medication(
        id: str(j, 'id'),
        patientId: str(j, 'patientId'),
        name: str(j, 'name'),
        dose: str(j, 'dose'),
        frequency: str(j, 'frequency'),
        times: strList(j, 'times'),
        startDate: str(j, 'startDate'),
        endDate: strOrNull(j, 'endDate'),
        instructions: strOrNull(j, 'instructions'),
        source: str(j, 'source'),
        prescribedByName: strOrNull(j, 'prescribedByName'),
        active: boolOf(j, 'active', true),
        today: listOf(j['today'], DoseToday.fromJson),
        createdAt: dateOrNull(j, 'createdAt'),
      );
}

class DoseLog {
  DoseLog({
    required this.id,
    required this.medicationId,
    required this.scheduledAt,
    required this.status,
    required this.loggedAt,
  });
  final String id;
  final String medicationId;
  final String scheduledAt;
  final String status;
  final DateTime? loggedAt;

  factory DoseLog.fromJson(Json j) => DoseLog(
        id: str(j, 'id'),
        medicationId: str(j, 'medicationId'),
        scheduledAt: str(j, 'scheduledAt'),
        status: str(j, 'status'),
        loggedAt: dateOrNull(j, 'loggedAt'),
      );
}

class CarePlan {
  CarePlan({
    required this.id,
    required this.careEpisodeId,
    required this.patientId,
    required this.doctorId,
    required this.doctorName,
    required this.status,
    required this.summary,
    required this.instructions,
    required this.tasks,
    required this.medications,
    required this.followUpDueAt,
    required this.createdAt,
  });
  final String id;
  final String careEpisodeId;
  final String patientId;
  final String doctorId;
  final String doctorName;
  final String status;
  final String summary;
  final String instructions;
  final List<CareTask> tasks;
  final List<Medication> medications;
  final DateTime? followUpDueAt;
  final DateTime? createdAt;

  factory CarePlan.fromJson(Json j) => CarePlan(
        id: str(j, 'id'),
        careEpisodeId: str(j, 'careEpisodeId'),
        patientId: str(j, 'patientId'),
        doctorId: str(j, 'doctorId'),
        doctorName: str(j, 'doctorName'),
        status: str(j, 'status'),
        summary: str(j, 'summary'),
        instructions: str(j, 'instructions'),
        tasks: listOf(j['tasks'], CareTask.fromJson),
        medications: listOf(j['medications'], Medication.fromJson),
        followUpDueAt: dateOrNull(j, 'followUpDueAt'),
        createdAt: dateOrNull(j, 'createdAt'),
      );
}

class Reminder {
  Reminder({
    required this.id,
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.at,
    required this.status,
    required this.refId,
  });
  final String id;
  final String kind;
  final String title;
  final String? subtitle;
  final DateTime at;
  final String status;
  final String refId;

  factory Reminder.fromJson(Json j) => Reminder(
        id: str(j, 'id'),
        kind: str(j, 'kind'),
        title: str(j, 'title'),
        subtitle: strOrNull(j, 'subtitle'),
        at: dateOf(j, 'at'),
        status: str(j, 'status'),
        refId: str(j, 'refId'),
      );
}

// ---------- Care episodes ----------

class EpisodeStatus {
  EpisodeStatus._();
  static const happyPath = [
    'NEW',
    'INTAKE',
    'AWAITING_CARE',
    'CARE_SCHEDULED',
    'UNDER_CARE',
    'FOLLOW_UP',
    'RESOLVED',
  ];
  static const exceptional = ['ESCALATED', 'EMERGENCY', 'TRANSFERRED', 'CANCELLED'];
}

class CareEpisode {
  CareEpisode({
    required this.id,
    required this.patientId,
    required this.patientName,
    required this.title,
    required this.concern,
    required this.status,
    required this.priority,
    required this.ownerUserId,
    required this.ownerName,
    required this.nextAction,
    required this.createdAt,
    required this.updatedAt,
  });
  final String id;
  final String patientId;
  final String patientName;
  final String title;
  final String concern;
  final String status;
  final String priority;
  final String? ownerUserId;
  final String? ownerName;
  final String? nextAction;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory CareEpisode.fromJson(Json j) => CareEpisode(
        id: str(j, 'id'),
        patientId: str(j, 'patientId'),
        patientName: str(j, 'patientName'),
        title: str(j, 'title'),
        concern: str(j, 'concern'),
        status: str(j, 'status'),
        priority: str(j, 'priority', 'routine'),
        ownerUserId: strOrNull(j, 'ownerUserId'),
        ownerName: strOrNull(j, 'ownerName'),
        nextAction: strOrNull(j, 'nextAction'),
        createdAt: dateOf(j, 'createdAt'),
        updatedAt: dateOf(j, 'updatedAt'),
      );
}

class EpisodeEvent {
  EpisodeEvent({
    required this.id,
    required this.type,
    required this.description,
    required this.actorName,
    required this.actorRole,
    required this.data,
    required this.createdAt,
  });
  final String id;
  final String type;
  final String description;
  final String? actorName;
  final String? actorRole;
  final Json data;
  final DateTime createdAt;

  factory EpisodeEvent.fromJson(Json j) => EpisodeEvent(
        id: str(j, 'id'),
        type: str(j, 'type'),
        description: str(j, 'description'),
        actorName: strOrNull(j, 'actorName'),
        actorRole: strOrNull(j, 'actorRole'),
        data: asJson(j['data']),
        createdAt: dateOf(j, 'createdAt'),
      );
}

class SafetyEvent {
  SafetyEvent({
    required this.id,
    required this.level,
    required this.source,
    required this.status,
    required this.createdAt,
    required this.ruleTitles,
  });
  final String id;
  final String level;
  final String source;
  final String status;
  final DateTime createdAt;
  final List<String> ruleTitles;

  factory SafetyEvent.fromJson(Json j) => SafetyEvent(
        id: str(j, 'id'),
        level: str(j, 'level'),
        source: str(j, 'source'),
        status: str(j, 'status'),
        createdAt: dateOf(j, 'createdAt'),
        ruleTitles: listOf(j['rules'], (r) => str(r, 'title')),
      );
}

class CareEpisodeDetail {
  CareEpisodeDetail({
    required this.episode,
    required this.events,
    required this.appointments,
    required this.homeVisits,
    required this.carePlans,
    required this.safetyEvents,
  });
  final CareEpisode episode;
  final List<EpisodeEvent> events;
  final List<Appointment> appointments;
  final List<HomeVisit> homeVisits;
  final List<CarePlan> carePlans;
  final List<SafetyEvent> safetyEvents;

  factory CareEpisodeDetail.fromJson(Json j) => CareEpisodeDetail(
        episode: CareEpisode.fromJson(j),
        events: listOf(j['events'], EpisodeEvent.fromJson),
        appointments: listOf(j['appointments'], Appointment.fromJson),
        homeVisits: listOf(j['homeVisits'], HomeVisit.fromJson),
        carePlans: listOf(j['carePlans'], CarePlan.fromJson),
        safetyEvents: listOf(j['safetyEvents'], SafetyEvent.fromJson),
      );
}

// ---------- Video consultation (API_CONTRACT §26) ----------

class VideoSession {
  VideoSession({
    required this.provider,
    required this.joinUrl,
    required this.roomName,
    required this.token,
    required this.opensAt,
    required this.expiresAt,
  });
  final String provider;
  final String joinUrl;
  final String roomName;
  final String? token;
  final DateTime? opensAt;
  final DateTime? expiresAt;

  factory VideoSession.fromJson(Json j) => VideoSession(
        provider: str(j, 'provider', 'placeholder'),
        joinUrl: str(j, 'joinUrl'),
        roomName: str(j, 'roomName'),
        token: strOrNull(j, 'token'),
        opensAt: dateOrNull(j, 'opensAt'),
        expiresAt: dateOrNull(j, 'expiresAt'),
      );
}

enum JoinWindowState { tooEarly, open, closed }

/// The join window of a video/audio consultation: from 10 minutes before
/// `startAt` until 60 minutes after `endAt` (server-enforced; this mirrors
/// it for the button state and countdown).
class JoinWindow {
  const JoinWindow(this.opensAt, this.closesAt);

  factory JoinWindow.forAppointment(DateTime startAt, DateTime endAt) =>
      JoinWindow(startAt.subtract(openBefore), endAt.add(closeAfter));

  static const openBefore = Duration(minutes: 10);
  static const closeAfter = Duration(minutes: 60);

  final DateTime opensAt;
  final DateTime closesAt;

  JoinWindowState stateAt(DateTime now) {
    if (now.isBefore(opensAt)) return JoinWindowState.tooEarly;
    if (now.isAfter(closesAt)) return JoinWindowState.closed;
    return JoinWindowState.open;
  }

  Duration untilOpen(DateTime now) =>
      now.isBefore(opensAt) ? opensAt.difference(now) : Duration.zero;
}

/// Whether an appointment is a remote consultation that can be joined.
bool isJoinableAppointment(Appointment a) =>
    (a.mode == 'video' || a.mode == 'audio') &&
    (a.status == 'confirmed' || a.status == 'in_progress');
