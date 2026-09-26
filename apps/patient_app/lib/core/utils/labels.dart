import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../theme/tokens.dart';
import 'format.dart';

/// Localized labels for contract enums.
class Labels {
  Labels._();

  static String episodeStatus(AppLocalizations l, String s) => switch (s) {
        'NEW' => l.epNew,
        'INTAKE' => l.epIntake,
        'AWAITING_CARE' => l.epAwaitingCare,
        'CARE_SCHEDULED' => l.epCareScheduled,
        'UNDER_CARE' => l.epUnderCare,
        'FOLLOW_UP' => l.epFollowUp,
        'RESOLVED' => l.epResolved,
        'ESCALATED' => l.epEscalated,
        'EMERGENCY' => l.epEmergency,
        'TRANSFERRED' => l.epTransferred,
        'CANCELLED' => l.epCancelled,
        _ => humanize(s),
      };

  static Color episodeColor(String s) => switch (s) {
        'ESCALATED' || 'EMERGENCY' => AppColors.danger,
        'RESOLVED' => AppColors.primaryLight,
        'CANCELLED' || 'TRANSFERRED' => AppColors.textSecondary,
        'AWAITING_CARE' || 'FOLLOW_UP' => AppColors.peachFg,
        _ => AppColors.skyFg,
      };

  static String appointmentStatus(AppLocalizations l, String s) => switch (s) {
        'pending_payment' => l.apPendingPayment,
        'confirmed' => l.apConfirmed,
        'in_progress' => l.apInProgress,
        'completed' => l.apCompleted,
        'cancelled' => l.apCancelled,
        'no_show' => l.apNoShow,
        _ => humanize(s),
      };

  static Color appointmentColor(String s) => switch (s) {
        'pending_payment' => AppColors.peachFg,
        'confirmed' || 'in_progress' => AppColors.primaryLight,
        'cancelled' || 'no_show' => AppColors.danger,
        _ => AppColors.textSecondary,
      };

  static String mode(AppLocalizations l, String m) => switch (m) {
        'video' => l.modeVideo,
        'audio' => l.modeAudio,
        'chat' => l.modeChat,
        'in_clinic' => l.modeInClinic,
        _ => humanize(m),
      };

  static IconData modeIcon(String m) => switch (m) {
        'video' => Icons.videocam_outlined,
        'audio' => Icons.call_outlined,
        'chat' => Icons.chat_bubble_outline,
        _ => Icons.local_hospital_outlined,
      };

  static String visitStatus(AppLocalizations l, String s) => switch (s) {
        'requested' => l.hvRequested,
        'unassigned' => l.hvUnassigned,
        'assigned' => l.hvAssigned,
        'accepted' => l.hvAccepted,
        'en_route' => l.hvEnRoute,
        'arrived' => l.hvArrived,
        'in_progress' => l.hvInProgress,
        'completed' => l.hvCompleted,
        'cancelled' => l.hvCancelled,
        'escalated' => l.hvEscalated,
        _ => humanize(s),
      };

  static String recordType(AppLocalizations l, String t) => switch (t) {
        'lab_report' => l.rtLabReport,
        'prescription' => l.rtPrescription,
        'imaging' => l.rtImaging,
        'discharge_summary' => l.rtDischargeSummary,
        'visit_summary' => l.rtVisitSummary,
        _ => l.rtOther,
      };

  static IconData recordIcon(String t) => switch (t) {
        'lab_report' => Icons.science_outlined,
        'prescription' => Icons.receipt_long_outlined,
        'imaging' => Icons.image_outlined,
        'discharge_summary' => Icons.summarize_outlined,
        'visit_summary' => Icons.home_work_outlined,
        _ => Icons.description_outlined,
      };

  static Accent recordAccent(String t) => switch (t) {
        'lab_report' => Accent.sky,
        'prescription' => Accent.teal,
        'imaging' => Accent.lavender,
        'discharge_summary' => Accent.peach,
        _ => Accent.rose,
      };

  static String provenance(AppLocalizations l, String? p) => switch (p) {
        'patient_entered' => l.provPatientEntered,
        'clinician_verified' => l.provClinicianVerified,
        'home_visit' => l.provHomeVisit,
        'imported' => l.provImported,
        'ai_extracted' => l.provAiExtracted,
        'device' => l.provDevice,
        _ => l.provUnknown,
      };

  static Color provenanceColor(String? p) => switch (p) {
        'clinician_verified' => AppColors.primaryLight,
        'home_visit' => AppColors.skyFg,
        'ai_extracted' => AppColors.lavenderFg,
        'device' => AppColors.peachFg,
        _ => AppColors.textSecondary,
      };

