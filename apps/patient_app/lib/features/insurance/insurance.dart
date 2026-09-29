import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/api/api_exception.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/state_views.dart';
import '../../core/widgets/status_timeline.dart' show NoticeBox;
import '../../l10n/app_localizations.dart';
import '../../models/doctor.dart';
import '../../models/json.dart';
import '../../models/services.dart';
import '../../state/core_providers.dart';
import '../../state/v13_providers.dart';
import '../facilities/facilities_screen.dart' show FacilityCard;

// Insurance helper (API_CONTRACT §51).

String policyTypeLabel(AppLocalizations l, String t) => switch (t) {
      'individual' => l.policyIndividual,
      'family_floater' => l.policyFamilyFloater,
      'corporate' => l.policyCorporate,
      'government' => l.policyGovernment,
      _ => humanize(t),
    };

class InsuranceScreen extends ConsumerWidget {
  const InsuranceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.insurance)),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('policy-add'),
        onPressed: () => context.push('/insurance/edit'),
        icon: const Icon(Icons.add),
        label: Text(l.addPolicy),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(insurancePoliciesProvider.future),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Space.screen, Space.md, Space.screen, 96),
          children: [
            AsyncView<List<InsurancePolicy>>(
              value: ref.watch(insurancePoliciesProvider),
              onRetry: () => ref.invalidate(insurancePoliciesProvider),
              isEmpty: (p) => p.isEmpty,
              empty: EmptyStateView(icon: Icons.shield_outlined, title: l.noPolicies, message: l.noPoliciesBody),
              data: (list) => Column(children: [for (final p in list) PolicyCard(policy: p)]),
            ),
            SectionHeader(title: l.claimHelp),
            ListRowTile(
              icon: Icons.checklist_rtl,
              accent: Accent.sky,
              title: l.claimChecklist,
              subtitle: l.claimChecklistSub,
              onTap: () => context.push('/insurance/checklist'),
            ),
          ],
        ),
      ),
    );
  }
}

