import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_exception.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/format.dart';
import '../../core/utils/labels.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/legal_links.dart';
import '../../core/widgets/state_views.dart';
import '../../models/auth.dart';
import '../../state/core_providers.dart';
import '../../state/data_providers.dart';

class OnboardingConsentsScreen extends ConsumerStatefulWidget {
  const OnboardingConsentsScreen({super.key});

  @override
  ConsumerState<OnboardingConsentsScreen> createState() => _OnboardingConsentsScreenState();
}

class _OnboardingConsentsScreenState extends ConsumerState<OnboardingConsentsScreen> {
  final Set<String> _ticked = {};
  Set<String> _alreadyGranted = {};
  bool _saving = false;
  bool _initialised = false;

  Future<void> _init(List<ConsentCatalogItem> catalog) async {
    if (_initialised) return;
    _initialised = true;
    try {
      final existing = await ref.read(consentRepositoryProvider).list();
      _alreadyGranted = existing.where((c) => c.isGranted).map((c) => c.purpose).toSet();
      if (!mounted) return;
      setState(() => _ticked.addAll(_alreadyGranted));
      final requiredAll =
          catalog.where((c) => c.required).every((c) => _alreadyGranted.contains(c.purpose));
      if (requiredAll && mounted) context.go('/onboarding/profile');
    } catch (_) {
      // Non-fatal: the user can still tick and submit.
    }
  }

  Future<void> _submit(List<ConsentCatalogItem> catalog) async {
    setState(() => _saving = true);
    try {
      final repo = ref.read(consentRepositoryProvider);
      for (final c in catalog) {
        if (_ticked.contains(c.purpose) && !_alreadyGranted.contains(c.purpose)) {
          await repo.grant(c.purpose, c.version);
          _alreadyGranted.add(c.purpose);
        }
      }
      await ref.read(sessionProvider.notifier).refreshMe();
      if (mounted) context.go('/onboarding/profile');
    } on ApiException catch (e) {
      if (mounted) showSnack(context, errorMessage(context, e), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final catalog = ref.watch(consentCatalogProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l.consentsTitle), automaticallyImplyLeading: false),
      body: AsyncView<List<ConsentCatalogItem>>(
        value: catalog,
        onRetry: () => ref.invalidate(consentCatalogProvider),
        data: (items) {
          _init(items);
          final requiredOk =
              items.where((c) => c.required).every((c) => _ticked.contains(c.purpose));
          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(Space.screen),
                  children: [
                    Text(l.consentsIntro, style: TextStyle(color: context.textMuted)),
                    const LegalLinks(center: false),
                    const SizedBox(height: Space.sm),
                    for (final c in items)
                      Padding(
                        padding: const EdgeInsets.only(bottom: Space.sm),
                        child: ConsentTile(
                          item: c,
                          value: _ticked.contains(c.purpose),
                          onChanged: (v) => setState(() =>
                              v ? _ticked.add(c.purpose) : _ticked.remove(c.purpose)),
                        ),
                      ),
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(Space.screen),
                  child: Column(
                    children: [
                      if (!requiredOk)
                        Padding(
                          padding: const EdgeInsets.only(bottom: Space.sm),
                          child: Text(l.consentsRequiredHint,
                              style: TextStyle(color: context.textMuted, fontSize: 12)),
                        ),
                      PrimaryButton(
                        label: l.agreeAndContinue,
                        loading: _saving,
                        onPressed: requiredOk ? () => _submit(items) : null,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class ConsentTile extends StatelessWidget {
  const ConsentTile({super.key, required this.item, required this.value, required this.onChanged});
  final ConsentCatalogItem item;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return CcCard(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: CheckboxListTile(
        value: value,
        onChanged: (v) => onChanged(v ?? false),
        controlAffinity: ListTileControlAffinity.leading,
        contentPadding: EdgeInsets.zero,
        title: Row(
          children: [
            Flexible(child: Text(item.title.isNotEmpty ? item.title : Labels.consentPurpose(l, item.purpose))),
            const SizedBox(width: 6),
            StatusPill(
              label: item.required ? l.required : l.optional,
              color: item.required ? AppColors.danger : context.textMuted,
            ),
          ],
        ),
        subtitle: item.description.isEmpty
            ? null
            : Text(item.description, style: const TextStyle(fontSize: 12.5)),
      ),
    );
  }
}
