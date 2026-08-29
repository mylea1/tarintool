import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

List<Map<String, dynamic>> encodeWorkoutRecords(
  Iterable<WorkoutRecord> records,
) => records.map(_recordToMap).toList(growable: false);

List<WorkoutRecord> decodeWorkoutRecords(Object? value) => value is List
    ? value
          .whereType<Map>()
          .map((item) => _recordFromMap(Map<String, dynamic>.from(item)))
          .toList(growable: false)
    : const [];

abstract class WorkoutHistoryPersistence {
  Future<List<WorkoutRecord>> read(String userId);

  Future<void> write(String userId, List<WorkoutRecord> records);
}

class TrainingLibrarySnapshot {
  const TrainingLibrarySnapshot({
    required this.routines,
    required this.routineFolders,
    required this.scheduledLabels,
  });

  final List<Routine> routines;
  final List<String> routineFolders;
  final Map<String, String> scheduledLabels;
}

abstract class TrainingLibraryPersistence {
  Future<TrainingLibrarySnapshot> read(String userId);

  Future<void> write(String userId, TrainingLibrarySnapshot snapshot);
}

class SharedPreferencesTrainingLibraryPersistence
    implements TrainingLibraryPersistence {
  static const storageKey = 'kilo.training-library.v1';
  SharedPreferences? _preferences;

  Future<SharedPreferences> get _store async =>
      _preferences ??= await SharedPreferences.getInstance();

  @override
  Future<TrainingLibrarySnapshot> read(String userId) async {
    final raw = (await _store).getString(storageKey);
    if (raw == null || raw.isEmpty) return _emptyTrainingLibrary();
    try {
      final root = jsonDecode(raw);
      if (root is! Map || root['users'] is! Map) {
        return _emptyTrainingLibrary();
      }
      final value = (root['users'] as Map)[userId];
      if (value is! Map) return _emptyTrainingLibrary();
      final map = Map<String, dynamic>.from(value);
      return TrainingLibrarySnapshot(
        routines: _asMapList(map['routines']).map(_routineFromMap).toList(),
        routineFolders: _asStringList(map['routineFolders']),
        scheduledLabels: map['scheduledLabels'] is Map
            ? Map<String, String>.from(
                (map['scheduledLabels'] as Map).map(
                  (key, value) => MapEntry(key.toString(), value.toString()),
                ),
              )
            : const {},
      );
    } catch (_) {
      return _emptyTrainingLibrary();
    }
  }

  @override
  Future<void> write(String userId, TrainingLibrarySnapshot snapshot) async {
    final preferences = await _store;
    Map<String, dynamic> root = {'version': 1, 'users': <String, dynamic>{}};
    final raw = preferences.getString(storageKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) root = Map<String, dynamic>.from(decoded);
      } catch (_) {
        // Replace only the damaged training-library entry.
      }
    }
    final users = root['users'] is Map
        ? Map<String, dynamic>.from(root['users'] as Map)
        : <String, dynamic>{};
    users[userId] = {
      'routines': snapshot.routines.map(_routineToMap).toList(),
      'routineFolders': snapshot.routineFolders,
      'scheduledLabels': snapshot.scheduledLabels,
    };
    root['users'] = users;
    await preferences.setString(storageKey, jsonEncode(root));
  }
}

class InMemoryTrainingLibraryPersistence implements TrainingLibraryPersistence {
  final Map<String, Map<String, dynamic>> _snapshots = {};

  @override
  Future<TrainingLibrarySnapshot> read(String userId) async {
    final value = _snapshots[userId];
    if (value == null) return _emptyTrainingLibrary();
    return TrainingLibrarySnapshot(
      routines: _asMapList(value['routines']).map(_routineFromMap).toList(),
      routineFolders: _asStringList(value['routineFolders']),
      scheduledLabels: Map<String, String>.from(
        value['scheduledLabels'] as Map? ?? const {},
      ),
    );
  }

  @override
  Future<void> write(String userId, TrainingLibrarySnapshot snapshot) async {
    _snapshots[userId] = {
      'routines': snapshot.routines.map(_routineToMap).toList(),
      'routineFolders': [...snapshot.routineFolders],
      'scheduledLabels': Map<String, String>.from(snapshot.scheduledLabels),
    };
  }
}

