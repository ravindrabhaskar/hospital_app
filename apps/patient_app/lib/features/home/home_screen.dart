import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/tokens.dart';
import '../../core/utils/format.dart';
import '../../core/utils/labels.dart';
import '../../core/widgets/branding.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/illustrations.dart';
import '../../core/widgets/state_views.dart';
import '../../models/care.dart';
import '../../models/config.dart';
import '../../models/misc.dart';
import '../../models/patient.dart';
import '../../state/core_providers.dart';
import '../../state/data_providers.dart';
import '../../state/v13_providers.dart';
import '../care/dose_display.dart';
import '../checkin/checkin.dart';
import '../messages/inbox_screen.dart' show UnreadBadge;
import '../programs/programs.dart' show MyProgramsSection;
import '../reviews/review_prompt.dart';
import 'family_switcher.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(patientsProvider);
    ref.invalidate(remindersTodayProvider);
    ref.invalidate(activeEpisodesProvider);
    ref.invalidate(insightsTodayProvider);
    ref.invalidate(notificationsProvider);
    ref.invalidate(inboxProvider);
    ref.invalidate(pendingReviewsProvider);
    ref.invalidate(checkinSettingsProvider);
    ref.invalidate(checkinHistoryProvider);
    ref.invalidate(enrollmentsProvider);
    try {
      await ref.read(activePatientProvider.future);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(activePatientProvider);
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => _refresh(ref),
        child: CustomScrollView(
          slivers: [
            const SliverToBoxAdapter(child: HomeHeader()),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: Space.screen),
              sliver: SliverList.list(children: [
                const AiHeroCard(),
                const DailyCheckinCard(),
                const SizedBox(height: Space.xl),
                const QuickActionsRow(),
                const SizedBox(height: Space.xl),
                const CareBanner(),
                const QuickAccessGrid(),
                if (active.hasError)
                  ErrorStateView(
                      compact: true, error: active.error!, onRetry: () => _refresh(ref))
                else ...const [
                  ReviewPromptHost(),
                  MyProgramsSection(),
                  RemindersSection(),
                  ActiveEpisodesSection(),
                  InsightsSection(),
                ],
                const SizedBox(height: Space.xxl),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

String greetingFor(BuildContext context, DateTime now) {
  final l = context.l10n;
  final h = now.hour;
  if (h < 12) return l.goodMorning;
  if (h < 17) return l.goodAfternoon;
  return l.goodEvening;
}

class HomeHeader extends ConsumerWidget {
  const HomeHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final me = ref.watch(sessionProvider).me;
    final active = ref.watch(activePatientProvider).value;
    final unread = ref.watch(notificationsProvider).value?.unreadCount ?? 0;
    final unreadMessages = ref.watch(inboxUnreadProvider);
    final firstName = (me?.name ?? '').trim().split(' ').first;
    final top = MediaQuery.paddingOf(context).top;
    return Stack(
      children: [
        const Positioned.fill(child: MintHillsBackground()),
        Padding(
          padding: EdgeInsets.fromLTRB(Space.screen, top + Space.lg, Space.md, Space.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const TenantLogo(size: 28),
                        // Single line each: shrink rather than wrap when the action icons leave little room.
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text('${greetingFor(context, DateTime.now())},',
                              maxLines: 1,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w500)),
                        ),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            firstName.isEmpty ? '👋' : '$firstName 👋',
                            maxLines: 1,
                            style: Theme.of(context).textTheme.displaySmall?.copyWith(fontSize: 32),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(l.yourHealthOurPriority,
                            style: TextStyle(color: context.textMuted, fontSize: 15)),
                      ],
                    ),
                  ),
                  _CircleAction(
                    icon: Icons.search,
                    label: l.search,
                    onTap: () => context.push('/search'),
                  ),
                  const SizedBox(width: 4),
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      _CircleAction(
                        key: const Key('home-inbox'),
                        icon: Icons.chat_bubble_outline_rounded,
                        label: unreadMessages > 0 ? l.inboxUnread(unreadMessages) : l.inbox,
                        onTap: () => context.push('/inbox'),
                      ),
                      if (unreadMessages > 0)
                        Positioned(
                          right: -2,
                          top: -2,
                          child: ExcludeSemantics(child: UnreadBadge(count: unreadMessages)),
                        ),
                    ],
                  ),
                  const SizedBox(width: 4),
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      _CircleAction(
                        icon: Icons.notifications_none_rounded,
                        label: unread > 0 ? l.notificationsUnread(unread) : l.notifications,
                        onTap: () => context.push('/notifications'),
                      ),
                      if (unread > 0)
                        Positioned(
                          right: 11,
                          top: 9,
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: AppColors.danger,
                              shape: BoxShape.circle,
                              border: Border.all(color: context.surface, width: 1.5),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 4),
                  Semantics(
                    button: true,
                    label: l.switchFamilyMember,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => showFamilySwitcher(context),
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: context.surface, width: 2),
                          boxShadow: context.isDark ? null : Shadows.card,
                        ),
                        child: Avatar(
                            name: active?.name ?? me?.name ?? '?', url: active?.avatarUrl, size: 44),
                      ),
                    ),
                  ),
                ],
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (active != null && !active.isSelf)
                    ActingForChip(patient: active)
                  else
                    const Spacer(),
                  if (active != null && !active.isSelf) const Spacer(),
                  Flexible(
                    flex: 2,
                    child: Padding(
                      padding: const EdgeInsets.only(top: Space.sm, right: Space.sm),
                      child: Text(
                        l.homeQuote,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontStyle: FontStyle.italic,
                            color: context.isDark ? AppColors.darkPrimary : AppColors.primaryDark,
                            fontSize: 14.5,
                            height: 1.35),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class ActingForChip extends StatelessWidget {
  const ActingForChip({super.key, required this.patient});
  final PatientSummary patient;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: Space.sm),
      child: ActionChip(
        avatar: Icon(Icons.family_restroom, size: 18, color: context.brand),
        label: Text(context.l10n.actingFor(patient.name)),
        onPressed: () => showFamilySwitcher(context),
      ),
    );
  }
}

