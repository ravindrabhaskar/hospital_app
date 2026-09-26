import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../models/provider_application.dart';
import '../../models/public_config.dart';
import '../../ui/l10n_helpers.dart';
import '../../ui/widgets.dart';
import 'application_controller.dart';
import 'application_documents.dart';
import 'application_form.dart';
import 'document_picker.dart';

/// Shown to signed-in accounts without the `provider` role (replaces the old
/// "Access restricted" screen): apply, upload documents, follow the review.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  late final ApplicationController _controller;

  @override
  void initState() {
    super.initState();
    final auth = ref.read(authControllerProvider);
    _controller = ApplicationController(
      repository: ref.read(applicationRepositoryProvider),
      // Approval adds the role server-side: re-read /me so the router moves on.
      onApproved: auth.loadIdentity,
    )..load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    return OnboardingView(
      controller: _controller,
      picker: ref.watch(documentPickerProvider),
      support: ref.watch(publicConfigProvider).config?.support,
      onLogout: auth.logout,
      onCheckApproved: () async {
        await auth.loadIdentity();
        await _controller.load();
      },
    );
  }
}

/// Pure presentation of the onboarding flow; routes on [ApplicationController.phase].
class OnboardingView extends StatelessWidget {
  const OnboardingView({
    super.key,
    required this.controller,
    required this.picker,
    required this.onLogout,
    required this.onCheckApproved,
    this.support,
  });

