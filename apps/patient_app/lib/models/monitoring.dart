import 'json.dart';

// Models for API_CONTRACT v1.3 monitoring features: daily check-in (§41),
// care programs (§42), preventive care (§52), exercise plans (§53) and diet
// plans (§54).

// ---------------------------------------------------------------- §41 Daily check-in

class CheckinSettings {
  const CheckinSettings({
    required this.patientId,
    required this.enabled,
    required this.windowStart,
    required this.windowEnd,
    required this.escalateAfterMins,
    required this.notifyFamily,
    required this.notifyCoordinator,
  });
  final String patientId;
  final bool enabled;

  /// "HH:MM" (IST).
  final String windowStart;
  final String windowEnd;
  final int escalateAfterMins;
  final bool notifyFamily;
  final bool notifyCoordinator;

  static const defaults = CheckinSettings(
    patientId: '',
    enabled: false,
    windowStart: '08:00',
    windowEnd: '10:00',
    escalateAfterMins: 60,
    notifyFamily: true,
    notifyCoordinator: true,
  );

  factory CheckinSettings.fromJson(Json j) => CheckinSettings(
        patientId: str(j, 'patientId'),
        enabled: boolOf(j, 'enabled'),
        windowStart: str(j, 'windowStart', '08:00'),
        windowEnd: str(j, 'windowEnd', '10:00'),
        escalateAfterMins: intOf(j, 'escalateAfterMins', 60),
        notifyFamily: boolOf(j, 'notifyFamily', true),
        notifyCoordinator: boolOf(j, 'notifyCoordinator', true),
      );

  /// Body for `PUT /patients/:id/checkin-settings` (without `patientId`).
  Json toJson() => {
        'enabled': enabled,
        'windowStart': windowStart,
        'windowEnd': windowEnd,
        'escalateAfterMins': escalateAfterMins,
        'notifyFamily': notifyFamily,
        'notifyCoordinator': notifyCoordinator,
      };

  CheckinSettings copyWith({
    bool? enabled,
    String? windowStart,
    String? windowEnd,
    int? escalateAfterMins,
    bool? notifyFamily,
    bool? notifyCoordinator,
  }) =>
      CheckinSettings(
        patientId: patientId,
        enabled: enabled ?? this.enabled,
        windowStart: windowStart ?? this.windowStart,
        windowEnd: windowEnd ?? this.windowEnd,
        escalateAfterMins: escalateAfterMins ?? this.escalateAfterMins,
        notifyFamily: notifyFamily ?? this.notifyFamily,
        notifyCoordinator: notifyCoordinator ?? this.notifyCoordinator,
      );
}

/// Minutes since midnight for "HH:MM" (null when malformed).
int? hhmmToMinutes(String v) {
  final m = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(v.trim());
  if (m == null) return null;
  final h = int.parse(m.group(1)!), mi = int.parse(m.group(2)!);
  if (h > 23 || mi > 59) return null;
  return h * 60 + mi;
}

String minutesToHhmm(int minutes) =>
    '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';

class CheckIn {
  const CheckIn({
    required this.id,
    required this.patientId,
    required this.date,
    required this.status,
    required this.checkedInAt,
    required this.mood,
    required this.note,
  });
  final String id;
  final String patientId;

  /// `YYYY-MM-DD`.
  final String date;

  /// ok | late | missed | pending
  final String status;
  final DateTime? checkedInAt;
  final int? mood;
  final String? note;

  bool get isDone => status == 'ok' || status == 'late';

  factory CheckIn.fromJson(Json j) => CheckIn(
        id: str(j, 'id'),
        patientId: str(j, 'patientId'),
        date: str(j, 'date'),
        status: str(j, 'status', 'pending'),
        checkedInAt: dateOrNull(j, 'checkedInAt'),
        mood: intOrNull(j, 'mood'),
        note: strOrNull(j, 'note'),
      );
}

/// What the Home check-in card shows.
enum CheckinCardState { hidden, pending, missed, done }

/// Decides the Home card state from the settings and today's entry.
CheckinCardState checkinCardState(CheckinSettings? settings, CheckIn? today) {
  if (settings == null || !settings.enabled) return CheckinCardState.hidden;
  if (today == null) return CheckinCardState.pending;
  if (today.isDone) return CheckinCardState.done;
  if (today.status == 'missed') return CheckinCardState.missed;
  return CheckinCardState.pending;
}

