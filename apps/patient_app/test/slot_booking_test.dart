import 'package:care_companion_patient/data/repositories.dart';
import 'package:care_companion_patient/features/doctors/doctor_detail_screen.dart';
import 'package:care_companion_patient/models/doctor.dart';
import 'package:care_companion_patient/state/core_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

final doctor = Doctor(
  id: 'd1',
  name: 'Dr. Ananya Rao',
  specialty: 'general_physician',
  specialtyName: 'General Physician',
  qualifications: 'MBBS, MD',
  experienceYears: 8,
  rating: 4.8,
  ratingCount: 320,
  languages: const ['English', 'Telugu'],
  fees: DoctorFees(video: 499, audio: 499, chat: 399, inClinic: 0),
  photoUrl: null,
  verified: true,
  nextAvailableAt: null,
  availableNow: true,
  facility: null,
  rankingFactors: const [],
);

class FakeDoctorRepository extends DoctorRepository {
  FakeDoctorRepository() : super(deadApiClient());
  @override
  Future<List<Slot>> slots(String doctorId, DateTime date) async {
    final base = DateTime.now().add(const Duration(hours: 2));
    return [
      Slot(id: 's-booked', startAt: base, endAt: base.add(const Duration(minutes: 30)), status: 'booked'),
      Slot(
          id: 's-free',
          startAt: base.add(const Duration(minutes: 30)),
          endAt: base.add(const Duration(minutes: 60)),
          status: 'available'),
    ];
  }
}

FilledButton confirmButton(WidgetTester tester) => tester.widget<FilledButton>(
      find.descendant(of: find.byKey(const Key('confirm-appointment')), matching: find.byType(FilledButton)),
    );

void main() {
  testWidgets('confirm button is disabled until an available slot is selected', (tester) async {
    useTallPhone(tester, height: 1400);
    final overrides = await baseOverrides();
    await tester.pumpWidget(testApp(
      Scaffold(body: SlotBookingPanel(doctor: doctor)),
      overrides: [...overrides, doctorRepositoryProvider.overrideWithValue(FakeDoctorRepository())],
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(SlotPill), findsNWidgets(2));
    expect(find.text('Select a time slot'), findsOneWidget);
    expect(confirmButton(tester).onPressed, isNull);

    // A booked slot cannot be selected.
    await tester.tap(find.byType(SlotPill).first);
    await tester.pump();
    expect(confirmButton(tester).onPressed, isNull);

    // Selecting the available slot enables booking and shows the fee.
    await tester.tap(find.byType(SlotPill).last);
    await tester.pump();
    expect(confirmButton(tester).onPressed, isNotNull);
    expect(find.textContaining('Confirm Appointment'), findsOneWidget);
    expect(find.textContaining('499'), findsWidgets);

    // Changing the date clears the selection again.
    await tester.tap(find.byType(InkWell).at(1));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(confirmButton(tester).onPressed, isNull);
  });
}
