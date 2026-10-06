import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/theme.dart';
import '../../../models/home_visit.dart';
import '../../../ui/l10n_helpers.dart';
import '../../../ui/widgets.dart';
import '../../field/attendance_screen.dart';
import '../../field/location_permission_banner.dart';
import '../../field/route_view.dart';
import '../../profile/profile_photo.dart';
import '../data/provider_repository.dart';
import '../data/visit_providers.dart';
import '../domain/visit_lifecycle.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Location: explain first, ask at most once automatically.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) maybePromptForLocation(context, ref);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final auth = ref.watch(authControllerProvider);
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: ListenableBuilder(
            listenable: auth,
            builder: (context, _) => Text(
              l.homeGreeting(auth.profile?.name ?? auth.me?.name ?? ''),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          actions: [
            IconButton(
              tooltip: l.earnTitle,
              icon: const Icon(Icons.account_balance_wallet_outlined),
              onPressed: () => context.push('/earnings'),
            ),
            ListenableBuilder(
              listenable: auth,
              builder: (context, _) => IconButton(
                tooltip: l.profileTooltip,
                icon: auth.photoUrl == null
                    ? const Icon(Icons.account_circle_outlined)
                    : ProviderAvatar(name: auth.profile?.name ?? '', photoUrl: auth.photoUrl, radius: 14),
                onPressed: () => context.push('/profile'),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: NestedScrollView(
          headerSliverBuilder: (context, _) => [
            const SliverToBoxAdapter(child: SyncBanners()),
            const SliverToBoxAdapter(child: _CredentialWarning()),
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(AppSpacing.screen, 12, AppSpacing.screen, 0),
                child: _DutyCard(),
              ),
            ),
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(AppSpacing.screen, 8, AppSpacing.screen, 0),
                child: AttendanceCard(),
              ),
            ),
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(AppSpacing.screen, 8, AppSpacing.screen, 4),
                child: _TodaySummary(),
              ),
            ),
            SliverToBoxAdapter(
              child: _HomeTabBar(labels: [l.tabToday, l.tabUpcoming, l.tabCompleted, l.tabRoute]),
            ),
          ],
          body: const TabBarView(
            children: [
              _VisitList(scope: VisitScope.today),
              _VisitList(scope: VisitScope.upcoming),
              _VisitList(scope: VisitScope.completed),
              RouteView(),
            ],
          ),
        ),
      ),
    );
  }
}

/// Home tabs. Equal-width tabs when every label fits; otherwise (narrow
/// phone, large font, long translation) a scrollable bar, so labels are
/// never cut ("Upcomi…").
class _HomeTabBar extends StatelessWidget {
  const _HomeTabBar({required this.labels});
  final List<String> labels;

  static const _labelPadding = 16.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.tabBarTheme.labelStyle ?? theme.textTheme.titleSmall;
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    return LayoutBuilder(builder: (context, constraints) {
      var widest = 0.0;
      for (final label in labels) {
        final painter = TextPainter(
          text: TextSpan(text: label, style: style),
          textScaler: scaler,
          textDirection: direction,
          maxLines: 1,
        )..layout();
        if (painter.width > widest) widest = painter.width;
        painter.dispose();
      }
      final fits = (widest + 2 * _labelPadding + 1) * labels.length <= constraints.maxWidth;
      return TabBar(
        isScrollable: !fits,
        tabAlignment: fits ? null : TabAlignment.start,
        tabs: [
          for (var i = 0; i < labels.length; i++)
            Tab(key: i == labels.length - 1 ? const Key('tabRoute') : null, text: labels[i]),
        ],
      );
    });
  }
}

/// Credential expiring within 30 days (also shown on Profile).
class _CredentialWarning extends ConsumerWidget {
  const _CredentialWarning();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    return ListenableBuilder(
      listenable: auth,
      builder: (context, _) {
        final p = auth.profile;
        final now = ref.read(clockProvider)();
        final days = p?.daysUntilCredentialExpiry(now);
        if (p == null || days == null || !p.credentialExpiringSoon(now)) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 12, AppSpacing.screen, 0),
          child: CredentialExpiryBanner(
            key: const Key('homeCredentialWarning'),
            days: days,
            onTap: () => context.push('/profile'),
          ),
        );
      },
    );
  }
}

class _DutyCard extends ConsumerStatefulWidget {
  const _DutyCard();

  @override
  ConsumerState<_DutyCard> createState() => _DutyCardState();
}

class _DutyCardState extends ConsumerState<_DutyCard> {
  bool _busy = false;