/// Today's entry from a history list (by local `YYYY-MM-DD`).
CheckIn? todaysCheckin(List<CheckIn> history, DateTime now) {
  final key = ymd(now);
  for (final c in history) {
    if (c.date == key) return c;
  }
  return null;
}

// ---------------------------------------------------------------- §42 Care programs

class ProgramThreshold {
  const ProgramThreshold({
    required this.type,
    required this.op,
    required this.value,
    required this.level,
    required this.message,
  });
  final String type;

  /// lt | gt
  final String op;
  final double value;

  /// routine | urgent | emergency
  final String level;
  final String message;

  factory ProgramThreshold.fromJson(Json j) => ProgramThreshold(
        type: str(j, 'type'),
        op: str(j, 'op'),
        value: dbl(j, 'value'),
        level: str(j, 'level', 'routine'),
        message: str(j, 'message'),
      );
}

class ProgramMetric {
  const ProgramMetric({required this.type, required this.frequency, required this.unit});
  final String type;

  /// daily | twice_daily | weekly
  final String frequency;
  final String unit;

  factory ProgramMetric.fromJson(Json j) => ProgramMetric(
        type: str(j, 'type'),
        frequency: str(j, 'frequency', 'daily'),
        unit: str(j, 'unit'),
      );
}

class ProgramTemplate {
  const ProgramTemplate({
    required this.code,
    required this.name,
    required this.description,
    required this.metrics,
    required this.status,
  });
  final String code;
  final String name;
  final String description;
  final List<ProgramMetric> metrics;
  final String status;

  factory ProgramTemplate.fromJson(Json j) => ProgramTemplate(
        code: str(j, 'code'),
        name: str(j, 'name'),
        description: str(j, 'description'),
        metrics: listOf(j['metrics'], ProgramMetric.fromJson),
        status: str(j, 'status'),
      );
}

class Enrollment {
  const Enrollment({
    required this.id,
    required this.patientId,
    required this.patientName,
    required this.templateCode,
    required this.templateName,
    required this.status,
    required this.thresholds,
    required this.thresholdsApprovedByName,
    required this.startDate,
    required this.endDate,
    required this.careEpisodeId,
    required this.adherencePct7d,
    required this.lastReadingAt,
    required this.openBreaches,
    required this.createdAt,
  });
  final String id;
  final String patientId;
  final String patientName;
  final String templateCode;
  final String templateName;

  /// active | paused | completed
  final String status;
  final List<ProgramThreshold> thresholds;
  final String? thresholdsApprovedByName;
  final String startDate;
  final String? endDate;
  final String? careEpisodeId;
  final num? adherencePct7d;
  final DateTime? lastReadingAt;
  final int openBreaches;
  final DateTime? createdAt;

  bool get isActive => status == 'active';

  factory Enrollment.fromJson(Json j) => Enrollment(
        id: str(j, 'id'),
        patientId: str(j, 'patientId'),
        patientName: str(j, 'patientName'),
        templateCode: str(j, 'templateCode'),
        templateName: str(j, 'templateName'),
        status: str(j, 'status', 'active'),
        thresholds: listOf(j['thresholds'], ProgramThreshold.fromJson),
        thresholdsApprovedByName: strOrNull(j, 'thresholdsApprovedByName'),
        startDate: str(j, 'startDate'),
        endDate: strOrNull(j, 'endDate'),
        careEpisodeId: strOrNull(j, 'careEpisodeId'),
        adherencePct7d: dblOrNull(j, 'adherencePct7d'),
        lastReadingAt: dateOrNull(j, 'lastReadingAt'),
        openBreaches: intOf(j, 'openBreaches'),
        createdAt: dateOrNull(j, 'createdAt'),
      );
}

class ProgramBreach {
  const ProgramBreach({
    required this.at,
    required this.type,
    required this.value,
    required this.threshold,
    required this.safetyEventId,
  });
  final DateTime at;
  final String type;
  final double value;
  final ProgramThreshold threshold;
  final String? safetyEventId;

  factory ProgramBreach.fromJson(Json j) => ProgramBreach(
        at: dateOf(j, 'at'),
        type: str(j, 'type'),
        value: dbl(j, 'value'),
        threshold: ProgramThreshold.fromJson(asJson(j['threshold'])),
        safetyEventId: strOrNull(j, 'safetyEventId'),
      );
}

