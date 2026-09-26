import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'wearable_sync.dart';

/// Syncs the connected health store when the app opens and on every resume,
/// at most once per [wearableResumeThrottle] (the controller checks it).
class WearableResumeSync extends ConsumerStatefulWidget {
  const WearableResumeSync({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<WearableResumeSync> createState() => _WearableResumeSyncState();
}

class _WearableResumeSyncState extends ConsumerState<WearableResumeSync> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeSync());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _maybeSync();
  }

  Future<void> _maybeSync() async {
    if (!mounted) return;
    try {
      await ref.read(wearableSyncProvider.notifier).sync(onlyIfDue: true);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
