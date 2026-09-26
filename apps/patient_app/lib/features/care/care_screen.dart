import 'package:flutter/material.dart' hide Page;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/tokens.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/load_more.dart';
import '../../core/widgets/state_views.dart';
import '../../models/care.dart';
import '../../models/json.dart';
import '../../state/core_providers.dart';
import '../../state/data_providers.dart';
import '../home/home_screen.dart' show EpisodeCard;
import 'care_widgets.dart';

const careTabs = ['episodes', 'appointments', 'visits', 'plans', 'meds'];

class CareScreen extends StatefulWidget {
  const CareScreen({super.key, this.initialTab});
  final String? initialTab;

  @override
  State<CareScreen> createState() => _CareScreenState();
}

class _CareScreenState extends State<CareScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(
    length: careTabs.length,
    vsync: this,
    initialIndex: careTabs.indexOf(widget.initialTab ?? '').clamp(0, careTabs.length - 1),
  );

  @override
  void didUpdateWidget(covariant CareScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final i = careTabs.indexOf(widget.initialTab ?? '');
    if (i >= 0 && widget.initialTab != oldWidget.initialTab) _tabs.animateTo(i);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.navCare),
        automaticallyImplyLeading: false,
        actions: const [InboxAction()],
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            Tab(text: l.careEpisodes),
            Tab(text: l.appointments),
            Tab(text: l.homeVisits),
            Tab(text: l.carePlans),
            Tab(text: l.medications),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [
          _EpisodesTab(),
          _AppointmentsTab(),
          _VisitsTab(),
          _PlansTab(),
          _MedsTab(),
        ],
      ),
    );
  }
}

class _EpisodesTab extends ConsumerWidget {
  const _EpisodesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return RefreshIndicator(
      onRefresh: () => ref.refresh(allEpisodesProvider.future),
      child: AsyncView<List<CareEpisode>>(
        value: ref.watch(allEpisodesProvider),
        onRetry: () => ref.invalidate(allEpisodesProvider),
        isEmpty: (l) => l.isEmpty,
        empty: EmptyStateView(
          icon: Icons.favorite_border,
          title: l.noEpisodesTitle,
          message: l.noEpisodesMessage,
          actionLabel: l.askAiNow,
          onAction: () => context.go('/ai'),
        ),
        data: (list) {
          const terminal = ['RESOLVED', 'CANCELLED', 'TRANSFERRED'];
          final active = list.where((e) => !terminal.contains(e.status)).toList();
          final closed = list.where((e) => terminal.contains(e.status)).toList();
          return ListView(
            padding: const EdgeInsets.all(Space.screen),
            children: [
              if (active.isNotEmpty) SectionHeader(title: l.active),
              for (final e in active) EpisodeCard(episode: e),
              if (closed.isNotEmpty) SectionHeader(title: l.closed),
              for (final e in closed) EpisodeCard(episode: e),
            ],
          );
        },
      ),
    );
  }
}

class _AppointmentsTab extends ConsumerStatefulWidget {
  const _AppointmentsTab();

  @override
  ConsumerState<_AppointmentsTab> createState() => _AppointmentsTabState();
}

class _AppointmentsTabState extends ConsumerState<_AppointmentsTab> {
  String _scope = 'upcoming';

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final v = ref.watch(appointmentsProvider(_scope));
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.screen, Space.md, Space.screen, 0),
          child: SegmentedButton<String>(
            segments: [
              ButtonSegment(value: 'upcoming', label: Text(l.upcoming)),
              ButtonSegment(value: 'past', label: Text(l.past)),
            ],
            selected: {_scope},
            onSelectionChanged: (s) => setState(() => _scope = s.first),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => ref.refresh(appointmentsProvider(_scope).future),
            child: AsyncView<Page<Appointment>>(
              value: v,
              onRetry: () => ref.invalidate(appointmentsProvider(_scope)),
              isEmpty: (p) => p.items.isEmpty,
              empty: EmptyStateView(
                icon: Icons.event_available_outlined,
                title: _scope == 'upcoming' ? l.noUpcomingAppointments : l.noPastAppointments,
                actionLabel: l.bookDoctor,
                onAction: () => context.push('/doctors'),
              ),
              data: (page) {
                final scope = _scope;
                return PagedItems<Appointment>(
                  first: page.items,
                  nextCursor: page.nextCursor,
                  fetch: (cursor) async => ref.read(appointmentRepositoryProvider).page(
                      (await ref.read(activePatientProvider.future)).id, scope,
                      cursor: cursor),
                  builder: (context, list, footer) => ListView(
                    padding: const EdgeInsets.all(Space.screen),
                    children: [for (final a in list) AppointmentCard(appointment: a), ?footer],
                  ),
                );
              },
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Space.screen, 0, Space.screen, Space.md),
            child: PrimaryButton(
              label: l.bookDoctor,
              icon: Icons.add,
              onPressed: () => context.push('/doctors'),
            ),
          ),
        ),
      ],
    );
  }
}

