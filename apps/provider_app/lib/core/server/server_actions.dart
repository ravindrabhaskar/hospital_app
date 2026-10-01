import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import 'server_address_dialog.dart';

/// Opens the "Server address" dialog wired to this app: a signed-in user is
/// logged out before the server changes (tokens belong to a server), then the
/// public config is reloaded from the new server.
Future<bool> openServerAddressDialog(BuildContext context) {
  // The container outlives the calling screen (logging out re-routes).
  final container = ProviderScope.containerOf(context, listen: false);
  return showServerAddressDialog(
    context,
    settings: container.read(serverSettingsProvider),
    httpClient: container.read(httpClientProvider),
    signedIn: container.read(tokenStoreProvider).hasSession,
    beforeChange: () => container.read(authControllerProvider).logout(timeout: const Duration(seconds: 5)),
    afterChange: () => container.read(publicConfigProvider).load(),
  );
}