class PolicyCard extends StatelessWidget {
  const PolicyCard({super.key, required this.policy});
  final InsurancePolicy policy;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = policy;
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.sm),
      child: CcCard(
        key: Key('policy-${p.id}'),
        onTap: () => context.push('/insurance/edit', extra: p),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const IconTile(icon: Icons.shield_outlined, accent: Accent.teal, size: 44),
              const SizedBox(width: Space.md),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(p.insurerName, style: Theme.of(context).textTheme.titleSmall),
                  Text([p.policyNumberMasked, ?p.planName].join(' · '),
                      style: TextStyle(fontSize: 12.5, color: context.textMuted)),
                ]),
              ),
              if (p.status == 'expiring_soon')
                StatusPill(key: const Key('policy-expiring'), label: l.expiringSoon, color: AppColors.peachFg, icon: Icons.schedule)
              else if (p.status == 'expired')
                StatusPill(label: l.expired, color: AppColors.danger)
              else
                StatusPill(label: l.active, icon: Icons.check),
            ]),
            const SizedBox(height: Space.sm),
            Text(
              [
                policyTypeLabel(l, p.type),
                if (p.sumInsured != null) l.sumInsuredValue(money(p.sumInsured!)),
                l.validUntil(fmtYmd(context, p.validTo)),
              ].join(' · '),
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: Space.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => context.push(Uri(
                    path: '/insurance/cashless',
                    queryParameters: {'insurer': p.insurerCode, 'name': p.insurerName}).toString()),
                icon: const Icon(Icons.local_hospital_outlined),
                label: Text(l.findCashlessHospitals),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PolicyEditScreen extends ConsumerStatefulWidget {
  const PolicyEditScreen({super.key, this.policy});
  final InsurancePolicy? policy;

  @override
  ConsumerState<PolicyEditScreen> createState() => _PolicyEditScreenState();
}

class _PolicyEditScreenState extends ConsumerState<PolicyEditScreen> {
  final _form = GlobalKey<FormState>();
  late String? _insurer = widget.policy?.insurerCode;
  late String _type = widget.policy?.type ?? 'individual';
  final _number = TextEditingController();
  late final _plan = TextEditingController(text: widget.policy?.planName ?? '');
  late final _sum = TextEditingController(text: widget.policy?.sumInsured?.toString() ?? '');
  late final _tpa = TextEditingController(text: widget.policy?.tpaName ?? '');
  late DateTime? _from = DateTime.tryParse(widget.policy?.validFrom ?? '');
  late DateTime? _to = DateTime.tryParse(widget.policy?.validTo ?? '');
  late String? _cardRecordId = widget.policy?.cardRecordId;
  bool _busy = false;
  bool _uploading = false;

  bool get _editing => widget.policy != null;

  @override
  void dispose() {
    for (final c in [_number, _plan, _sum, _tpa]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate(bool from) async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 10),
      initialDate: (from ? _from : _to) ?? now,
    );
    if (d != null) setState(() => from ? _from = d : _to = d);
  }

  Future<void> _uploadCard() async {
    final l = context.l10n;
    final file = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 2000, imageQuality: 85);
    if (file == null) return;
    setState(() => _uploading = true);
    try {
      final patient = await ref.read(activePatientProvider.future);
      final r = await ref.read(recordsRepositoryProvider).upload(
            patientId: patient.id,
            type: 'other',
            title: l.insuranceCardTitle,
            recordDate: ymd(DateTime.now()),
            bytes: await file.readAsBytes(),
            fileName: file.name,
            mimeType: mimeFromName(file.name),
          );
      setState(() => _cardRecordId = r.id);
    } on ApiException catch (e) {
      if (mounted) showSnack(context, errorMessage(context, e), error: true);
    } catch (_) {
      if (mounted) showSnack(context, l.pickerFailed, error: true);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _save() async {
    final l = context.l10n;
    if (!(_form.currentState?.validate() ?? false)) return;
    if (_from == null || _to == null || !_to!.isAfter(_from!)) {
      showSnack(context, l.policyDatesInvalid, error: true);
      return;
    }
    setState(() => _busy = true);
    final Json body = {
      'insurerCode': _insurer,
      if (_number.text.trim().isNotEmpty) 'policyNumber': _number.text.trim(),
      if (_plan.text.trim().isNotEmpty) 'planName': _plan.text.trim(),
      'type': _type,
      if (int.tryParse(_sum.text.trim()) != null) 'sumInsured': int.parse(_sum.text.trim()),
      'validFrom': ymd(_from!),
      'validTo': ymd(_to!),
      if (_tpa.text.trim().isNotEmpty) 'tpaName': _tpa.text.trim(),
      'cardRecordId': ?_cardRecordId,
    };
    try {
      final patient = await ref.read(activePatientProvider.future);
      final repo = ref.read(insuranceRepositoryProvider);
      if (_editing) {
        await repo.update(patient.id, widget.policy!.id, body);
      } else {
        await repo.add(patient.id, body);
      }
      ref.invalidate(insurancePoliciesProvider);
      if (mounted) context.pop();
    } on ApiException catch (e) {
      if (mounted) showSnack(context, errorMessage(context, e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final l = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(l.deletePolicy),
        content: Text(l.deletePolicyBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(l.cancel)),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
              onPressed: () => Navigator.pop(c, true),
              child: Text(l.remove)),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final patient = await ref.read(activePatientProvider.future);
      await ref.read(insuranceRepositoryProvider).delete(patient.id, widget.policy!.id);
      ref.invalidate(insurancePoliciesProvider);
      if (mounted) context.pop();
    } on ApiException catch (e) {
      if (mounted) showSnack(context, errorMessage(context, e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? l.editPolicy : l.addPolicy),
        actions: [
          if (_editing) IconButton(tooltip: l.deletePolicy, onPressed: _delete, icon: const Icon(Icons.delete_outline)),
        ],
      ),
      body: AsyncView<List<Insurer>>(
        value: ref.watch(insurersProvider),
        onRetry: () => ref.invalidate(insurersProvider),
        data: (insurers) => Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(Space.screen),
            children: [
              DropdownButtonFormField<String>(
                key: const Key('policy-insurer'),
                initialValue: insurers.any((i) => i.code == _insurer) ? _insurer : null,
                isExpanded: true,
                decoration: InputDecoration(labelText: l.insurer),
                items: [for (final i in insurers) DropdownMenuItem(value: i.code, child: Text(i.name))],
                validator: (v) => v == null ? l.fieldRequired : null,
                onChanged: (v) => setState(() => _insurer = v),
              ),
              const SizedBox(height: Space.md),
              TextFormField(
                key: const Key('policy-number'),
                controller: _number,
                decoration: InputDecoration(
                  labelText: l.policyNumber,
                  helperText: _editing ? l.policyNumberKeep(widget.policy!.policyNumberMasked) : null,
                ),
                validator: (v) => !_editing && (v ?? '').trim().isEmpty ? l.fieldRequired : null,
              ),
              const SizedBox(height: Space.md),
              TextFormField(controller: _plan, decoration: InputDecoration(labelText: l.planNameOptional)),
              const SizedBox(height: Space.md),
              DropdownButtonFormField<String>(
                initialValue: _type,
                decoration: InputDecoration(labelText: l.policyType),
                items: [for (final t in policyTypes) DropdownMenuItem(value: t, child: Text(policyTypeLabel(l, t)))],
                onChanged: (v) => setState(() => _type = v ?? _type),
              ),
              const SizedBox(height: Space.md),
              TextFormField(
                controller: _sum,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: l.sumInsuredOptional, prefixText: '₹ '),
              ),
              const SizedBox(height: Space.md),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickDate(true),
                    icon: const Icon(Icons.event),
                    label: Text(_from == null ? l.validFrom : fmtDate(context, _from!)),
                  ),
                ),
                const SizedBox(width: Space.sm),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickDate(false),
                    icon: const Icon(Icons.event_available),
                    label: Text(_to == null ? l.validTo : fmtDate(context, _to!)),
                  ),
                ),
              ]),
              const SizedBox(height: Space.md),
              TextFormField(controller: _tpa, decoration: InputDecoration(labelText: l.tpaOptional)),
              const SizedBox(height: Space.md),
              OutlinedButton.icon(
                onPressed: _uploading ? null : _uploadCard,
                icon: _uploading
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : Icon(_cardRecordId == null ? Icons.add_a_photo_outlined : Icons.check_circle),
                label: Text(_cardRecordId == null ? l.uploadCardPhoto : l.cardPhotoAdded),
              ),
              const SizedBox(height: Space.sm),
              Text(l.policyPrivacyNote, style: TextStyle(fontSize: 12, color: context.textMuted)),
              const SizedBox(height: Space.lg),
              PrimaryButton(key: const Key('policy-save'), label: l.save, loading: _busy, onPressed: _save),
            ],
          ),
        ),
      ),
    );
  }
}

