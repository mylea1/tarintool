import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

abstract class WorkoutHistoryPersistence {
  Future<List<WorkoutRecord>> read(String userId);

  Future<void> write(String userId, List<WorkoutRecord> records);
}

class SharedPreferencesWorkoutHistoryPersistence
    implements WorkoutHistoryPersistence {
  static const storageKey = 'kilo.workout-history.v1';

  SharedPreferences? _preferences;

  Future<SharedPreferences> get _store async =>
      _preferences ??= await SharedPreferences.getInstance();

  @override
  Future<List<WorkoutRecord>> read(String userId) async {
    final raw = (await _store).getString(storageKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final root = jsonDecode(raw);
      if (root is! Map) return const [];
      final users = root['users'];
      if (users is! Map || users[userId] is! List) return const [];
      return (users[userId] as List)
          .whereType<Map>()
          .map((item) => _recordFromMap(Map<String, dynamic>.from(item)))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<void> write(String userId, List<WorkoutRecord> records) async {
    final preferences = await _store;
    Map<String, dynamic> root = {'version': 1, 'users': <String, dynamic>{}};
    final raw = preferences.getString(storageKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) root = Map<String, dynamic>.from(decoded);
      } catch (_) {
        // Replace only the damaged workout-history entry.
      }
    }
    final users = root['users'] is Map
        ? Map<String, dynamic>.from(root['users'] as Map)
        : <String, dynamic>{};
    users[userId] = records.map(_recordToMap).toList();
    root['version'] = 1;
    root['users'] = users;
    await preferences.setString(storageKey, jsonEncode(root));
  }
}

class InMemoryWorkoutHistoryPersistence implements WorkoutHistoryPersistence {
  final Map<String, List<Map<String, dynamic>>> _records = {};

  @override
  Future<List<WorkoutRecord>> read(String userId) async =>
      (_records[userId] ?? [])
          .map((item) => _recordFromMap(Map<String, dynamic>.from(item)))
          .toList();

  @override
  Future<void> write(String userId, List<WorkoutRecord> records) async {
    _records[userId] = records.map(_recordToMap).toList();
  }
}

Map<String, dynamic> _recordToMap(WorkoutRecord record) => {
  'id': record.id,
  'name': record.name,
  'date': record.date.toIso8601String(),
  'startTime': record.startTime,
  'durationSeconds': record.durationSeconds,
  'volume': record.volume,
  'effectiveSets': record.effectiveSets,
  'note': record.note,
  'exerciseIds': record.exerciseIds,
  'prs': record.prs,
  'exercises': record.exercises.map(_exerciseToMap).toList(),
};

WorkoutRecord _recordFromMap(Map<String, dynamic> map) => WorkoutRecord(
  id: map['id']?.toString() ?? '',
  name: map['name']?.toString() ?? '训练记录',
  date: DateTime.tryParse(map['date']?.toString() ?? '') ?? DateTime.now(),
  startTime: map['startTime']?.toString() ?? '',
  durationSeconds: _asInt(map['durationSeconds']),
  volume: _asDouble(map['volume']),
  effectiveSets: _asInt(map['effectiveSets']),
  note: map['note']?.toString() ?? '',
  exerciseIds: _asStringList(map['exerciseIds']),
  prs: _asStringList(map['prs']),
  exercises: _asMapList(map['exercises']).map(_exerciseFromMap).toList(),
);

Map<String, dynamic> _exerciseToMap(WorkoutExercise exercise) => {
  'id': exercise.id,
  'exerciseId': exercise.exerciseId,
  'restSeconds': exercise.restSeconds,
  'collapsed': exercise.collapsed,
  'supersetId': exercise.supersetId,
  'sets': exercise.sets.map(_setToMap).toList(),
};

WorkoutExercise _exerciseFromMap(Map<String, dynamic> map) => WorkoutExercise(
  id: map['id']?.toString() ?? '',
  exerciseId: map['exerciseId']?.toString() ?? '',
  restSeconds: _asInt(map['restSeconds'], fallback: 120),
  collapsed: map['collapsed'] == true,
  supersetId: map['supersetId']?.toString(),
  sets: _asMapList(map['sets']).map(_setFromMap).toList(),
);

Map<String, dynamic> _setToMap(WorkoutSet set) => {
  'id': set.id,
  'type': set.type,
  'weight': set.weight,
  'plannedWeight': set.plannedWeight,
  'reps': set.reps,
  'targetMin': set.targetMin,
  'targetMax': set.targetMax,
  'restSeconds': set.restSeconds,
  'completed': set.completed,
  'failed': set.failed,
  'note': set.note,
};

WorkoutSet _setFromMap(Map<String, dynamic> map) => WorkoutSet(
  id: map['id']?.toString() ?? '',
  type: map['type']?.toString() ?? 'work',
  weight: _asDouble(map['weight']),
  plannedWeight: map['plannedWeight'] == null
      ? null
      : _asDouble(map['plannedWeight']),
  reps: _asInt(map['reps']),
  targetMin: _asInt(map['targetMin'], fallback: 6),
  targetMax: _asInt(map['targetMax'], fallback: 8),
  restSeconds: _asInt(map['restSeconds'], fallback: 120),
  completed: map['completed'] == true,
  failed: map['failed'] == true,
  note: map['note']?.toString() ?? '',
);

List<Map<String, dynamic>> _asMapList(Object? value) => value is List
    ? value
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList()
    : const [];

List<String> _asStringList(Object? value) =>
    value is List ? value.map((item) => item.toString()).toList() : const [];

int _asInt(Object? value, {int fallback = 0}) =>
    value is num ? value.toInt() : int.tryParse('$value') ?? fallback;

double _asDouble(Object? value) =>
    value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
