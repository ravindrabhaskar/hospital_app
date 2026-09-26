import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/tokens.dart';
import '../../core/utils/format.dart';
import '../../core/utils/links.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/state_views.dart';
import '../../models/engagement.dart';
import '../../state/data_providers.dart';

const defaultSchemeState = 'Telangana';

/// Central schemes always apply; state schemes only for the chosen state
/// (null = every state).
List<Scheme> filterSchemes(List<Scheme> all, String? state) => all
    .where((s) => s.isCentral || state == null || (s.state ?? '').toLowerCase() == state.toLowerCase())
    .toList()
  ..sort((a, b) {
    // State schemes first (more local), then central, then by name.
    final byLevel = (a.isCentral ? 1 : 0) - (b.isCentral ? 1 : 0);
    return byLevel != 0 ? byLevel : a.name.compareTo(b.name);
  });

/// Home → Govt. Health Schemes (§38). Information only.
class SchemesScreen extends ConsumerStatefulWidget {
  const SchemesScreen({super.key});

  @override
  ConsumerState<SchemesScreen> createState() => _SchemesScreenState();
}

class _SchemesScreenState extends ConsumerState<SchemesScreen> {
  String? _state = defaultSchemeState;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    // All published schemes; filtered locally so central ones always show.
    final v = ref.watch(schemesProvider(null));
    return Scaffold(
      appBar: AppBar(title: Text(l.govtSchemes)),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(schemesProvider(null).future),
        child: AsyncView<List<Scheme>>(
          value: v,
          onRetry: () => ref.invalidate(schemesProvider(null)),
          data: (all) {
            final states = {defaultSchemeState, for (final s in all) if (s.state != null && s.state!.isNotEmpty) s.state!}
                .toList()
              ..sort();
            final list = filterSchemes(all, _state);
            return ListView(
              padding: const EdgeInsets.all(Space.screen),
              children: [
                const SchemesDisclaimer(),
                const SizedBox(height: Space.md),
                DropdownButtonFormField<String?>(
                  key: const Key('scheme-state'),
                  initialValue: _state,
                  decoration: InputDecoration(labelText: l.yourState, prefixIcon: const Icon(Icons.map_outlined)),
                  items: [
                    for (final s in states) DropdownMenuItem<String?>(value: s, child: Text(s)),
                    DropdownMenuItem<String?>(value: null, child: Text(l.allStates)),
                  ],
                  onChanged: (s) => setState(() => _state = s),
                ),
                const SizedBox(height: Space.xs),
                Text(l.centralSchemesAlwaysShown, style: TextStyle(fontSize: 12, color: context.textMuted)),
                const SizedBox(height: Space.md),
                if (list.isEmpty)
                  EmptyStateView(icon: Icons.account_balance_outlined, title: l.noSchemes)
                else
                  for (final s in list) SchemeTile(scheme: s),
              ],
            );
          },
        ),
      ),
    );
  }
}

class SchemesDisclaimer extends StatelessWidget {
  const SchemesDisclaimer({super.key, this.text});
  final String? text;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Semantics(
      container: true,
      child: Container(
        key: const Key('schemes-disclaimer'),
        padding: const EdgeInsets.all(Space.md),
        decoration: BoxDecoration(
          color: context.peachSurface,
          borderRadius: BorderRadius.circular(Radii.tile),
          border: Border.all(color: AppColors.peachFg.withValues(alpha: 0.4)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline, color: AppColors.peachFg),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.schemesDisclaimer, style: const TextStyle(fontWeight: FontWeight.w600)),
                  if (text != null && text!.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(text!, style: const TextStyle(fontSize: 12.5)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SchemeTile extends StatelessWidget {
  const SchemeTile({super.key, required this.scheme});
  final Scheme scheme;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = scheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.sm),
      child: CcCard(
        onTap: () => context.push('/schemes/${s.id}'),
        semanticLabel: [s.name, s.isCentral ? l.centralScheme : l.stateScheme(s.state ?? ''), s.summary].join('. '),
        child: ExcludeSemantics(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconTile(
                  icon: s.isCentral ? Icons.account_balance_outlined : Icons.location_city_outlined,
                  accent: s.isCentral ? Accent.sky : Accent.peach,
                  size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.name, style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 2),
                    StatusPill(
                      label: s.isCentral ? l.centralScheme : l.stateScheme(s.state ?? ''),
                      color: s.isCentral ? AppColors.skyFg : AppColors.peachFg,
                    ),
                    const SizedBox(height: 4),
                    Text(s.summary,
                        maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.textMuted)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: context.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

/// `/schemes/:id`.
class SchemeDetailScreen extends ConsumerWidget {
  const SchemeDetailScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.govtSchemes)),
      body: AsyncView<Scheme>(
        value: ref.watch(schemeProvider(id)),
        onRetry: () => ref.invalidate(schemeProvider(id)),
        data: (s) => ListView(
          padding: const EdgeInsets.all(Space.screen),
          children: [
            Text(s.name, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              [s.authority, s.isCentral ? l.centralScheme : l.stateScheme(s.state ?? '')]
                  .where((e) => e.isNotEmpty)
                  .join(' · '),
              style: TextStyle(color: context.textMuted),
            ),
            const SizedBox(height: Space.md),
            SchemesDisclaimer(text: s.disclaimer),
            SectionHeader(title: l.aboutScheme),
            Text(s.summary, style: const TextStyle(height: 1.45)),
            if (s.benefits.isNotEmpty) ...[
              SectionHeader(title: l.schemeBenefits),
              _Bullets(items: s.benefits, icon: Icons.check_circle_outline),
            ],
            if (s.eligibilityHints.isNotEmpty) ...[
              SectionHeader(title: l.mayBeRelevantIf),
              _Bullets(items: s.eligibilityHints, icon: Icons.help_outline),
              Text(l.eligibilityNotDetermined, style: TextStyle(fontSize: 12, color: context.textMuted)),
            ],
            if (s.documentsTypicallyNeeded.isNotEmpty) ...[
              SectionHeader(title: l.documentsTypicallyNeeded),
              _Bullets(items: s.documentsTypicallyNeeded, icon: Icons.description_outlined),
            ],
            const SizedBox(height: Space.lg),
            if (s.helpline != null && s.helpline!.trim().isNotEmpty)
              ListRowTile(
                icon: Icons.call_outlined,
                accent: Accent.teal,
                title: l.helpline,
                subtitle: s.helpline,
                onTap: () => openExternal(context, telUri(s.helpline!)),
              ),
            if (s.officialUrl.isNotEmpty) ...[
              const SizedBox(height: Space.sm),
              PrimaryButton(
                label: l.openOfficialWebsite,
                icon: Icons.open_in_new,
                onPressed: () {
                  final uri = Uri.tryParse(s.officialUrl);
                  if (uri != null) openExternal(context, uri);
                },
              ),
            ],
            if (s.lastReviewedAt != null) ...[
              const SizedBox(height: Space.md),
              Text(l.lastReviewedOn(fmtDate(context, s.lastReviewedAt!)),
                  textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: context.textMuted)),
            ],
          ],
        ),
      ),
    );
  }
}

class _Bullets extends StatelessWidget {
  const _Bullets({required this.items, required this.icon});
  final List<String> items;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          for (final i in items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, size: 18, color: AppColors.primaryLight),
                  const SizedBox(width: 8),
                  Expanded(child: Text(i)),
                ],
              ),
            ),
        ],
      );
}
