import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../utils/format.dart';

/// Rounded white card with the design-system border and soft shadow.
class CcCard extends StatelessWidget {
  const CcCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(Space.lg),
    this.onTap,
    this.color,
    this.radius = Radii.card,
    this.borderColor,
    this.semanticLabel,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final double radius;
  final Color? borderColor;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final content = Padding(padding: padding, child: child);
    final card = Container(
      decoration: BoxDecoration(
        color: color ?? Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor ?? (dark ? const Color(0xFF3D2330) : AppColors.border)),
        boxShadow: dark ? null : Shadows.card,
      ),
      child: onTap == null
          // Transparent Material so ListTiles inside paint ink on the card.
          ? Material(type: MaterialType.transparency, child: content)
          : Material(
              type: MaterialType.transparency,
              child: InkWell(
                borderRadius: BorderRadius.circular(radius),
                onTap: onTap,
                child: content,
              ),
            ),
    );
    if (semanticLabel != null) {
      return Semantics(button: onTap != null, label: semanticLabel, child: card);
    }
    return card;
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.onSeeAll, this.trailing});
  final String title;
  final VoidCallback? onSeeAll;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: Space.xl, bottom: Space.sm),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 18)),
            ),
          ),
          ?trailing,
          if (onSeeAll != null)
            TextButton(
              onPressed: onSeeAll,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(context.l10n.seeAll,
                      style: TextStyle(color: context.textMuted)),
                  Icon(Icons.chevron_right, size: 18, color: context.textMuted),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.icon,
    this.color,
    this.foreground,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;
  final Color? color;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        style: color == null && foreground == null
            ? null
            : FilledButton.styleFrom(backgroundColor: color, foregroundColor: foreground),
        onPressed: loading ? null : onPressed,
        child: loading
            ? const SizedBox(
                width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4))
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: 8)],
                  Flexible(child: Text(label, textAlign: TextAlign.center)),
                ],
              ),
      ),
    );
  }
}

/// A short, centred label that wraps between words only: when the widest
/// word does not fit (large font scale, long Hindi/Telugu words) the text is
/// scaled down so it never breaks mid-word ("Consultatio/n").
///
/// Pass [maxWidth] when the label sits under an `IntrinsicHeight` (which
/// can't measure a LayoutBuilder); otherwise the available width is used.
class WordWrapLabel extends StatelessWidget {
  const WordWrapLabel(this.text, {super.key, this.style, this.maxWidth});
  final String text;
  final TextStyle? style;
  final double? maxWidth;

  /// Font scale factor (<= 1) that makes the widest word fit [width].
  static double fitFactor(String text, TextStyle style, double width,
      {TextScaler textScaler = TextScaler.noScaling, TextDirection direction = TextDirection.ltr}) {
    if (width <= 1) return 1;
    var widest = 0.0;
    for (final word in text.split(RegExp(r'\s+'))) {
      if (word.isEmpty) continue;
      final tp = TextPainter(
        text: TextSpan(text: word, style: style),
        textDirection: direction,
        textScaler: textScaler,
        maxLines: 1,
      )..layout();
      if (tp.width > widest) widest = tp.width;
      tp.dispose();
    }
    // Small margin for glyph overhang / rounding.
    return widest > width - 1 ? (width - 1) / widest : 1;
  }

  Widget _text(BuildContext context, double width) {
    final base = DefaultTextStyle.of(context).style.merge(style);
    final factor = fitFactor(text, base, width,
        textScaler: MediaQuery.textScalerOf(context), direction: Directionality.of(context));
    return Text(text,
        textAlign: TextAlign.center, style: base.copyWith(fontSize: (base.fontSize ?? 14) * factor));
  }

  @override
  Widget build(BuildContext context) {
    final w = maxWidth;
    if (w != null) return _text(context, w);
    return LayoutBuilder(
      builder: (context, constraints) =>
          _text(context, constraints.hasBoundedWidth ? constraints.maxWidth : double.infinity),
    );
  }
}

