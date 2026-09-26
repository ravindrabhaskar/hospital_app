import 'ai.dart';
import 'doctor.dart';
import 'json.dart';

// ---------- Notifications ----------

class AppNotification {
  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.category,
    required this.critical,
    required this.read,
    required this.deepLink,
    required this.createdAt,
  });
  final String id;
  final String title;
  final String body;
  final String category;
  final bool critical;
  final bool read;
  final String? deepLink;
  final DateTime createdAt;

  factory AppNotification.fromJson(Json j) => AppNotification(
        id: str(j, 'id'),
        title: str(j, 'title'),
        body: str(j, 'body'),
        category: str(j, 'category', 'system'),
        critical: boolOf(j, 'critical'),
        read: boolOf(j, 'read'),
        deepLink: strOrNull(j, 'deepLink'),
        createdAt: dateOf(j, 'createdAt'),
      );
}

class NotificationPage {
  NotificationPage(this.items, this.unreadCount, {this.nextCursor});
  final List<AppNotification> items;
  final int unreadCount;
  final String? nextCursor;
}

class NotificationPreferences {
  NotificationPreferences({
    required this.push,
    required this.sms,
    required this.email,
    required this.whatsapp,
    required this.marketing,
  });
  final bool push;
  final bool sms;
  final bool email;
  final bool whatsapp;
  final bool marketing;

  factory NotificationPreferences.fromJson(Json j) => NotificationPreferences(
        push: boolOf(j, 'push'),
        sms: boolOf(j, 'sms'),
        email: boolOf(j, 'email'),
        whatsapp: boolOf(j, 'whatsapp'),
        marketing: boolOf(j, 'marketing'),
      );

  Json toJson() => {
        'push': push,
        'sms': sms,
        'email': email,
        'whatsapp': whatsapp,
        'marketing': marketing,
      };

  NotificationPreferences copyWith(String key, bool v) => NotificationPreferences(
        push: key == 'push' ? v : push,
        sms: key == 'sms' ? v : sms,
        email: key == 'email' ? v : email,
        whatsapp: key == 'whatsapp' ? v : whatsapp,
        marketing: key == 'marketing' ? v : marketing,
      );
}

// ---------- Pharmacy ----------

class PharmacyCategory {
  PharmacyCategory({required this.code, required this.name, required this.icon});
  final String code;
  final String name;
  final String icon;

  factory PharmacyCategory.fromJson(Json j) =>
      PharmacyCategory(code: str(j, 'code'), name: str(j, 'name'), icon: str(j, 'icon'));
}

class Product {
  Product({
    required this.id,
    required this.name,
    required this.packSize,
    required this.mrp,
    required this.price,
    required this.category,
    required this.requiresPrescription,
    required this.imageUrl,
    required this.inStock,
  });
  final String id;
  final String name;
  final String packSize;
  final int mrp;
  final int price;
  final String category;
  final bool requiresPrescription;
  final String? imageUrl;
  final bool inStock;

  factory Product.fromJson(Json j) => Product(
        id: str(j, 'id'),
        name: str(j, 'name'),
        packSize: str(j, 'packSize'),
        mrp: intOf(j, 'mrp'),
        price: intOf(j, 'price'),
        category: str(j, 'category'),
        requiresPrescription: boolOf(j, 'requiresPrescription'),
        imageUrl: strOrNull(j, 'imageUrl'),
        inStock: boolOf(j, 'inStock', true),
      );
}

class OrderItem {
  OrderItem({required this.productId, required this.name, required this.qty, required this.price});
  final String productId;
  final String name;
  final int qty;
  final int price;

  factory OrderItem.fromJson(Json j) => OrderItem(
        productId: str(j, 'productId'),
        name: str(j, 'name'),
        qty: intOf(j, 'qty'),
        price: intOf(j, 'price'),
      );
}

class PharmacyOrder {
  PharmacyOrder({
    required this.id,
    required this.patientId,
    required this.items,
    required this.total,
    required this.status,
    required this.partnerName,
    required this.createdAt,
  });
  final String id;
  final String patientId;
  final List<OrderItem> items;
  final int total;
  final String status;
  final String partnerName;
  final DateTime createdAt;

  factory PharmacyOrder.fromJson(Json j) => PharmacyOrder(
        id: str(j, 'id'),
        patientId: str(j, 'patientId'),
        items: listOf(j['items'], OrderItem.fromJson),
        total: intOf(j, 'total'),
        status: str(j, 'status'),
        partnerName: str(j, 'partnerName'),
        createdAt: dateOf(j, 'createdAt'),
      );
}

// ---------- Wellness ----------

class WellnessActivity {
  WellnessActivity({
    required this.code,
    required this.title,
    required this.description,
    required this.durationMins,
    required this.kind,
  });
  final String code;
  final String title;
  final String description;
  final int durationMins;
  final String kind;

  factory WellnessActivity.fromJson(Json j) => WellnessActivity(
        code: str(j, 'code'),
        title: str(j, 'title'),
        description: str(j, 'description'),
        durationMins: intOf(j, 'durationMins'),
        kind: str(j, 'kind'),
      );
}

class MoodEntry {
  MoodEntry({
    required this.id,
    required this.patientId,
    required this.score,
    required this.note,
    required this.shareWithClinician,
    required this.createdAt,
  });
  final String id;
  final String patientId;
  final int score;
  final String? note;
  final bool shareWithClinician;
  final DateTime createdAt;

  factory MoodEntry.fromJson(Json j) => MoodEntry(
        id: str(j, 'id'),
        patientId: str(j, 'patientId'),
        score: intOf(j, 'score', 3),
        note: strOrNull(j, 'note'),
        shareWithClinician: boolOf(j, 'shareWithClinician'),
        createdAt: dateOf(j, 'createdAt'),
      );
}

