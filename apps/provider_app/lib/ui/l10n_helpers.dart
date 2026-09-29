import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import '../core/api/api_exception.dart';
import '../l10n/gen/app_localizations.dart';
import '../models/home_visit.dart';

extension L10nContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

String visitStatusLabel(AppLocalizations l, String status) {
  switch (status) {
    case VisitStatus.requested:
      return l.statusRequested;
    case VisitStatus.unassigned:
      return l.statusUnassigned;
    case VisitStatus.assigned:
      return l.statusAssigned;
    case VisitStatus.accepted:
      return l.statusAccepted;
    case VisitStatus.enRoute:
      return l.statusEnRoute;
    case VisitStatus.arrived:
      return l.statusArrived;
    case VisitStatus.inProgress:
      return l.statusInProgress;
    case VisitStatus.completed:
      return l.statusCompleted;
    case VisitStatus.cancelled:
      return l.statusCancelled;
    case VisitStatus.escalated:
      return l.statusEscalated;
    default:
      return status;
  }
}

String providerTypeLabel(AppLocalizations l, String type) {
  switch (type) {
    case 'nurse':
      return l.typeNurse;
    case 'technician':
      return l.typeTechnician;
    case 'intern':
      return l.typeIntern;
    case 'physiotherapist':
      return l.typePhysiotherapist;
    case 'dietitian':
      return l.typeDietitian;
    case 'doctor':
      return l.typeDoctor;
    default:
      return type;
  }
}

/// Application document types (contract §30).
String docTypeLabel(AppLocalizations l, String docType) => switch (docType) {
      'registration_certificate' => l.docRegistrationCertificate,
      'degree' => l.docDegree,
      'id_proof' => l.docIdProof,
      'experience_letter' => l.docExperienceLetter,
      _ => l.docOther,
    };

/// Integer rupees (contract: money is integer rupees), Indian grouping.
String formatRupees(num amount) =>
    NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: amount % 1 == 0 ? 0 : 2).format(amount);

String verificationLabel(AppLocalizations l, String status) {
  switch (status) {
    case 'verified':
      return l.verificationVerified;
    case 'pending':
      return l.verificationPending;
    case 'rejected':
      return l.verificationRejected;
    case 'suspended':
      return l.verificationSuspended;
    case 'expired':
      return l.verificationExpired;
    default:
      return status;
  }
}

String genderLabel(AppLocalizations l, String? gender) {
  switch (gender) {
    case 'male':
      return l.genderMale;
    case 'female':
      return l.genderFemale;
    case 'other':
      return l.genderOther;
    default:
      return gender ?? '–';
  }
}

String errorMessage(AppLocalizations l, Object error) {
  if (error is ApiException) {
    if (error.isNetwork) return l.errorNetwork;
    if (error.isMfaRequired) return l.errorMfaRequired;
    if (error.code == ApiException.localFileMissingCode) return l.photoFileMissing;
    if (error.code == 'FILE_TOO_LARGE') return l.onbFileTooLarge;
    if (error.isUnauthenticated) return l.errorSessionExpired;
    if (error.message.isNotEmpty) return error.message;
  }
  return l.errorGeneric;
}

String formatTime(BuildContext context, DateTime? dt) {
  if (dt == null) return '–';
  final locale = Localizations.localeOf(context).toString();
  return DateFormat.jm(locale).format(dt.toLocal());
}

String formatDate(BuildContext context, DateTime? dt) {
  if (dt == null) return '–';
  final locale = Localizations.localeOf(context).toString();
  return DateFormat.yMMMd(locale).format(dt.toLocal());
}

/// "12 Oct, 10:00 AM – 11:00 AM" (date omitted when [withDate] is false).
String formatWindow(BuildContext context, DateTime? start, DateTime? end, {bool withDate = true}) {
  if (start == null) return '–';
  final locale = Localizations.localeOf(context).toString();
  final s = start.toLocal();
  final date = withDate ? '${DateFormat.MMMd(locale).format(s)}, ' : '';
  final range = end == null
      ? DateFormat.jm(locale).format(s)
      : '${DateFormat.jm(locale).format(s)} – ${DateFormat.jm(locale).format(end.toLocal())}';
  return '$date$range';
}
