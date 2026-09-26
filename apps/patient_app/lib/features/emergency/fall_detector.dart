import 'dart:math' as math;

/// Standard gravity (m/s²). `sensors_plus` accelerometer events include it.
const standardGravity = 9.80665;

/// One accelerometer reading. [x], [y], [z] are in m/s² including gravity.
class AccelSample {
  const AccelSample(this.t, this.x, this.y, this.z);

  /// From g-units along one axis (handy for synthetic test sequences).
  factory AccelSample.g(Duration t, double g) => AccelSample(t, 0, 0, g * standardGravity);

  final Duration t;
  final double x;
  final double y;
  final double z;

  /// Magnitude in g.
  double get g => math.sqrt(x * x + y * y + z * z) / standardGravity;
}

enum _Phase { idle, freeFall, impact, cooldown }

/// On-device fall heuristic from API_CONTRACT §40:
///
/// 1. **Free fall**: magnitude drops below [freeFallG] (0.5 g);
/// 2. **Impact**: magnitude above [impactG] (2.5 g) within [impactWindow]
///    (1 s) of the free fall;
/// 3. **Stillness**: after a short [settle] period for bounces, the
///    magnitude stays within ±[stillnessToleranceG] of 1 g for
///    [stillnessDuration] (~2 s).
///
/// Any movement during the stillness check (a phone dropped on a bed and
/// picked up, the user getting up) cancels the candidate. Walking never
/// reaches free fall. After a detection it stays quiet for [cooldown].
///
/// Pure Dart and clock-free (timestamps come with the samples) so it is
/// unit-testable with synthetic sequences. A supportive signal only, not a
/// medical device.
class FallDetector {
  FallDetector({
    this.freeFallG = 0.5,
    this.impactG = 2.5,
    this.impactWindow = const Duration(seconds: 1),
    this.settle = const Duration(milliseconds: 500),
    this.stillnessDuration = const Duration(seconds: 2),
    this.stillnessToleranceG = 0.3,
    this.maxStillnessWait = const Duration(seconds: 4),
    this.cooldown = const Duration(seconds: 30),
  });

  final double freeFallG;
  final double impactG;
  final Duration impactWindow;
  final Duration settle;
  final Duration stillnessDuration;
  final double stillnessToleranceG;

  /// Give up if stillness has not been reached this long after impact.
  final Duration maxStillnessWait;
  final Duration cooldown;

  _Phase _phase = _Phase.idle;
  Duration _freeFallAt = Duration.zero;
  Duration _impactAt = Duration.zero;
  Duration? _stillSince;
  Duration _cooldownUntil = Duration.zero;

  /// Feeds one sample. Returns true exactly once per detected fall.
  bool add(AccelSample s) {
    final g = s.g;
    switch (_phase) {
      case _Phase.cooldown:
        if (s.t >= _cooldownUntil) _phase = _Phase.idle;
        return false;
      case _Phase.idle:
        if (g < freeFallG) {
          _phase = _Phase.freeFall;
          _freeFallAt = s.t;
        }
        return false;
      case _Phase.freeFall:
        if (g > impactG) {
          _phase = _Phase.impact;
          _impactAt = s.t;
          _stillSince = null;
        } else if (s.t - _freeFallAt > impactWindow) {
          reset();
          // This sample may itself start a new free fall.
          return add(s);
        }
        return false;
      case _Phase.impact:
        final sinceImpact = s.t - _impactAt;
        if (sinceImpact < settle) return false; // bounces
        final still = (g - 1.0).abs() <= stillnessToleranceG;
        if (!still) {
          // Movement after the impact: not a fall (or the person got up).
          reset();
          return false;
        }
        _stillSince ??= s.t;
        if (s.t - _stillSince! >= stillnessDuration) {
          _phase = _Phase.cooldown;
          _cooldownUntil = s.t + cooldown;
          _stillSince = null;
          return true;
        }
        if (sinceImpact > maxStillnessWait + stillnessDuration) reset();
        return false;
    }
  }

  void reset() {
    _phase = _Phase.idle;
    _stillSince = null;
  }
}
