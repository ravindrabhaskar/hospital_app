import 'json.dart';

/// Only physiotherapists (and doctors, who use the web portal) create
/// exercise plans (contract §53); only dietitians create diet plans (§54).
bool canCreateExercisePlan(String? providerType) => providerType == 'physiotherapist';
bool canCreateDietPlan(String? providerType) => providerType == 'dietitian';

/// `GET /exercise-library` item (§53).
class Exercise {
  const Exercise({
    required this.id,
    required this.title,
    required this.bodyArea,
    this.level = '',
    this.durationSecs,
    this.instructions = const [],
    this.precautions = const [],
  });

  final String id;
  final String title;
  final String bodyArea;
  final String level;
  final int? durationSecs;
  final List<String> instructions;
  final List<String> precautions;

  factory Exercise.fromJson(Json json) => Exercise(
        id: strOr(json['id']),
        title: strOr(json['title']),
        bodyArea: strOr(json['bodyArea']),
        level: strOr(json['level']),
        durationSecs: intOrNull(json['durationSecs']),
        instructions: stringList(json['instructions']),
        precautions: stringList(json['precautions']),
      );
}

/// One exercise in a plan being drafted.
class ExercisePlanItemDraft {
  ExercisePlanItemDraft(this.exercise, {this.sets = 2, this.reps = 10, this.holdSecs, this.perDay = 1, this.notes = ''});

  final Exercise exercise;
  int sets;
  int reps;
  int? holdSecs;
  int perDay;
  String notes;

  Json toJson() => {
        'exerciseId': exercise.id,
        'sets': sets,
        'reps': reps,
        'holdSecs': ?holdSecs,
        'perDay': perDay,
        if (notes.trim().isNotEmpty) 'notes': notes.trim(),
      };
}

/// Limits used by the plan form (kept here so tests can check them).
class ExercisePlanLimits {
  ExercisePlanLimits._();
  static const maxSets = 10;
  static const maxReps = 50;
  static const maxHoldSecs = 300;
  static const maxPerDay = 6;
  static const maxWeeks = 26;
}

enum ExercisePlanError { noExercises, sets, reps, hold, perDay, weeks, startDate }

class ExercisePlanDraft {
  ExercisePlanDraft({required this.patientId, this.careEpisodeId, required this.startDate, this.weeks = 4});

  final String patientId;
  final String? careEpisodeId;
  DateTime startDate;
  int weeks;
  final List<ExercisePlanItemDraft> items = [];

  bool contains(String exerciseId) => items.any((i) => i.exercise.id == exerciseId);

  /// Errors per field (empty = valid). [today] is the local date.
  Set<ExercisePlanError> validate(DateTime today) {
    final errors = <ExercisePlanError>{};
    if (items.isEmpty) errors.add(ExercisePlanError.noExercises);
    for (final i in items) {
      if (i.sets < 1 || i.sets > ExercisePlanLimits.maxSets) errors.add(ExercisePlanError.sets);
      if (i.reps < 1 || i.reps > ExercisePlanLimits.maxReps) errors.add(ExercisePlanError.reps);
      final hold = i.holdSecs;
      if (hold != null && (hold < 0 || hold > ExercisePlanLimits.maxHoldSecs)) errors.add(ExercisePlanError.hold);
      if (i.perDay < 1 || i.perDay > ExercisePlanLimits.maxPerDay) errors.add(ExercisePlanError.perDay);
    }
    if (weeks < 1 || weeks > ExercisePlanLimits.maxWeeks) errors.add(ExercisePlanError.weeks);
    final day = DateTime(today.year, today.month, today.day);
    if (DateTime(startDate.year, startDate.month, startDate.day).isBefore(day)) {
      errors.add(ExercisePlanError.startDate);
    }
    return errors;
  }

  Json toJson() => {
        'patientId': patientId,
        'careEpisodeId': ?careEpisodeId,
        'items': items.map((i) => i.toJson()).toList(),
        'startDate': ymd(startDate),
        'weeks': weeks,
      };
}

class ExercisePlan {
  const ExercisePlan({
    required this.id,
    required this.authorName,
    required this.itemCount,
    this.startDate,
    this.endDate,
    this.status = 'active',
  });

  final String id;
  final String authorName;
  final int itemCount;
  final String? startDate;
  final String? endDate;
  final String status;