class CashlessHospitalsScreen extends ConsumerWidget {
  const CashlessHospitalsScreen({super.key, required this.insurerCode, this.insurerName});
  final String insurerCode;
  final String? insurerName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.cashlessHospitals)),
      body: AsyncView<List<Facility>>(
        value: ref.watch(cashlessFacilitiesProvider(insurerCode)),
        onRetry: () => ref.invalidate(cashlessFacilitiesProvider(insurerCode)),
        isEmpty: (f) => f.isEmpty,
        empty: EmptyStateView(icon: Icons.local_hospital_outlined, title: l.noCashlessHospitals),
        data: (list) => ListView(
          padding: const EdgeInsets.all(Space.screen),
          children: [
            Text(l.cashlessIntro(insurerName ?? insurerCode), style: TextStyle(color: context.textMuted)),
            const SizedBox(height: Space.md),
            for (final f in list)
              Padding(padding: const EdgeInsets.only(bottom: Space.sm), child: FacilityCard(facility: f)),
            Text(l.cashlessVerifyNote, style: TextStyle(fontSize: 12, color: context.textMuted)),
          ],
        ),
      ),
    );
  }
}

class ClaimChecklistScreen extends ConsumerWidget {
  const ClaimChecklistScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l.claimChecklist),
          bottom: TabBar(tabs: [Tab(text: l.cashless), Tab(text: l.reimbursement)]),
        ),
        body: TabBarView(children: [
          for (final type in ['cashless', 'reimbursement'])
            AsyncView<ClaimChecklist>(
              value: ref.watch(claimChecklistProvider(type)),
              onRetry: () => ref.invalidate(claimChecklistProvider(type)),
              data: (c) => ListView(
                padding: const EdgeInsets.all(Space.screen),
                children: [
                  SectionHeader(title: l.claimSteps),
                  for (var i = 0; i < c.steps.length; i++)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(radius: 14, child: Text('${i + 1}', style: const TextStyle(fontSize: 12))),
                      title: Text(c.steps[i]),
                    ),
                  SectionHeader(title: l.documentsTypicallyNeeded),
                  for (final d in c.documents)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.description_outlined, color: AppColors.primaryLight),
                      title: Text(d),
                    ),
                  const SizedBox(height: Space.md),
                  if (c.disclaimer.isNotEmpty) NoticeBox(icon: Icons.info_outline, text: c.disclaimer),
                ],
              ),
            ),
        ]),
      ),
    );
  }
}