  static String vitalType(AppLocalizations l, String t) => switch (t) {
        'bp_systolic' => l.vitalBpSystolic,
        'bp_diastolic' => l.vitalBpDiastolic,
        'pulse' => l.vitalPulse,
        'spo2' => l.vitalSpo2,
        'temperature' => l.vitalTemperature,
        'blood_glucose' => l.vitalBloodGlucose,
        'weight' => l.vitalWeight,
        'respiratory_rate' => l.vitalRespiratoryRate,
        _ => humanize(t),
      };

  static String doseStatus(AppLocalizations l, String s) => switch (s) {
        'taken' => l.doseTaken,
        'skipped' => l.doseSkipped,
        'missed' => l.doseMissed,
        _ => l.dosePending,
      };

  static String taskStatus(AppLocalizations l, String s) => switch (s) {
        'open' => l.taskOpen,
        'done' => l.taskDone,
        'overdue' => l.taskOverdue,
        'cancelled' => l.taskCancelled,
        _ => humanize(s),
      };

  static String paymentStatus(AppLocalizations l, String s) => switch (s) {
        'pending' => l.payPending,
        'succeeded' => l.paySucceeded,
        'failed' => l.payFailed,
        'refunded' => l.payRefunded,
        'partially_refunded' => l.payPartiallyRefunded,
        _ => humanize(s),
      };

  static String paymentPurpose(AppLocalizations l, String s) => switch (s) {
        'appointment' => l.purposeAppointment,
        'home_visit' => l.purposeHomeVisit,
        'pharmacy_order' => l.purposePharmacyOrder,
        'subscription' => l.purposeSubscription,
        _ => humanize(s),
      };

  static String consentPurpose(AppLocalizations l, String p) => switch (p) {
        'terms' => l.consentTerms,
        'privacy' => l.consentPrivacy,
        'health_data_processing' => l.consentHealthData,
        'ai_assistance' => l.consentAi,
        'share_with_clinicians' => l.consentShareClinicians,
        'family_sharing' => l.consentFamilySharing,
        'marketing' => l.consentMarketing,
        _ => humanize(p),
      };

  static String familyPermission(AppLocalizations l, String p) => switch (p) {
        'view_records' => l.permViewRecords,
        'manage_care' => l.permManageCare,
        'book' => l.permBook,
        'receive_alerts' => l.permReceiveAlerts,
        _ => humanize(p),
      };

  static String gender(AppLocalizations l, String g) => switch (g) {
        'male' => l.genderMale,
        'female' => l.genderFemale,
        'other' => l.genderOther,
        _ => g,
      };

  static String relation(AppLocalizations l, String r) => r == 'self' ? l.relationSelf : r;

  static String language(AppLocalizations l, String code) => switch (code) {
        'hi' => l.langHindi,
        'te' => l.langTelugu,
        _ => l.langEnglish,
      };

  static IconData specialtyIcon(String code) => switch (code) {
        'general_physician' => Icons.medical_services_outlined,
        'dermatologist' => Icons.face_retouching_natural_outlined,
        'pediatrician' => Icons.child_care_outlined,
        'gynecologist' => Icons.pregnant_woman_outlined,
        'cardiologist' => Icons.favorite_border,
        'orthopedist' => Icons.accessibility_new_outlined,
        'psychiatrist' => Icons.psychology_outlined,
        'ent' => Icons.hearing_outlined,
        'diabetologist' => Icons.bloodtype_outlined,
        'neurologist' => Icons.hub_outlined,
        _ => Icons.local_hospital_outlined,
      };

  static Accent specialtyAccent(int i) =>
      const [Accent.teal, Accent.rose, Accent.sky, Accent.lavender, Accent.peach][i % 5];

  static IconData homeServiceIcon(String code) => switch (code) {
        'vitals_check' => Icons.monitor_heart_outlined,
        'sample_collection' => Icons.science_outlined,
        'elderly_care' => Icons.elderly_outlined,
        'post_report_consult' => Icons.assignment_outlined,
        _ => Icons.home_outlined,
      };

  static String woundIssue(AppLocalizations l, String issue) => switch (issue) {
        'image_too_small' => l.woundIssueTooSmall,
        'file_too_small' => l.woundIssueFileTooSmall,
        'too_dark' => l.woundIssueTooDark,
        'blurry' => l.woundIssueBlurry,
        _ => humanize(issue),
      };

  static String facilityType(AppLocalizations l, String t) => switch (t) {
        'hospital' => l.facHospital,
        'clinic' => l.facClinic,
        'lab' => l.facLab,
        'pharmacy' => l.facPharmacy,
        _ => humanize(t),
      };
}
