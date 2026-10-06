import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../core/api/api_exception.dart';
import '../../core/storage/key_value_store.dart';
import '../../models/json.dart';
import '../../models/provider_application.dart';
import 'application_repository.dart';
import 'document_picker.dart';

/// Which onboarding screen to show.
enum ApplicationPhase { loading, error, form, status, approved }

/// Pure routing rule, driven by `GET /provider-applications/me`:
/// 404 → new form; `changes_requested` + "Edit & resubmit" → prefilled form;
/// `approved` → approved (the identity is refreshed); otherwise → status.
ApplicationPhase applicationPhaseFor({
  required bool loaded,
  required bool hasError,
  required ProviderApplication? application,
  required bool editing,
}) {
  if (!loaded) return hasError ? ApplicationPhase.error : ApplicationPhase.loading;
  if (application == null) return ApplicationPhase.form;
  if (application.status == ApplicationStatus.approved) return ApplicationPhase.approved;
  if (editing && application.isEditable) return ApplicationPhase.form;
  return ApplicationPhase.status;
}

enum UploadState { uploading, failed }

/// A document upload that has not (yet) become a server document.
class DocumentUpload {
  DocumentUpload({required this.docType, required this.file});
  final String docType;
  final PickedDocument file;
  UploadState state = UploadState.uploading;
  double progress = 0;
  ApiException? error;

  /// A file over 10 MB fails the same way on every retry, so no "Retry"
  /// is offered for it (only "remove").
  bool get canRetry {
    final e = error;
    return e == null || (e.code != 'FILE_TOO_LARGE' && e.statusCode != 413);
  }
}

/// Client-side limit mirroring the server (contract §30: ≤ 10 MB).
const maxDocumentBytes = 10 * 1024 * 1024;

/// A new application's form state kept on the device until it is submitted
/// (survives an app reload / web refresh).
class SavedApplicationDraft {
  const SavedApplicationDraft({required this.draft, this.step = 0, this.experienceText = ''});
  final ApplicationDraft draft;
  final int step;
  final String experienceText;

  Json toJson() => {'draft': draft.toDraftJson(), 'step': step, 'experience': experienceText};

  static SavedApplicationDraft? fromJson(Object? json) {
    if (json is! Map) return null;
    final draft = json['draft'];
    if (draft is! Map) return null;
    return SavedApplicationDraft(
      draft: ApplicationDraft.fromDraftJson(asJson(draft)),
      step: (intOrNull(json['step']) ?? 0).clamp(0, 3),
      experienceText: strOr(json['experience']),
    );
  }
}

class ApplicationController extends ChangeNotifier {
  ApplicationController({required this.repository, this.onApproved, this.store});

  final ApplicationRepository repository;

  /// Where the unsubmitted draft and known zone names are kept (secure
  /// storage in the app). Null: nothing is persisted.
  final KeyValueStore? store;

  static const zoneNamesKey = 'onboarding.zoneNames';

  SavedApplicationDraft? _savedDraft;
  Map<String, String> _zoneNames = const {};

  /// Draft restored from the device for a new application (null if none).
  SavedApplicationDraft? get savedDraft => _savedDraft;

  /// Zone id → name remembered from pincode lookups on this device.
  Map<String, String> get zoneNames => _zoneNames;

  /// Called once when the application is seen as approved, so the identity
  /// (`/me` roles) can be refreshed and the router can move on.
  Future<void> Function()? onApproved;

  bool _loaded = false;
  bool _loading = false;
  bool _editing = false;
  bool _busy = false;
  bool _approvedHandled = false;
  ApiException? _error;
  ProviderApplication? _application;
  final List<DocumentUpload> _uploads = [];

  ProviderApplication? get application => _application;
  ApiException? get error => _error;
  bool get loading => _loading;
  bool get editing => _editing;

  /// A submit/delete is in flight.
  bool get busy => _busy;
  List<DocumentUpload> get uploads => List.unmodifiable(_uploads);

