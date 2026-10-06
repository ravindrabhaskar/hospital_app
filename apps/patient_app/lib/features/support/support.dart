import 'dart:async';

import 'package:flutter/material.dart' hide Page;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_exception.dart';
import '../../core/config.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/format.dart';
import '../../core/utils/links.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/state_views.dart';
import '../../core/widgets/status_timeline.dart' show NoticeBox;
import '../../l10n/app_localizations.dart';
import '../../models/care.dart';
import '../../models/engagement_v13.dart';
import '../../models/json.dart';
import '../../models/records.dart';
import '../../state/data_providers.dart';
import '../../state/v13_providers.dart';

// Support desk (API_CONTRACT §61).

String ticketCategoryLabel(AppLocalizations l, String c) => switch (c) {
      'booking' => l.tcBooking,
      'payment' => l.tcPayment,
      'refund' => l.tcRefund,
      'app_issue' => l.tcAppIssue,
      'clinical_concern' => l.tcClinicalConcern,
      _ => l.tcOther,
    };

String ticketStatusLabel(AppLocalizations l, String s) => switch (s) {
      'open' => l.tsOpen,
      'pending_customer' => l.tsPendingCustomer,
      'resolved' => l.tsResolved,
      'closed' => l.tsClosed,
      _ => humanize(s),
    };

Color ticketStatusColor(String s) => switch (s) {
      'resolved' || 'closed' => AppColors.primaryLight,
      'pending_customer' => AppColors.peachFg,
      _ => AppColors.skyFg,
    };

