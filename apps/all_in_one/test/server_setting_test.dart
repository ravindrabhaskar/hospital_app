// The runtime "Server address" is ONE setting for the whole all-in-one build:
// it lives under a global, unprefixed shared-preferences key, so whichever
// role changes it, the other two roles use the same server.
import 'package:care_companion_all_in_one/roles.dart';
import 'package:care_companion_doctor/core/providers.dart' as doc;
import 'package:care_companion_doctor/core/server/server_settings.dart' as doc_srv;
import 'package:care_companion_patient/core/server/server_settings.dart' as pat_srv;
import 'package:care_companion_patient/core/storage/namespaced_prefs.dart';
import 'package:care_companion_provider/core/providers.dart' as pro;
import 'package:care_companion_provider/core/server/server_settings.dart' as pro_srv;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _default = 'http://10.0.2.2:4000/api/v1';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('the three apps use the same global key', () {
    expect(pat_srv.ServerSettings.prefsKey, 'server.baseUrl.override');
    expect(pro_srv.ServerSettings.prefsKey, pat_srv.ServerSettings.prefsKey);
    expect(doc_srv.ServerSettings.prefsKey, pat_srv.ServerSettings.prefsKey);
  });

  test('set in one role, used by every role (never namespaced)', () async {
    final raw = await SharedPreferences.getInstance();

    // The patient role changes the server.
    final patient = await pat_srv.ServerSettings.load(defaultUrl: _default, overrideAllowed: true, prefs: raw);
    await patient.setOverride('10.10.17.134');
    const url = 'http://10.10.17.134:4000/api/v1';

    expect(raw.getString('server.baseUrl.override'), url);
    expect(raw.getKeys().where((k) => k.contains('server.baseUrl')), {'server.baseUrl.override'},
        reason: 'no role-prefixed copy');
    expect(NamespacedSharedPreferences(raw, DemoRole.patient.storagePrefix).getString('server.baseUrl.override'),
        isNull);

    // Provider and doctor (as their bootstraps load it) pick up the same server.
    final provider = await pro_srv.ServerSettings.load(defaultUrl: _default, overrideAllowed: true);
    final doctor = await doc_srv.ServerSettings.load(defaultUrl: _default, overrideAllowed: true);
    expect(provider.effectiveUrl, url);
    expect(doctor.effectiveUrl, url);

    final pc = ProviderContainer(overrides: [
      pro.storagePrefixProvider.overrideWithValue(DemoRole.provider.storagePrefix),
      pro.serverSettingsProvider.overrideWithValue(provider),
    ]);
    final dc = ProviderContainer(overrides: [
      doc.storagePrefixProvider.overrideWithValue(DemoRole.doctor.storagePrefix),
      doc.serverSettingsProvider.overrideWithValue(doctor),
    ]);
    addTearDown(pc.dispose);
    addTearDown(dc.dispose);
    expect(pc.read(pro.apiClientProvider).baseUrl, url);
    expect(dc.read(doc.apiClientProvider).baseUrl, url);

    // Reset from the doctor role → everyone is back on the compiled URL.
    await doctor.reset();
    final providerAgain = await pro_srv.ServerSettings.load(defaultUrl: _default, overrideAllowed: true);
    expect(providerAgain.effectiveUrl, _default);
  });
}
