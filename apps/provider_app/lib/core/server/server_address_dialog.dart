import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../l10n/gen/app_localizations.dart';
import 'server_settings.dart';

/// Opens the "Server address" dialog. Returns true when the server changed.
///
/// [beforeChange] runs before a new address is applied (signed-in users are
/// logged out first, because tokens belong to a server); [afterChange] runs
/// once the API client points at the new server (e.g. reload public config).
Future<bool> showServerAddressDialog(
  BuildContext context, {
  required ServerSettings settings,
  required http.Client httpClient,
  bool signedIn = false,
  Future<void> Function()? beforeChange,
  Future<void> Function()? afterChange,
}) async {
  if (!settings.overrideAllowed) return false;
  final changed = await showDialog<bool>(
    context: context,
    builder: (_) => ServerAddressDialog(
      settings: settings,
      httpClient: httpClient,
      signedIn: signedIn,
      beforeChange: beforeChange,
      afterChange: afterChange,
    ),
  );
  return changed ?? false;
}

class ServerAddressDialog extends StatefulWidget {
  const ServerAddressDialog({
    super.key,
    required this.settings,
    required this.httpClient,
    this.signedIn = false,
    this.beforeChange,
    this.afterChange,
  });

  final ServerSettings settings;
  final http.Client httpClient;
  final bool signedIn;
  final Future<void> Function()? beforeChange;
  final Future<void> Function()? afterChange;

  @override
  State<ServerAddressDialog> createState() => _ServerAddressDialogState();
}

class _ServerAddressDialogState extends State<ServerAddressDialog> {
  late final TextEditingController _ctrl = TextEditingController(text: widget.settings.effectiveUrl);
  String? _invalid;
  bool _testing = false;
  bool _busy = false;
  ServerCheckResult? _result;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String? _normalized() => normalizeServerUrl(_ctrl.text);

  Future<void> _test() async {
    final l = AppLocalizations.of(context);
    final url = _normalized();
    if (url == null) {
      setState(() => _invalid = l.serverAddressInvalid);
      return;
    }
    setState(() {
      _testing = true;
      _result = null;
    });
    final r = await checkServerHealth(widget.httpClient, url);
    if (!mounted) return;
    setState(() {
      _testing = false;
      _result = r;
    });
  }

  Future<void> _apply(Future<void> Function() change) async {
    setState(() => _busy = true);
    var done = false;
    try {
      if (widget.signedIn) await widget.beforeChange?.call();
      await change();
      done = true;
      await widget.afterChange?.call();
    } catch (_) {
      // Best effort: a failed reload must not keep the dialog stuck.
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    // The dialog may already be gone (logging out re-routes to the login screen).
    if (mounted) Navigator.of(context).pop(done);
  }

  Future<void> _save() async {
    final l = AppLocalizations.of(context);
    final url = _normalized();
    if (url == null) {
      setState(() => _invalid = l.serverAddressInvalid);
      return;
    }
    final s = widget.settings;
    if (url == s.effectiveUrl) {
      Navigator.of(context).pop(false);
      return;
    }
    await _apply(() async {
      if (url == s.defaultUrl) {
        await s.reset();
      } else {
        await s.setOverride(url);
      }
    });
  }

  Future<void> _reset() async {
    if (!widget.settings.isOverridden) {
      Navigator.of(context).pop(false);
      return;
    }
    await _apply(widget.settings.reset);
  }

  Widget _resultView(AppLocalizations l) {
    final r = _result;
    if (_testing) {
      return Row(children: [
        const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
        const SizedBox(width: 10),
        Expanded(child: Text(l.serverTesting)),
      ]);
    }
    if (r == null) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final (IconData icon, Color color, String text) = r.ok
        ? (Icons.check_circle, Colors.green.shade700, '✓ ${l.serverConnectedVersion(r.version ?? '?')}')
        : r.unreachable
            ? (Icons.error_outline, scheme.error, l.serverCantReach)
            : (Icons.error_outline, scheme.error, l.serverNotCareCompanion('${r.statusCode}'));
    return Semantics(
      liveRegion: true,
      child: Row(
        key: const Key('serverResult'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: TextStyle(color: color))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final normalized = _normalized();
    final muted = Theme.of(context).textTheme.bodySmall?.color;
    return AlertDialog(
      title: Text(l.serverAddressTitle),
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l.serverAddressHelp, style: TextStyle(fontSize: 13, color: muted)),
          const SizedBox(height: 12),
          TextField(
            key: const Key('serverUrlField'),
            controller: _ctrl,
            keyboardType: TextInputType.url,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              labelText: l.serverAddressLabel,
              errorText: _invalid,
              helperText: _invalid == null && normalized != null && normalized != _ctrl.text.trim()
                  ? '→ $normalized'
                  : null,
              helperMaxLines: 2,
            ),
            onChanged: (_) => setState(() {
              _invalid = null;
              _result = null;
            }),
            onSubmitted: (_) => _test(),
          ),
          const SizedBox(height: 4),
          Text(l.serverDefaultIs(widget.settings.defaultUrl), style: TextStyle(fontSize: 12, color: muted)),
          const SizedBox(height: 8),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: OutlinedButton.icon(
              key: const Key('serverTest'),
              onPressed: _testing || _busy ? null : _test,
              icon: const Icon(Icons.network_check, size: 18),
              label: Text(l.serverTestConnection),
            ),
          ),
          const SizedBox(height: 8),
          _resultView(l),
          if (widget.signedIn) ...[
            const SizedBox(height: 12),
            Text(l.serverSignOutWarning, style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.error)),
          ],
        ],
      ),
      actions: [
        TextButton(
          key: const Key('serverReset'),
          onPressed: _busy || !widget.settings.isOverridden ? null : _reset,
          child: Text(l.serverReset),
        ),
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          key: const Key('serverSave'),
          onPressed: _busy ? null : _save,
          child: Text(l.serverSave),
        ),
      ],
    );
  }
}

/// Small "Server: host" chip for the login screen (demo builds only).
class ServerAddressChip extends StatelessWidget {
  const ServerAddressChip({super.key, required this.settings, required this.onTap});

  final ServerSettings settings;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (!settings.overrideAllowed) return const SizedBox.shrink();
    final l = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => Center(
        child: ActionChip(
          key: const Key('serverChip'),
          avatar: const Icon(Icons.dns_outlined, size: 16),
          label: Text(l.serverChip(settings.host), style: const TextStyle(fontSize: 12)),
          visualDensity: VisualDensity.compact,
          onPressed: onTap,
        ),
      ),
    );
  }
}

/// "Can't reach the server at host" + a "Change server" action (when allowed).
class ServerUnreachableNotice extends StatelessWidget {
  const ServerUnreachableNotice({super.key, required this.settings, required this.onChangeServer, this.color});

  final ServerSettings settings;
  final VoidCallback onChangeServer;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = color ?? Theme.of(context).colorScheme.error;
    return Semantics(
      liveRegion: true,
      child: Column(
        key: const Key('serverUnreachable'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.serverCantReachAt(settings.host), style: TextStyle(color: c, fontWeight: FontWeight.w600)),
          if (settings.overrideAllowed)
            TextButton.icon(
              key: const Key('changeServer'),
              style: TextButton.styleFrom(padding: EdgeInsets.zero),
              onPressed: onChangeServer,
              icon: const Icon(Icons.dns_outlined, size: 18),
              label: Text(l.serverChange),
            ),
        ],
      ),
    );
  }
}
