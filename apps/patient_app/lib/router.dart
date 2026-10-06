import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'features/ai/ask_ai_screen.dart';
import 'features/care/appointment_detail_screen.dart';
import 'features/care/care_plan_screen.dart';
import 'features/care/care_screen.dart';
import 'features/care/episode_detail_screen.dart';
import 'features/care/home_visit_tracking_screen.dart';
import 'features/care/medications_screen.dart';
import 'features/doctors/doctor_detail_screen.dart';
import 'features/doctors/find_doctor_screen.dart';
import 'features/emergency/fall_detection_screen.dart';
import 'features/emergency/sos_screen.dart';
import 'features/facilities/facilities_screen.dart';
import 'features/home/home_screen.dart';
import 'features/home/notifications_screen.dart';
import 'features/home/search_screen.dart';
import 'features/home_checkup/book_home_visit_screen.dart';
import 'features/home_checkup/home_checkup_screen.dart';
import 'features/misc/coming_soon_screen.dart';
import 'features/misc/force_update_screen.dart';
import 'features/onboarding/consents_screen.dart';
import 'features/onboarding/emergency_contact_screen.dart';
import 'features/onboarding/language_screen.dart';
import 'features/onboarding/onboarding_resume.dart';
import 'features/onboarding/otp_screen.dart';
import 'features/onboarding/phone_screen.dart';
import 'features/onboarding/profile_setup_screen.dart';
import 'features/onboarding/splash_screen.dart';
import 'features/payments/booking_success_screen.dart';
import 'features/pharmacy/cart_screen.dart';
import 'features/pharmacy/pharmacy_screen.dart';
import 'features/profile/consents_settings_screen.dart';
import 'features/profile/delete_account_screen.dart';
import 'features/profile/emergency_contacts_screen.dart';
import 'features/profile/family_screen.dart';
import 'features/profile/health_profile_screen.dart';
import 'features/profile/help_support_screen.dart';
import 'features/profile/language_settings_screen.dart';
import 'features/profile/notification_settings_screen.dart';
import 'features/profile/payments_history_screen.dart';
import 'features/profile/personal_info_screen.dart';
import 'features/profile/profile_screen.dart';
import 'features/records/record_detail_screen.dart';
import 'features/records/records_screen.dart';
import 'features/records/timeline_screen.dart';
import 'features/records/upload_record_screen.dart';
import 'features/records/vitals_screen.dart';
import 'features/shell/app_shell.dart';
import 'features/wearables/wearables_screen.dart';
import 'features/wellness/wellness_screen.dart';
import 'features/wound/wound_screen.dart';
import 'features/messages/inbox_screen.dart';
import 'features/messages/thread_screen.dart';
import 'features/prescriptions/pharmacy_match_screen.dart';
import 'features/prescriptions/prescription_detail_screen.dart';
import 'features/profile/appearance_screen.dart';
import 'features/profile/invoice_screen.dart';
import 'features/schemes/schemes_screen.dart';
import 'features/subscriptions/family_plan_screen.dart';
import 'features/wearables/health_privacy_screen.dart';
import 'features/abdm/abdm.dart';
import 'features/ambulance/ambulance.dart';
import 'features/checkin/checkin.dart';
import 'features/diet/diet.dart';
import 'features/exercise/exercise.dart';
import 'features/insurance/insurance.dart';
import 'features/lab/lab_screens.dart';
import 'features/preventive/preventive.dart';
import 'features/programs/programs.dart';
import 'features/safety/safety.dart';
import 'features/second_opinion/second_opinion.dart';
import 'features/support/support.dart';
import 'features/wallet/wallet.dart';
import 'models/services.dart' show InsurancePolicy;
import 'state/core_providers.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

