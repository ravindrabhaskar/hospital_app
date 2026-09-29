import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_exception.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/state_views.dart';
import '../../core/widgets/status_timeline.dart' show NoticeBox;
import '../../l10n/app_localizations.dart';
import '../../models/patient.dart';
import '../../models/services.dart';
import '../../state/core_providers.dart';
import '../../state/data_providers.dart';
import '../../state/v13_providers.dart';
import '../profile/abha_section.dart' show AbhaNumberFormatter, abhaDigits, formatAbhaNumber, isValidAbhaNumber;

// ABDM: ABHA creation / linking and consent-based record fetch (§50).

enum AbhaFlowMode { create, link }

enum AbhaStep { enterId, enterOtp, done }

/// Pure state machine of the ABHA create/link OTP flow (testable without UI).
class AbhaFlowController extends ChangeNotifier {
  AbhaFlowController({required this.start, required this.verify});

  /// Sends the OTP; returns the transaction id.
  final Future<String> Function(String id) start;
  final Future<AbhaInfo> Function(String txnId, String otp) verify;

  AbhaStep step = AbhaStep.enterId;
  String? txnId;
  AbhaInfo? result;
  bool busy = false;
  Object? error;

  static bool validMobile(String v) => RegExp(r'^[6-9]\d{9}$').hasMatch(v.trim());
  static bool validOtp(String v) => RegExp(r'^\d{6}$').hasMatch(v.trim());