class _VisitsTab extends ConsumerStatefulWidget {
  const _VisitsTab();

  @override
  ConsumerState<_VisitsTab> createState() => _VisitsTabState();
}

class _VisitsTabState extends ConsumerState<_VisitsTab> {
  String _scope = 'active';

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final v = ref.watch(homeVisitsProvider(_scope));
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.screen, Space.md, Space.screen, 0),
          child: SegmentedButton<String>(
            segments: [
              ButtonSegment(value: 'active', label: Text(l.active)),
              ButtonSegment(value: 'past', label: Text(l.past)),
            ],
            selected: {_scope},
            onSelectionChanged: (s) => setState(() => _scope = s.first),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => ref.refresh(homeVisitsProvider(_scope).future),
            child: AsyncView<List<HomeVisit>>(
              value: v,
              onRetry: () => ref.invalidate(homeVisitsProvider(_scope)),
              isEmpty: (l) => l.isEmpty,
              empty: EmptyStateView(
                icon: Icons.home_outlined,
                title: l.noHomeVisits,
                actionLabel: l.bookHomeCheckup,
                onAction: () => context.push('/home-checkup'),
              ),
              data: (list) => ListView(
                padding: const EdgeInsets.all(Space.screen),
                children: [for (final h in list) HomeVisitCard(visit: h)],
              ),
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Space.screen, 0, Space.screen, Space.md),
            child: PrimaryButton(
              label: l.bookHomeCheckup,
              icon: Icons.add,
              onPressed: () => context.push('/home-checkup'),
            ),
          ),
        ),
      ],
    );
  }
}

class _PlansTab extends ConsumerWidget {
  const _PlansTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final plans = ref.watch(carePlansProvider);
    final tasks = ref.watch(careTasksProvider);
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(careTasksProvider);
        ref.invalidate(carePlansProvider);
        await ref.read(carePlansProvider.future);
      },
      child: ListView(
        padding: const EdgeInsets.all(Space.screen),
        children: [
          AsyncView<List<CarePlan>>(
            value: plans,
            compact: true,
            onRetry: () => ref.invalidate(carePlansProvider),
            isEmpty: (l) => l.isEmpty,
            empty: EmptyStateView(
              compact: true,
              icon: Icons.assignment_outlined,
              title: l.noCarePlansTitle,
              message: l.noCarePlansMessage,
            ),
            data: (list) => Column(
              children: [
                for (final p in list)
                  ListRowTile(
                    icon: Icons.assignment_outlined,
                    accent: p.status == 'active' ? Accent.teal : Accent.sky,
                    title: p.summary.isEmpty ? l.carePlan : p.summary,
                    subtitle: '${p.doctorName} · ${p.status == 'active' ? l.active : l.closed}',
                    onTap: () => context.push('/care-plans/${p.id}'),
                  ),
              ],
            ),
          ),
          SectionHeader(title: l.openTasks),
          AsyncView<List<CareTask>>(
            value: tasks,
            compact: true,
            onRetry: () => ref.invalidate(careTasksProvider),
            isEmpty: (l) => l.where((t) => t.isOpen).isEmpty,
            empty: EmptyStateView(compact: true, icon: Icons.task_alt, title: l.noOpenTasks),
            data: (list) => Column(
              children: [for (final t in list.where((t) => t.isOpen)) TaskTile(task: t)],
            ),
          ),
        ],
      ),
    );
  }
}

class _MedsTab extends ConsumerWidget {
  const _MedsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) => const MedicationsBody();
}

class MedicationsBody extends ConsumerWidget {
  const MedicationsBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => ref.refresh(medicationsProvider.future),
            child: AsyncView<List<Medication>>(
              value: ref.watch(medicationsProvider),
              onRetry: () => ref.invalidate(medicationsProvider),
              isEmpty: (l) => l.isEmpty,
              empty: EmptyStateView(
                  icon: Icons.medication_outlined, title: l.noMedications, message: l.noMedicationsMessage),
              data: (list) => ListView(
                padding: const EdgeInsets.all(Space.screen),
                children: [
                  Text(l.todaysDoses, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: Space.sm),
                  for (final m in list) MedicationCard(medication: m),
                ],
              ),
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Space.screen, 0, Space.screen, Space.md),
            child: PrimaryButton(
              label: l.addMedication,
              icon: Icons.add,
              onPressed: () => context.push('/medications/add'),
            ),
          ),
        ),
      ],
    );
  }
}

/// App-bar shortcut to the care-team inbox with an unread badge.
class InboxAction extends ConsumerWidget {
  const InboxAction({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final unread = ref.watch(inboxUnreadProvider);
    return IconButton(
      key: const Key('care-inbox'),
      tooltip: unread > 0 ? l.inboxUnread(unread) : l.inbox,
      onPressed: () => context.push('/inbox'),
      icon: Badge(
        isLabelVisible: unread > 0,
        label: Text(unread > 99 ? '99+' : '$unread'),
        child: const Icon(Icons.forum_outlined),
      ),
    );
  }
}