String? appRedirect({
  required SessionState session,
  required bool languageChosen,
  required String location,
  bool updateRequired = false,
  String? onboardingResume,
}) {
  // Health Connect opens the app on its privacy/rationale screen; it must be
  // reachable in any state (store requirement).
  if (location == healthPrivacyRoute) return null;
  // Blocking "Please update" screen when below minAppVersion (§21).
  if (updateRequired) return location == '/update' ? null : '/update';
  if (location == '/update') return '/splash';
  final isPublic = location == '/splash' ||
      location.startsWith('/welcome') ||
      location.startsWith('/auth');
  switch (session.status) {
    case AuthStatus.unknown:
    case AuthStatus.offline:
      return location == '/splash' ? null : '/splash';
    case AuthStatus.unauthenticated:
      if (isPublic && location != '/splash') return null;
      return languageChosen ? '/auth/phone' : '/welcome/language';
    case AuthStatus.authenticated:
      if (session.needsOnboarding) {
        return location.startsWith('/onboarding') ? null : '/onboarding/consents';
      }
      // Reloaded during the optional steps after the profile: resume there.
      if (isPublic && onboardingResume != null) return onboardingResume;
      return isPublic ? '/home' : null;
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(sessionProvider, (_, _) => refresh.value++);
  ref.listen(updateRequiredProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  GoRoute page(String path, Widget Function(GoRouterState s) b) =>
      GoRoute(path: path, parentNavigatorKey: rootNavigatorKey, builder: (_, s) => b(s));

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) => appRedirect(
      session: ref.read(sessionProvider),
      languageChosen: ref.read(localeProvider.notifier).hasChosen,
      location: state.matchedLocation,
      updateRequired: ref.read(updateRequiredProvider),
      onboardingResume:
          ref.read(onboardingResumeProvider.notifier).routeFor(ref.read(sessionProvider).me?.id),
    ),
    routes: [
      page('/splash', (_) => const SplashScreen()),
      page('/update', (_) => const ForceUpdateScreen()),
      page('/welcome/language', (_) => const LanguageSelectScreen()),
      page('/auth/phone', (_) => const PhoneScreen()),
      page(
          '/auth/otp',
          (s) => OtpScreen(
                phone: s.uri.queryParameters['phone'] ?? '',
                devOtp: s.uri.queryParameters['devOtp'],
              )),
      page('/onboarding/consents', (_) => const OnboardingConsentsScreen()),
      page('/onboarding/profile', (_) => const ProfileSetupScreen()),
      page('/onboarding/emergency', (_) => const EmergencyContactSetupScreen()),
      page('/onboarding/invite', (_) => const OnboardingInviteScreen()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: '/home', builder: (_, _) => const HomeScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
                path: '/care',
                builder: (_, s) => CareScreen(initialTab: s.uri.queryParameters['tab'])),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
                path: '/ai',
                builder: (_, s) => AskAiScreen(
                      initialQuery: s.uri.queryParameters['q'],
                      voice: s.uri.queryParameters['voice'] == '1',
                    )),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/records', builder: (_, _) => const RecordsScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/profile', builder: (_, _) => const ProfileScreen()),
          ]),
        ],
      ),
      // Full-screen routes (root navigator).
      page('/search', (s) => SearchScreen(initial: s.uri.queryParameters['q'])),
      page('/notifications', (_) => const NotificationsScreen()),
      page('/episodes/:id', (s) => EpisodeDetailScreen(id: s.pathParameters['id']!)),
      page('/appointments/:id', (s) => AppointmentDetailScreen(id: s.pathParameters['id']!)),
      page('/home-visits/:id', (s) => HomeVisitTrackingScreen(id: s.pathParameters['id']!)),
      page('/care-plans/:id', (s) => CarePlanScreen(id: s.pathParameters['id']!)),
      page('/medications', (_) => const MedicationsScreen()),
      page('/medications/add', (_) => const AddMedicationScreen()),
      page(
          '/doctors',
          (s) => FindDoctorScreen(
                specialty: s.uri.queryParameters['specialty'],
                mode: s.uri.queryParameters['mode'],
                careEpisodeId: s.uri.queryParameters['episode'],
              )),
      page(
          '/doctors/:id',
          (s) => DoctorDetailScreen(
                id: s.pathParameters['id']!,
                rescheduleAppointmentId: s.uri.queryParameters['reschedule'],
                careEpisodeId: s.uri.queryParameters['episode'],
                initialTab: int.tryParse(s.uri.queryParameters['tab'] ?? ''),
              )),
      page('/booking/success', (s) => BookingSuccessScreen(args: s.extra as BookingSuccessArgs?)),
      page('/home-checkup', (_) => const HomeCheckupScreen()),
      page('/home-checkup/book',
          (s) => BookHomeVisitScreen(
                serviceCode: s.uri.queryParameters['service'],
                careEpisodeId: s.uri.queryParameters['episode'],
              )),
      page('/pharmacy', (_) => const PharmacyScreen()),
      page('/pharmacy/cart', (_) => const CartScreen()),
      page('/records/upload', (s) => UploadRecordScreen(initialType: s.uri.queryParameters['type'])),
      page('/records/:id', (s) => RecordDetailScreen(id: s.pathParameters['id']!)),
      page('/timeline', (_) => const TimelineScreen()),
      page('/vitals', (_) => const VitalsScreen()),
      page('/wellness', (_) => const WellnessScreen()),
      page('/wound', (_) => const WoundScreen()),
      page('/wearables', (_) => const WearablesScreen()),
      page('/sos', (_) => const SosScreen()),
      page('/facilities', (s) => FacilitiesScreen(initialType: s.uri.queryParameters['type'])),
      page('/fall-detection', (_) => const FallDetectionScreen()),
      page('/schemes', (_) => const SchemesScreen()),
      page('/schemes/:id', (s) => SchemeDetailScreen(id: s.pathParameters['id']!)),
      page('/prescriptions/:id', (s) => PrescriptionDetailScreen(id: s.pathParameters['id']!)),
      page('/prescriptions/:id/pharmacy-match',
          (s) => PharmacyMatchScreen(prescriptionId: s.pathParameters['id']!)),
      page('/payments/:id/invoice', (s) => InvoiceScreen(paymentId: s.pathParameters['id']!)),
      page('/inbox', (_) => const InboxScreen()),
      page('/care-episodes/:id/messages', (s) => ThreadScreen(episodeId: s.pathParameters['id']!)),
      page('/profile/family-plan', (_) => const FamilyPlanScreen()),
      page('/profile/appearance', (_) => const AppearanceScreen()),
      page(healthPrivacyRoute, (_) => const HealthPrivacyScreen()),
      page('/unavailable',
          (s) => ComingSoonScreen(kind: ComingSoonKind.feature, title: s.uri.queryParameters['title'])),
      page('/profile/help', (_) => const HelpSupportScreen()),
      page('/profile/delete-account', (_) => const DeleteAccountScreen()),
      page('/profile/personal', (_) => const PersonalInfoScreen()),
      page('/profile/health', (_) => const HealthProfileScreen()),
      page('/profile/family', (_) => const FamilyScreen()),
      page('/profile/language', (_) => const LanguageSettingsScreen()),
      page('/profile/notifications', (_) => const NotificationSettingsScreen()),
      page('/profile/consents', (_) => const ConsentsSettingsScreen()),
      page('/profile/emergency-contacts', (_) => const EmergencyContactsScreen()),
      page('/profile/payments', (_) => const PaymentsHistoryScreen()),
      // v1.3 (API_CONTRACT §41–§61)
      page('/checkin', (_) => const CheckinSettingsScreen()),
      page('/programs', (_) => const ProgramsScreen()),
      page('/programs/:id', (s) => ProgramDetailScreen(id: s.pathParameters['id']!)),
      page('/lab', (_) => const LabScreen()),
      page('/lab/checkout', (_) => const LabCheckoutScreen()),
      page('/lab/orders', (_) => const LabOrdersScreen()),
      page('/lab/orders/:id', (s) => LabOrderScreen(id: s.pathParameters['id']!)),
      page('/second-opinion', (_) => const SecondOpinionScreen()),
      page('/second-opinion/new', (_) => const NewSecondOpinionScreen()),
      page('/second-opinion/:id', (s) => SecondOpinionDetailScreen(id: s.pathParameters['id']!)),
      page('/abha/create', (_) => const AbhaFlowScreen(mode: AbhaFlowMode.create)),
      page('/abha/link', (_) => const AbhaFlowScreen(mode: AbhaFlowMode.link)),
      page('/abdm/consents', (_) => const AbdmConsentsScreen()),
      page('/insurance', (_) => const InsuranceScreen()),
      page('/insurance/edit', (s) => PolicyEditScreen(policy: s.extra is InsurancePolicy ? s.extra as InsurancePolicy : null)),
      page('/insurance/checklist', (_) => const ClaimChecklistScreen()),
      page(
          '/insurance/cashless',
          (s) => CashlessHospitalsScreen(
              insurerCode: s.uri.queryParameters['insurer'] ?? '', insurerName: s.uri.queryParameters['name'])),
      page('/preventive', (_) => const PreventiveCareScreen()),
      page('/exercise', (_) => const ExerciseScreen()),
      page('/diet', (_) => const DietScreen()),
      page('/ambulance/book', (_) => const AmbulanceBookScreen()),
      page('/ambulance/:id', (s) => AmbulanceTrackingScreen(id: s.pathParameters['id']!)),
      page('/safety', (_) => const SafetyHubScreen()),
      page('/safety/safe-zone', (_) => const SafeZoneScreen()),
      page('/safety/companion', (_) => const CompanionModeScreen()),
      page('/safety/sos-button', (_) => const SosButtonScreen()),
      page('/wallet', (_) => const WalletScreen()),
      page('/invite', (_) => const InviteScreen()),
      page('/support/tickets', (_) => const TicketsScreen()),
      page('/support/new', (_) => const NewTicketScreen()),
      page('/support/tickets/:id', (s) => TicketScreen(id: s.pathParameters['id']!)),
    ],
  );
});
