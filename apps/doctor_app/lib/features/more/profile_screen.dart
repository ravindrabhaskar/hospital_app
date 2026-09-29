import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../models/doctor.dart';
import '../../ui/l10n_helpers.dart';
import '../../ui/widgets.dart';

final doctorProfileProvider = FutureProvider.autoDispose<DoctorProfile>(
  (ref) => ref.watch(clinicianRepositoryProvider).profile(),
);

/// Doctor profile (contract §29): photo, fees, bio, languages, accepting
/// bookings.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.profileTitle)),
      body: AsyncBody<DoctorProfile>(
        value: ref.watch(doctorProfileProvider),
        onRetry: () => ref.invalidate(doctorProfileProvider),
        data: (p) => ProfileForm(profile: p),
      ),
    );
  }
}

class ProfileForm extends ConsumerStatefulWidget {
  const ProfileForm({super.key, required this.profile});
  final DoctorProfile profile;

  @override
  ConsumerState<ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends ConsumerState<ProfileForm> {
  late DoctorProfile _p = widget.profile;
  late final _bio = TextEditingController(text: _p.bio);
  late final _quals = TextEditingController(text: _p.qualifications);
  late final _langs = TextEditingController(text: _p.languages.join(', '));
  late final _video = TextEditingController(text: '${_p.fees.video}');
  late final _audio = TextEditingController(text: '${_p.fees.audio}');
  late final _chat = TextEditingController(text: '${_p.fees.chat}');
  late final _clinic = TextEditingController(text: '${_p.fees.inClinic}');
  bool _busy = false;
  bool _photoBusy = false;

  Future<void> _patch(Map<String, dynamic> body, String ok) async {
    final l = context.l10n;
    setState(() => _busy = true);
    try {
      final updated = await ref.read(clinicianRepositoryProvider).updateProfile(body);
      setState(() => _p = updated);
      ref.read(authControllerProvider).updateProfile(updated);
      if (mounted) showSnack(context, ok);
    } catch (e) {
      if (mounted) showSnack(context, errorMessage(l, e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _photo(bool camera) async {
    final l = context.l10n;
    final picked = await ref.read(photoPickerProvider)(camera: camera);
    if (picked == null || !mounted) return;
    if (picked.bytes.length > 5 * 1024 * 1024) {
      showSnack(context, l.photoTooLarge, error: true);
      return;
    }
    setState(() => _photoBusy = true);
    try {
      await ref
          .read(clinicianRepositoryProvider)
          .uploadPhoto(picked.bytes, filename: picked.filename, contentType: picked.contentType);
      final refreshed = await ref.read(clinicianRepositoryProvider).profile();
      setState(() => _p = refreshed);
      ref.read(authControllerProvider).updateProfile(refreshed);
      if (mounted) showSnack(context, l.photoUpdated);
    } catch (e) {
      if (mounted) showSnack(context, errorMessage(l, e), error: true);
    } finally {
      if (mounted) setState(() => _photoBusy = false);
    }
  }

  Widget _fee(TextEditingController c, String label) => Expanded(
    child: TextField(
      controller: c,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(5)],
      decoration: InputDecoration(labelText: label, prefixText: '₹ '),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.screen),
      children: [
        Center(
          child: CircleAvatar(
            radius: 48,
            backgroundColor: AppColors.mint100,
            foregroundImage: _p.photoUrl == null ? null : NetworkImage(_p.photoUrl!),
            child: _photoBusy
                ? const CircularProgressIndicator()
                : const Icon(Icons.person, size: 48, color: AppColors.primary),
          ),
        ),
        gap8,
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton.icon(
              key: const Key('photoGallery'),
              onPressed: _photoBusy ? null : () => _photo(false),
              icon: const Icon(Icons.photo_library_outlined),
              label: Text(l.photoGallery),
            ),
            TextButton.icon(
              onPressed: _photoBusy ? null : () => _photo(true),
              icon: const Icon(Icons.photo_camera_outlined),
              label: Text(l.photoCamera),
            ),
          ],
        ),
        Text(_p.name, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
        Text(
          [
            _p.specialtyName ?? '',
            if (_p.registrationNumber != null) l.regNo(_p.registrationNumber!),
          ].where((s) => s.isNotEmpty).join(' · '),
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        if (_p.rating != null)
          Text(
            l.ratingLine(formatNumber(_p.rating!), _p.ratingCount),
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        gap16,
        Card(
          child: SwitchListTile(
            key: const Key('acceptingBookings'),
            value: _p.acceptingBookings,
            onChanged: _busy ? null : (v) => _patch({'acceptingBookings': v}, v ? l.bookingsOn : l.bookingsOff),
            title: Text(l.acceptingBookings),
            subtitle: Text(l.acceptingBookingsHint),
          ),
        ),
        gap12,
        SectionCard(
          title: l.feesTitle,
          child: Column(
            children: [
              Row(children: [_fee(_video, l.modeVideo), const SizedBox(width: 8), _fee(_audio, l.modeAudio)]),
              gap8,
              Row(children: [_fee(_chat, l.modeChat), const SizedBox(width: 8), _fee(_clinic, l.modeInClinic)]),
            ],
          ),
        ),
        gap12,
        TextField(
          controller: _quals,
          decoration: InputDecoration(labelText: l.qualifications),
        ),
        gap12,
        TextField(
          controller: _langs,
          decoration: InputDecoration(labelText: l.languagesSpoken, helperText: l.commaSeparated),
        ),
        gap12,
        TextField(
          controller: _bio,
          minLines: 3,
          maxLines: 8,
          decoration: InputDecoration(labelText: l.bio),
        ),
        gap16,
        FilledButton(
          key: const Key('saveProfile'),
          onPressed: _busy
              ? null
              : () => _patch({
                  'bio': _bio.text.trim(),
                  'qualifications': _quals.text.trim(),
                  'languages': _langs.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList(),
                  'fees': Fees(
                    video: int.tryParse(_video.text) ?? 0,
                    audio: int.tryParse(_audio.text) ?? 0,
                    chat: int.tryParse(_chat.text) ?? 0,
                    inClinic: int.tryParse(_clinic.text) ?? 0,
                  ).toJson(),
                }, l.profileSaved),
          child: _busy ? const ButtonSpinner() : Text(l.commonSave),
        ),
      ],
    );
  }
}