class TrendPoint {
  const TrendPoint({required this.date, required this.type, required this.avg, required this.min, required this.max});
  final DateTime date;
  final String type;
  final double avg;
  final double min;
  final double max;

  factory TrendPoint.fromJson(Json j) {
    final avg = dbl(j, 'avg');
    return TrendPoint(
      date: DateTime.tryParse(str(j, 'date')) ?? DateTime.fromMillisecondsSinceEpoch(0),
      type: str(j, 'type'),
      avg: avg,
      min: dblOrNull(j, 'min') ?? avg,
      max: dblOrNull(j, 'max') ?? avg,
    );
  }
}

class ProgramSummary {
  const ProgramSummary({
    required this.enrollmentId,
    required this.from,
    required this.to,
    required this.expectedReadings,
    required this.receivedReadings,
    required this.adherencePct,
    required this.breaches,
    required this.trend,
  });
  final String enrollmentId;
  final String from;
  final String to;
  final int expectedReadings;
  final int receivedReadings;
  final num adherencePct;
  final List<ProgramBreach> breaches;
  final List<TrendPoint> trend;

  /// Trend points of one vital type, oldest first.
  List<TrendPoint> trendFor(String type) =>
      trend.where((t) => t.type == type).toList()..sort((a, b) => a.date.compareTo(b.date));

  /// Vital types present in the trend (stable order).
  List<String> get trendTypes {
    final seen = <String>[];
    for (final t in trend) {
      if (!seen.contains(t.type)) seen.add(t.type);
    }
    return seen;
  }

  factory ProgramSummary.fromJson(Json j) => ProgramSummary(
        enrollmentId: str(j, 'enrollmentId'),
        from: str(j, 'from'),
        to: str(j, 'to'),
        expectedReadings: intOf(j, 'expectedReadings'),
        receivedReadings: intOf(j, 'receivedReadings'),
        adherencePct: dbl(j, 'adherencePct'),
        breaches: listOf(j['breaches'], ProgramBreach.fromJson),
        trend: listOf(j['trend'], TrendPoint.fromJson),
      );
}

/// A quick reading entered from "Log reading".
enum ReadingKind { bp, glucose, weight }

/// Validation result for a reading: null when valid, else an error code.
enum ReadingError { missing, notNumber, outOfRange, systolicNotAboveDiastolic }

/// Plausible entry ranges (patient-entered; not clinical thresholds).
const readingRanges = {
  'bp_systolic': (60.0, 260.0),
  'bp_diastolic': (30.0, 160.0),
  'blood_glucose': (20.0, 600.0),
  'weight': (2.0, 300.0),
};

ReadingError? _checkOne(String raw, String type) {
  final t = raw.trim();
  if (t.isEmpty) return ReadingError.missing;
  final v = double.tryParse(t);
  if (v == null) return ReadingError.notNumber;
  final r = readingRanges[type]!;
  if (v < r.$1 || v > r.$2) return ReadingError.outOfRange;
  return null;
}

/// Validates the raw text fields of a reading. For BP pass both values.
ReadingError? validateReading(ReadingKind kind, String primary, [String secondary = '']) {
  switch (kind) {
    case ReadingKind.bp:
      final a = _checkOne(primary, 'bp_systolic');
      if (a != null) return a;
      final b = _checkOne(secondary, 'bp_diastolic');
      if (b != null) return b;
      if (double.parse(primary.trim()) <= double.parse(secondary.trim())) {
        return ReadingError.systolicNotAboveDiastolic;
      }
      return null;
    case ReadingKind.glucose:
      return _checkOne(primary, 'blood_glucose');
    case ReadingKind.weight:
      return _checkOne(primary, 'weight');
  }
}

/// The vitals (`type`, `value`, `unit`) a valid reading is posted as.
List<(String, double, String)> readingToVitals(ReadingKind kind, String primary, [String secondary = '']) {
  switch (kind) {
    case ReadingKind.bp:
      return [
        ('bp_systolic', double.parse(primary.trim()), 'mmHg'),
        ('bp_diastolic', double.parse(secondary.trim()), 'mmHg'),
      ];
    case ReadingKind.glucose:
      return [('blood_glucose', double.parse(primary.trim()), 'mg/dL')];
    case ReadingKind.weight:
      return [('weight', double.parse(primary.trim()), 'kg')];
  }
}