/// The "care team will review" + Call 108 note for clinical concerns.
class ClinicalConcernNote extends StatelessWidget {
  const ClinicalConcernNote({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return NoticeBox(
      key: const Key('clinical-note'),
      icon: Icons.medical_services_outlined,
      color: AppColors.danger,
      title: l.clinicalConcernTitle,
      text: l.clinicalConcernBody,
      action: TextButton.icon(
        onPressed: () => openExternal(context, telUri(AppConfig.emergencyHelpline)),
        icon: const Icon(Icons.call, color: AppColors.danger),
        label: Text(l.callNumber(AppConfig.emergencyHelpline), style: const TextStyle(color: AppColors.danger)),
      ),
    );
  }
}

class TicketsScreen extends ConsumerWidget {
  const TicketsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.myTickets)),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('ticket-new'),
        onPressed: () => context.push('/support/new'),
        icon: const Icon(Icons.add),
        label: Text(l.newTicket),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(ticketsProvider.future),
        child: AsyncView<List<Ticket>>(
          value: ref.watch(ticketsProvider),
          onRetry: () => ref.invalidate(ticketsProvider),
          isEmpty: (t) => t.isEmpty,
          empty: ListView(children: [
            EmptyStateView(icon: Icons.support_agent, title: l.noTickets, message: l.noTicketsBody),
          ]),
          data: (list) => ListView(
            padding: const EdgeInsets.fromLTRB(Space.screen, Space.md, Space.screen, 96),
            children: [
              for (final t in list)
                ListRowTile(
                  icon: t.category == 'clinical_concern' ? Icons.medical_services_outlined : Icons.support_agent,
                  accent: t.category == 'clinical_concern' ? Accent.rose : Accent.sky,
                  title: t.subject,
                  subtitle: [t.number, ticketCategoryLabel(l, t.category), if (t.updatedAt != null) fmtDate(context, t.updatedAt!)]
                      .join(' · '),
                  trailing: StatusPill(label: ticketStatusLabel(l, t.status), color: ticketStatusColor(t.status)),
                  onTap: () => context.push('/support/tickets/${t.id}'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class NewTicketScreen extends ConsumerStatefulWidget {
  const NewTicketScreen({super.key});

  @override
  ConsumerState<NewTicketScreen> createState() => _NewTicketScreenState();
}

class _NewTicketScreenState extends ConsumerState<NewTicketScreen> {
  String _category = 'booking';
  final _subject = TextEditingController();
  final _message = TextEditingController();
  MedicalRecord? _attachment;
  ({String type, String id, String label})? _ref;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _subject.addListener(() => setState(() {}));
    _message.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _subject.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _pickRecord() async {
    final r = await showModalBottomSheet<MedicalRecord>(
      useRootNavigator: true,
      context: context,
      isScrollControlled: true,
      builder: (_) => const _RecordPickerSheet(),
    );
    if (r != null) setState(() => _attachment = r);
  }

  Future<void> _pickBooking() async {
    final r = await showModalBottomSheet<({String type, String id, String label})>(
      useRootNavigator: true,
      context: context,
      isScrollControlled: true,
      builder: (_) => const _BookingPickerSheet(),
    );
    if (r != null) setState(() => _ref = r);
  }

  Future<void> _submit() async {
    final l = context.l10n;
    setState(() => _busy = true);
    try {
      final t = await ref.read(supportRepositoryProvider).create(
            subject: _subject.text.trim(),
            category: _category,
            message: _message.text.trim(),
            refType: _ref?.type,
            refId: _ref?.id,
            attachmentRecordId: _attachment?.id,
          );
      ref.invalidate(ticketsProvider);
      if (!mounted) return;
      showSnack(context, l.ticketCreated(t.number));
      context.pushReplacement('/support/tickets/${t.id}');
    } on ApiException catch (e) {
      if (mounted) showSnack(context, errorMessage(context, e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final ready = _subject.text.trim().length >= 3 && _message.text.trim().length >= 5;
    return Scaffold(
      appBar: AppBar(title: Text(l.newTicket)),
      body: ListView(
        padding: const EdgeInsets.all(Space.screen),
        children: [
          Text(l.ticketCategory, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: Space.sm),
          Wrap(spacing: Space.sm, runSpacing: Space.sm, children: [
            for (final c in ticketCategories)
              ChoiceChip(
                key: Key('tc-$c'),
                label: Text(ticketCategoryLabel(l, c)),
                selected: _category == c,
                onSelected: (_) => setState(() => _category = c),
              ),
          ]),
          if (_category == 'clinical_concern') ...[const SizedBox(height: Space.md), const ClinicalConcernNote()],
          const SizedBox(height: Space.lg),
          TextField(
            key: const Key('ticket-subject'),
            controller: _subject,
            maxLength: 120,
            decoration: InputDecoration(labelText: l.subject),
          ),
          const SizedBox(height: Space.sm),
          TextField(
            key: const Key('ticket-message'),
            controller: _message,
            maxLines: 5,
            maxLength: 2000,
            decoration: InputDecoration(labelText: l.describeIssue),
          ),
          const SizedBox(height: Space.sm),
          ListTile(
            minTileHeight: 56,
            leading: const Icon(Icons.attach_file),
            title: Text(_attachment?.title ?? l.attachRecord),
            trailing: _attachment == null
                ? const Icon(Icons.chevron_right)
                : IconButton(tooltip: l.remove, onPressed: () => setState(() => _attachment = null), icon: const Icon(Icons.close)),
            onTap: _pickRecord,
          ),
          ListTile(
            minTileHeight: 56,
            leading: const Icon(Icons.event_note_outlined),
            title: Text(_ref?.label ?? l.linkBooking),
            trailing: _ref == null
                ? const Icon(Icons.chevron_right)
                : IconButton(tooltip: l.remove, onPressed: () => setState(() => _ref = null), icon: const Icon(Icons.close)),
            onTap: _pickBooking,
          ),
          const SizedBox(height: Space.lg),
          PrimaryButton(key: const Key('ticket-submit'), label: l.submitTicket, loading: _busy, onPressed: ready ? _submit : null),
          const SizedBox(height: Space.md),
          Text(l.supportNotForEmergencies, style: TextStyle(fontSize: 12, color: context.textMuted)),
        ],
      ),
    );
  }
}

class _RecordPickerSheet extends ConsumerWidget {
  const _RecordPickerSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.6,
        child: AsyncView<Page<MedicalRecord>>(
          value: ref.watch(recordsProvider(null)),
          onRetry: () => ref.invalidate(recordsProvider(null)),
          isEmpty: (p) => p.items.isEmpty,
          empty: EmptyStateView(compact: true, icon: Icons.folder_open, title: l.noRecordsTitle),
          data: (p) => ListView(children: [
            for (final r in p.items)
              ListTile(
                leading: const Icon(Icons.description_outlined),
                title: Text(r.title),
                subtitle: Text(fmtYmd(context, r.recordDate)),
                onTap: () => Navigator.pop(context, r),
              ),
          ]),
        ),
      ),
    );
  }
}

class _BookingPickerSheet extends ConsumerWidget {
  const _BookingPickerSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final appts = ref.watch(appointmentsProvider('upcoming')).value?.items ?? const <Appointment>[];
    final past = ref.watch(appointmentsProvider('past')).value?.items ?? const <Appointment>[];
    final visits = ref.watch(homeVisitsProvider('active')).value ?? const <HomeVisit>[];
    final items = <({String type, String id, String label})>[
      for (final a in [...appts, ...past].take(10))
        (type: 'appointment', id: a.id, label: '${a.doctorName} · ${fmtDate(context, a.startAt)}'),
      for (final v in visits.take(10))
        (type: 'home_visit', id: v.id, label: '${v.serviceName} · ${fmtDate(context, v.preferredStart)}'),
    ];
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.6,
        child: items.isEmpty
            ? EmptyStateView(compact: true, icon: Icons.event_busy, title: l.noBookingsToLink)
            : ListView(children: [
                for (final i in items)
                  ListTile(
                    leading: Icon(i.type == 'appointment' ? Icons.videocam_outlined : Icons.home_outlined),
                    title: Text(i.label),
                    onTap: () => Navigator.pop(context, i),
                  ),
              ]),
      ),
    );
  }
}

/// Conversation view; polls the ticket every 15 s while open.
class TicketScreen extends ConsumerStatefulWidget {
  const TicketScreen({super.key, required this.id});
  final String id;

  @override
  ConsumerState<TicketScreen> createState() => _TicketScreenState();
}

class _TicketScreenState extends ConsumerState<TicketScreen> with WidgetsBindingObserver {
  Ticket? _ticket;
  Object? _error;
  Timer? _timer;
  bool _polling = false;
  bool _sending = false;
  final _input = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _input.addListener(() => setState(() {}));
    _poll();
    _start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _input.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) {
      _start();
      _poll();
    } else if (s == AppLifecycleState.paused || s == AppLifecycleState.hidden) {
      _timer?.cancel();
    }
  }

  void _start() {
    _timer?.cancel();
    _timer = Timer.periodic(ref.read(ticketPollIntervalProvider), (_) => _poll());
  }

  Future<void> _poll() async {
    if (_polling) return;
    _polling = true;
    try {
      final t = await ref.read(supportRepositoryProvider).get(widget.id);
      if (mounted) {
        setState(() {
          _ticket = t;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted && _ticket == null) setState(() => _error = e);
    } finally {
      _polling = false;
    }
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    try {
      await ref.read(supportRepositoryProvider).send(widget.id, text);
      _input.clear();
      await _poll();
    } on ApiException catch (e) {
      if (mounted) showSnack(context, errorMessage(context, e), error: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _rate() async {
    final updated = await showModalBottomSheet<Ticket>(
      useRootNavigator: true,
      context: context,
      isScrollControlled: true,
      builder: (_) => RateTicketSheet(ticketId: widget.id),
    );
    if (updated != null && mounted) {
      setState(() => _ticket = updated);
      ref.invalidate(ticketsProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = _ticket;
    return Scaffold(
      appBar: AppBar(title: Text(t?.number ?? l.supportTicket)),
      body: t == null
          ? (_error != null
              ? ErrorStateView(error: _error!, onRetry: _poll)
              : const LoadingView())
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(Space.screen),
                    children: [
                      CcCard(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Expanded(child: Text(t.subject, style: Theme.of(context).textTheme.titleSmall)),
                            StatusPill(label: ticketStatusLabel(l, t.status), color: ticketStatusColor(t.status)),
                          ]),
                          Text([ticketCategoryLabel(l, t.category), if (t.assignedToName != null) l.handledBy(t.assignedToName!)]
                              .join(' · '),
                              style: TextStyle(fontSize: 12.5, color: context.textMuted)),
                        ]),
                      ),
                      if (t.category == 'clinical_concern') ...[const SizedBox(height: Space.md), const ClinicalConcernNote()],
                      const SizedBox(height: Space.md),
                      for (final m in t.visibleMessages) TicketBubble(message: m),
                      if (t.canRate) ...[
                        const SizedBox(height: Space.md),
                        PrimaryButton(key: const Key('ticket-rate'), icon: Icons.star_outline, label: l.rateSupport, onPressed: _rate),
                      ] else if (t.ratingScore != null)
                        Padding(
                          padding: const EdgeInsets.only(top: Space.md),
                          child: Text(l.youRated(t.ratingScore!), textAlign: TextAlign.center),
                        ),
                    ],
                  ),
                ),
                if (!t.isResolved)
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(Space.md, Space.sm, Space.sm, Space.sm),
                      child: Row(children: [
                        Expanded(
                          child: TextField(
                            key: const Key('ticket-input'),
                            controller: _input,
                            minLines: 1,
                            maxLines: 4,
                            decoration: InputDecoration(hintText: l.messageHint),
                          ),
                        ),
                        IconButton.filled(
                          key: const Key('ticket-send'),
                          tooltip: l.send,
                          onPressed: _sending || _input.text.trim().isEmpty ? null : _send,
                          icon: const Icon(Icons.send),
                        ),
                      ]),
                    ),
                  ),
              ],
            ),
    );
  }
}

