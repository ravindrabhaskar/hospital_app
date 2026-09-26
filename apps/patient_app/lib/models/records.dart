import 'json.dart';

class RecordType {
  RecordType._();
  static const labReport = 'lab_report';
  static const prescription = 'prescription';
  static const imaging = 'imaging';
  static const dischargeSummary = 'discharge_summary';
  static const visitSummary = 'visit_summary';
  static const other = 'other';
  static const all = [
    labReport,
    prescription,
    imaging,
    dischargeSummary,
    visitSummary,
    other,
  ];

  /// Types a patient may upload (visit summaries are system generated).
  static const uploadable = [labReport, prescription, imaging, dischargeSummary, other];
}

class AiSummary {
  AiSummary({
    required this.text,
    required this.model,
    required this.generatedAt,
    required this.disclaimer,
  });
  final String text;
  final String model;
  final DateTime? generatedAt;
  final String disclaimer;

  factory AiSummary.fromJson(Json j) => AiSummary(
        text: str(j, 'text'),
        model: str(j, 'model'),
        generatedAt: dateOrNull(j, 'generatedAt'),
        disclaimer: str(j, 'disclaimer'),
      );
}

class MedicalRecord {
  MedicalRecord({
    required this.id,
    required this.patientId,
    required this.type,
    required this.title,
    required this.recordDate,
    required this.source,
    required this.uploadedByName,
    required this.fileName,
    required this.mimeType,
    required this.sizeBytes,
    required this.hasFile,
    required this.aiSummary,
    required this.createdAt,
  });
  final String id;
  final String patientId;
  final String type;
  final String title;
  final String recordDate;
  final String source;
  final String? uploadedByName;
  final String fileName;
  final String mimeType;
  final int sizeBytes;
  final bool hasFile;
  final AiSummary? aiSummary;
  final DateTime? createdAt;

  bool get isImage => mimeType.startsWith('image/');
  bool get isPdf => mimeType.contains('pdf') || fileName.toLowerCase().endsWith('.pdf');

  factory MedicalRecord.fromJson(Json j) => MedicalRecord(
        id: str(j, 'id'),
        patientId: str(j, 'patientId'),
        type: str(j, 'type'),
        title: str(j, 'title'),
        recordDate: str(j, 'recordDate'),
        source: str(j, 'source'),
        uploadedByName: strOrNull(j, 'uploadedByName'),
        fileName: str(j, 'fileName'),
        mimeType: str(j, 'mimeType'),
        sizeBytes: intOf(j, 'sizeBytes'),
        hasFile: boolOf(j, 'hasFile'),
        aiSummary:
            j['aiSummary'] is Map ? AiSummary.fromJson(asJson(j['aiSummary'])) : null,
        createdAt: dateOrNull(j, 'createdAt'),
      );
}

class TimelineItem {
  TimelineItem({
    required this.id,
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.occurredAt,
    required this.refId,
    required this.source,
  });
  final String id;
  final String kind;
  final String title;
  final String? subtitle;
  final DateTime occurredAt;
  final String refId;
  final String? source;

  factory TimelineItem.fromJson(Json j) => TimelineItem(
        id: str(j, 'id'),
        kind: str(j, 'kind'),
        title: str(j, 'title'),
        subtitle: strOrNull(j, 'subtitle'),
        occurredAt: dateOf(j, 'occurredAt'),
        refId: str(j, 'refId'),
        source: strOrNull(j, 'source'),
      );
}
