// Proves the storage namespaces keep the three bundled apps apart: the same
// logical keys written by different apps under different prefixes never
// collide, and each app's providers really apply the prefix it is given.
import 'package:care_companion_all_in_one/roles.dart';
import 'package:care_companion_doctor/core/providers.dart' as doc;
import 'package:care_companion_doctor/core/storage/key_value_store.dart' as doc_kv;
import 'package:care_companion_patient/core/api/token_store.dart' as pat_tokens;
import 'package:care_companion_patient/core/storage/namespaced_prefs.dart';
import 'package:care_companion_patient/state/core_providers.dart' as pat;
import 'package:care_companion_provider/core/providers.dart' as pro;
import 'package:care_companion_provider/core/storage/key_value_store.dart' as pro_kv;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
  });

  group('prefix primitives', () {
    test('two namespaced SharedPreferences views never see each other\'s keys', () async {
      final raw = await SharedPreferences.getInstance();
      final a = NamespacedSharedPreferences(raw, 'patient.');
      final b = NamespacedSharedPreferences(raw, 'provider.');

      await a.setString('app.locale', 'hi');
      await b.setString('app.locale', 'te');
      await raw.setString('app.locale', 'en'); // a standalone (unprefixed) value

      expect(a.getString('app.locale'), 'hi');
      expect(b.getString('app.locale'), 'te');
      expect(raw.getString('app.locale'), 'en');
      expect(a.getKeys(), {'app.locale'});

      await a.clear(); // only the patient namespace
      expect(a.getString('app.locale'), isNull);
      expect(b.getString('app.locale'), 'te');
      expect(raw.getString('app.locale'), 'en');
      expect(namespacedPrefs(raw, ''), same(raw), reason: 'standalone builds use the prefs unchanged');
    });

    test('provider and doctor use the same logical keys but different secure-storage entries', () async {
      final provider = pro_kv.PrefixedKeyValueStore(pro_kv.SecureKeyValueStore(), 'provider.');
      final doctor = doc_kv.PrefixedKeyValueStore(doc_kv.SecureKeyValueStore(), 'doctor.');

      await provider.write(pro_kv.StoreKeys.accessToken, 'provider-token');
      await doctor.write(doc_kv.StoreKeys.accessToken, 'doctor-token');
      expect(pro_kv.StoreKeys.accessToken, doc_kv.StoreKeys.accessToken, reason: 'the collision being prevented');

      expect(await provider.read(pro_kv.StoreKeys.accessToken), 'provider-token');
      expect(await doctor.read(doc_kv.StoreKeys.accessToken), 'doctor-token');

      await doctor.delete(doc_kv.StoreKeys.accessToken); // doctor logout
      expect(await provider.read(pro_kv.StoreKeys.accessToken), 'provider-token');

      final all = await const FlutterSecureStorage().readAll();
      expect(all.keys, contains('provider.auth.accessToken'));
      expect(all.keys, isNot(contains('auth.accessToken')));
    });
  });

  group('each app applies the prefix the all-in-one build passes', () {
    test('all three apps signed in at once keep separate tokens and preferences', () async {
      final raw = await SharedPreferences.getInstance();

      final patient = ProviderContainer(
        overrides: [
          pat.storagePrefixProvider.overrideWithValue(DemoRole.patient.storagePrefix),
          pat.sharedPrefsProvider.overrideWithValue(namespacedPrefs(raw, DemoRole.patient.storagePrefix)),
        ],
      );
      final provider = ProviderContainer(
        overrides: [pro.storagePrefixProvider.overrideWithValue(DemoRole.provider.storagePrefix)],
      );
      final doctor = ProviderContainer(
        overrides: [doc.storagePrefixProvider.overrideWithValue(DemoRole.doctor.storagePrefix)],
      );
      addTearDown(patient.dispose);
      addTearDown(provider.dispose);
      addTearDown(doctor.dispose);

      await patient
          .read(pat.tokenStoreProvider)
          .write(const pat_tokens.StoredTokens(accessToken: 'pa', refreshToken: 'pr'));
      await provider.read(pro.tokenStoreProvider).save('va', 'vr');
      await doctor.read(doc.tokenStoreProvider).save('da', 'dr');

      await patient.read(pat.localeProvider.notifier).set('hi');
      await provider.read(pro.localeControllerProvider).setLocale('te');
      await doctor.read(doc.localeControllerProvider).setLocale('en');

      final secure = await const FlutterSecureStorage().readAll();
      expect(secure, {
        'patient.cc_access_token': 'pa',
        'patient.cc_refresh_token': 'pr',
        'provider.auth.accessToken': 'va',
        'provider.auth.refreshToken': 'vr',
        'doctor.auth.accessToken': 'da',
        'doctor.auth.refreshToken': 'dr',
      });
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('patient.cc_locale'), 'hi');
      expect(prefs.getString('provider.app.locale'), 'te');
      expect(prefs.getString('doctor.app.locale'), 'en');
      expect(
        prefs.getKeys().where((k) => !k.contains('.') || k.startsWith('app.') || k.startsWith('cc_')),
        isEmpty,
        reason: 'nothing is written to the standalone (unprefixed) keys',
      );

      // Fresh instances (an app re-opened after "Switch app") read their own session back.
      final provider2 = ProviderContainer(
        overrides: [pro.storagePrefixProvider.overrideWithValue(DemoRole.provider.storagePrefix)],
      );
      addTearDown(provider2.dispose);
      final tokens = provider2.read(pro.tokenStoreProvider);
      await tokens.load();
      expect(tokens.accessToken, 'va');

      // Logging out of the doctor app leaves the other two signed in.
      await doctor.read(doc.keyValueStoreProvider).delete(doc_kv.StoreKeys.accessToken);
      expect(await provider.read(pro.keyValueStoreProvider).read(pro_kv.StoreKeys.accessToken), 'va');
      expect((await patient.read(pat.tokenStoreProvider).read())?.accessToken, 'pa');
    });

    test('the default (standalone) prefix keeps the original keys', () async {
      final provider = ProviderContainer();
      final patient = ProviderContainer(
        overrides: [pat.sharedPrefsProvider.overrideWithValue(await SharedPreferences.getInstance())],
      );
      addTearDown(provider.dispose);
      addTearDown(patient.dispose);

      expect(provider.read(pro.keyValueStoreProvider), isA<pro_kv.SecureKeyValueStore>());
      await provider.read(pro.tokenStoreProvider).save('a', 'r');
      await patient
          .read(pat.tokenStoreProvider)
          .write(const pat_tokens.StoredTokens(accessToken: 'pa', refreshToken: 'pr'));
      final secure = await const FlutterSecureStorage().readAll();
      expect(secure.keys, containsAll(['auth.accessToken', 'cc_access_token']));
    });
  });

  test('the switch-app callback is null unless the all-in-one build provides one', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    expect(c.read(pro.switchAppProvider), isNull);
    expect(c.read(doc.switchAppProvider), isNull);
    expect(c.read(pat.switchAppProvider), isNull);
    void cb() {}
    final w = ProviderContainer(overrides: [pro.switchAppProvider.overrideWithValue(cb)]);
    addTearDown(w.dispose);
    expect(w.read(pro.switchAppProvider), same(cb));
  });
}
