import 'package:care_companion_patient/features/pharmacy/cart.dart';
import 'package:care_companion_patient/features/prescriptions/pharmacy_match_screen.dart';
import 'package:care_companion_patient/features/prescriptions/prescription_detail_screen.dart';
import 'package:care_companion_patient/models/misc.dart';
import 'package:care_companion_patient/models/prescription.dart';
import 'package:care_companion_patient/state/data_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers.dart';

Prescription samplePrescription() => Prescription.fromJson({
      'id': 'rx1',
      'patientId': 'p-self',
      'patientName': 'Vaibhav',
      'patientAge': 24,
      'patientGender': 'male',
      'doctorId': 'd1',
      'doctorName': 'Dr. Ananya Rao',
      'doctorQualifications': 'MBBS, MD',
      'doctorRegistration': 'TSMC/12345',
      'appointmentId': 'a1',
      'careEpisodeId': 'e1',
      'clinicalNote': null,
      'items': [
        {
          'drugName': 'Paracetamol',
          'strength': '500 mg',
          'form': 'tablet',
          'dose': '1 tablet',
          'frequency': 'Twice a day',
          'timing': 'After food',
          'durationDays': 5,
          'times': ['08:00', '20:00'],
          'instructions': 'Take with water',
        },
        {
          'drugName': 'Cetirizine',
          'form': 'syrup',
          'dose': '5 ml',
          'frequency': 'At night',
          'durationDays': 3,
          'times': ['21:00'],
        },
      ],
      'advice': 'Drink plenty of fluids and rest.',
      'followUpInDays': 7,
      'recordId': 'r1',
      'createdAt': '2026-09-20T09:30:00.000Z',
    });

Product product(String id, String name, {int price = 30, bool inStock = true, bool rx = false}) => Product(
      id: id,
      name: name,
      packSize: 'Strip of 10',
      mrp: price + 5,
      price: price,
      category: 'general',
      requiresPrescription: rx,
      imageUrl: null,
      inStock: inStock,
    );

final matches = [
  RxMatch(itemIndex: 0, drugName: 'Paracetamol 500 mg', product: product('pr1', 'Paracetamol 500mg', price: 30)),
  RxMatch(itemIndex: 1, drugName: 'Cetirizine syrup', product: product('pr2', 'Cetirizine 60ml', price: 85, rx: true)),
  RxMatch(itemIndex: 2, drugName: 'Rare drug', product: null),
  RxMatch(itemIndex: 3, drugName: 'Out of stock', product: product('pr3', 'Vitamin D3', inStock: false)),
];

void main() {
  testWidgets('Rx detail renders the doctor, registration, items, advice and actions', (tester) async {
    useTallPhone(tester);
    final overrides = await baseOverrides();
    await tester.pumpWidget(testApp(const PrescriptionDetailScreen(id: 'rx1'), overrides: [
      ...overrides,
      prescriptionProvider('rx1').overrideWith((ref) async => samplePrescription()),
    ]));
    await tester.pumpAndSettle();

    expect(find.text('Dr. Ananya Rao'), findsOneWidget);
    expect(find.text('MBBS, MD'), findsOneWidget);
    expect(find.text('Reg. No. TSMC/12345'), findsOneWidget);
    expect(find.text('Vaibhav • 24 years • Male'), findsOneWidget);
    expect(find.text('Paracetamol 500 mg'), findsOneWidget);
    expect(find.text('Twice a day'), findsOneWidget);
    expect(find.text('After food'), findsOneWidget);
    expect(find.text('5 days'), findsOneWidget);
    expect(find.text('Take with water'), findsOneWidget);
    expect(find.text('Cetirizine'), findsOneWidget);
    expect(find.text('Syrup'), findsOneWidget);
    expect(find.text('Drink plenty of fluids and rest.'), findsOneWidget);
    expect(find.text('Review after 7 days'), findsOneWidget);
    expect(find.byKey(const Key('rx-pdf')), findsOneWidget);
    expect(find.byKey(const Key('rx-order')), findsOneWidget);
    // Each item is announced as one semantic node.
    expect(find.bySemanticsLabel(RegExp(r'^1\. Paracetamol 500 mg\. Tablet\. Dose: 1 tablet')), findsOneWidget);
  });

  test('cart prefill keeps only matched, in-stock, selected lines', () {
    final all = cartFromRxMatch(matches);
    expect(all.keys, ['pr1', 'pr2']);
    expect(all.itemCount, 2);
    expect(all.total, 115);
    expect(all.needsPrescription, isTrue);

    final onlyFirst = cartFromRxMatch(matches, selected: {0});
    expect(onlyFirst.keys, ['pr1']);

    // Two Rx lines matching the same product merge into one line, qty 2.
    final dup = cartFromRxMatch([matches[0], RxMatch(itemIndex: 5, drugName: 'Para', product: matches[0].product)]);
    expect(dup['pr1']!.qty, 2);
  });

  testWidgets('pharmacy match prefills the cart and carries the prescriptionId to checkout', (tester) async {
    useTallPhone(tester);
    final overrides = await baseOverrides();
    late WidgetRef capturedRef;
    final router = GoRouter(initialLocation: '/m', routes: [
      GoRoute(
          path: '/m',
          builder: (_, _) => Consumer(builder: (context, ref, _) {
                capturedRef = ref;
                return const PharmacyMatchScreen(prescriptionId: 'rx1');
              })),
      GoRoute(path: '/pharmacy/cart', builder: (_, _) => const Scaffold(body: Text('CART'))),
    ]);
    await tester.pumpWidget(testAppRouter(router, overrides: [
      ...overrides,
      pharmacyMatchProvider('rx1').overrideWith((ref) async => matches),
      prescriptionProvider('rx1').overrideWith((ref) async => samplePrescription()),
    ]));
    await tester.pumpAndSettle();

    expect(find.text('Rare drug'), findsOneWidget);
    expect(find.text('Not available from our pharmacy partner'), findsOneWidget);
    expect(find.textContaining('Add 2 to cart'), findsOneWidget);

    // Untick Cetirizine: one item left.
    await tester.tap(find.text('Cetirizine syrup'));
    await tester.pump();
    expect(find.textContaining('Add 1 to cart'), findsOneWidget);

    await tester.tap(find.byKey(const Key('rx-add-to-cart')));
    await tester.pumpAndSettle();
    expect(find.text('CART'), findsOneWidget);
    final cart = capturedRef.read(cartProvider);
    expect(cart.keys, ['pr1']);
    expect(capturedRef.read(cartRxProvider)?.prescriptionId, 'rx1');
    expect(capturedRef.read(cartRxProvider)?.doctorName, 'Dr. Ananya Rao');
  });
}
