import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/api/api_exception.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/state_views.dart';
import '../../models/engagement_v13.dart';
import '../../state/v13_providers.dart';
import '../onboarding/onboarding_resume.dart';

// Wallet & invites (API_CONTRACT §60).

/// Normalises an invite code (trim, upper-case, no spaces); null if invalid.
String? normalizeInviteCode(String raw) {
  final c = raw.replaceAll(RegExp(r'\s'), '').toUpperCase();
  return RegExp(r'^[A-Z0-9-]{4,20}$').hasMatch(c) ? c : null;
}

class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.wallet)),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(walletProvider.future),
        child: AsyncView<Wallet>(
          value: ref.watch(walletProvider),
          onRetry: () => ref.invalidate(walletProvider),
          data: (w) => ListView(
            padding: const EdgeInsets.all(Space.screen),
            children: [
              CcCard(
                key: const Key('wallet-balance'),
                color: context.mintSurface,
                semanticLabel: l.walletBalanceSemantic(money(w.balance)),
                child: Row(children: [
                  Icon(Icons.account_balance_wallet_outlined, color: context.brand, size: 36),
                  const SizedBox(width: Space.md),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(l.walletBalance, style: TextStyle(color: context.textMuted)),
                      Text(money(w.balance), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
                    ]),
                  ),
                ]),
              ),
              const SizedBox(height: Space.sm),
              Text(l.walletNote, style: TextStyle(fontSize: 12, color: context.textMuted)),
              const SizedBox(height: Space.md),
              ListRowTile(
                icon: Icons.card_giftcard,
                accent: Accent.peach,
                title: l.inviteFamilyFriends,
                subtitle: l.inviteRewardSub,
                onTap: () => context.push('/invite'),
              ),
              SectionHeader(title: l.transactions),
              if (w.transactions.isEmpty)
                EmptyStateView(compact: true, icon: Icons.receipt_long_outlined, title: l.noTransactions)
              else
                CcCard(
                  padding: EdgeInsets.zero,
                  child: Column(children: [
                    for (final t in w.transactions)
                      ListTile(
                        leading: Icon(t.isCredit ? Icons.south_west : Icons.north_east,
                            color: t.isCredit ? AppColors.primaryLight : AppColors.danger),
                        title: Text(t.reason.isEmpty ? (t.isCredit ? l.credit : l.debit) : t.reason),
                        subtitle: t.at == null ? null : Text(fmtDateTime(context, t.at!)),
                        trailing: Text('${t.isCredit ? '+' : '−'}${money(t.amount)}',
                            style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: t.isCredit ? AppColors.primaryLight : AppColors.danger)),
                      ),
                  ]),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class InviteScreen extends ConsumerWidget {
  const InviteScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.inviteFamilyFriends)),
      body: AsyncView<InviteInfo>(
        value: ref.watch(inviteProvider),
        onRetry: () => ref.invalidate(inviteProvider),
        data: (i) => ListView(
          padding: const EdgeInsets.all(Space.screen),
          children: [
            const Center(child: IconTile(icon: Icons.card_giftcard, accent: Accent.peach, size: 72)),
            const SizedBox(height: Space.lg),
            Text(l.inviteIntro, textAlign: TextAlign.center, style: TextStyle(color: context.textMuted)),
            const SizedBox(height: Space.lg),
            CcCard(
              child: Column(children: [
                Text(l.yourInviteCode, style: TextStyle(color: context.textMuted)),
                const SizedBox(height: 4),
                SelectableText(i.code,
                    key: const Key('invite-code'),
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: 4)),
                TextButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: i.code));
                    showSnack(context, l.copied);
                  },
                  icon: const Icon(Icons.copy),
                  label: Text(l.copyCode),
                ),
              ]),
            ),
            const SizedBox(height: Space.md),
            PrimaryButton(
              key: const Key('invite-share'),
              icon: Icons.share,
              label: l.shareInvite,
              onPressed: () => SharePlus.instance.share(ShareParams(text: i.shareText.isEmpty ? i.code : i.shareText)),
            ),
            const SizedBox(height: Space.lg),
            Row(children: [
              Expanded(child: _Stat(label: l.friendsInvited, value: '${i.invitedCount}')),
              const SizedBox(width: Space.sm),
              Expanded(child: _Stat(label: l.rewardsEarned, value: money(i.rewardsEarned))),
            ]),
            const SizedBox(height: Space.lg),
            OutlinedButton.icon(
              key: const Key('invite-redeem-open'),
              onPressed: () => showRedeemInviteDialog(context),
              icon: const Icon(Icons.redeem),
              label: Text(l.haveInviteCode),
            ),
            const SizedBox(height: Space.md),
            Text(l.inviteTerms, style: TextStyle(fontSize: 12, color: context.textMuted)),
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
  Widget build(BuildContext context) => CcCard(
        semanticLabel: '$label: $value',
        child: Column(children: [
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: context.textMuted)),
        ]),
      );
}

Future<bool?> showRedeemInviteDialog(BuildContext context) =>
    showDialog<bool>(context: context, builder: (_) => const RedeemInviteDialog());

/// Redeems an invite code (once, within 7 days of signup).
class RedeemInviteForm extends ConsumerStatefulWidget {
  const RedeemInviteForm({super.key, required this.onDone});
  final VoidCallback onDone;

  @override
  ConsumerState<RedeemInviteForm> createState() => _RedeemInviteFormState();
}

class _RedeemInviteFormState extends ConsumerState<RedeemInviteForm> {
  final _c = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _c.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _redeem() async {
    final l = context.l10n;
    final code = normalizeInviteCode(_c.text);
    if (code == null) {
      setState(() => _error = l.inviteCodeInvalid);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(offersRepositoryProvider).redeemInvite(code);
      if (!mounted) return;
      showSnack(context, l.inviteRedeemed);
      widget.onDone();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = errorMessage(context, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const Key('invite-redeem-field'),
          controller: _c,
          textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(labelText: l.inviteCode, errorText: _error),
        ),
        const SizedBox(height: Space.md),
        PrimaryButton(
          key: const Key('invite-redeem'),
          label: l.redeem,
          loading: _busy,
          onPressed: _c.text.trim().isEmpty ? null : _redeem,
        ),
      ],
    );
  }
}

class RedeemInviteDialog extends StatelessWidget {
  const RedeemInviteDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      title: Text(l.haveInviteCode),
      content: SizedBox(
        width: 360,
        child: RedeemInviteForm(onDone: () => Navigator.of(context).pop(true)),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l.cancel))],
    );
  }
}

/// Optional last onboarding step: "Were you invited?".
class OnboardingInviteScreen extends ConsumerWidget {
  const OnboardingInviteScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.haveInviteCode),
        automaticallyImplyLeading: false,
        actions: [TextButton(key: const Key('invite-skip'), onPressed: () => goOnboardingStep(context, ref, '/home'), child: Text(l.skip))],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(Space.screen),
          children: [
            const Center(child: IconTile(icon: Icons.redeem, accent: Accent.peach, size: 72)),
            const SizedBox(height: Space.lg),
            Text(l.onboardingInviteBody, textAlign: TextAlign.center, style: TextStyle(color: context.textMuted)),
            const SizedBox(height: Space.xl),
            RedeemInviteForm(onDone: () => goOnboardingStep(context, ref, '/home')),
          ],
        ),
      ),
    );
  }
}