class TicketBubble extends StatelessWidget {
  const TicketBubble({super.key, required this.message});
  final TicketMessage message;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final m = message;
    final mine = m.isMine;
    final system = m.authorRole == 'system';
    return Align(
      alignment: system ? Alignment.center : (mine ? Alignment.centerRight : Alignment.centerLeft),
      child: Container(
        margin: const EdgeInsets.only(bottom: Space.sm),
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.8),
        padding: const EdgeInsets.all(Space.md),
        decoration: BoxDecoration(
          color: system ? context.skySurface : (mine ? context.mintSurface : context.surface),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.borderColor),
        ),
        child: Semantics(
          label: mine ? l.youSaid(m.text) : l.senderSaid(m.authorName, m.text),
          excludeSemantics: true,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (!mine) Text(m.authorName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
            Text(m.text),
            if (m.at != null) Text(fmtTime(context, m.at!), style: TextStyle(fontSize: 11, color: context.textMuted)),
          ]),
        ),
      ),
    );
  }
}

class RateTicketSheet extends ConsumerStatefulWidget {
  const RateTicketSheet({super.key, required this.ticketId});
  final String ticketId;

  @override
  ConsumerState<RateTicketSheet> createState() => _RateTicketSheetState();
}

class _RateTicketSheetState extends ConsumerState<RateTicketSheet> {
  int _score = 0;
  final _comment = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    try {
      final t = await ref.read(supportRepositoryProvider).rate(widget.ticketId, _score, comment: _comment.text);
      if (mounted) Navigator.pop(context, t);
    } on ApiException catch (e) {
      if (mounted) showSnack(context, errorMessage(context, e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(Space.screen, 0, Space.screen, Space.lg + MediaQuery.viewInsetsOf(context).bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(l.rateSupport, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: Space.md),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (var i = 1; i <= 5; i++)
              IconButton(
                key: Key('ticket-star-$i'),
                tooltip: l.rateStars(i),
                onPressed: () => setState(() => _score = i),
                icon: Icon(i <= _score ? Icons.star : Icons.star_border, color: AppColors.warning, size: 34),
              ),
          ]),
          TextField(controller: _comment, maxLength: 500, decoration: InputDecoration(labelText: l.reviewCommentOptional)),
          const SizedBox(height: Space.md),
          PrimaryButton(key: const Key('ticket-rate-submit'), label: l.submitReview, loading: _busy, onPressed: _score == 0 ? null : _submit),
        ]),
      ),
    );
  }
}

/// Parses a ticket from JSON (used by tests and deep links).
Ticket ticketFromJson(Json j) => Ticket.fromJson(j);