// ---------------------------------------------------------------- §52 Preventive care

class PreventiveItem {
  const PreventiveItem({
    required this.code,
    required this.name,
    required this.category,
    required this.description,
    required this.dueDate,
    required this.status,
    required this.lastDoneAt,
    required this.repeatEveryMonths,
  });
  final String code;
  final String name;

  /// vaccine | screening
  final String category;
  final String description;
  final String? dueDate;

  /// upcoming | due | overdue | done | not_applicable
  final String status;
  final DateTime? lastDoneAt;
  final int? repeatEveryMonths;

  factory PreventiveItem.fromJson(Json j) => PreventiveItem(
        code: str(j, 'code'),
        name: str(j, 'name'),
        category: str(j, 'category', 'screening'),
        description: str(j, 'description'),
        dueDate: strOrNull(j, 'dueDate'),
        status: str(j, 'status', 'upcoming'),
        lastDoneAt: dateOrNull(j, 'lastDoneAt'),
        repeatEveryMonths: intOrNull(j, 'repeatEveryMonths'),
      );
}

class PreventiveSchedule {
  const PreventiveSchedule({required this.items, required this.scheduleVersion, required this.scheduleStatus});
  final List<PreventiveItem> items;
  final String scheduleVersion;
  final String scheduleStatus;

  List<PreventiveItem> withStatus(String s) => items.where((i) => i.status == s).toList();

  factory PreventiveSchedule.fromJson(Json j) => PreventiveSchedule(
        items: listOf(j['items'], PreventiveItem.fromJson),
        scheduleVersion: str(j, 'scheduleVersion'),
        scheduleStatus: str(j, 'scheduleStatus'),
      );
}

// ---------------------------------------------------------------- §53 Exercise

class Exercise {
  const Exercise({
    required this.id,
    required this.title,
    required this.bodyArea,
    required this.level,
    required this.durationSecs,
    required this.videoUrl,
    required this.imageUrl,
    required this.instructions,
    required this.precautions,
  });
  final String id;
  final String title;
  final String bodyArea;
  final String level;
  final int durationSecs;
  final String? videoUrl;
  final String? imageUrl;
  final List<String> instructions;
  final List<String> precautions;

  factory Exercise.fromJson(Json j) => Exercise(
        id: str(j, 'id'),
        title: str(j, 'title'),
        bodyArea: str(j, 'bodyArea'),
        level: str(j, 'level'),
        durationSecs: intOf(j, 'durationSecs'),
        videoUrl: strOrNull(j, 'videoUrl'),
        imageUrl: strOrNull(j, 'imageUrl'),
        instructions: strList(j, 'instructions'),
        precautions: strList(j, 'precautions'),
      );
}

class ExercisePlanItem {
  const ExercisePlanItem({
    required this.exerciseId,
    required this.sets,
    required this.reps,
    required this.holdSecs,
    required this.perDay,
    required this.notes,
    this.exercise,
  });
  final String exerciseId;
  final int sets;
  final int reps;
  final int? holdSecs;
  final int perDay;
  final String? notes;

  /// Embedded exercise details when the server includes them.
  final Exercise? exercise;

  ExercisePlanItem withExercise(Exercise? e) => ExercisePlanItem(
      exerciseId: exerciseId, sets: sets, reps: reps, holdSecs: holdSecs, perDay: perDay, notes: notes, exercise: e ?? exercise);

  factory ExercisePlanItem.fromJson(Json j) {
    Exercise? embedded;
    if (j['exercise'] is Map) {
      embedded = Exercise.fromJson(asJson(j['exercise']));
    } else if (j['title'] != null) {
      embedded = Exercise.fromJson({...j, 'id': j['exerciseId']});
    }
    return ExercisePlanItem(
      exerciseId: str(j, 'exerciseId'),
      sets: intOf(j, 'sets', 1),
      reps: intOf(j, 'reps', 1),
      holdSecs: intOrNull(j, 'holdSecs'),
      perDay: intOf(j, 'perDay', 1),
      notes: strOrNull(j, 'notes'),
      exercise: embedded,
    );
  }
}

