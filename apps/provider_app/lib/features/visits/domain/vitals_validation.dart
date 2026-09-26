/// Structured vitals capture. Validation only checks that a value is a number
/// in a physically plausible range (to catch typos). It deliberately performs
/// **no clinical interpretation** (no "high"/"low"/"normal" labels).
class VitalSpec {
  const VitalSpec({
    required this.type,
    required this.unit,
    required this.min,
    required this.max,
    this.decimals = 0,
  });

  /// API `VitalType`.
  final String type;
  final String unit;
  final double min;
  final double max;

  /// Allowed decimal places (0 for integers).
  final int decimals;
}

class VitalSpecs {
  VitalSpecs._();

  static const bpSystolic = VitalSpec(type: 'bp_systolic', unit: 'mmHg', min: 50, max: 260);
  static const bpDiastolic = VitalSpec(type: 'bp_diastolic', unit: 'mmHg', min: 30, max: 160);
  static const pulse = VitalSpec(type: 'pulse', unit: 'bpm', min: 25, max: 250);
  static const spo2 = VitalSpec(type: 'spo2', unit: '%', min: 50, max: 100);
  static const temperature = VitalSpec(type: 'temperature', unit: '°C', min: 30, max: 44, decimals: 1);
  static const bloodGlucose = VitalSpec(type: 'blood_glucose', unit: 'mg/dL', min: 20, max: 800);
  static const weight = VitalSpec(type: 'weight', unit: 'kg', min: 0.5, max: 350, decimals: 1);
  static const respiratoryRate = VitalSpec(type: 'respiratory_rate', unit: 'breaths/min', min: 4, max: 70);

  static const all = [
    bpSystolic,
    bpDiastolic,
    pulse,
    spo2,
    temperature,
    bloodGlucose,
    weight,
    respiratoryRate,
  ];

  static VitalSpec? byType(String type) {
    for (final s in all) {
      if (s.type == type) return s;
    }
    return null;
  }
}

enum VitalErrorKind { notANumber, outOfRange, bpPairRequired, bpOrder, empty }

class VitalError {
  const VitalError(this.kind, [this.spec]);
  final VitalErrorKind kind;
  final VitalSpec? spec;

  @override
  bool operator ==(Object other) => other is VitalError && other.kind == kind && other.spec == spec;

  @override
  int get hashCode => Object.hash(kind, spec);

  @override
  String toString() => 'VitalError($kind, ${spec?.type})';
}

class VitalsValidationResult {
  const VitalsValidationResult({required this.fieldErrors, this.formError, required this.values});

  /// Per vital type.
  final Map<String, VitalError> fieldErrors;

  /// Error not tied to a single field (e.g. nothing entered).
  final VitalError? formError;

  /// Parsed values of valid, non-empty fields keyed by vital type.
  final Map<String, double> values;

  bool get isValid => fieldErrors.isEmpty && formError == null;
}

class VitalsValidator {
  VitalsValidator._();

  static String _normalise(String raw) => raw.trim().replaceAll(',', '.');

  /// Validates a single raw input. Empty input is valid (vitals are optional).
  static VitalError? validateField(VitalSpec spec, String raw) {
    final text = _normalise(raw);
    if (text.isEmpty) return null;
    final pattern = spec.decimals == 0 ? RegExp(r'^\d+$') : RegExp('^\\d+(\\.\\d{1,${spec.decimals}})?\$');
    if (!pattern.hasMatch(text)) return VitalError(VitalErrorKind.notANumber, spec);
    final value = double.parse(text);
    if (value < spec.min || value > spec.max) return VitalError(VitalErrorKind.outOfRange, spec);
    return null;
  }

  /// Validates the whole form (raw text keyed by vital type).
  static VitalsValidationResult validate(Map<String, String> raw) {
    final errors = <String, VitalError>{};
    final values = <String, double>{};

    for (final spec in VitalSpecs.all) {
      final input = raw[spec.type] ?? '';
      final error = validateField(spec, input);
      if (error != null) {
        errors[spec.type] = error;
      } else if (_normalise(input).isNotEmpty) {
        values[spec.type] = double.parse(_normalise(input));
      }
    }

    // Blood pressure is captured as a pair.
    final sysText = _normalise(raw[VitalSpecs.bpSystolic.type] ?? '');
    final diaText = _normalise(raw[VitalSpecs.bpDiastolic.type] ?? '');
    if (sysText.isEmpty != diaText.isEmpty) {
      final missing = sysText.isEmpty ? VitalSpecs.bpSystolic : VitalSpecs.bpDiastolic;
      errors.putIfAbsent(missing.type, () => VitalError(VitalErrorKind.bpPairRequired, missing));
    }
    final sys = values[VitalSpecs.bpSystolic.type];
    final dia = values[VitalSpecs.bpDiastolic.type];
    if (sys != null && dia != null && dia >= sys) {
      errors[VitalSpecs.bpDiastolic.type] = const VitalError(VitalErrorKind.bpOrder, VitalSpecs.bpDiastolic);
    }

    final formError = errors.isEmpty && values.isEmpty ? const VitalError(VitalErrorKind.empty) : null;
    return VitalsValidationResult(fieldErrors: errors, formError: formError, values: values);
  }

  /// Builds the `POST /home-visits/:id/vitals` body.
  static Map<String, dynamic> toRequestBody(Map<String, double> values, DateTime measuredAt) {
    final at = measuredAt.toUtc().toIso8601String();
    return {
      'measurements': [
        for (final spec in VitalSpecs.all)
          if (values.containsKey(spec.type))
            {
              'type': spec.type,
              'value': spec.decimals == 0 ? values[spec.type]!.round() : values[spec.type],
              'unit': spec.unit,
              'measuredAt': at,
            },
      ],
    };
  }
}