  ApplicationPhase get phase => applicationPhaseFor(
        loaded: _loaded,
        hasError: _error != null,
        application: _application,
        editing: _editing,
      );

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    await _loadLocal();
    try {
      _application = await repository.mine();
      _loaded = true;
    } on ApiException catch (e) {
      _error = e;
    } finally {
      _loading = false;
      notifyListeners();
    }
    await _handleApproved();
  }

  Future<void> _loadLocal() async {
    final store = this.store;
    if (store == null) return;
    try {
      final raw = await store.read(StoreKeys.applicationDraft);
      _savedDraft = raw == null ? null : SavedApplicationDraft.fromJson(jsonDecode(raw));
    } catch (_) {
      _savedDraft = null;
    }
    try {
      final raw = await store.read(zoneNamesKey);
      final decoded = raw == null ? null : jsonDecode(raw);
      if (decoded is Map) _zoneNames = {for (final e in decoded.entries) '${e.key}': '${e.value}'};
    } catch (_) {}
  }

  /// Persists the new-application form (called by the form, debounced).
  Future<void> saveDraft(SavedApplicationDraft draft) async {
    if (_application != null) return; // Only unsubmitted applications.
    _savedDraft = draft;
    try {
      await store?.write(StoreKeys.applicationDraft, jsonEncode(draft.toJson()));
    } catch (_) {}
  }

  Future<void> clearDraft() async {
    _savedDraft = null;
    try {
      await store?.delete(StoreKeys.applicationDraft);
    } catch (_) {}
  }

  /// Remembers a zone's name so "Edit & resubmit" can show it later.
  Future<void> rememberZone(String id, String? name) async {
    if (name == null || name.isEmpty || _zoneNames[id] == name) return;
    _zoneNames = {..._zoneNames, id: name};
    try {
      await store?.write(zoneNamesKey, jsonEncode(_zoneNames));
    } catch (_) {}
  }

  Future<void> _handleApproved() async {
    if (_application?.status != ApplicationStatus.approved || _approvedHandled) return;
    _approvedHandled = true;
    try {
      await onApproved?.call();
    } catch (_) {}
  }

  void startEditing() {
    if (_application?.isEditable != true) return;
    _editing = true;
    notifyListeners();
  }

  void cancelEditing() {
    _editing = false;
    notifyListeners();
  }

  /// Creates the application, or edits and resubmits it. Throws [ApiException].
  Future<void> submit(ApplicationDraft draft) async {
    _busy = true;
    notifyListeners();
    try {
      final created = _application == null;
      _application = created ? await repository.create(draft) : await repository.update(draft);
      _loaded = true;
      _editing = false;
      if (created) await clearDraft();
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// Uploads right away (the application must exist). Failures stay in the
  /// list with a retry option; they never throw.
  Future<void> uploadDocument(String docType, PickedDocument file) async {
    final upload = DocumentUpload(docType: docType, file: file);
    _uploads.add(upload);
    notifyListeners();
    await _send(upload);
  }

  Future<void> retryUpload(DocumentUpload upload) async {
    upload
      ..state = UploadState.uploading
      ..progress = 0
      ..error = null;
    notifyListeners();
    await _send(upload);
  }

  void dismissUpload(DocumentUpload upload) {
    _uploads.remove(upload);
    notifyListeners();
  }

  Future<void> _send(DocumentUpload upload) async {
    if (upload.file.bytes.length > maxDocumentBytes) {
      upload
        ..state = UploadState.failed
        ..error = const ApiException(statusCode: 413, code: 'FILE_TOO_LARGE', message: 'File is larger than 10 MB');
      notifyListeners();
      return;
    }
    try {
      final updated = await repository.uploadDocument(upload.docType, upload.file, onProgress: (p) {
        upload.progress = p;
        notifyListeners();
      });
      _application = updated;
      _uploads.remove(upload);
    } on ApiException catch (e) {
      upload
        ..state = UploadState.failed
        ..error = e;
    }
    notifyListeners();
  }

  /// Throws [ApiException].
  Future<void> deleteDocument(String docId) async {
    _busy = true;
    notifyListeners();
    try {
      _application = await repository.deleteDocument(docId);
    } finally {
      _busy = false;
      notifyListeners();
    }
  }
}