class _CircleAction extends StatelessWidget {
  const _CircleAction({super.key, required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: context.surface,
        shape: const CircleBorder(),
        elevation: 0,
        shadowColor: Colors.transparent,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: context.isDark ? null : Shadows.card),
            child: Icon(icon, color: context.textStrong, size: 24),
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ AI hero

class AiHeroCard extends StatefulWidget {
  const AiHeroCard({super.key});

  @override
  State<AiHeroCard> createState() => _AiHeroCardState();
}

class _AiHeroCardState extends State<AiHeroCard> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _ask() {
    final q = _ctrl.text.trim();
    _ctrl.clear();
    FocusScope.of(context).unfocus();
    context.go(q.isEmpty ? '/ai' : Uri(path: '/ai', queryParameters: {'q': q}).toString());
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: context.isDark
              ? const [Color(0xFF3A1A2A), AppColors.darkSurface, Color(0xFF3A2A1E)]
              : [Color(0xFFF7E6EE), Colors.white, context.mintSurface],
        ),
        border: Border.all(color: context.borderColor),
        boxShadow: context.isDark ? null : Shadows.card,
      ),
      padding: const EdgeInsets.fromLTRB(Space.md, Space.lg, Space.lg, Space.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          RobotAssistant(size: 100, semanticLabel: l.robotSemantic),
          const SizedBox(width: Space.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(l.aiHeroTitle,
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700, height: 1.2)),
                    ),
                    Semantics(
                      button: true,
                      label: l.openAssistant,
                      excludeSemantics: true,
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => context.go('/ai'),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                              color: context.surface,
                              shape: BoxShape.circle,
                              boxShadow: context.isDark ? null : Shadows.card),
                          child: const Icon(Icons.chevron_right),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(l.aiHeroSubtitle,
                    style: TextStyle(color: context.textMuted, fontSize: 13.5)),
                const SizedBox(height: Space.md),
                Container(
                  height: 52,
                  decoration: BoxDecoration(
                    color: context.surface,
                    borderRadius: BorderRadius.circular(Radii.input),
                    border: Border.all(color: context.borderColor),
                  ),
                  padding: const EdgeInsets.only(left: 16, right: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _ctrl,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _ask(),
                          decoration: InputDecoration(
                            hintText: l.howCanIHelp,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            filled: false,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                      Semantics(
                        button: true,
                        label: l.voiceInput,
                        excludeSemantics: true,
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => context.go('/ai?voice=1'),
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration:
                                const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                            child: const Icon(Icons.mic, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ Quick actions

class QuickActionsRow extends ConsumerWidget {
  const QuickActionsRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final pharmacyOn = ref.watch(featureFlagsProvider).pharmacyOrders;
    final items = [
      (Icons.medical_services_outlined, Accent.teal, l.qaTalkToDoctor, l.qaTalkToDoctorSub, '/doctors'),
      (Icons.home_rounded, Accent.rose, l.qaHomeCheckup, l.qaHomeCheckupSub, '/home-checkup'),
      (Icons.description_rounded, Accent.lavender, l.qaUploadReport, l.qaUploadReportSub, '/records/upload'),
      (
        Icons.medication_rounded,
        Accent.peach,
        l.qaOrderMedicines,
        pharmacyOn ? l.qaOrderMedicinesSub : l.comingSoon,
        pharmacyOn ? '/pharmacy' : unavailableRoute(l.qaOrderMedicines),
      ),
    ];
    // Each column's text width: labels are fitted word by word, and an
    // IntrinsicHeight can't measure a LayoutBuilder below it.
    return LayoutBuilder(builder: (context, constraints) {
      final labelWidth = (constraints.maxWidth - (items.length - 1)) / items.length - 4;
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) const VerticalDivider(width: 1, indent: 10, endIndent: 10),
              Expanded(
                child: Semantics(
                  button: true,
                  label: '${items[i].$3}. ${items[i].$4}',
                  excludeSemantics: true,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(Radii.tile),
                    onTap: () => context.push(items[i].$5),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                      child: Column(
                        children: [
                          IconTile(icon: items[i].$1, accent: items[i].$2, size: 64, iconSize: 32),
                          const SizedBox(height: Space.sm),
                          WordWrapLabel(items[i].$3,
                              maxWidth: labelWidth,
                              style: TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 13.5, color: context.textStrong)),
                          const SizedBox(height: 2),
                          WordWrapLabel(items[i].$4,
                              maxWidth: labelWidth,
                              style: TextStyle(color: context.textMuted, fontSize: 11.5)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    });
  }
}

// ------------------------------------------------------------------ Banner

class CareBanner extends StatelessWidget {
  const CareBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return ClipRRect(
      borderRadius: BorderRadius.circular(Radii.card),
      child: Container(
        constraints: const BoxConstraints(minHeight: 176),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [AppColors.primaryDark, AppColors.primary, AppColors.primaryLight],
          ),
        ),
        child: Stack(
          children: [
            const Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: 190,
              child: FamilyCareIllustration(),
            ),
            Positioned(
              right: 16,
              top: 14,
              child: ExcludeSemantics(
                child: Text(l.bannerScript,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                        color: AppColors.mint100,
                        fontSize: 17,
                        height: 1.15,
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w500)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(Space.xl),
              child: FractionallySizedBox(
                widthFactor: 0.62,
                alignment: Alignment.centerLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(l.bannerTitle,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 19, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Text(l.bannerSubtitle,
                        style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.35)),
                    const SizedBox(height: Space.lg),
                    Material(
                      color: AppColors.mint100,
                      shape: const StadiumBorder(),
                      child: InkWell(
                        customBorder: const StadiumBorder(),
                        onTap: () => context.go('/care?tab=plans'),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(l.exploreCarePlans,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600, color: AppColors.primaryDark)),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.arrow_forward, size: 18, color: AppColors.primaryDark),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ Quick access

class QuickAccessItem {
  const QuickAccessItem(this.icon, this.accent, this.label, this.route, {this.comingSoon = false, this.danger = false});
  final IconData icon;
  final Accent accent;
  final String label;
  final String route;
  final bool comingSoon;
  final bool danger;
}

/// Route for a feature that a server flag has switched off.
String unavailableRoute(String title) => Uri(path: '/unavailable', queryParameters: {'title': title}).toString();

List<QuickAccessItem> quickAccessItems(BuildContext context, FeatureFlags flags) {
  final l = context.l10n;
  QuickAccessItem gated(IconData icon, Accent accent, String label, String route, bool on) =>
      on ? QuickAccessItem(icon, accent, label, route) : QuickAccessItem(icon, accent, label, unavailableRoute(label), comingSoon: true);
  // The first [quickAccessPrimaryCount] items fill the grid (SOS always
  // visible); the rest open from the "More" tile.
  return [
    gated(Icons.monitor_heart_outlined, Accent.rose, l.qxSymptoms, '/ai', flags.aiAssistant),
    gated(Icons.biotech_outlined, Accent.lavender, l.qxLabTests, '/lab', flags.labTests),
    gated(Icons.insights_outlined, Accent.teal, l.qxCarePrograms, '/programs', flags.carePrograms),
    QuickAccessItem(Icons.notifications_active_outlined, Accent.peach, l.qxMedicineReminders, '/medications'),
    QuickAccessItem(Icons.description_outlined, Accent.sky, l.qxHealthRecords, '/records'),
    gated(Icons.vaccines_outlined, Accent.teal, l.qxPreventiveCare, '/preventive', flags.preventiveCare),
    gated(Icons.rate_review_outlined, Accent.lavender, l.qxSecondOpinion, '/second-opinion', flags.secondOpinion),
    QuickAccessItem(Icons.location_on_outlined, Accent.rose, l.qxFindHospitals, '/facilities'),
    QuickAccessItem(Icons.sos_outlined, Accent.rose, l.qxEmergencySos, '/sos', danger: true),
    // "More" sheet
    gated(Icons.spa_outlined, Accent.lavender, l.qxMentalWellness, '/wellness', flags.mentalWellness),
    QuickAccessItem(Icons.photo_camera_outlined, Accent.teal, l.qxWound, '/wound'),
    gated(Icons.shield_outlined, Accent.sky, l.qxInsurance, '/insurance', flags.insurance),
    gated(Icons.fitness_center, Accent.peach, l.qxExercise, '/exercise', flags.exercisePlans),
    gated(Icons.restaurant_menu, Accent.teal, l.qxDiet, '/diet', flags.dietPlans),
    gated(Icons.directions_run, Accent.teal, l.qxFallDetection, '/fall-detection', flags.fallDetection),
    gated(Icons.account_balance_outlined, Accent.peach, l.qxGovtSchemes, '/schemes', flags.govtSchemes),
    gated(Icons.watch_outlined, Accent.lavender, l.qxWearables, '/wearables', flags.wearables),
  ];
}

/// Tiles shown directly in the Home grid; the rest go to the "More" sheet.
const quickAccessPrimaryCount = 9;

void showMoreQuickAccess(BuildContext context, List<QuickAccessItem> items) {
  showModalBottomSheet<void>(
    useRootNavigator: true,
    context: context,
    isScrollControlled: true,
    builder: (c) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Space.screen, 0, Space.screen, Space.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(c.l10n.moreServices, style: Theme.of(c).textTheme.titleLarge),
            const SizedBox(height: Space.md),
            QuickAccessWrap(items: items, onTapped: () => Navigator.of(c).pop()),
          ],
        ),
      ),
    ),
  );
}

/// The tile grid (5 columns, 4 on narrow phones).
const quickAccessMoreRoute = '#more';

class QuickAccessWrap extends StatelessWidget {
  const QuickAccessWrap({super.key, required this.items, this.onTapped, this.onMore});
  final List<QuickAccessItem> items;
  final VoidCallback? onTapped;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth < 330 ? 4 : 5;
      const gap = 8.0;
      final w = (c.maxWidth - gap * (cols - 1)) / cols;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final it in items)
            SizedBox(
              width: w,
              child: QuickAccessTile(
                key: Key('qa-${it.route}'),
                item: it,
                onTapped: onTapped,
                onOverride: it.route == quickAccessMoreRoute ? onMore : null,
              ),
            ),
        ],
      );
    });
  }
}

class QuickAccessGrid extends ConsumerWidget {
  const QuickAccessGrid({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final all = quickAccessItems(context, ref.watch(featureFlagsProvider));
    final hasMore = all.length > quickAccessPrimaryCount + 1;
    final primary = hasMore ? all.take(quickAccessPrimaryCount).toList() : all;
    final rest = hasMore ? all.skip(quickAccessPrimaryCount).toList() : const <QuickAccessItem>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: l.quickAccess),
        QuickAccessWrap(items: [
          ...primary,
          if (hasMore) QuickAccessItem(Icons.apps_rounded, Accent.sky, l.more, quickAccessMoreRoute),
        ], onMore: () => showMoreQuickAccess(context, rest)),
      ],
    );
  }
}

class QuickAccessTile extends StatelessWidget {
  const QuickAccessTile({super.key, required this.item, this.onTapped, this.onOverride});
  final QuickAccessItem item;

