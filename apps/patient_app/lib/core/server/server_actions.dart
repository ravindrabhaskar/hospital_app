import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/core_providers.dart';
import 'server_address_dialog.dart';

/// Opens the "Server address" dialog wired to this app: signed-in users are
/// logged out before the server changes (tokens belong to a server), then the
/// public config is reloaded from the new server.
Future<bool> openServerAddressDialog(BuildContext context) {
  // The container outlives the calling screen (logging out re-routes).
  final container = ProviderScope.containerOf(context, listen: false);
  final signedIn = container.read(sessionProvider).status == AuthStatus.authenticated;
  return showServerAddressDialog(
    context,
    settings: container.read(serverSettingsProvider),
    httpClient: container.read(httpClientProvider),
    signedIn: signedIn,
    beforeChange: () => container.read(sessionProvider.notifier).logout(timeout: const Duration(seconds: 5)),
    afterChange: () async {
      await container.read(publicConfigProvider.notifier).refresh();
    },
  );
}
