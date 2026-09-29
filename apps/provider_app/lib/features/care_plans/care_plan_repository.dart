import '../../core/api/api_client.dart';
import '../../models/care_plans.dart';
import '../../models/json.dart';

/// Exercise programs (§53) and diet plans (§54).
class CarePlanRepository {
  CarePlanRepository(this._api);
  final ApiClient _api;

  Future<List<Exercise>> exerciseLibrary({String? bodyArea}) async {
    final res = await _api.get('/exercise-library', query: {
      'limit': '100',
      if (bodyArea != null && bodyArea.isNotEmpty) 'bodyArea': bodyArea,
    });
    return _items(res).map(Exercise.fromJson).toList();
  }

  Future<Json> createExercisePlan(ExercisePlanDraft draft, {required String idempotencyKey}) async =>
      asJson(await _api.post('/exercise-plans', body: draft.toJson(), idempotencyKey: idempotencyKey));

  Future<List<ExercisePlan>> exercisePlans(String patientId) async =>
      _items(await _api.get('/exercise-plans', query: {'patientId': patientId})).map(ExercisePlan.fromJson).toList();

  Future<ExerciseProgress> exerciseProgress(String planId) async =>
      ExerciseProgress.fromJson(asJson(await _api.get('/exercise-plans/$planId/progress')));

  Future<List<DietTemplate>> dietTemplates() async =>
      _items(await _api.get('/diet-templates')).map(DietTemplate.fromJson).toList();

  Future<Json> createDietPlan(DietPlanDraft draft, {required String idempotencyKey}) async =>
      asJson(await _api.post('/diet-plans', body: draft.toJson(), idempotencyKey: idempotencyKey));

  static List<Json> _items(Object? res) => res is List ? jsonList(res) : jsonList(asJson(res)['items']);
}
