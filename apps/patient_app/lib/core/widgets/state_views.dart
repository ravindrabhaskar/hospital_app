import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/core_providers.dart';
import '../api/api_exception.dart';
import '../theme/tokens.dart';
import '../utils/format.dart';

/// Converts any error into user-facing, localized text.
String errorMessage(BuildContext context, Object error) {
  final l = context.l10n;
  if (error is ApiException) {
    if (error.isOffline) return l.errorOffline;
    if (error.isUnauthenticated) return l.errorSessionExpired;
    if (error.isMfaRequired) return l.errorMfaRequired;
    if (error.isForbidden) return l.errorForbidden;
    if (error.isConsentRequired) return l.errorConsentRequired;
    if (error.isRateLimited) return l.errorRateLimited;
    if (error.isServerError) return l.errorServer;
    if (error.isNotFound) return l.errorNotFound;
    // Validation / business messages from the server are human readable.
    if (error.message.isNotEmpty) return error.message;
  }
  return l.errorGeneric;
}

class EmptyStateView extends StatelessWidget {
  const EmptyStateView({
    super.key,
    required this.title,
    this.message,
    this.icon = Icons.inbox_outlined,
    this.actionLabel,
    this.onAction,
    this.compact = false,
  });
  final String title;
  final String? message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(compact ? Space.lg : Space.xxxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: compact ? 52 : 72,
              height: compact ? 52 : 72,
              decoration: BoxDecoration(color: context.mintSurface, shape: BoxShape.circle),
              child: Icon(icon, color: AppColors.primaryLight, size: compact ? 26 : 34),
            ),
            const SizedBox(height: Space.md),
            Text(title,
                textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
            if (message != null) ...[
              const SizedBox(height: Space.xs),
              Text(message!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.textMuted)),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: Space.lg),
              OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Error state covering offline, unauthorized, forbidden and generic errors.
class ErrorStateView extends ConsumerWidget {
  const ErrorStateView({super.key, required this.error, this.onRetry, this.compact = false});
  final Object error;
  final VoidCallback? onRetry;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final e = error is ApiException ? error as ApiException : null;
    IconData icon = Icons.error_outline;
    String title = l.errorTitle;
    Widget? action;
    if (e?.isOffline ?? false) {
      icon = Icons.wifi_off_rounded;
      title = l.offlineTitle;
    } else if (e?.isUnauthenticated ?? false) {
      icon = Icons.lock_outline;
      title = l.unauthorizedTitle;
      action = FilledButton(
        onPressed: () => ref.read(sessionProvider.notifier).logout(),
        child: Text(l.signInAgain),
      );
    } else if (e?.isMfaRequired ?? false) {
      icon = Icons.admin_panel_settings_outlined;
      title = l.mfaRequiredTitle;
      action = OutlinedButton(
        onPressed: () => ref.read(sessionProvider.notifier).logout(),
        child: Text(l.logout),
      );
    } else if (e?.isForbidden ?? false) {
      icon = Icons.no_accounts_outlined;
      title = l.forbiddenTitle;
    }
    action ??= onRetry == null
        ? null
        : OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: Text(l.retry),
          );
    return Center(
      child: Padding(
        padding: EdgeInsets.all(compact ? Space.lg : Space.xxxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: compact ? 32 : 44, color: context.textMuted),
            const SizedBox(height: Space.md),
            Text(title,
                textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: Space.xs),
            Text(errorMessage(context, error),
                textAlign: TextAlign.center,
                style: TextStyle(color: context.textMuted)),
            if (action != null) ...[const SizedBox(height: Space.lg), action],
          ],
        ),
      ),
    );
  }
}

class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.compact = false});
  final bool compact;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: EdgeInsets.all(compact ? Space.lg : Space.xxxl),
          child: Semantics(
            label: context.l10n.loading,
            child: const CircularProgressIndicator(),
          ),
        ),
      );
}

/// Renders an [AsyncValue] with consistent loading / error / empty states.
class AsyncView<T> extends StatelessWidget {
  const AsyncView({
    super.key,
    required this.value,
    required this.data,
    this.onRetry,
    this.isEmpty,
    this.empty,
    this.compact = false,
  });
  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final VoidCallback? onRetry;
  final bool Function(T data)? isEmpty;
  final Widget? empty;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    // Keep showing previous data while refreshing.
    if (value.hasValue && !value.hasError) {
      final v = value.requireValue;
      if (isEmpty != null && isEmpty!(v) && empty != null) return empty!;
      return data(v);
    }
    if (value.hasError) {
      return ErrorStateView(error: value.error!, onRetry: onRetry, compact: compact);
    }
    return LoadingView(compact: compact);
  }
}