  factory ExercisePlan.fromJson(Json json) => ExercisePlan(
        id: strOr(json['id']),
        authorName: strOr(json['authorName']),
        itemCount: json['items'] is List ? (json['items'] as List).length : 0,
        startDate: str(json['startDate']),
        endDate: str(json['endDate']),
        status: strOr(json['status'], 'active'),
      );
}

/// `GET /exercise-plans/:id/progress`.
class ExerciseProgress {
  const ExerciseProgress({
    required this.sessionsPlanned,
    required this.sessionsDone,
    required this.adherencePct,
    this.painTrend = const [],
  });

  final int sessionsPlanned;
  final int sessionsDone;
  final num adherencePct;
  final List<({String date, num painScore})> painTrend;

  num? get latestPain => painTrend.isEmpty ? null : painTrend.last.painScore;

  factory ExerciseProgress.fromJson(Json json) => ExerciseProgress(
        sessionsPlanned: intOrNull(json['sessionsPlanned']) ?? 0,
        sessionsDone: intOrNull(json['sessionsDone']) ?? 0,
        adherencePct: numOrNull(json['adherencePct']) ?? 0,
        painTrend: [
          for (final p in jsonList(json['painTrend']))
            (date: strOr(p['date']), painScore: numOrNull(p['painScore']) ?? 0),
        ],
      );
}

/// `GET /diet-templates` item (§54).
class DietTemplate {
  const DietTemplate({required this.code, required this.name, this.conditions = const [], this.status = ''});
  final String code;
  final String name;
  final List<String> conditions;

  /// `fixture_unapproved` templates carry the clinical-governance label.
  final String status;

  bool get unapproved => status != 'approved';

  factory DietTemplate.fromJson(Json json) => DietTemplate(
        code: strOr(json['code']),
        name: strOr(json['name'], strOr(json['code'])),
        conditions: stringList(json['conditions']),
        status: strOr(json['status']),
      );
}

/// Meal slots in the §54 order.
const mealSlots = ['early_morning', 'breakfast', 'mid_morning', 'lunch', 'evening', 'dinner', 'bedtime'];

enum DietPlanError { noMeals, calories, validUntil, noConditions }

class DietPlanLimits {
  DietPlanLimits._();
  static const minCalories = 800;
  static const maxCalories = 4000;
}

class DietPlanDraft {
  DietPlanDraft({required this.patientId, required this.validUntil});

  final String patientId;
  String? templateCode;
  final List<String> conditions = [];
  int? calorieTarget;

  /// slot -> food items.
  final Map<String, List<String>> meals = {};
  final Map<String, String> mealNotes = {};
  final List<String> avoid = [];
  String notes = '';
  DateTime validUntil;

  Set<DietPlanError> validate(DateTime today) {
    final errors = <DietPlanError>{};
    if (!meals.values.any((items) => items.isNotEmpty)) errors.add(DietPlanError.noMeals);
    if (conditions.isEmpty) errors.add(DietPlanError.noConditions);
    final c = calorieTarget;
    if (c != null && (c < DietPlanLimits.minCalories || c > DietPlanLimits.maxCalories)) {
      errors.add(DietPlanError.calories);
    }
    final day = DateTime(today.year, today.month, today.day);
    final until = DateTime(validUntil.year, validUntil.month, validUntil.day);
    if (!until.isAfter(day)) errors.add(DietPlanError.validUntil);
    return errors;
  }

  Json toJson() => {
        'patientId': patientId,
        'templateCode': ?templateCode,
        'conditions': conditions,
        'calorieTarget': ?calorieTarget,
        'meals': [
          for (final slot in mealSlots)
            if ((meals[slot] ?? const []).isNotEmpty)
              {
                'slot': slot,
                'items': meals[slot],
                if ((mealNotes[slot] ?? '').trim().isNotEmpty) 'notes': mealNotes[slot]!.trim(),
              },
        ],
        'avoid': avoid,
        if (notes.trim().isNotEmpty) 'notes': notes.trim(),
        'validUntil': ymd(validUntil),
      };
}

/// Splits a comma/newline separated entry into trimmed, non-empty values.
List<String> splitList(String text) =>
    text.split(RegExp(r'[,\n]')).map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

String ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