TrainingLibrarySnapshot _emptyTrainingLibrary() =>
    const TrainingLibrarySnapshot(
      routines: [],
      routineFolders: [],
      scheduledLabels: {},
    );

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

class ActiveWorkoutSnapshot {
  const ActiveWorkoutSnapshot({
    required this.name,
    required this.note,
    required this.freeWorkout,
    required this.draft,
    required this.timerStarted,
    required this.paused,
    required this.elapsedSeconds,
    required this.startedAt,
    required this.exercises,
    this.defaultRestSeconds = 0,
    this.restRunning = false,
    this.restRemainingSeconds = 0,
    this.restEndsAt,
    this.restExerciseName,
    this.restSetupPending = false,
    this.pendingRestSetId,
  });

  final String name;
  final String note;
  final bool freeWorkout;
  final bool draft;
  final bool timerStarted;
  final bool paused;
  final int elapsedSeconds;
  final DateTime? startedAt;
  final List<WorkoutExercise> exercises;
  final int defaultRestSeconds;
  final bool restRunning;
  final int restRemainingSeconds;
  final DateTime? restEndsAt;
  final String? restExerciseName;
  final bool restSetupPending;
  final String? pendingRestSetId;
}

abstract class ActiveWorkoutPersistence {
  Future<ActiveWorkoutSnapshot?> read(String userId);

  Future<void> write(String userId, ActiveWorkoutSnapshot? snapshot);
}