class ExercisePlan {
  const ExercisePlan({
    required this.id,
    required this.patientId,
    required this.authorName,
    required this.authorRole,
    required this.items,
    required this.startDate,
    required this.endDate,
    required this.status,
  });
  final String id;
  final String patientId;
  final String authorName;
  final String authorRole;
  final List<ExercisePlanItem> items;
  final String startDate;
  final String endDate;
  final String status;

  bool get isActive => status == 'active';

  factory ExercisePlan.fromJson(Json j) => ExercisePlan(
        id: str(j, 'id'),
        patientId: str(j, 'patientId'),
        authorName: str(j, 'authorName'),
        authorRole: str(j, 'authorRole'),
        items: listOf(j['items'], ExercisePlanItem.fromJson),
        startDate: str(j, 'startDate'),
        endDate: str(j, 'endDate'),
        status: str(j, 'status', 'active'),
      );
}

class ExerciseProgress {
  const ExerciseProgress({
    required this.sessionsPlanned,
    required this.sessionsDone,
    required this.adherencePct,
    required this.painTrend,
  });
  final int sessionsPlanned;
  final int sessionsDone;
  final num adherencePct;
  final List<(DateTime, int)> painTrend;

  factory ExerciseProgress.fromJson(Json j) => ExerciseProgress(
        sessionsPlanned: intOf(j, 'sessionsPlanned'),
        sessionsDone: intOf(j, 'sessionsDone'),
        adherencePct: dbl(j, 'adherencePct'),
        painTrend: [
          for (final p in listOf(j['painTrend'], (e) => e))
            (DateTime.tryParse(str(p, 'date')) ?? DateTime.fromMillisecondsSinceEpoch(0), intOf(p, 'painScore')),
        ],
      );
}

// ---------------------------------------------------------------- §54 Diet

const dietSlots = ['early_morning', 'breakfast', 'mid_morning', 'lunch', 'evening', 'dinner', 'bedtime'];

class DietMeal {
  const DietMeal({required this.slot, required this.items, required this.notes});
  final String slot;
  final List<String> items;
  final String? notes;

  factory DietMeal.fromJson(Json j) =>
      DietMeal(slot: str(j, 'slot'), items: strList(j, 'items'), notes: strOrNull(j, 'notes'));
}

class DietPlan {
  const DietPlan({
    required this.id,
    required this.patientId,
    required this.authorName,
    required this.authorRole,
    required this.conditions,
    required this.calorieTarget,
    required this.meals,
    required this.avoid,
    required this.notes,
    required this.validUntil,
    required this.status,
  });
  final String id;
  final String patientId;
  final String authorName;
  final String authorRole;
  final List<String> conditions;
  final int? calorieTarget;
  final List<DietMeal> meals;
  final List<String> avoid;
  final String? notes;
  final String validUntil;
  final String status;

  bool get isActive => status == 'active';

  /// Meals ordered by the day's time slots.
  List<DietMeal> get orderedMeals {
    final list = [...meals];
    int idx(String s) {
      final i = dietSlots.indexOf(s);
      return i < 0 ? dietSlots.length : i;
    }

    list.sort((a, b) => idx(a.slot).compareTo(idx(b.slot)));
    return list;
  }

  factory DietPlan.fromJson(Json j) => DietPlan(
        id: str(j, 'id'),
        patientId: str(j, 'patientId'),
        authorName: str(j, 'authorName'),
        authorRole: str(j, 'authorRole'),
        conditions: strList(j, 'conditions'),
        calorieTarget: intOrNull(j, 'calorieTarget'),
        meals: listOf(j['meals'], DietMeal.fromJson),
        avoid: strList(j, 'avoid'),
        notes: strOrNull(j, 'notes'),
        validUntil: str(j, 'validUntil'),
        status: str(j, 'status', 'active'),
      );
}

class DietAdherence {
  const DietAdherence({required this.days, required this.adherencePct});
  final List<({String date, int slotsLogged, int slotsFollowed})> days;
  final num adherencePct;

  factory DietAdherence.fromJson(Json j) => DietAdherence(
        days: [
          for (final d in listOf(j['days'], (e) => e))
            (date: str(d, 'date'), slotsLogged: intOf(d, 'slotsLogged'), slotsFollowed: intOf(d, 'slotsFollowed')),
        ],
        adherencePct: dbl(j, 'adherencePct'),
      );
}
