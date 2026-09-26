import 'package:care_companion_patient/features/profile/abha_section.dart';
import 'package:care_companion_patient/features/profile/appearance_screen.dart';
import 'package:care_companion_patient/features/subscriptions/family_plan_screen.dart';
import 'package:care_companion_patient/models/billing.dart';
import 'package:care_companion_patient/state/core_providers.dart';
import 'package:care_companion_patient/state/data_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

final basic = Plan.fromJson({
  'code': 'family_basic',
  'name': 'Family Basic',
  'description': 'Everyday care for the family',
  'priceMonthly': 299,
  'priceYearly': 2999,
  'benefits': ['Priority booking'],
  'maxMembers': 4,
  'coordinatorIncluded': false,
  'homeVisitDiscountPct': 10,
  'active': true,
});

final plus = Plan.fromJson({
  'code': 'family_plus',
  'name': 'Family Plus',
  'description': 'With a dedicated coordinator',
  'priceMonthly': 699,
  'priceYearly': 6999,
  'benefits': <String>[],
  'maxMembers': 6,
  'coordinatorIncluded': true,
  'homeVisitDiscountPct': 15,
  'active': true,
});

void main() {
  group('Family Care Plan pricing', () {
    test('monthly and yearly prices with savings', () {
      final m = PlanPricing.of(basic, Billing.monthly);
      expect(m.price, 299);
      expect(m.savings, 0);
      final y = PlanPricing.of(basic, Billing.yearly);
      expect(y.price, 2999);
      expect(y.savings, 299 * 12 - 2999); // 589
      expect(y.savingsPct, 16);
      expect(PlanPricing.of(plus, Billing.yearly).savingsPct, 17); // 1389 / 8388
    });

    testWidgets('the monthly/yearly toggle switches the prices and shows savings', (tester) async {
      useTallPhone(tester);
      final overrides = await baseOverrides();
      await tester.pumpWidget(testApp(const FamilyPlanScreen(), overrides: [
        ...overrides,
        mySubscriptionProvider.overrideWith((ref) async => null),
        subscriptionPlansProvider.overrideWith((ref) async => [basic, plus]),
      ]));
      await tester.pumpAndSettle();

      String price(String code) => tester
          .widget<Text>(find.byKey(Key('plan-price-$code')))
          .textSpan!
          .toPlainText();
      expect(price('family_basic'), '₹299 / month');
      expect(price('family_plus'), '₹699 / month');
      expect(find.byKey(const Key('plan-savings-family_basic')), findsNothing);
      expect(find.text('10% off home visits'), findsOneWidget);
      expect(find.text('A dedicated care coordinator'), findsOneWidget);

      await tester.tap(find.text('Yearly · save 17%'));
      await tester.pumpAndSettle();
      expect(price('family_basic'), '₹2,999 / year');
      expect(price('family_plus'), '₹6,999 / year');
      expect(find.text('You save ₹589 (16%) a year'), findsOneWidget);
      expect(find.text('Subscribe · ₹2,999'), findsOneWidget);
    });

    testWidgets('an active plan shows the period end, benefits and cancel at period end', (tester) async {
      useTallPhone(tester);
      final overrides = await baseOverrides();
      await tester.pumpWidget(testApp(const FamilyPlanScreen(), overrides: [
        ...overrides,
        mySubscriptionProvider.overrideWith((ref) async => Subscription.fromJson({
              'id': 's1',
              'planCode': 'family_plus',
              'planName': 'Family Plus',
              'status': 'active',
              'billing': 'yearly',
              'currentPeriodStart': '2026-09-01T00:00:00.000Z',
              'currentPeriodEnd': '2027-09-01T00:00:00.000Z',
              'cancelAtPeriodEnd': false,
              'benefits': ['15% off home visits', 'Dedicated coordinator'],
              'createdAt': '2026-09-01T00:00:00.000Z',
            })),
      ]));
      await tester.pumpAndSettle();
      expect(find.text('Family Plus'), findsOneWidget);
      expect(find.textContaining('Current period ends on'), findsOneWidget);
      expect(find.text('Dedicated coordinator'), findsOneWidget);
      expect(find.text('Cancel at period end'), findsOneWidget);
    });
  });

  group('ABHA', () {
    test('formats 14 digits as XX-XXXX-XXXX-XXXX (also while typing)', () {
      expect(formatAbhaNumber('12345678901234'), '12-3456-7890-1234');
      expect(formatAbhaNumber('12-3456-7890-1234'), '12-3456-7890-1234');
      expect(formatAbhaNumber('123'), '12-3');
      expect(formatAbhaNumber('1234567'), '12-3456-7');
      expect(formatAbhaNumber('12 3456 7890 1234 99'), '12-3456-7890-1234'); // capped at 14
      expect(abhaDigits('12-3456-7890-1234'), '12345678901234');
    });

    test('validates the number and the address', () {
      expect(isValidAbhaNumber('12-3456-7890-1234'), isTrue);
      expect(isValidAbhaNumber('12345678901234'), isTrue);
      expect(isValidAbhaNumber('12-3456-7890-123'), isFalse);
      expect(isValidAbhaNumber('12-3456-7890-12a4'), isFalse);
      expect(isValidAbhaAddress('vaibhav@abdm'), isTrue);
      expect(isValidAbhaAddress('vaibhav.k_1@sbx'), isTrue);
      expect(isValidAbhaAddress('vaibhav@gmail.com'), isFalse);
      expect(isValidAbhaAddress('@abdm'), isFalse);
    });

    test('input formatter inserts the dashes', () {
      final f = AbhaNumberFormatter();
      final out = f.formatEditUpdate(TextEditingValue.empty, const TextEditingValue(text: '123456'));
      expect(out.text, '12-3456');
      expect(out.selection.baseOffset, out.text.length);
    });
  });

  group('Appearance', () {
    testWidgets('the theme mode is persisted and restored', (tester) async {
      final overrides = await baseOverrides();
      late ProviderContainer container;
      await tester.pumpWidget(testApp(
        Consumer(builder: (context, ref, _) {
          container = ProviderScope.containerOf(context);
          return const AppearanceScreen();
        }),
        overrides: overrides,
      ));
      await tester.pumpAndSettle();
      expect(container.read(themeModeProvider), ThemeMode.system);

      await tester.tap(find.byKey(const Key('theme-dark')));
      await tester.pumpAndSettle();
      expect(container.read(themeModeProvider), ThemeMode.dark);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(ThemeModeNotifier.key), 'dark');

      // A fresh app start reads the saved choice.
      final fresh = ProviderContainer(overrides: [sharedPrefsProvider.overrideWithValue(prefs)]);
      addTearDown(fresh.dispose);
      expect(fresh.read(themeModeProvider), ThemeMode.dark);

      await tester.tap(find.byKey(const Key('theme-light')));
      await tester.pumpAndSettle();
      expect(prefs.getString(ThemeModeNotifier.key), 'light');
    });
  });
}
