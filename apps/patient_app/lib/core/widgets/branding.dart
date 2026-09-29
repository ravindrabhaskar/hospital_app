import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/config.dart';
import '../../state/core_providers.dart';
import '../theme/tokens.dart';
import '../utils/format.dart';

/// The tenant's primary colour (null for the default app).
Color? brandSeedColor(Branding? b) {
  final argb = b?.primaryArgb;
  return argb == null ? null : Color(argb);
}

/// The hospital logo of a white-label build (§58); nothing otherwise.
class TenantLogo extends ConsumerWidget {
  const TenantLogo({super.key, this.size = 40});
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final b = ref.watch(brandingProvider);
    final url = b?.logoUrl;
    if (b == null || url == null || url.isEmpty) return const SizedBox.shrink();
    return Semantics(
      image: true,
      label: context.l10n.logoOf(b.displayName),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: CachedNetworkImage(
          imageUrl: url,
          height: size,
          width: size * 2.5,
          fit: BoxFit.contain,
          errorWidget: (_, _, _) => const SizedBox.shrink(),
          placeholder: (_, _) => SizedBox(height: size),
        ),
      ),
    );
  }
}

/// Profile footer: hospital name/logo and "Powered by CareCompanion".
class PoweredByFooter extends ConsumerWidget {
  const PoweredByFooter({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final b = ref.watch(brandingProvider);
    if (b == null) return const SizedBox.shrink();
    final l = context.l10n;
    return Padding(
      key: const Key('powered-by'),
      padding: const EdgeInsets.symmetric(vertical: Space.md),
      child: Column(
        children: [
          const TenantLogo(size: 36),
          if (b.displayName.isNotEmpty)
            Text(b.displayName, style: const TextStyle(fontWeight: FontWeight.w700)),
          Text(l.poweredByCareCompanion, style: TextStyle(fontSize: 12, color: context.textMuted)),
        ],
      ),
    );
  }
}
