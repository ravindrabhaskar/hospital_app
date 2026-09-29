import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_exception.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/state_views.dart';
import '../../models/care.dart';
import '../../state/core_providers.dart';
import '../doctors/doctor_detail_screen.dart' show DateChipRow;
import 'book_home_visit_screen.dart' show ServiceabilityNote, visitWindows;

/// Address, pincode serviceability and a preferred arrival window: the
/// home-checkup booking fields, reused by lab sample collection (§44).
class AddressSlotController extends ChangeNotifier {
  AddressSlotController() {
    final n = DateTime.now();
    date = DateTime(n.year, n.month, n.day);
    for (final c in [line1, line2, landmark, city, pincode]) {
      c.addListener(notifyListeners);
    }
  }

  final line1 = TextEditingController();
  final line2 = TextEditingController();
  final landmark = TextEditingController();
  final city = TextEditingController(text: 'Hyderabad');
  final pincode = TextEditingController();
  late DateTime date;
  (int, int)? window;
  Serviceability? serviceability;
  String? serviceabilityError;
  bool checking = false;

  bool windowAvailable((int, int) w, {DateTime? now}) =>
      DateTime(date.year, date.month, date.day, w.$1).isAfter((now ?? DateTime.now()).add(const Duration(minutes: 60)));

  bool get ready =>
      line1.text.trim().isNotEmpty &&
      city.text.trim().isNotEmpty &&
      (serviceability?.serviceable ?? false) &&
      window != null &&
      windowAvailable(window!);

  Address get address => Address(
        line1: line1.text.trim(),
        line2: line2.text.trim(),
        landmark: landmark.text.trim(),
        city: city.text.trim(),
        pincode: pincode.text.trim(),
      );

  DateTime get start => DateTime(date.year, date.month, date.day, window!.$1);
  DateTime get end => DateTime(date.year, date.month, date.day, window!.$2);

  void selectDate(DateTime d) {
    date = d;
    window = null;
    notifyListeners();
  }

  void selectWindow((int, int) w) {
    window = w;
    notifyListeners();
  }

  void update(VoidCallback f) {
    f();
    notifyListeners();
  }

  @override
  void dispose() {
    for (final c in [line1, line2, landmark, city, pincode]) {
      c.dispose();
    }
    super.dispose();
  }
}

class AddressSlotSection extends ConsumerStatefulWidget {
  const AddressSlotSection({super.key, required this.controller, required this.addressTitle, required this.timeTitle});
  final AddressSlotController controller;
  final String addressTitle;
  final String timeTitle;

  @override
  ConsumerState<AddressSlotSection> createState() => _AddressSlotSectionState();
}

class _AddressSlotSectionState extends ConsumerState<AddressSlotSection> {
  AddressSlotController get _c => widget.controller;

  @override
  void initState() {
    super.initState();
    _c.addListener(_changed);
  }

  @override
  void dispose() {
    _c.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  List<DateTime> get _days {
    final n = DateTime.now();
    final today = DateTime(n.year, n.month, n.day);
    return List.generate(7, (i) => today.add(Duration(days: i)));
  }

  Future<void> _check() async {
    final l = context.l10n;
    final pin = _c.pincode.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(pin)) {
      _c.update(() => _c.serviceabilityError = l.pincodeInvalid);
      return;
    }
    _c.update(() {
      _c.checking = true;
      _c.serviceabilityError = null;
      _c.serviceability = null;
    });
    try {
      final r = await ref.read(homeVisitRepositoryProvider).serviceability(pin);
      _c.update(() => _c.serviceability = r);
    } on ApiException catch (e) {
      if (!mounted) return;
      _c.update(() => _c.serviceabilityError = e.isNotServiceable ? l.notServiceable : errorMessage(context, e));
    } finally {
      _c.update(() => _c.checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final svc = _c.serviceability;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(title: widget.addressTitle),
        TextField(controller: _c.line1, decoration: InputDecoration(labelText: l.addressLine1)),
        const SizedBox(height: 12),
        TextField(controller: _c.line2, decoration: InputDecoration(labelText: l.addressLine2)),
        const SizedBox(height: 12),
        TextField(controller: _c.landmark, decoration: InputDecoration(labelText: l.landmark)),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: TextField(controller: _c.city, decoration: InputDecoration(labelText: l.city))),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                key: const Key('slot-pincode'),
                controller: _c.pincode,
                keyboardType: TextInputType.number,
                maxLength: 6,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (v) {
                  _c.update(() => _c.serviceability = null);
                  if (v.length == 6) _check();
                },
                decoration: InputDecoration(labelText: l.pincode, counterText: ''),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_c.checking)
          const LinearProgressIndicator()
        else if (_c.serviceabilityError != null)
          ServiceabilityNote(ok: false, text: _c.serviceabilityError!)
        else if (svc != null)
          ServiceabilityNote(
            ok: svc.serviceable,
            text: svc.message.isNotEmpty ? svc.message : (svc.serviceable ? l.serviceable(svc.zoneName ?? '') : l.notServiceable),
          ),
        SectionHeader(title: widget.timeTitle),
        DateChipRow(days: _days, selected: _c.date, onSelect: _c.selectDate),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final w in visitWindows)
              ChoiceChip(
                label: Text(
                    '${fmtTime(context, DateTime(2000, 1, 1, w.$1))} – ${fmtTime(context, DateTime(2000, 1, 1, w.$2))}'),
                selected: _c.window == w,
                onSelected: _c.windowAvailable(w) ? (_) => _c.selectWindow(w) : null,
              ),
          ],
        ),
      ],
    );
  }
}
