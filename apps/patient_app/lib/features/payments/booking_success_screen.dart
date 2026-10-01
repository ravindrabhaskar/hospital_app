import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/tokens.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/common.dart';

class BookingSuccessArgs {
  const BookingSuccessArgs({
    required this.title,
    required this.lines,
    this.detailRoute,
    this.detailLabel,
    this.highlight,
    this.highlightLabel,
  });
  final String title;
  final List<String> lines;
  final String? detailRoute;
  final String? detailLabel;

  /// Big value to show prominently (e.g. the home-visit code).
  final String? highlight;
  final String? highlightLabel;
}

class BookingSuccessScreen extends StatelessWidget {
  const BookingSuccessScreen({super.key, this.args});
  final BookingSuccessArgs? args;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final a = args ?? BookingSuccessArgs(title: l.bookingConfirmed, lines: const []);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Space.xxl),
          child: Column(
            children: [
              const Spacer(),
              Container(
                width: 96,
                height: 96,
                decoration: const BoxDecoration(color: AppColors.mint100, shape: BoxShape.circle),
                child: Icon(Icons.check_rounded, size: 56, color: context.brand),
              ),
              const SizedBox(height: Space.xl),
              Semantics(
                header: true,
                liveRegion: true,
                child: Text(a.title,
                    textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall),
              ),
              const SizedBox(height: Space.md),
              for (final line in a.lines)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(line,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: context.textMuted)),
                ),
              if (a.highlight != null) ...[
                const SizedBox(height: Space.lg),
                CcCard(
                  color: context.mintSurface,
                  child: Column(
                    children: [
                      Text(a.highlightLabel ?? '', style: TextStyle(color: context.textMuted)),
                      Text(a.highlight!,
                          style: const TextStyle(
                              fontSize: 34, fontWeight: FontWeight.w800, letterSpacing: 8)),
                    ],
                  ),
                ),
              ],
              const Spacer(),
              if (a.detailRoute != null)
                PrimaryButton(
                  label: a.detailLabel ?? l.viewDetails,
                  onPressed: () => context.pushReplacement(a.detailRoute!),
                ),
              const SizedBox(height: Space.sm),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(onPressed: () => context.go('/home'), child: Text(l.goHome)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
