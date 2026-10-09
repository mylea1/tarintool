import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:kilo_strength/account_membership.dart';
import 'package:kilo_strength/ai_api.dart';
import 'package:kilo_strength/controller.dart';
import 'package:kilo_strength/models.dart';
import 'package:kilo_strength/recognition_api.dart';
import 'package:kilo_strength/web_sync_merge.dart';
import 'package:kilo_strength/workout_history_persistence.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Newer MCP records survive an older phone backup; unrelated fields and tombstones remain',
    () {
      final merged = mergeWebBackup(
        {
          'nutrition': [
            {
              'id': 'meal',
              'calories': 100,
              'updatedAt': '2026-10-01T00:00:00Z',
            },
            {'id': 'deleted', 'calories': 300},
          ],
          'trainingProfile': {
            'updatedAt': '2026-10-02T00:00:00Z',
            'profile': {'heightCm': 170},
          },
        },
        {
          'privateExtension': {'keep': true},
          'nutrition': [
            {
              'id': 'meal',
              'calories': 520,
              'updatedAt': '2026-10-09T00:00:00Z',
            },
            {'id': 'new', 'calories': 400},
          ],
          'webTombstones': {
            'nutrition': {'deleted': '2026-10-09T00:00:00Z'},
          },
          'trainingProfile': {
            'updatedAt': '2026-10-02T00:00:00Z',
            'profile': {'heightCm': 181, 'updatedAt': '2026-10-09T00:00:00Z'},
          },
        },
      );
      expect((merged['nutrition'] as List).length, 2);
      expect((merged['nutrition'] as List).first['calories'], 520);
      expect(merged['privateExtension'], {'keep': true});
      expect(merged['trainingProfile']['profile']['heightCm'], 181);
    },
  );
  test(
    'Web backup imports into actual App stores, preserves set notes, goals and survives hydration',
    () async {
      SharedPreferences.setMockInitialValues({});
      final accounts = AccountService();
      accounts.loginWithPhone('13800138999');
      final history = InMemoryWorkoutHistoryPersistence(),
          library = InMemoryTrainingLibraryPersistence();
      final controller = AppController(
        accountService: accounts,
        coachApi: UnconfiguredCoachApi(),
        recognitionApi: UnconfiguredRecognitionApi(),
        workoutHistoryPersistence: history,
        trainingLibraryPersistence: library,
      );
      addTearDown(controller.dispose);
      final now = DateTime.now().toUtc(),
          day =
              '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final exercises = [
        {
          'id': 'e1',
          'exerciseId': 'bench_press',
          'restSeconds': 120,
          'note': '肩胛收紧',
          'sets': [
            {
              'id': 's1',
              'type': 'work',
              'weight': 60,
              'reps': 8,
              'completed': true,
              'restSeconds': 120,
              'note': '状态稳定；右侧略疲劳；下次热身',
              'rpe': 8,
              'rir': 2,
            },
          ],
        },
      ];
      final backup = {
        'source': 'traintool-web',
        'schemaVersion': 2,
        'workoutHistory': [
          {
            'id': 'w1',
            'name': 'MCP 训练',
            'date': now.toIso8601String(),
            'updatedAt': now.toIso8601String(),
            'volume': 480,
            'effectiveSets': 1,
            'durationSeconds': 1600,
            'note': '整次训练感受',
            'exerciseIds': ['bench_press'],
            'exercises': exercises,
          },
        ],
        'trainingLibrary': {
          'routines': [
            {
              'id': 'p1',
              'name': 'MCP 计划',
              'folder': '我的计划',
              'updatedAt': now.toIso8601String(),
              'exercises': exercises,
            },
          ],
        },
        'nutrition': [
          {
            'id': 'm1',
            'recordedAt': now.toIso8601String(),
            'updatedAt': now.toIso8601String(),
            'mealType': '午餐',
            'foodName': '鸡肉饭',
            'calories': 520,
            'estimated': true,
            'note': '油量不确定',
          },
        ],
        'weight': [
          {
            'id': 'weight1',
            'recordedAt': now.toIso8601String(),
            'weightKg': 79.2,
            'note': '晨起',
          },
        ],
        'trainingProfile': {
          'profile': {
            'heightCm': 181,
            'weightKg': 79.2,
            'age': 30,
            'gender': 'male',
          },
        },
        'nutritionGoals': [
          {
            'id': 'g1',
            'date': day,
            'calories': 2300,
            'goalType': '减脂',
            'basis': '外部 AI 估算，用户确认',
            'source': 'external-ai',
            'updatedAt': now.toIso8601String(),
          },
        ],
      };
      await controller.importWebBackup(backup);
      expect(
        controller.history.single.exercises.single.sets.single.note,
        contains('右侧略疲劳'),
      );
      expect(
        controller.history.single.exercises.single.sets.single.restSeconds,
        120,
      );
      expect(
        controller.routines.single.exercises.single.exerciseId,
        'bench_press',
      );
      expect(controller.nutritionEntries.single.calories, 520);
      expect(controller.nutritionEntries.single.estimated, true);
      expect(controller.nutritionEntries.single.note, '油量不确定');
      expect(controller.weightEntries.single.weightKg, 79.2);
      expect(controller.trainingProfile.heightCm, 181);
      expect(controller.estimatedDailyCalories, 2300);
      await controller.importWebBackup(backup);
      expect(controller.history.length, 1);
      expect(controller.nutritionEntries.length, 1);
      final prefs = await SharedPreferences.getInstance();
      expect(
        jsonDecode(
          prefs.getString('kilo.nutrition.v1.${accounts.currentUser!.id}')!,
        ).single['foodName'],
        '鸡肉饭',
      );
      await controller.hydratePersonalAgentData();
      expect(controller.nutritionEntries.single.note, '油量不确定');
      final encoded = encodeWorkoutRecords(controller.history).single;
      expect(encoded['updatedAt'], now.toIso8601String());
      expect(encoded['exercises'][0]['sets'][0]['note'], contains('右侧略疲劳'));
    },
  );
  test('Nutrition and body models roundtrip Web estimates and timestamps', () {
    final now = DateTime.now().toUtc();
    final meal = NutritionEntry(
      id: 'n',
      recordedAt: now,
      mealType: '午餐',
      foodName: '测试',
      calories: 500,
      note: '感受',
      estimated: true,
      updatedAt: now,
    );
    expect(NutritionEntry.fromJson(meal.toJson()).estimated, true);
    expect(NutritionEntry.fromJson(meal.toJson()).note, '感受');
    final weight = WeightEntry(
      id: 'w',
      recordedAt: now,
      weightKg: 72,
      updatedAt: now,
    );
    expect(WeightEntry.fromJson(weight.toJson()).updatedAt, now);
  });
}