  /// Called after navigating (e.g. to close the "More" sheet).
  final VoidCallback? onTapped;

  /// Replaces navigation (the "More" tile).
  final VoidCallback? onOverride;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Semantics(
      button: true,
      label: item.comingSoon ? '${item.label}, ${l.comingSoon}' : item.label,
      excludeSemantics: true,
      child: Material(
        color: context.isDark ? item.accent.fg.withValues(alpha: 0.16) : item.accent.bg.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(Radii.tile),
        child: InkWell(
          borderRadius: BorderRadius.circular(Radii.tile),
          onTap: () {
            if (onOverride != null) return onOverride!();
            onTapped?.call();
            if (item.route == '/records') {
              context.go(item.route);
            } else if (item.route == '/ai') {
              context.go(item.route);
            } else {
              context.push(item.route);
            }
          },
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 104),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: context.surface.withValues(alpha: 0.7),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(item.icon, color: item.accent.fg, size: 24),
                  ),
                  const SizedBox(height: 6),
                  // Word-by-word so a long word ("Emergency") shrinks instead of breaking mid-word.
                  WordWrapLabel(item.label,
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, height: 1.2)),
                  if (item.comingSoon)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(l.comingSoon,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 9.5, color: AppColors.peachFg, fontWeight: FontWeight.w700)),
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

// ------------------------------------------------------------------ Reminders

class RemindersSection extends ConsumerWidget {
  const RemindersSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final v = ref.watch(remindersTodayProvider);
    if (v.hasError) {
      return Column(children: [
        SectionHeader(title: l.todaysReminders),
        ErrorStateView(
            compact: true, error: v.error!, onRetry: () => ref.invalidate(remindersTodayProvider)),
      ]);
    }
    final raw = v.value;
    if (raw == null) return const LoadingView(compact: true);
    final items = visibleReminders(raw, ref.watch(medicationAddedLogProvider));
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: l.todaysReminders, onSeeAll: () => context.push('/medications')),
        for (final r in items.take(4)) ReminderTile(reminder: r),
      ],
    );
  }
}

