import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../state/core_providers.dart';

/// The optional onboarding steps after the profile (emergency contact, invite
/// code) run when the server already counts onboarding as complete. If the
/// app reloads in between, resume at the step the user had reached instead of
/// skipping to Home (B30). Stored per user as `userId|route`.
class OnboardingResume extends Notifier<String?> {
  static const key = 'cc_onboarding_resume';

  @override
  String? build() {
    try {
      return ref.read(sharedPrefsProvider).getString(key);
    } catch (_) {
      return null;
    }
  }

  /// The step to resume for [userId], if any.
  String? routeFor(String? userId) {
    final v = state;
    if (userId == null || v == null) return null;
    final i = v.indexOf('|');
    if (i < 0 || v.substring(0, i) != userId) return null;
    final route = v.substring(i + 1);
    return route.startsWith('/onboarding/') ? route : null;
  }

  /// Remembers [route] as the next step, or clears it when [route] leaves
  /// onboarding (e.g. `/home`).
  Future<void> set(String? userId, String route) async {
    final keep = userId != null && route.startsWith('/onboarding/');
    state = keep ? '$userId|$route' : null;
    try {
      final prefs = ref.read(sharedPrefsProvider);
      keep ? await prefs.setString(key, state!) : await prefs.remove(key);
    } catch (_) {}
  }
}

final onboardingResumeProvider = NotifierProvider<OnboardingResume, String?>(OnboardingResume.new);

/// Moves to the next onboarding step (or Home), remembering it for a reload.
Future<void> goOnboardingStep(BuildContext context, WidgetRef ref, String route) async {
  await ref.read(onboardingResumeProvider.notifier).set(ref.read(sessionProvider).me?.id, route);
  if (context.mounted) context.go(route);
}