class SharedPreferencesActiveWorkoutPersistence
    implements ActiveWorkoutPersistence {
  static const storageKey = 'kilo.active-workout.v1';
  SharedPreferences? _preferences;

  Future<SharedPreferences> get _store async =>
      _preferences ??= await SharedPreferences.getInstance();

  @override
  Future<ActiveWorkoutSnapshot?> read(String userId) async {
    final raw = (await _store).getString(storageKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final root = jsonDecode(raw);
      if (root is! Map || root['users'] is! Map) return null;
      final value = (root['users'] as Map)[userId];
      if (value is! Map) return null;
      final map = Map<String, dynamic>.from(value);
      return ActiveWorkoutSnapshot(
        name: map['name']?.toString() ?? '自由训练',
        note: map['note']?.toString() ?? '',
        freeWorkout: map['freeWorkout'] == true,
        draft: map['draft'] == true,
        timerStarted: map['timerStarted'] == true,
        paused: map['paused'] == true,
        elapsedSeconds: _asInt(map['elapsedSeconds']),
        startedAt: DateTime.tryParse(map['startedAt']?.toString() ?? ''),
        exercises: _asMapList(map['exercises']).map(_exerciseFromMap).toList(),
        defaultRestSeconds: _asInt(map['defaultRestSeconds']),
        restRunning: map['restRunning'] == true,
        restRemainingSeconds: _asInt(map['restRemainingSeconds']),
        restEndsAt: DateTime.tryParse(map['restEndsAt']?.toString() ?? ''),
        restExerciseName: map['restExerciseName']?.toString(),
        restSetupPending: map['restSetupPending'] == true,
        pendingRestSetId: map['pendingRestSetId']?.toString(),
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(String userId, ActiveWorkoutSnapshot? snapshot) async {
    final preferences = await _store;
    Map<String, dynamic> root = {'version': 1, 'users': <String, dynamic>{}};
    final raw = preferences.getString(storageKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) root = Map<String, dynamic>.from(decoded);
      } catch (_) {
        // Replace only the damaged active-session entry.
      }
    }
    final users = root['users'] is Map
        ? Map<String, dynamic>.from(root['users'] as Map)
        : <String, dynamic>{};
    if (snapshot == null) {
      users.remove(userId);
    } else {
      users[userId] = {
        'name': snapshot.name,
        'note': snapshot.note,
        'freeWorkout': snapshot.freeWorkout,
        'draft': snapshot.draft,
        'timerStarted': snapshot.timerStarted,
        'paused': snapshot.paused,
        'elapsedSeconds': snapshot.elapsedSeconds,
        'startedAt': snapshot.startedAt?.toIso8601String(),
        'exercises': snapshot.exercises.map(_exerciseToMap).toList(),
        'defaultRestSeconds': snapshot.defaultRestSeconds,
        'restRunning': snapshot.restRunning,
        'restRemainingSeconds': snapshot.restRemainingSeconds,
        'restEndsAt': snapshot.restEndsAt?.toIso8601String(),
        'restExerciseName': snapshot.restExerciseName,
        'restSetupPending': snapshot.restSetupPending,
        'pendingRestSetId': snapshot.pendingRestSetId,
      };
    }
    root['version'] = 1;
    root['users'] = users;
    await preferences.setString(storageKey, jsonEncode(root));
  }
}

class InMemoryActiveWorkoutPersistence implements ActiveWorkoutPersistence {
  final Map<String, ActiveWorkoutSnapshot> _snapshots = {};

  @override
  Future<ActiveWorkoutSnapshot?> read(String userId) async =>
      _snapshots[userId];

  @override
  Future<void> write(String userId, ActiveWorkoutSnapshot? snapshot) async {
    if (snapshot == null) {
      _snapshots.remove(userId);
    } else {
      _snapshots[userId] = snapshot;
    }
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
  'prDetails': record.prDetails.map(_prDetailToMap).toList(),
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
  prDetails: _asMapList(map['prDetails']).map(_prDetailFromMap).toList(),
  exercises: _asMapList(map['exercises']).map(_exerciseFromMap).toList(),
);

Map<String, dynamic> _prDetailToMap(WorkoutPrDetail detail) => {
  'exerciseId': detail.exerciseId,
  'metric': detail.metric,
  'currentValue': detail.currentValue,
  'previousValue': detail.previousValue,
  'previousRecordId': detail.previousRecordId,
  'previousDate': detail.previousDate.toIso8601String(),
};

WorkoutPrDetail _prDetailFromMap(Map<String, dynamic> map) => WorkoutPrDetail(
  exerciseId: map['exerciseId']?.toString() ?? '',
  metric: map['metric']?.toString() ?? 'weight',
  currentValue: _asDouble(map['currentValue']),
  previousValue: _asDouble(map['previousValue']),
  previousRecordId: map['previousRecordId']?.toString() ?? '',
  previousDate:
      DateTime.tryParse(map['previousDate']?.toString() ?? '') ??
      DateTime.fromMillisecondsSinceEpoch(0),
);

Map<String, dynamic> _routineToMap(Routine routine) => {
  'id': routine.id,
  'name': routine.name,
  'folder': routine.folder,
  'updatedAt': routine.updatedAt.toIso8601String(),
  'exercises': routine.exercises.map(_exerciseToMap).toList(),
};

Routine _routineFromMap(Map<String, dynamic> map) => Routine(
  id: map['id']?.toString() ?? '',
  name: map['name']?.toString() ?? '训练计划',
  folder: map['folder']?.toString() ?? '',
  updatedAt:
      DateTime.tryParse(map['updatedAt']?.toString() ?? '') ?? DateTime.now(),
  exercises: _asMapList(map['exercises']).map(_exerciseFromMap).toList(),
);

Map<String, dynamic> _exerciseToMap(WorkoutExercise exercise) => {
  'id': exercise.id,
  'exerciseId': exercise.exerciseId,
  'restSeconds': exercise.restSeconds,
  'note': exercise.note,
  'collapsed': exercise.collapsed,
  'supersetId': exercise.supersetId,
  'sets': exercise.sets.map(_setToMap).toList(),
};

WorkoutExercise _exerciseFromMap(Map<String, dynamic> map) => WorkoutExercise(
  id: map['id']?.toString() ?? '',
  exerciseId: map['exerciseId']?.toString() ?? '',
  restSeconds: _asInt(map['restSeconds'], fallback: 120),
  note: map['note']?.toString() ?? '',
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
  'durationSeconds': set.durationSeconds,
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
  durationSeconds: map['durationSeconds'] == null
      ? null
      : _asInt(map['durationSeconds']),
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
