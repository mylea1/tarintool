// Shared, deterministic merge for App/cloud sync and Web-compatible imports.
// No device-only data or credentials are added to a cloud backup here.
List<Map<String, dynamic>> webRecordMaps(Object? value) => value is List
    ? value.whereType<Map>().map((v) => Map<String, dynamic>.from(v)).toList()
    : <Map<String, dynamic>>[];
DateTime webRecordTime(Map<String, dynamic> record) =>
    DateTime.tryParse(
      '${record['updatedAt'] ?? record['recordedAt'] ?? record['date'] ?? ''}',
    ) ??
    DateTime.fromMillisecondsSinceEpoch(0);
List<Map<String, dynamic>> mergeWebRecords(
  Object? local,
  Object? remote, {
  Set<String> deleted = const {},
}) {
  final result = <String, Map<String, dynamic>>{};
  for (final item in [...webRecordMaps(remote), ...webRecordMaps(local)]) {
    final id = item['id']?.toString() ?? '';
    if (id.isEmpty || deleted.contains(id)) continue;
    final current = result[id];
    if (current == null ||
        !webRecordTime(item).isBefore(webRecordTime(current))) {
      result[id] = item;
    }
  }
  return result.values.toList();
}

Map<String, dynamic> mergeWebBackup(
  Map<String, dynamic> local,
  Map<String, dynamic> remote,
) {
  final tombstones = <String, dynamic>{};
  for (final source in [remote['webTombstones'], local['webTombstones']]) {
    if (source is! Map) continue;
    for (final entry in source.entries) {
      tombstones[entry.key.toString()] = {
        ...?tombstones[entry.key] as Map?,
        if (entry.value is Map) ...entry.value as Map,
      };
    }
  }
  final merged = <String, dynamic>{
    ...remote,
    ...local,
    'webTombstones': tombstones,
  };
  for (final kind in [
    'nutrition',
    'weight',
    'nutritionGoals',
    'workoutHistory',
  ]) {
    merged[kind] = mergeWebRecords(
      local[kind],
      remote[kind],
      deleted: (tombstones[kind] as Map? ?? {}).keys.map((v) => '$v').toSet(),
    );
  }
  final lp = local['trainingProfile'] as Map? ?? {},
      rp = remote['trainingProfile'] as Map? ?? {};
  final lv = lp['profile'] as Map? ?? {}, rv = rp['profile'] as Map? ?? {};
  DateTime profileTime(Map wrapper, Map profile) {
    final a = webRecordTime(Map<String, dynamic>.from(wrapper)),
        b = webRecordTime(Map<String, dynamic>.from(profile));
    return a.isAfter(b) ? a : b;
  }

  final localProfileTime = profileTime(lp, lv);
  final remoteProfileTime = profileTime(rp, rv);
  final preferRemote = remoteProfileTime.isAfter(localProfileTime);
  merged['trainingProfile'] = {
    ...rp,
    ...lp,
    'updatedAt': (preferRemote ? remoteProfileTime : localProfileTime)
        .toUtc()
        .toIso8601String(),
    'profile': preferRemote ? {...lv, ...rv} : {...rv, ...lv},
  };
  final ll = local['trainingLibrary'] as Map? ?? {},
      rl = remote['trainingLibrary'] as Map? ?? {};
  merged['trainingLibrary'] = {
    ...rl,
    ...ll,
    'routines': mergeWebRecords(
      ll['routines'],
      rl['routines'],
      deleted: (tombstones['plan'] as Map? ?? {}).keys.map((v) => '$v').toSet(),
    ),
    'routineFolders': {
      ...(rl['routineFolders'] as List? ?? []),
      ...(ll['routineFolders'] as List? ?? []),
    }.toList(),
  };
  return merged;
}

Set<String> webDeletedIds(Map<String, dynamic> backup, String kind) =>
    ((backup['webTombstones'] as Map? ?? {})[kind] as Map? ?? {}).keys
        .map((v) => '$v')
        .toSet();
