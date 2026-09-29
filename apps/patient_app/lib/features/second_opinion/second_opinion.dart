import 'package:flutter/material.dart' hide Page;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_exception.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/pdf_viewer.dart';
import '../../core/widgets/state_views.dart';
import '../../core/widgets/status_timeline.dart' show NoticeBox;
import '../../l10n/app_localizations.dart';
import '../../models/care.dart';
import '../../models/json.dart';
import '../../models/patient.dart';
import '../../models/records.dart';
import '../../models/services.dart';
import '../../state/core_providers.dart';
import '../../state/data_providers.dart';
import '../../state/v13_providers.dart';
import '../offers/checkout_offers.dart';
import '../payments/payment_sheet.dart';

// Specialist second opinion (API_CONTRACT §49).

String opinionStatusLabel(AppLocalizations l, String s) => switch (s) {
      'pending_payment' => l.soPendingPayment,
      'open' => l.soOpen,
      'claimed' => l.soClaimed,
      'answered' => l.soAnswered,
      'cancelled' => l.soCancelled,
      _ => humanize(s),
    };

Color opinionStatusColor(String s) => switch (s) {
      'answered' => AppColors.primaryLight,
      'cancelled' => AppColors.danger,
      'pending_payment' => AppColors.peachFg,
      _ => AppColors.skyFg,
    };

/// Specialty display name from the specialties list, else humanized code.
String specialtyName(WidgetRef ref, String code) =>
    ref.watch(specialtiesProvider).value?.where((s) => s.code == code).firstOrNull?.name ?? humanize(code);

