import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kilo_strength/ai_api.dart';
import 'package:kilo_strength/controller.dart';
import 'package:kilo_strength/models.dart';
import 'package:kilo_strength/product_features.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('activity and food snapshots preserve reviewable server values', () {
    final activity = WorkoutActivityPost.fromJson({
      'id': 'post-1',
      'ownerId': 'user-1',
      'ownerName': '训练伙伴',
      'workoutName': '上肢力量',
      'completedAt': '2026-08-30T10:00:00Z',
      'durationSeconds': 2400,
      'volume': 1250,
      'effectiveSets': 12,
      'completionRate': 0.75,
      'exerciseSummary': [
        {'exerciseId': 'bench_press', 'name': '卧推', 'sets': 4, 'topWeight': 80},
      ],
      'likeCount': 3,
      'liked': true,
      'emojiCounts': {'🔥': 2, '👏': 1},
      'cardStyle': 'forest',
      'cardImageKey': 'exercise',
    });
    expect(activity.completionPercent, 75);
    expect(activity.exerciseSummary.single.name, '卧推');
    expect(activity.likeCount, 3);
    expect(activity.emojiCounts['🔥'], 2);
    expect(activity.cardStyle, 'forest');
    expect(activity.cardImageKey, 'exercise');

    final unsafeActivity = WorkoutActivityPost.fromJson({
      'id': 'post-unsafe',
      'ownerId': 'user-1',
      'ownerName': '训练伙伴',
      'workoutName': '训练',
      'completedAt': '2026-08-30T10:00:00Z',
      'cardStyle': 'custom-css',
      'cardImageKey': 'file:///private/photo.jpg',
    });
    expect(unsafeActivity.cardStyle, 'coral');
    expect(unsafeActivity.cardImageKey, 'brand');

    final food = FoodPhotoRecognitionResult.fromJson({
      'status': 'completed',
      'requiresReview': true,
      'modelVersion': 'food-v1',
      'warnings': ['分量为估算值'],
      'items': [
        {
          'label': '鸡胸肉',
          'confidence': 0.91,
          'estimatedGrams': 180,
          'estimatedCalories': 297,
          'calorieRange': [260, 340],
          'proteinGrams': 56,
          'carbsGrams': 0,
          'fatGrams': 6,
          'nutritionSource': 'food-v1',
        },
      ],
    });
    expect(food.status, FoodRecognitionStatus.completed);
    expect(food.requiresReview, isTrue);
    expect(food.hasNutrition, isTrue);
    expect(food.items.single.calorieRange, (260.0, 340.0));
    expect(food.warnings, contains('分量为估算值'));
  });

  test(
    'activity API keeps publish, like and emoji comment requests separate',
    () async {
      final requests = <http.Request>[];
      final api = HttpCoachApi(
        baseUrl: 'https://api.example.test',
        client: MockClient((request) async {
          expect(request, isA<http.Request>());
          requests.add(request);
          final body = request.url.path == '/v1/auth/phone/login'
              ? {
                  'session': {'token': 'session-token'},
                }
              : <String, dynamic>{
                  'post': {'id': 'post-1'},
                };
          return http.Response(
            jsonEncode(body),
            200,
            headers: const {'content-type': 'application/json'},
          );
        }),
      );

      await api.signIn(identifier: '13800138000', password: 'test');
      await api.publishWorkoutActivity(const {'workoutName': '腿部训练'});
      await api.toggleWorkoutActivityLike('post-1');
      await api.commentOnWorkoutActivity('post-1', '🔥');

      expect(requests.map((request) => request.url.path), [
        '/v1/auth/phone/login',
        '/v1/friends/workouts',
        '/v1/friends/workouts/post-1/like',
        '/v1/friends/workouts/post-1/comments',
      ]);
      expect(jsonDecode(requests[1].body), {'workoutName': '腿部训练'});
      expect(jsonDecode(requests[2].body), isEmpty);
      expect(jsonDecode(requests[3].body), {'emoji': '🔥'});
    },
  );

  testWidgets('unified calendar combines a historical meal and workout', (
    tester,
  ) async {
    final controller = AppController();
    addTearDown(controller.dispose);
    final date = DateTime(2026, 8, 12, 8, 30);
    await controller.addNutritionEntry(
      NutritionEntry(
        id: 'nutrition-history',
        recordedAt: date,
        mealType: '第一餐',
        foodName: '鸡胸肉',
        calories: 297,
        proteinGrams: 56,
      ),
    );
    controller.history.add(
      WorkoutRecord(
        id: 'workout-history',
        name: '力量日',
        date: DateTime(2026, 8, 12, 18),
        startTime: '18:00',
        durationSeconds: 2400,
        volume: 1250,
        effectiveSets: 12,
        exerciseIds: const ['bench_press'],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: UnifiedCalendarPage(controller: controller, initialDate: date),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const Key('unified-calendar-day-2026-8-12')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('unified-day-timeline')), findsOneWidget);
    expect(find.text('鸡胸肉'), findsOneWidget);
    expect(find.text('力量日'), findsOneWidget);
    expect(find.text('训练'), findsOneWidget);
    expect(find.text('饮食'), findsOneWidget);
  });

  testWidgets('guide and theme pages expose compact self-service controls', (
    tester,
  ) async {
    final controller = AppController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(home: GuidePage(controller: controller)),
    );
    await tester.pump();
    expect(find.byKey(const Key('guide-page')), findsOneWidget);
    expect(find.byKey(const Key('guide-chapter-0')), findsOneWidget);
    expect(find.text('快速开始'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(home: ThemeChoicePage(controller: controller)),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('theme-choice-glacier')));
    await tester.pump();
    expect(controller.themeChoice, KiloThemeChoice.glacier);
  });
}