class ReminderTile extends StatelessWidget {
  const ReminderTile({super.key, required this.reminder});
  final Reminder reminder;

  (IconData, Accent) get _style => switch (reminder.kind) {
        'medication' => (Icons.medication_outlined, Accent.peach),
        'appointment' => (Icons.event_outlined, Accent.sky),
        'home_visit' => (Icons.home_outlined, Accent.rose),
        'follow_up' => (Icons.update, Accent.lavender),
        _ => (Icons.task_alt, Accent.teal),
      };

  String? get _route => switch (reminder.kind) {
        'medication' => '/medications',
        'appointment' => '/appointments/${reminder.refId}',
        'home_visit' => '/home-visits/${reminder.refId}',
        _ => '/care?tab=plans',
      };

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final (icon, accent) = _style;
    final done = reminder.status == 'done';
    return ListRowTile(
      icon: icon,
      accent: accent,
      title: reminder.title,
      subtitle: [fmtTime(context, reminder.at), ?reminder.subtitle].join(' · '),
      onTap: _route == null ? null : () => context.push(_route!),
      trailing: StatusPill(
        label: done
            ? l.doseTaken
            : reminder.status == 'missed'
                ? l.doseMissed
                : l.dosePending,
        color: done
            ? AppColors.primaryLight
            : reminder.status == 'missed'
                ? AppColors.danger
                : AppColors.peachFg,
        icon: done ? Icons.check : null,
      ),
    );
  }
}