class SecondOpinionScreen extends ConsumerWidget {
  const SecondOpinionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.secondOpinion)),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('so-new'),
        onPressed: () => context.push('/second-opinion/new'),
        icon: const Icon(Icons.add),
        label: Text(l.requestSecondOpinion),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(secondOpinionsProvider.future),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Space.screen, Space.md, Space.screen, 96),
          children: [
            CcCard(
              color: context.lavenderSurface,
              child: Row(
                children: [
                  const IconTile(icon: Icons.rate_review_outlined, accent: Accent.lavender, size: 48),
                  const SizedBox(width: Space.md),
                  Expanded(child: Text(l.secondOpinionIntro)),
                ],
              ),
            ),
            SectionHeader(title: l.myRequests),
            AsyncView<List<SecondOpinion>>(
              value: ref.watch(secondOpinionsProvider),
              compact: true,
              onRetry: () => ref.invalidate(secondOpinionsProvider),
              isEmpty: (list) => list.isEmpty,
              empty: EmptyStateView(compact: true, icon: Icons.rate_review_outlined, title: l.noSecondOpinions),
              data: (list) => Column(
                children: [
                  for (final s in list)
                    ListRowTile(
                      icon: Icons.rate_review_outlined,
                      accent: Accent.lavender,
                      title: specialtyName(ref, s.specialty),
                      subtitle: [
                        opinionStatusLabel(l, s.status),
                        if (s.createdAt != null) fmtDate(context, s.createdAt!),
                      ].join(' · '),
                      onTap: () => context.push('/second-opinion/${s.id}'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class NewSecondOpinionScreen extends ConsumerStatefulWidget {
  const NewSecondOpinionScreen({super.key});

  @override
  ConsumerState<NewSecondOpinionScreen> createState() => _NewSecondOpinionScreenState();
}

class _NewSecondOpinionScreenState extends ConsumerState<NewSecondOpinionScreen> {
  String? _specialty;
  final _question = TextEditingController();
  final _records = <String>{};
  bool _consent = false;
  bool _busy = false;
  final _offers = CheckoutOffersController();
  final _action = IdempotentAction();
  SecondOpinion? _created;
  Payment? _payment;

  static const minQuestion = 20;

  @override
  void initState() {
    super.initState();
    _question.addListener(() => setState(() {}));
    _offers.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _question.dispose();
    _offers.dispose();
    super.dispose();
  }

  Future<void> _submit(PatientSummary patient) async {
    setState(() => _busy = true);
    try {
      final res = await ref.read(secondOpinionRepositoryProvider).create(
            patientId: patient.id,
            specialty: _specialty!,
            question: _question.text.trim(),
            recordIds: _records.toList(),
            couponCode: _offers.couponCode,
            useWallet: _offers.useWallet,
            idempotencyKey: _action.key,
          );
      _action.complete();
      setState(() {
        _created = res.item;
        _payment = res.payment;
      });
      await _pay();
    } on ApiException catch (e) {
      if (!e.isOffline) _action.complete();
      if (mounted) showSnack(context, errorMessage(context, e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pay() async {
    final l = context.l10n;
    final so = _created, p = _payment;
    if (so == null || p == null) return;
    final res = await showPaymentSheet(context, payment: p, title: l.secondOpinion);
    if (!mounted) return;
    ref.invalidate(secondOpinionsProvider);
    if (res != null && res.succeeded) {
      showSnack(context, l.secondOpinionSubmitted);
      context.pushReplacement('/second-opinion/${so.id}');
    } else {
      setState(() => _payment = res ?? p);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final patient = ref.watch(activePatientProvider).value;
    final canBook = patient?.can(FamilyPermission.book) ?? false;
    final pricing = ref.watch(secondOpinionPricingProvider);
    final price = pricing.value?.where((p) => p.specialty == _specialty).firstOrNull;
    final questionOk = _question.text.trim().length >= minQuestion;
    final ready = price != null && questionOk && _consent && canBook && _payment == null;
    final payable = _offers.breakdown(price?.price ?? 0).payable;
    return Scaffold(
      appBar: AppBar(title: Text(l.requestSecondOpinion)),
      body: AsyncView<List<SecondOpinionPrice>>(
        value: pricing,
        onRetry: () => ref.invalidate(secondOpinionPricingProvider),
        isEmpty: (list) => list.isEmpty,
        empty: EmptyStateView(icon: Icons.rate_review_outlined, title: l.secondOpinionUnavailable),
        data: (list) => Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(Space.screen),
                children: [
                  if (_payment != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: Space.md),
                      child: NoticeBox(
                        icon: Icons.error_outline,
                        title: _payment!.failed ? l.paymentFailedTitle : l.paymentPendingTitle,
                        text: l.paymentNotConfirmedBody,
                        action: FilledButton(
                            onPressed: _pay, child: Text(l.retryPaymentAmount(money(_payment!.amount)))),
                      ),
                    ),
                  Text(l.chooseSpecialty, style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: Space.sm),
                  RadioGroup<String>(
                    groupValue: _specialty,
                    onChanged: (v) => setState(() => _specialty = v),
                    child: Column(
                      children: [
                        for (final p in list)
                          Padding(
                            padding: const EdgeInsets.only(bottom: Space.sm),
                            child: CcCard(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              borderColor: _specialty == p.specialty ? AppColors.primary : null,
                              child: RadioListTile<String>(
                                key: Key('so-specialty-${p.specialty}'),
                                value: p.specialty,
                                title: Text(specialtyName(ref, p.specialty)),
                                subtitle: Text(l.opinionWithinHours(p.turnaroundHours)),
                                secondary: Text(money(p.price), style: const TextStyle(fontWeight: FontWeight.w800)),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  SectionHeader(title: l.yourQuestion),
                  TextField(
                    key: const Key('so-question'),
                    controller: _question,
                    maxLines: 5,
                    maxLength: 2000,
                    decoration: InputDecoration(hintText: l.yourQuestionHint),
                  ),
                  if (_question.text.isNotEmpty && !questionOk)
                    Text(l.questionTooShort(minQuestion), style: const TextStyle(color: AppColors.danger, fontSize: 12.5)),
                  SectionHeader(title: l.recordsToShare),
                  _RecordPicker(selected: _records, onChanged: () => setState(() {})),
                  const SizedBox(height: Space.md),
                  CcCard(
                    color: context.skySurface,
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    child: CheckboxListTile(
                      key: const Key('so-consent'),
                      value: _consent,
                      onChanged: (v) => setState(() => _consent = v ?? false),
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(l.secondOpinionConsent(_records.length)),
                    ),
                  ),
                  const SizedBox(height: Space.md),
                  if (price != null)
                    CheckoutOffersCard(controller: _offers, purpose: 'second_opinion', amount: price.price),
                  const SizedBox(height: Space.sm),
                  Text(l.secondOpinionDisclaimer, style: TextStyle(fontSize: 12, color: context.textMuted)),
                  if (!canBook && patient != null)
                    Text(l.noBookPermission, style: const TextStyle(color: AppColors.danger)),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(Space.screen, Space.sm, Space.screen, Space.md),
                child: PrimaryButton(
                  key: const Key('so-submit'),
                  label: price == null ? l.chooseSpecialty : l.payAmount(money(payable)),
                  loading: _busy,
                  onPressed: ready && patient != null ? () => _submit(patient) : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecordPicker extends ConsumerWidget {
  const _RecordPicker({required this.selected, required this.onChanged});
  final Set<String> selected;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return AsyncView<Page<MedicalRecord>>(
      value: ref.watch(recordsProvider(null)),
      compact: true,
      onRetry: () => ref.invalidate(recordsProvider(null)),
      isEmpty: (p) => p.items.isEmpty,
      empty: Text(l.noRecordsToShare, style: TextStyle(color: context.textMuted)),
      data: (p) => CcCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            for (final r in p.items)
              CheckboxListTile(
                key: Key('so-record-${r.id}'),
                value: selected.contains(r.id),
                onChanged: (v) {
                  if (v == true) {
                    selected.add(r.id);
                  } else {
                    selected.remove(r.id);
                  }
                  onChanged();
                },
                title: Text(r.title),
                subtitle: Text(fmtYmd(context, r.recordDate)),
              ),
          ],
        ),
      ),
    );
  }
}

class SecondOpinionDetailScreen extends ConsumerWidget {
  const SecondOpinionDetailScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.secondOpinion)),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(secondOpinionProvider(id).future),
        child: AsyncView<SecondOpinion>(
          value: ref.watch(secondOpinionProvider(id)),
          onRetry: () => ref.invalidate(secondOpinionProvider(id)),
          data: (s) => ListView(
            padding: const EdgeInsets.all(Space.screen),
            children: [
              CcCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                            child: Text(specialtyName(ref, s.specialty), style: Theme.of(context).textTheme.titleMedium)),
                        StatusPill(label: opinionStatusLabel(l, s.status), color: opinionStatusColor(s.status)),
                      ],
                    ),
                    const SizedBox(height: Space.sm),
                    if (s.doctorName != null) LabeledValue(label: l.specialist, value: s.doctorName!),
                    if (s.dueAt != null && !s.isAnswered)
                      LabeledValue(label: l.expectedBy, value: fmtDateTime(context, s.dueAt!)),
                    LabeledValue(label: l.fee, value: money(s.price)),
                  ],
                ),
              ),
              SectionHeader(title: l.yourQuestion),
              CcCard(child: Text(s.question)),
              if (s.records.isNotEmpty) ...[
                SectionHeader(title: l.recordsShared),
                for (final r in s.records)
                  ListRowTile(
                    icon: Icons.description_outlined,
                    accent: Accent.sky,
                    title: r.title,
                    onTap: () => context.push('/records/${r.id}'),
                  ),
              ],
              if (s.isAnswered) ...[
                SectionHeader(title: l.specialistOpinion),
                CcCard(
                  key: const Key('so-opinion'),
                  color: context.mintSurface,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (s.doctorName != null)
                        Text(l.opinionBy(s.doctorName!), style: const TextStyle(fontWeight: FontWeight.w700)),
                      if (s.answeredAt != null)
                        Text(fmtDateTime(context, s.answeredAt!), style: TextStyle(fontSize: 12, color: context.textMuted)),
                      const SizedBox(height: Space.sm),
                      Text(s.opinion ?? ''),
                      if (s.recommendations.isNotEmpty) ...[
                        const SizedBox(height: Space.md),
                        Text(l.recommendations, style: const TextStyle(fontWeight: FontWeight.w700)),
                        for (final r in s.recommendations)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              const Icon(Icons.check_circle, size: 18, color: AppColors.primaryLight),
                              const SizedBox(width: 8),
                              Expanded(child: Text(r)),
                            ]),
                          ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: Space.md),
                if (s.opinionRecordId != null)
                  OutlinedButton.icon(
                    onPressed: () => openPdf(context,
                        title: l.specialistOpinion,
                        fileName: 'second-opinion-${s.id}.pdf',
                        load: () => ref.read(recordsRepositoryProvider).file(s.opinionRecordId!)),
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    label: Text(l.viewPdf),
                  ),
                const SizedBox(height: Space.sm),
                OutlinedButton.icon(
                  onPressed: () => context.push(Uri(path: '/doctors', queryParameters: {'specialty': s.specialty}).toString()),
                  icon: const Icon(Icons.videocam_outlined),
                  label: Text(l.bookTeleconsult),
                ),
              ] else
                Padding(
                  padding: const EdgeInsets.only(top: Space.lg),
                  child: NoticeBox(icon: Icons.hourglass_top, color: AppColors.skyFg, text: l.opinionPendingBody),
                ),
              const SizedBox(height: Space.md),
              Text(l.secondOpinionDisclaimer, style: TextStyle(fontSize: 12, color: context.textMuted)),
            ],
          ),
        ),
      ),
    );
  }
}
