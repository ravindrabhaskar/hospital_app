import '../../../models/home_visit.dart';

/// The provider-facing steps shown in the guided stepper.
enum VisitStep { accept, travel, arrive, verify, care, complete }

/// What the provider should do next for a visit in a given status.
enum NextAction {
  /// `requested`: no provider yet (should not normally reach a provider).
  awaitingAssignment,

  /// `assigned`: accept or reject.
  acceptOrReject,

  /// `accepted`: start travel with an ETA.
  startTravel,

  /// `en_route`: navigate, then mark arrived.
  markArrived,

  /// `arrived`: visit code + consent.
  verifyPatient,

  /// `in_progress`: vitals, observations, escalate, complete.
  recordCare,

  /// `escalated`: can still record and complete.
  completeEscalated,

  /// `completed`.
  done,

  /// `cancelled`.
  cancelled,

  /// `unassigned` (rejected / reassigned away from this provider).
  reassigned,
}

/// Visit action types; each maps to `POST /home-visits/:id/<segment>`.
enum VisitActionType {
  accept('accept'),
  reject('reject'),
  enRoute('en-route'),
  arrived('arrived'),
  verifyIdentity('verify-identity'),
  vitals('vitals'),
  observations('observations'),
  escalate('escalate'),
  complete('complete'),

  /// Consented visit photo, uploaded as a medical record (`POST /records`,
  /// multipart). Not a lifecycle transition.
  photo('photo');

  const VisitActionType(this.pathSegment);
  final String pathSegment;

  /// A 403/404 on a visit-scoped action means the visit was reassigned, so
  /// everything queued for it is dropped. A photo upload hits `/records`,
  /// where 403 only means this provider may not upload records.
  bool get isVisitScoped => this != photo;

  static VisitActionType? fromName(String name) {
    for (final t in values) {
      if (t.name == name) return t;
    }
    return null;
  }
}

class VisitLifecycle {
  VisitLifecycle._();

  static NextAction nextActionFor(String status) {
    switch (status) {
      case VisitStatus.assigned:
        return NextAction.acceptOrReject;
      case VisitStatus.accepted:
        return NextAction.startTravel;
      case VisitStatus.enRoute:
        return NextAction.markArrived;
      case VisitStatus.arrived:
        return NextAction.verifyPatient;
      case VisitStatus.inProgress:
        return NextAction.recordCare;
      case VisitStatus.escalated:
        return NextAction.completeEscalated;
      case VisitStatus.completed:
        return NextAction.done;
      case VisitStatus.cancelled:
        return NextAction.cancelled;
      case VisitStatus.unassigned:
        return NextAction.reassigned;
      case VisitStatus.requested:
      default:
        return NextAction.awaitingAssignment;
    }
  }

  /// Index into [VisitStep.values] of the current step;
  /// `VisitStep.values.length` means every step is done.
  static int currentStepIndex(String status) {
    switch (status) {
      case VisitStatus.accepted:
        return VisitStep.travel.index;
      case VisitStatus.enRoute:
        return VisitStep.arrive.index;
      case VisitStatus.arrived:
        return VisitStep.verify.index;
      case VisitStatus.inProgress:
      case VisitStatus.escalated:
        return VisitStep.care.index;
      case VisitStatus.completed:
        return VisitStep.values.length;
      default:
        return VisitStep.accept.index;
    }
  }

  /// Big red escalate button is always visible while the checkup is running.
  static bool canEscalate(String status) => status == VisitStatus.inProgress;

  static bool canRecordCare(String status) =>
      status == VisitStatus.inProgress || status == VisitStatus.escalated;

  static bool canComplete(String status) => canRecordCare(status);

  /// Full address only once the provider has accepted.
  static bool showFullAddress(String status) => const {
        VisitStatus.accepted,
        VisitStatus.enRoute,
        VisitStatus.arrived,
        VisitStatus.inProgress,
        VisitStatus.escalated,
        VisitStatus.completed,
      }.contains(status);

  static bool canNavigate(String status) => const {
        VisitStatus.accepted,
        VisitStatus.enRoute,
        VisitStatus.arrived,
      }.contains(status);

  static bool isActive(String status) => const {
        VisitStatus.assigned,
        VisitStatus.accepted,
        VisitStatus.enRoute,
        VisitStatus.arrived,
        VisitStatus.inProgress,
        VisitStatus.escalated,
      }.contains(status);

  /// The status a successful action leads to (used for optimistic offline UI).
  static String? statusAfter(VisitActionType type) {
    switch (type) {
      case VisitActionType.accept:
        return VisitStatus.accepted;
      case VisitActionType.reject:
        return VisitStatus.unassigned;
      case VisitActionType.enRoute:
        return VisitStatus.enRoute;
      case VisitActionType.arrived:
        return VisitStatus.arrived;
      case VisitActionType.verifyIdentity:
        return VisitStatus.inProgress;
      case VisitActionType.escalate:
        return VisitStatus.escalated;
      case VisitActionType.complete:
        return VisitStatus.completed;
      case VisitActionType.vitals:
      case VisitActionType.observations:
      case VisitActionType.photo:
        return null;
    }
  }

  /// Applies a not-yet-synced action to a local visit copy so the stepper can
  /// advance while offline. The server copy always wins once synced.
  static HomeVisit applyOptimistic(HomeVisit visit, VisitActionType type, Map<String, dynamic> body,
      DateTime at) {
    final next = statusAfter(type);
    var v = visit.copyWith(pendingSync: true);
    switch (type) {
      case VisitActionType.vitals:
        final measurements = (body['measurements'] as List? ?? const [])
            .map((m) => VitalMeasurement.fromJson(Map<String, dynamic>.from(m as Map)))
            .toList();
        return v.copyWith(vitals: [...visit.vitals, ...measurements]);
      case VisitActionType.observations:
        return v.copyWith(
          observations: VisitObservations(
            notes: (body['notes'] ?? '').toString(),
            checklist: Map<String, dynamic>.from(body['checklist'] as Map? ?? const {}),
          ),
        );
      case VisitActionType.enRoute:
        v = v.copyWith(etaMinutes: (body['etaMinutes'] as num?)?.toInt());
      case VisitActionType.escalate:
        v = v.copyWith(
          escalation: VisitEscalation(
            reason: (body['reason'] ?? '').toString(),
            severity: (body['severity'] ?? '').toString(),
            at: at,
          ),
        );
      case VisitActionType.complete:
        v = v.copyWith(summary: (body['summary'] ?? '').toString());
      default:
        break;
    }
    if (next == null) return v;
    return v.copyWith(
      status: next,
      timeline: [...v.timeline, TimelineEntry(status: next, at: at, note: null)],
    );
  }
}
