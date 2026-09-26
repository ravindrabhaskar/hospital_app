import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/tokens.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/common.dart';
import '../../state/core_providers.dart';

/// Store listings used by the "Update now" button.
const androidStoreUrl = 'https://play.google.com/store/apps/details?id=com.carecompanion.patient';

/// Replace with the real App Store URL once the app is listed.
const iosStoreUrl = 'https://apps.apple.com/in/search?term=CareCompanion';

/// Blocking screen shown when the installed version is below the server's
/// `minAppVersion` (§21). There is no way past it except updating.
class ForceUpdateScreen extends ConsumerWidget {
  const ForceUpdateScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final cfg = ref.watch(publicConfigProvider);
    final platform = ref.watch(appPlatformProvider);
    final min = minVersionFor(cfg, platform) ?? '-';
    final current = ref.watch(appVersionProvider);
    final store = defaultTargetPlatform == TargetPlatform.iOS ? iosStoreUrl : androidStoreUrl;
    return PopScope(
      canPop: false,
      child: Scaffold(
        key: const Key('force-update'),
        backgroundColor: context.mintSurface,
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
                  child: const Icon(Icons.system_update_rounded, size: 52, color: AppColors.primary),
                ),
                const SizedBox(height: Space.xl),
                Semantics(
                  header: true,
                  child: Text(l.updateRequiredTitle,
                      textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall),
                ),
                const SizedBox(height: Space.md),
                Text(l.updateRequiredBody,
                    textAlign: TextAlign.center, style: TextStyle(color: context.textMuted)),
                const SizedBox(height: Space.md),
                Text(l.updateVersionInfo(current, min),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12.5, color: context.textMuted)),
                const Spacer(),
                PrimaryButton(
                  label: l.updateNow,
                  icon: Icons.open_in_new,
                  onPressed: () => launchUrl(Uri.parse(store), mode: LaunchMode.externalApplication),
                ),
                const SizedBox(height: Space.sm),
                TextButton(
                  onPressed: () => ref.read(publicConfigProvider.notifier).refresh(),
                  child: Text(l.checkAgain),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
