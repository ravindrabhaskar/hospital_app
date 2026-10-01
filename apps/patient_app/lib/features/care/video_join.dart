import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_exception.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/format.dart';
import '../../core/utils/links.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/state_views.dart';
import '../../models/care.dart';
import '../../state/core_providers.dart';

/// "1h 05m" / "4m 09s" countdown text (digits only, locale-neutral).
String fmtCountdown(Duration d) {
  if (d.isNegative) return '0m 00s';
  final h = d.inHours, m = d.inMinutes.remainder(60), s = d.inSeconds.remainder(60);
  if (h > 0) return '${h}h ${m.toString().padLeft(2, '0')}m';
  return '${m}m ${s.toString().padLeft(2, '0')}s';
}

/// Audio consultations use the same Jitsi room with the camera off (§26).
String joinUrlForMode(VideoSession s, String mode) {
  if (mode != 'audio' || s.provider != 'jitsi' || s.joinUrl.contains('#')) return s.joinUrl;
  return '${s.joinUrl}#config.startWithVideoMuted=true';
}

/// Join card for video/audio appointments (API_CONTRACT §26): countdown
/// before the window opens, a pre-join checklist, then the Jitsi link opens
/// outside the app (Jitsi Meet app if installed, otherwise the browser).
class VideoJoinCard extends ConsumerStatefulWidget {
  const VideoJoinCard({super.key, required this.appointment, this.now});
  final Appointment appointment;

  /// Test hook: a fixed "now".
  final DateTime Function()? now;

  @override
  ConsumerState<VideoJoinCard> createState() => _VideoJoinCardState();
}

class _VideoJoinCardState extends ConsumerState<VideoJoinCard> {
  Timer? _timer;
  bool _busy = false;
  DateTime? _serverOpensAt;

  DateTime _now() => (widget.now ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  JoinWindow get _window {
    final a = widget.appointment;
    final w = JoinWindow.forAppointment(a.startAt, a.endAt);
    final server = _serverOpensAt;
    return server != null && server.isAfter(w.opensAt) ? JoinWindow(server, w.closesAt) : w;
  }

  Future<void> _join() async {
    final l = context.l10n;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => PreJoinChecklist(audioOnly: widget.appointment.mode == 'audio'),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final s = await ref.read(appointmentRepositoryProvider).videoSession(widget.appointment.id);
      if (!mounted) return;
      if (s.joinUrl.isEmpty) {
        showSnack(context, l.videoLinkLater);
        return;
      }
      await openExternal(context, Uri.parse(joinUrlForMode(s, widget.appointment.mode)));
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.isConflict && e.details['opensAt'] is String) {
        final opens = DateTime.tryParse(e.details['opensAt'] as String)?.toLocal();
        if (opens != null) {
          setState(() => _serverOpensAt = opens);
          showSnack(context, l.consultationOpensAt(fmtDateTime(context, opens)));
          return;
        }
      }
      showSnack(context, errorMessage(context, e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final now = _now();
    final w = _window;
    final state = w.stateAt(now);
    final audio = widget.appointment.mode == 'audio';
    final String status = switch (state) {
      JoinWindowState.tooEarly => w.untilOpen(now) > const Duration(hours: 24)
          ? l.consultationOpensAt(fmtDateTime(context, w.opensAt))
          : l.consultationOpensIn(fmtCountdown(w.untilOpen(now))),
      JoinWindowState.open => l.consultationOpenNow,
      JoinWindowState.closed => l.consultationEnded,
    };
    return CcCard(
      key: const Key('video-join-card'),
      color: state == JoinWindowState.open ? context.mintSurface : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(audio ? Icons.call_outlined : Icons.videocam_outlined, color: context.brand),
              const SizedBox(width: 8),
              Expanded(
                child: Text(audio ? l.audioConsultation : l.videoConsultation,
                    style: Theme.of(context).textTheme.titleSmall),
              ),
            ],
          ),
          const SizedBox(height: Space.xs),
          Semantics(
            liveRegion: true,
            child: Text(status, key: const Key('join-status'), style: TextStyle(color: context.textMuted)),
          ),
          const SizedBox(height: Space.md),
          PrimaryButton(
            key: const Key('join-consultation'),
            label: l.joinConsultation,
            icon: audio ? Icons.call : Icons.videocam,
            loading: _busy,
            onPressed: state == JoinWindowState.open ? _join : null,
          ),
        ],
      ),
    );
  }
}

/// Pre-join checklist (camera/mic, quiet place, connection).
class PreJoinChecklist extends StatefulWidget {
  const PreJoinChecklist({super.key, required this.audioOnly});
  final bool audioOnly;

  @override
  State<PreJoinChecklist> createState() => _PreJoinChecklistState();
}

class _PreJoinChecklistState extends State<PreJoinChecklist> {
  final _checked = <int>{};

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final items = [
      (widget.audioOnly ? Icons.mic_none : Icons.videocam_outlined,
          widget.audioOnly ? l.checklistMic : l.checklistCameraMic),
      (Icons.volume_off_outlined, l.checklistQuietPlace),
      (Icons.wifi, l.checklistConnection),
      (Icons.description_outlined, l.checklistReports),
    ];
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Space.screen, 0, Space.screen, Space.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.beforeYouJoin, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: Space.xs),
            Text(l.beforeYouJoinSub, style: TextStyle(color: context.textMuted)),
            const SizedBox(height: Space.md),
            for (var i = 0; i < items.length; i++)
              CheckboxListTile(
                value: _checked.contains(i),
                onChanged: (v) => setState(() => v == true ? _checked.add(i) : _checked.remove(i)),
                secondary: Icon(items[i].$1, color: context.brand),
                title: Text(items[i].$2),
                contentPadding: EdgeInsets.zero,
              ),
            const SizedBox(height: Space.sm),
            Text(l.joinOpensOutside, style: TextStyle(fontSize: 12.5, color: context.textMuted)),
            const SizedBox(height: Space.lg),
            PrimaryButton(
              key: const Key('join-now'),
              label: l.joinNow,
              icon: Icons.open_in_new,
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        ),
      ),
    );
  }
}