/// `MoodEntry + { supportMessage, safety }`.
class MoodCheckInResult {
  MoodCheckInResult({required this.entry, required this.supportMessage, required this.safety});
  final MoodEntry entry;
  final String supportMessage;
  final SafetyResult safety;

  factory MoodCheckInResult.fromJson(Json j) => MoodCheckInResult(
        entry: MoodEntry.fromJson(j),
        supportMessage: str(j, 'supportMessage'),
        safety: SafetyResult.fromJson(asJson(j['safety'])),
      );
}

// ---------- Wound ----------

class WoundCase {
  WoundCase({
    required this.id,
    required this.patientId,
    required this.bodySite,
    required this.note,
    required this.status,
    required this.qualityAcceptable,
    required this.qualityIssues,
    required this.reviewerName,
    required this.reviewNotes,
    required this.reviewedAt,
    required this.imageRecordId,
    required this.createdAt,
  });
  final String id;
  final String patientId;
  final String bodySite;
  final String? note;
  final String status;
  final bool qualityAcceptable;
  final List<String> qualityIssues;
  final String? reviewerName;
  final String? reviewNotes;
  final DateTime? reviewedAt;
  final String? imageRecordId;
  final DateTime createdAt;

  factory WoundCase.fromJson(Json j) {
    final q = asJson(j['quality']);
    final r = j['clinicianReview'] is Map ? asJson(j['clinicianReview']) : null;
    return WoundCase(
      id: str(j, 'id'),
      patientId: str(j, 'patientId'),
      bodySite: str(j, 'bodySite'),
      note: strOrNull(j, 'note'),
      status: str(j, 'status'),
      qualityAcceptable: boolOf(q, 'acceptable'),
      qualityIssues: strList(q, 'issues'),
      reviewerName: r == null ? null : strOrNull(r, 'reviewerName'),
      reviewNotes: r == null ? null : strOrNull(r, 'notes'),
      reviewedAt: r == null ? null : dateOrNull(r, 'reviewedAt'),
      imageRecordId: strOrNull(j, 'imageRecordId'),
      createdAt: dateOf(j, 'createdAt'),
    );
  }
}

// ---------- Wearables ----------

class WearableProvider {
  WearableProvider({required this.code, required this.name, required this.status});
  final String code;
  final String name;
  final String status;

  bool get comingSoon => status == 'coming_soon';

  factory WearableProvider.fromJson(Json j) => WearableProvider(
        code: str(j, 'code'),
        name: str(j, 'name'),
        status: str(j, 'status'),
      );
}

class WearableConnection {
  WearableConnection({
    required this.id,
    required this.provider,
    required this.status,
    required this.connectedAt,
    required this.lastSyncAt,
  });
  final String id;
  final String provider;
  final String status;
  final DateTime? connectedAt;
  final DateTime? lastSyncAt;

  bool get isConnected => status == 'connected';

  factory WearableConnection.fromJson(Json j) => WearableConnection(
        id: str(j, 'id'),
        provider: str(j, 'provider'),
        status: str(j, 'status'),
        connectedAt: dateOrNull(j, 'connectedAt'),
        lastSyncAt: dateOrNull(j, 'lastSyncAt'),
      );
}

// ---------- Fall / SOS / Insights ----------

class FallEvent {
  FallEvent({
    required this.id,
    required this.patientId,
    required this.status,
    required this.source,
    required this.createdAt,
    required this.respondedAt,
  });
  final String id;
  final String patientId;
  final String status;
  final String source;
  final DateTime createdAt;
  final DateTime? respondedAt;

  factory FallEvent.fromJson(Json j) => FallEvent(
        id: str(j, 'id'),
        patientId: str(j, 'patientId'),
        status: str(j, 'status'),
        source: str(j, 'source'),
        createdAt: dateOf(j, 'createdAt'),
        respondedAt: dateOrNull(j, 'respondedAt'),
      );
}

class NotifiedContact {
  NotifiedContact({required this.name, required this.phoneMasked});
  final String name;
  final String phoneMasked;

  factory NotifiedContact.fromJson(Json j) =>
      NotifiedContact(name: str(j, 'name'), phoneMasked: str(j, 'phoneMasked'));
}

class SosResult {
  SosResult({
    required this.sosId,
    required this.careEpisodeId,
    required this.helpline,
    required this.notifiedContacts,
    required this.nearestEmergencyFacilities,
  });
  final String sosId;
  final String? careEpisodeId;
  final String helpline;
  final List<NotifiedContact> notifiedContacts;
  final List<Facility> nearestEmergencyFacilities;

  factory SosResult.fromJson(Json j) => SosResult(
        sosId: str(j, 'sosId'),
        careEpisodeId: strOrNull(j, 'careEpisodeId'),
        helpline: str(j, 'helpline', '108'),
        notifiedContacts: listOf(j['notifiedContacts'], NotifiedContact.fromJson),
        nearestEmergencyFacilities:
            listOf(j['nearestEmergencyFacilities'], Facility.fromJson),
      );
}

class Insight {
  Insight({
    required this.type,
    required this.label,
    required this.value,
    required this.unit,
    required this.status,
    required this.goal,
    required this.source,
    required this.measuredAt,
  });
  final String type;
  final String label;
  final String value;
  final String unit;
  final String? status;
  final num? goal;
  final String source;
  final DateTime? measuredAt;

  factory Insight.fromJson(Json j) => Insight(
        type: str(j, 'type'),
        label: str(j, 'label'),
        value: str(j, 'value'),
        unit: str(j, 'unit'),
        status: strOrNull(j, 'status'),
        goal: j['goal'] is num ? j['goal'] as num : null,
        source: str(j, 'source'),
        measuredAt: dateOrNull(j, 'measuredAt'),
      );
}