  Future<void> _toggle(bool value) async {
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await ref.read(authControllerProvider).setDuty(value);
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l.homeDutyFailed)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final auth = ref.watch(authControllerProvider);
    return ListenableBuilder(
      listenable: auth,
      builder: (context, _) {
        final onDuty = auth.profile?.onDuty ?? false;
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: onDuty ? [AppColors.mint50, AppColors.mint100] : [AppColors.surface, AppColors.surface],
            ),
            borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
            border: Border.all(color: AppColors.border),
          ),
          child: MergeSemantics(
            child: Row(
              children: [
                Icon(onDuty ? Icons.directions_walk : Icons.bedtime_outlined,
                    color: onDuty ? AppColors.primary : AppColors.textSecondary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(onDuty ? l.homeDutyOn : l.homeDutyOff, style: Theme.of(context).textTheme.titleMedium),
                      Text(onDuty ? l.homeDutyOnHint : l.homeDutyOffHint,
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                    ],
                  ),
                ),
                if (_busy)
                  const SizedBox(
                      width: 48, height: 48, child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2)))
                else
                  Semantics(
                    label: l.homeDutyToggleLabel,
                    child: Switch(
                      key: const Key('dutySwitch'),
                      value: onDuty,
                      onChanged: _toggle,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TodaySummary extends ConsumerWidget {
  const _TodaySummary();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final today = ref.watch(visitListProvider(VisitScope.today));
    final visits = today.value?.visits ?? const <HomeVisit>[];
    final active = visits.where((v) => VisitLifecycle.isActive(v.status)).toList();
    final done = visits.where((v) => v.status == VisitStatus.completed).length;
    final next = active.isEmpty ? null : active.first;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(child: _Stat(label: l.homeSummaryTotal, value: today.hasValue ? '${visits.length}' : '–')),
            Expanded(child: _Stat(label: l.homeSummaryActive, value: today.hasValue ? '${active.length}' : '–')),
            Expanded(child: _Stat(label: l.homeSummaryDone, value: today.hasValue ? '$done' : '–')),
            if (next != null)
              Flexible(
                flex: 2,
                child: Text(
                  l.homeNextVisit(formatTime(context, next.preferredStart)),
                  textAlign: TextAlign.end,
                  style: const TextStyle(color: AppColors.primaryLight, fontWeight: FontWeight.w600),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => MergeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: Theme.of(context).textTheme.titleLarge),
            Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ],
        ),
      );
}

class _VisitList extends ConsumerWidget {
  const _VisitList({required this.scope});
  final VisitScope scope;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final async = ref.watch(visitListProvider(scope));
    Future<void> refresh() => ref.refresh(visitListProvider(scope).future).then((_) {}, onError: (_) {});

    return async.when(
      loading: () => const LoadingView(),
      error: (e, _) => ErrorView(message: errorMessage(l, e), onRetry: refresh),
      data: (result) {
        if (result.visits.isEmpty) {
          final msg = switch (scope) {
            VisitScope.today => l.visitsEmptyToday,
            VisitScope.upcoming => l.visitsEmptyUpcoming,
            VisitScope.completed => l.visitsEmptyCompleted,
          };
          return RefreshIndicator(
            onRefresh: refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [const SizedBox(height: 40), EmptyView(message: msg)],
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: refresh,
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 12, AppSpacing.screen, 24),
            itemCount: result.visits.length + (result.fromCache ? 1 : 0),
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              if (result.fromCache && i == 0) {
                return Text(l.visitsShowingCached,
                    style: const TextStyle(color: AppColors.textSecondary, fontStyle: FontStyle.italic));
              }
              final visit = result.visits[i - (result.fromCache ? 1 : 0)];
              return VisitCard(visit: visit, showDate: scope != VisitScope.today);
            },
          ),
        );
      },
    );
  }
}

class VisitCard extends StatelessWidget {
  const VisitCard({super.key, required this.visit, this.showDate = true});
  final HomeVisit visit;
  final bool showDate;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final window = formatWindow(context, visit.preferredStart, visit.preferredEnd, withDate: showDate);
    final area = l.visitAreaOnly(visit.address.city, visit.address.pincode);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Semantics(
        button: true,
        label: '${visit.serviceName}, $window, $area, ${visitStatusLabel(l, visit.status)}',
        excludeSemantics: true,
        child: InkWell(
          onTap: () => context.push('/visits/${visit.id}'),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.mint100,
                      borderRadius: BorderRadius.circular(AppSpacing.tileRadius),
                    ),
                    child: Icon(_serviceIcon(visit.serviceCode), color: AppColors.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(visit.serviceName, style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 2),
                        Text(window, style: const TextStyle(color: AppColors.textSecondary)),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(Icons.place_outlined, size: 16, color: AppColors.textSecondary),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(area,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: AppColors.textSecondary)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      StatusChip(status: visit.status),
                      if (visit.pendingSync) ...[
                        const SizedBox(height: 6),
                        const Icon(Icons.sync, size: 18, color: AppColors.sky),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

IconData _serviceIcon(String code) {
  switch (code) {
    case 'sample_collection':
      return Icons.science_outlined;
    case 'elderly_care':
      return Icons.elderly;
    case 'post_report_consult':
      return Icons.assignment_outlined;
    case 'physiotherapy':
      return Icons.accessibility_new;
    default:
      return Icons.monitor_heart_outlined;
  }
}