class IconTile extends StatelessWidget {
  const IconTile({super.key, required this.icon, required this.accent, this.size = 56, this.iconSize});
  final IconData icon;
  final Accent accent;
  final double size;
  final double? iconSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: context.accentSurface(accent),
        borderRadius: BorderRadius.circular(size >= 48 ? Radii.tile : 12),
      ),
      child: Icon(icon, color: accent.fg, size: iconSize ?? size * 0.5),
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.label, this.color = AppColors.primaryLight, this.icon});
  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 12, color: color), const SizedBox(width: 4)],
          Flexible(
            child: Text(label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

/// "AI-generated · not a diagnosis" marker required on all AI text.
class AiGeneratedLabel extends StatelessWidget {
  const AiGeneratedLabel({super.key, this.light = false});
  final bool light;

  @override
  Widget build(BuildContext context) {
    final color = light ? Colors.white70 : AppColors.lavenderFg;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.auto_awesome, size: 12, color: color),
        const SizedBox(width: 4),
        Flexible(
          child: Text(context.l10n.aiGeneratedLabel,
              style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500)),
        ),
      ],
    );
  }
}

class Avatar extends StatelessWidget {
  const Avatar({super.key, required this.name, this.url, this.size = 44});
  final String name;
  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: [AppColors.mint100, context.tealSurface]),
      ),
      child: Text(initials(name),
          style: TextStyle(
              color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: size * 0.36)),
    );
    if (url == null || url!.isEmpty) return fallback;
    // Profile photos are public `/media/:id` URLs with a 1-day cache header;
    // cached on disk (memory on web) with an initials fallback.
    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: url!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholder: (_, _) => fallback,
        errorWidget: (_, _, _) => fallback,
      ),
    );
  }
}

/// Rounded-rectangle doctor/provider photo (cached) with an initials
/// fallback, used on doctor cards, details and appointments.
class DoctorPhoto extends StatelessWidget {
  const DoctorPhoto({super.key, required this.name, this.url, this.width = 76, this.height = 76, this.radius = 16});
  final String name;
  final String? url;
  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: width,
      height: height,
      color: context.mintSurface,
      alignment: Alignment.center,
      child: Avatar(name: name, size: width * 0.72),
    );
    return Semantics(
      image: true,
      label: context.l10n.photoOf(name),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: url == null || url!.isEmpty
            ? fallback
            : CachedNetworkImage(
                imageUrl: url!,
                width: width,
                height: height,
                fit: BoxFit.cover,
                placeholder: (_, _) => fallback,
                errorWidget: (_, _, _) => fallback,
              ),
      ),
    );
  }
}

class LabeledValue extends StatelessWidget {
  const LabeledValue({super.key, required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
              flex: 2,
              child: Text(label,
                  style: TextStyle(color: context.textMuted, fontSize: 14))),
          Expanded(flex: 3, child: Text(value, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }
}

class ListRowTile extends StatelessWidget {
  const ListRowTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.accent = Accent.teal,
    this.trailing,
  });
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Accent accent;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.sm),
      child: CcCard(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            IconTile(icon: icon, accent: accent, size: 44),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleSmall),
                  if (subtitle != null && subtitle!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(subtitle!,
                          style: TextStyle(color: context.textMuted, fontSize: 12.5)),
                    ),
                ],
              ),
            ),
            trailing ??
                (onTap != null
                    ? Icon(Icons.chevron_right, color: context.textMuted)
                    : const SizedBox.shrink()),
          ],
        ),
      ),
    );
  }
}

void showSnack(BuildContext context, String message,
    {bool error = false, SnackBarAction? action}) {
  final m = ScaffoldMessenger.maybeOf(context);
  m?.hideCurrentSnackBar();
  m?.showSnackBar(SnackBar(
    content: Text(message),
    backgroundColor: error ? AppColors.danger : null,
    action: action,
    duration: action == null ? const Duration(milliseconds: 4000) : const Duration(seconds: 8),
  ));
}
