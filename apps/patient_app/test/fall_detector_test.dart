import 'package:care_companion_patient/features/emergency/fall_detector.dart';
import 'package:flutter_test/flutter_test.dart';

/// Builds a 50 Hz synthetic accelerometer trace from (duration, g) segments.
List<AccelSample> trace(List<(Duration, double Function(int i))> segments) {
  const dt = Duration(milliseconds: 20);
  final out = <AccelSample>[];
  var t = Duration.zero;
  for (final (len, g) in segments) {
    final n = len.inMilliseconds ~/ dt.inMilliseconds;
    for (var i = 0; i < n; i++) {
      out.add(AccelSample.g(t, g(i)));
      t += dt;
    }
  }
  return out;
}

double Function(int) constant(double g) => (_) => g;

int detections(FallDetector d, List<AccelSample> samples) => samples.where(d.add).length;

void main() {
  const ms = Duration(milliseconds: 1);

  test('a true fall (free fall → impact → lying still) is detected once', () {
    final samples = trace([
      (ms * 1000, constant(1.0)), // standing
      (ms * 300, constant(0.2)), // free fall
      (ms * 100, constant(3.4)), // impact
      (ms * 400, (i) => i.isEven ? 1.8 : 0.6), // bounce/settle
      (ms * 3000, (i) => 1.0 + (i % 3 - 1) * 0.05), // still on the floor
    ]);
    final d = FallDetector();
    expect(detections(d, samples), 1);
  });

  test('a phone dropped onto a bed and picked up (no stillness) is not a fall', () {
    final samples = trace([
      (ms * 500, constant(1.0)),
      (ms * 250, constant(0.1)), // dropped
      (ms * 60, constant(2.8)), // hits the mattress
      (ms * 300, (i) => i.isEven ? 1.4 : 0.8), // bounces
      // Picked straight back up and carried: keeps moving.
      (ms * 3000, (i) => 1.0 + 0.6 * ((i % 10) < 5 ? 1 : -1)),
    ]);
    expect(detections(FallDetector(), samples), 0);
  });

  test('walking never looks like a fall', () {
    // Gait: ~2 steps/s oscillating between 0.7 g and 1.6 g, for a minute.
    final samples = trace([
      (const Duration(seconds: 60), (i) => (i % 25) < 12 ? 0.7 + (i % 12) * 0.075 : 1.6 - (i % 13) * 0.07),
    ]);
    expect(detections(FallDetector(), samples), 0);
  });

  test('free fall without an impact within 1 s is ignored', () {
    final samples = trace([
      (ms * 200, constant(1.0)),
      (ms * 300, constant(0.3)),
      (ms * 1500, constant(1.0)), // no impact
      (ms * 3000, constant(1.0)),
    ]);
    expect(detections(FallDetector(), samples), 0);
  });

  test('stays quiet during the cool-down after a detection', () {
    List<(Duration, double Function(int))> fall() => [
          (ms * 300, constant(0.2)),
          (ms * 100, constant(3.0)),
          (ms * 400, constant(1.0)),
          (ms * 2500, constant(1.0)),
        ];
    final samples = trace([(ms * 500, constant(1.0)), ...fall(), (ms * 1000, constant(1.0)), ...fall()]);
    expect(detections(FallDetector(), samples), 1);
  });

  test('magnitude is computed from all three axes in g', () {
    const s = AccelSample(Duration.zero, 0, standardGravity * 0.6, standardGravity * 0.8);
    expect(s.g, closeTo(1.0, 1e-9));
  });
}