// ------------------------------------------------------------------ Episodes

class ActiveEpisodesSection extends ConsumerWidget {
  const ActiveEpisodesSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final v = ref.watch(activeEpisodesProvider);
    if (v.hasError) {
      return Column(children: [
        SectionHeader(title: l.activeCare),
        ErrorStateView(
            compact: true, error: v.error!, onRetry: () => ref.invalidate(activeEpisodesProvider)),
      ]);
    }
    final items = v.value;
    if (items == null || items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: l.activeCare, onSeeAll: () => context.go('/care')),
        for (final e in items.take(3)) EpisodeCard(episode: e),
      ],
    );
  }
}

class EpisodeCard extends StatelessWidget {
  const EpisodeCard({super.key, required this.episode});
  final CareEpisode episode;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final color = Labels.episodeColor(episode.status);
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.sm),
      child: CcCard(
        onTap: () => context.push('/episodes/${episode.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                    child: Text(episode.title, style: Theme.of(context).textTheme.titleSmall)),
                StatusPill(label: Labels.episodeStatus(l, episode.status), color: color),
              ],
            ),
            if (episode.nextAction != null && episode.nextAction!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.arrow_circle_right_outlined, size: 16, color: AppColors.primaryLight),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(l.nextStep(episode.nextAction!),
                        style: TextStyle(color: context.textMuted, fontSize: 13)),
                  ),
                ],
              ),
            ],
            if (episode.priority != 'routine') ...[
              const SizedBox(height: 6),
              StatusPill(
                  label: episode.priority == 'emergency' ? l.priorityEmergency : l.priorityUrgent,
                  color: AppColors.danger,
                  icon: Icons.priority_high),
            ],
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ Insights