  final ApplicationController controller;
  final DocumentPicker picker;
  final VoidCallback onLogout;
  final Future<void> Function() onCheckApproved;
  final SupportContact? support;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final phase = controller.phase;
        final app = controller.application;
        final Widget body = switch (phase) {
          ApplicationPhase.loading => const LoadingView(),
          ApplicationPhase.error => ErrorView(
              message: errorMessage(l, controller.error ?? Exception()),
              onRetry: controller.load,
            ),
          ApplicationPhase.form => ApplicationForm(
              key: ValueKey('form.${controller.editing}'),
              repository: controller.repository,
              initial: app == null ? null : ApplicationDraft.fromApplication(app),
              busy: controller.busy,
              onSubmit: controller.submit,
              onCancel: controller.editing ? controller.cancelEditing : null,
            ),
          ApplicationPhase.status => _StatusBody(controller: controller, picker: picker, support: support),
          ApplicationPhase.approved => _ApprovedBody(
              application: app!,
              onLogout: onLogout,
              onCheck: onCheckApproved,
            ),
        };
        return Scaffold(
          appBar: AppBar(
            title: Text(controller.editing ? l.onbEditTitle : l.onbTitle),
            actions: [
              IconButton(
                key: const Key('onbLogout'),
                tooltip: l.commonLogout,
                icon: const Icon(Icons.logout),
                onPressed: onLogout,
              ),
            ],
          ),
          body: SafeArea(
            child: Column(
              children: [
                if (phase == ApplicationPhase.form && app == null)
                  Container(
                    key: const Key('onbIntro'),
                    width: double.infinity,
                    color: AppColors.mint50,
                    padding: const EdgeInsets.all(AppSpacing.screen),
                    child: Text(l.onbIntro),
                  ),
                Expanded(child: body),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StatusBody extends StatelessWidget {
  const _StatusBody({required this.controller, required this.picker, this.support});

  final ApplicationController controller;
  final DocumentPicker picker;
  final SupportContact? support;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final app = controller.application!;
    final (IconData icon, Color fg, Color bg, String title, String body) = switch (app.status) {
      ApplicationStatus.changesRequested => (
          Icons.edit_note,
          const Color(0xFF9A5A10),
          AppColors.warningBg,
          l.onbStatusChangesTitle,
          l.onbStatusChangesBody,
        ),
      ApplicationStatus.rejected => (
          Icons.cancel_outlined,
          AppColors.dangerDeep,
          AppColors.dangerBg,
          l.onbStatusRejectedTitle,
          l.onbStatusRejectedBody,
        ),
      _ => (
          Icons.hourglass_top,
          AppColors.primary,
          AppColors.mint50,
          l.onbStatusSubmittedTitle,
          l.onbStatusSubmittedBody,
        ),
    };
    final note = app.decisionNote;
    return RefreshIndicator(
      onRefresh: controller.load,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.screen),
        children: [
          SectionCard(
            key: Key('status.${app.status}'),
            color: bg,
            child: Column(
              children: [
                Icon(icon, size: 44, color: fg),
                const SizedBox(height: 8),
                Semantics(
                  header: true,
                  child: Text(title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
                ),
                const SizedBox(height: 8),
                Text(body, textAlign: TextAlign.center),
                if (app.updatedAt != null) ...[
                  const SizedBox(height: 8),
                  Text(l.onbUpdatedOn(formatDate(context, app.updatedAt)),
                      style: const TextStyle(color: AppColors.textSecondary)),
                ],
              ],
            ),
          ),
          if (note != null && note.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            SectionCard(
              key: const Key('reviewerNote'),
              title: app.decidedByName == null ? l.onbReviewerNote : l.onbReviewerNoteBy(app.decidedByName!),
              child: Text(note),
            ),
          ],
          if (app.status == ApplicationStatus.changesRequested) ...[
            const SizedBox(height: 12),
            FilledButton.icon(
              key: const Key('onbEditResubmit'),
              onPressed: controller.startEditing,
              icon: const Icon(Icons.edit_outlined),
              label: Text(l.onbEditResubmit),
            ),
          ],
          const SizedBox(height: 12),
          ApplicationDocumentsCard(controller: controller, picker: picker),
          const SizedBox(height: 12),
          SectionCard(
            title: providerTypeLabel(l, app.type),
            child: Column(
              children: [
                LabeledValue(icon: Icons.person_outline, label: l.onbFullName, value: app.fullName),
                LabeledValue(icon: Icons.school_outlined, label: l.onbQualification, value: app.qualification),
                LabeledValue(icon: Icons.verified_outlined, label: l.onbRegNumber, value: app.registrationNumber),
                LabeledValue(icon: Icons.translate, label: l.onbLanguages, value: app.languages.join(', ')),
              ],
            ),
          ),
          if (app.status == ApplicationStatus.submitted) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              key: const Key('onbEditDetails'),
              onPressed: controller.startEditing,
              icon: const Icon(Icons.edit_outlined),
              label: Text(l.onbEditDetails),
            ),
          ],
          if (app.status == ApplicationStatus.rejected && support != null && !support!.isEmpty) ...[
            const SizedBox(height: 12),
            SectionCard(title: l.profileSupport, child: SupportContactButtons(support: support!)),
          ],
          const SizedBox(height: 8),
          TextButton.icon(
            key: const Key('onbRefresh'),
            onPressed: controller.loading ? null : controller.load,
            icon: const Icon(Icons.refresh),
            label: Text(l.onbCheckStatus),
          ),
        ],
      ),
    );
  }
}

class _ApprovedBody extends StatefulWidget {
  const _ApprovedBody({required this.application, required this.onLogout, required this.onCheck});

  final ProviderApplication application;
  final VoidCallback onLogout;
  final Future<void> Function() onCheck;

  @override
  State<_ApprovedBody> createState() => _ApprovedBodyState();
}

class _ApprovedBodyState extends State<_ApprovedBody> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final doctor = widget.application.type == 'doctor';
    return ListView(
      key: const Key('status.approved'),
      padding: const EdgeInsets.all(AppSpacing.screen),
      children: [
        const SizedBox(height: 24),
        const Icon(Icons.verified, size: 64, color: AppColors.primary),
        const SizedBox(height: 12),
        Semantics(
          header: true,
          child: Text(l.onbApprovedTitle, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
        ),
        const SizedBox(height: 12),
        Text(doctor ? l.onbApprovedDoctorBody : l.onbApprovedBody, textAlign: TextAlign.center),
        const SizedBox(height: 24),
        FilledButton(
          key: const Key('onbSignOutAndIn'),
          onPressed: widget.onLogout,
          child: Text(l.onbSignOutAndIn),
        ),
        if (!doctor) ...[
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _busy
                ? null
                : () async {
                    setState(() => _busy = true);
                    await widget.onCheck();
                    if (mounted) setState(() => _busy = false);
                  },
            child: Text(l.onbCheckStatus),
          ),
        ],
      ],
    );
  }
}