  Future<void> sendOtp(String id) async {
    busy = true;
    error = null;
    notifyListeners();
    try {
      txnId = await start(id);
      step = AbhaStep.enterOtp;
    } catch (e) {
      error = e;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> submitOtp(String otp) async {
    final t = txnId;
    if (t == null) return;
    busy = true;
    error = null;
    notifyListeners();
    try {
      result = await verify(t, otp.trim());
      step = AbhaStep.done;
    } catch (e) {
      error = e;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  void restart() {
    step = AbhaStep.enterId;
    txnId = null;
    error = null;
    notifyListeners();
  }
}

class AbhaFlowScreen extends ConsumerStatefulWidget {
  const AbhaFlowScreen({super.key, required this.mode});
  final AbhaFlowMode mode;

  @override
  ConsumerState<AbhaFlowScreen> createState() => _AbhaFlowScreenState();
}

class _AbhaFlowScreenState extends ConsumerState<AbhaFlowScreen> {
  late final AbhaFlowController _c;
  final _id = TextEditingController();
  final _otp = TextEditingController();
  String? _fieldError;

  bool get _create => widget.mode == AbhaFlowMode.create;

  @override
  void initState() {
    super.initState();
    final repo = ref.read(abdmRepositoryProvider);
    Future<String> pid() async => (await ref.read(activePatientProvider.future)).id;
    _c = AbhaFlowController(
      start: (id) async => _create ? repo.createStart(await pid(), id) : repo.linkStart(await pid(), abhaDigits(id)),
      verify: (t, otp) => _create ? repo.createVerify(t, otp) : repo.linkVerify(t, otp),
    )..addListener(() {
        if (mounted) setState(() {});
        if (_c.step == AbhaStep.done) ref.invalidate(patientProfileProvider);
      });
  }

  @override
  void dispose() {
    _c.dispose();
    _id.dispose();
    _otp.dispose();
    super.dispose();
  }

  void _send() {
    final l = context.l10n;
    final v = _id.text.trim();
    final ok = _create ? AbhaFlowController.validMobile(v) : isValidAbhaNumber(v);
    setState(() => _fieldError = ok ? null : (_create ? l.phoneInvalid : l.abhaNumberInvalid));
    if (ok) _c.sendOtp(v);
  }

  void _verify() {
    final l = context.l10n;
    final ok = AbhaFlowController.validOtp(_otp.text);
    setState(() => _fieldError = ok ? null : l.otpInvalid);
    if (ok) _c.submitOtp(_otp.text);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(_create ? l.createAbha : l.linkAbha)),
      body: ListView(
        padding: const EdgeInsets.all(Space.screen),
        children: [
          const Center(child: IconTile(icon: Icons.badge_outlined, accent: Accent.sky, size: 72)),
          const SizedBox(height: Space.lg),
          if (_c.step == AbhaStep.done) ...[
            Semantics(
              liveRegion: true,
              child: Text(_create ? l.abhaCreated : l.abhaLinked,
                  key: const Key('abha-done'), textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
            ),
            const SizedBox(height: Space.md),
            CcCard(
              child: Column(children: [
                LabeledValue(
                    label: l.abhaNumber,
                    value: _c.result?.number == null ? '—' : formatAbhaNumber(_c.result!.number!)),
                LabeledValue(label: l.abhaAddress, value: _c.result?.address ?? '—'),
              ]),
            ),
            const SizedBox(height: Space.lg),
            PrimaryButton(label: l.done, onPressed: () => context.pop()),
          ] else ...[
            Text(_create ? l.createAbhaIntro : l.linkAbhaIntro,
                textAlign: TextAlign.center, style: TextStyle(color: context.textMuted)),
            const SizedBox(height: Space.xl),
            if (_c.step == AbhaStep.enterId)
              TextField(
                key: const Key('abha-id'),
                controller: _id,
                keyboardType: _create ? TextInputType.phone : TextInputType.number,
                maxLength: _create ? 10 : 17,
                inputFormatters: _create ? [FilteringTextInputFormatter.digitsOnly] : [AbhaNumberFormatter()],
                decoration: InputDecoration(
                  labelText: _create ? l.abhaMobileLabel : l.abhaNumber,
                  prefixText: _create ? '+91  ' : null,
                  hintText: _create ? null : 'XX-XXXX-XXXX-XXXX',
                  counterText: '',
                  errorText: _fieldError,
                ),
              )
            else ...[
              Text(l.abhaOtpSent, textAlign: TextAlign.center),
              const SizedBox(height: Space.md),
              TextField(
                key: const Key('abha-otp'),
                controller: _otp,
                keyboardType: TextInputType.number,
                maxLength: 6,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(labelText: l.otpLabel, counterText: '', errorText: _fieldError),
              ),
              TextButton(onPressed: _c.busy ? null : _c.restart, child: Text(l.change)),
            ],
            if (_c.error != null) ...[
              const SizedBox(height: Space.sm),
              Semantics(
                liveRegion: true,
                child: Text(errorMessage(context, _c.error!),
                    key: const Key('abha-error'), style: const TextStyle(color: AppColors.danger)),
              ),
            ],
            const SizedBox(height: Space.lg),
            PrimaryButton(
              key: const Key('abha-next'),
              label: _c.step == AbhaStep.enterId ? l.sendOtp : l.verify,
              loading: _c.busy,
              onPressed: _c.step == AbhaStep.enterId ? _send : _verify,
            ),
            const SizedBox(height: Space.md),
            Text(l.abdmPrivacyNote, style: TextStyle(fontSize: 12, color: context.textMuted)),
          ],
        ],
      ),
    );
  }
}

/// Health Profile → ABHA actions (create, link, fetch records).
class AbdmActionsCard extends ConsumerWidget {
  const AbdmActionsCard({super.key, required this.profile});
  final PatientProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    if (!ref.watch(featureFlagsProvider).abdm) return const SizedBox.shrink();
    final verified = profile.abha?.verified ?? false;
    return Padding(
      padding: const EdgeInsets.only(top: Space.sm),
      child: CcCard(
        key: const Key('abdm-actions'),
        padding: EdgeInsets.zero,
        child: Column(children: [
          if (!verified) ...[
            ListTile(
              key: const Key('abha-create'),
              minTileHeight: 56,
              leading: const Icon(Icons.add_card_outlined),
              title: Text(l.createAbha),
              subtitle: Text(l.createAbhaSub),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/abha/create'),
            ),
            const Divider(indent: 56),
            ListTile(
              key: const Key('abha-link'),
              minTileHeight: 56,
              leading: const Icon(Icons.link),
              title: Text(l.linkAbha),
              subtitle: Text(l.linkAbhaSub),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/abha/link'),
            ),
            const Divider(indent: 56),
          ],
          ListTile(
            key: const Key('abdm-fetch'),
            minTileHeight: 56,
            leading: const Icon(Icons.cloud_download_outlined),
            title: Text(l.fetchRecords),
            subtitle: Text(l.fetchRecordsSub),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/abdm/consents'),
          ),
        ]),
      ),
    );
  }
}

String hiTypeLabel(AppLocalizations l, String t) => switch (t) {
      'Prescription' => l.hiPrescription,
      'DiagnosticReport' => l.hiDiagnosticReport,
      'DischargeSummary' => l.hiDischargeSummary,
      'OPConsultation' => l.hiOpConsultation,
      _ => t,
    };

String consentStatusLabel(AppLocalizations l, String s) => switch (s) {
      'requested' => l.abdmRequested,
      'granted' => l.abdmGranted,
      'denied' => l.abdmDenied,
      'expired' => l.abdmExpired,
      'data_received' => l.abdmDataReceived,
      _ => humanize(s),
    };

class AbdmConsentsScreen extends ConsumerStatefulWidget {
  const AbdmConsentsScreen({super.key});

  @override
  ConsumerState<AbdmConsentsScreen> createState() => _AbdmConsentsScreenState();
}

class _AbdmConsentsScreenState extends ConsumerState<AbdmConsentsScreen> {
  final _types = <String>{...abdmHiTypes};
  late DateTimeRange _range =
      DateTimeRange(start: DateTime.now().subtract(const Duration(days: 365 * 2)), end: DateTime.now());
  bool _busy = false;

  Future<void> _pickRange() async {
    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(1990),
      lastDate: DateTime.now(),
      initialDateRange: _range,
    );
    if (r != null) setState(() => _range = r);
  }

  Future<void> _request() async {
    final l = context.l10n;
    setState(() => _busy = true);
    try {
      final p = await ref.read(activePatientProvider.future);
      await ref.read(abdmRepositoryProvider).requestConsent(
            patientId: p.id,
            hiTypes: abdmHiTypes.where(_types.contains).toList(),
            from: _range.start,
            to: _range.end,
          );
      ref.invalidate(abdmConsentRequestsProvider);
      if (mounted) showSnack(context, l.abdmRequestSent);
    } on ApiException catch (e) {
      if (mounted) showSnack(context, errorMessage(context, e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.fetchRecords)),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(abdmConsentRequestsProvider);
          ref.invalidate(recordsProvider(null));
          await ref.read(abdmConsentRequestsProvider.future);
        },
        child: ListView(
          padding: const EdgeInsets.all(Space.screen),
          children: [
            Text(l.fetchRecordsIntro, style: TextStyle(color: context.textMuted)),
            SectionHeader(title: l.recordTypesToFetch),
            CcCard(
              padding: EdgeInsets.zero,
              child: Column(children: [
                for (final t in abdmHiTypes)
                  CheckboxListTile(
                    key: Key('hi-$t'),
                    value: _types.contains(t),
                    title: Text(hiTypeLabel(l, t)),
                    onChanged: (v) => setState(() => v == true ? _types.add(t) : _types.remove(t)),
                  ),
              ]),
            ),
            const SizedBox(height: Space.md),
            ListTile(
              minTileHeight: 56,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(Radii.tile), side: BorderSide(color: context.borderColor)),
              leading: const Icon(Icons.date_range),
              title: Text(l.dateRange),
              subtitle: Text('${fmtDate(context, _range.start)} – ${fmtDate(context, _range.end)}'),
              onTap: _pickRange,
            ),
            const SizedBox(height: Space.md),
            NoticeBox(icon: Icons.privacy_tip_outlined, color: AppColors.skyFg, text: l.abdmConsentExplain),
            const SizedBox(height: Space.md),
            PrimaryButton(
              key: const Key('abdm-request'),
              label: l.sendConsentRequest,
              loading: _busy,
              onPressed: _types.isEmpty ? null : _request,
            ),
            SectionHeader(title: l.myConsentRequests),
            AsyncView<List<AbdmConsentRequest>>(
              value: ref.watch(abdmConsentRequestsProvider),
              compact: true,
              onRetry: () => ref.invalidate(abdmConsentRequestsProvider),
              isEmpty: (x) => x.isEmpty,
              empty: Text(l.noConsentRequests, style: TextStyle(color: context.textMuted)),
              data: (list) => Column(children: [
                for (final r in list)
                  ListRowTile(
                    icon: Icons.cloud_sync_outlined,
                    accent: r.status == 'data_received' ? Accent.teal : Accent.sky,
                    title: r.hiTypes.map((t) => hiTypeLabel(l, t)).join(', '),
                    subtitle: [
                      consentStatusLabel(l, r.status),
                      '${fmtYmd(context, r.from)} – ${fmtYmd(context, r.to)}',
                      if (r.recordsImported > 0) l.recordsImported(r.recordsImported),
                    ].join(' · '),
                    onTap: r.recordsImported > 0 ? () => context.go('/records') : null,
                  ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}