/// Rendered only when the API returns real data (HOME-05).
class InsightsSection extends ConsumerWidget {
  const InsightsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(insightsTodayProvider).value;
    if (items == null || items.isEmpty) return const SizedBox.shrink();
    final l = context.l10n;
    return Column(
      key: const Key('insights-section'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: l.todaysInsights, onSeeAll: () => context.push('/vitals')),
        LayoutBuilder(builder: (context, c) {
          final cols = c.maxWidth < 330 ? 2 : 3;
          const gap = 10.0;
          final w = (c.maxWidth - gap * (cols - 1)) / cols;
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [for (final i in items) SizedBox(width: w, child: InsightCard(insight: i))],
          );
        }),
      ],
    );
  }
}

class InsightCard extends StatelessWidget {
  const InsightCard({super.key, required this.insight});
  final Insight insight;

  (IconData, Accent) get _style => switch (insight.type) {
        'heart_rate' => (Icons.favorite, Accent.rose),
        'steps' => (Icons.directions_walk, Accent.teal),
        'sleep' => (Icons.bedtime, Accent.lavender),
        'bp' => (Icons.speed, Accent.sky),
        'spo2' => (Icons.air, Accent.sky),
        _ => (Icons.insights, Accent.teal),
      };

  @override
  Widget build(BuildContext context) {
    final (icon, accent) = _style;
    final numeric = num.tryParse(insight.value);
    final progress = (insight.goal != null && insight.goal! > 0 && numeric != null)
        ? (numeric / insight.goal!).clamp(0.0, 1.0).toDouble()
        : null;
    return CcCard(
      padding: const EdgeInsets.all(12),
      semanticLabel: '${insight.label}: ${insight.value} ${insight.unit}. ${insight.status ?? ''}',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(color: context.accentSurface(accent), shape: BoxShape.circle),
                  child: Icon(icon, color: accent.fg, size: 19),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(insight.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: context.textMuted, fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text.rich(
              TextSpan(children: [
                TextSpan(
                    text: fmtNumber(context, insight.value),
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                TextSpan(text: ' ${insight.unit}', style: const TextStyle(fontSize: 13)),
              ]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (progress != null) ...[
              const SizedBox(height: 4),
              Text(context.l10n.goalLabel(fmtNumber(context, '${insight.goal}')),
                  style: TextStyle(fontSize: 10.5, color: context.textMuted)),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 5,
                    backgroundColor: context.borderColor,
                    color: AppColors.primaryLight),
              ),
            ] else if (insight.status != null) ...[
              const SizedBox(height: 2),
              Text(insight.status!,
                  style: const TextStyle(
                      color: AppColors.primaryLight, fontWeight: FontWeight.w600, fontSize: 13)),
            ],
          ],
        ),
      ),
    );
  }
}
