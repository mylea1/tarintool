import 'dart:io';

import 'package:kilo_strength/models.dart';

const _equipmentWeights = <String, int>{
  '训练锤': 14,
  '轮胎': 14,
  '滑雪机': 13,
  '波速球': 12,
  '雪橇器械': 10,
  '训练绳': 9,
  '泡沫轴': 9,
  '健身球': 7,
  '药球': 7,
  '辅助器械': 4,
};

const _protectedPopularNames = <String>{
  'cable kneeling crunch',
  'dumbbell incline biceps curl',
  'dumbbell incline fly',
  'dumbbell incline press',
  'jump rope',
  'weighted chin-up',
  'weighted dip',
  'weighted pull-up',
  'weighted push-up',
};

const _specializedTerms = <String>[
  'alternating',
  'around the world',
  'assisted',
  'behind neck',
  'bent knee',
  'cross body',
  'decline',
  'explosive',
  'finger',
  'hack',
  'handstand',
  'incline',
  'isometric',
  'jack',
  'jump',
  'kick',
  'kneeling',
  'leaning',
  'lying',
  'muscle-up',
  'neck',
  'one arm',
  'one leg',
  'overhead',
  'plyo',
  'power',
  'pulse',
  'reverse grip',
  'roll',
  'rotational',
  'scapula',
  'side',
  'single arm',
  'single leg',
  'split',
  'suspended',
  'twist',
  'wide grip',
  'wrist',
  'yoga',
];

const _commonTerms = <String>[
  'bench press',
  'biceps curl',
  'calf raise',
  'chest press',
  'deadlift',
  'front raise',
  'hip thrust',
  'lat pulldown',
  'lateral raise',
  'leg curl',
  'leg extension',
  'leg press',
  'lunge',
  'overhead press',
  'plank',
  'pull-up',
  'push-up',
  'row',
  'shoulder press',
  'squat',
  'triceps extension',
];

class _ScoredExercise {
  const _ScoredExercise(this.exercise, this.number, this.score, this.reasons);

  final Exercise exercise;
  final int number;
  final int score;
  final List<String> reasons;
}

void main(List<String> args) {
  final curatedIds = curatedCatalog.map((item) => item.id).toSet();
  final equipmentCounts = <String, int>{};
  final familyCounts = <String, int>{};
  for (final item in catalog) {
    equipmentCounts[item.equipment] =
        (equipmentCounts[item.equipment] ?? 0) + 1;
    familyCounts[item.family] = (familyCounts[item.family] ?? 0) + 1;
  }

  final scored = <_ScoredExercise>[];
  for (var index = 0; index < catalog.length; index++) {
    final item = catalog[index];
    if (curatedIds.contains(item.id)) continue;
    var score = 0;
    final reasons = <String>[];
    final equipmentWeight = _equipmentWeights[item.equipment] ?? 0;
    if (equipmentWeight > 0) {
      score += equipmentWeight;
      reasons.add('器械稀有：${item.equipment}');
    }
    final equipmentCount = equipmentCounts[item.equipment] ?? 0;
    if (equipmentCount <= 3) {
      score += 4;
      reasons.add('全库该器械仅 $equipmentCount 项');
    } else if (equipmentCount <= 15) {
      score += 2;
      reasons.add('器械分类样本少');
    }
    final familyCount = familyCounts[item.family] ?? 0;
    if (familyCount <= 8) {
      score += 2;
      reasons.add('动作家族使用面窄');
    }
    final english = item.englishName.toLowerCase();
    final haystack =
        '${item.name} ${item.englishName} ${item.equipment} ${item.family}'
            .toLowerCase();
    const legacyForbidden = <String>[
      '波速球',
      '滑雪机',
      '训练锤',
      'bosu',
      'ski erg',
      'ski machine',
      'training hammer',
      'sledgehammer',
    ];
    if (legacyForbidden.any(haystack.contains)) {
      score += 100;
      reasons.add('项目既有不支持器械');
    } else if (item.family == '心肺') {
      score -= 30;
      reasons.add('保护常见有氧设备');
    }
    if (_protectedPopularNames.contains(english)) {
      score -= 50;
      reasons.add('明确保护的常见动作');
    }
    if (item.name.contains('（变式')) {
      score += 3;
      reasons.add('同名变式重复度高');
    }
    final matchedTerms = _specializedTerms.where(english.contains).toList();
    if (matchedTerms.isNotEmpty) {
      score += matchedTerms.length.clamp(1, 4) * 2;
      reasons.add('过度细分变式：${matchedTerms.take(2).join(' / ')}');
    }
    if (RegExp(r'\b(stretch|mobility|warm-up)\b').hasMatch(english)) {
      score += 4;
      reasons.add('更偏拉伸/热身而非常规器械训练');
    }
    if (RegExp(r'\b(clean|snatch|jerk|swing|throw)\b').hasMatch(english)) {
      score += 3;
      reasons.add('技术或场地门槛高');
    }
    final commonMatches = _commonTerms.where(english.contains).length;
    if (commonMatches > 0 && equipmentWeight == 0) score -= 5;
    scored.add(_ScoredExercise(item, index + 1, score, reasons));
  }

  scored.sort((a, b) {
    final scoreOrder = b.score.compareTo(a.score);
    return scoreOrder != 0
        ? scoreOrder
        : a.exercise.id.compareTo(b.exercise.id);
  });
  final selected = scored.take(300).toList(growable: false);
  if (selected.length != 300) {
    throw StateError('Expected 300 candidates, got ${selected.length}');
  }
  if (!args.contains('--write')) {
    for (final item in selected.take(40)) {
      stdout.writeln(
        '${item.number}\t${item.score}\t${item.exercise.name}\t'
        '${item.exercise.englishName}\t${item.exercise.equipment}',
      );
    }
    return;
  }

  final dart = StringBuffer()
    ..writeln('// GENERATED FILE. DO NOT EDIT.')
    ..writeln(
      '// Generated by tool/generate_exercise_retirement_candidates.dart.',
    )
    ..writeln(
      '// IDs stay in the historical catalog and are hidden only from pickers.',
    )
    ..writeln('const retiredExerciseIds = <String>{');
  for (final item in selected) {
    dart.writeln(
      "  '${item.exercise.id}', // #${item.number} ${item.exercise.name}",
    );
  }
  dart.writeln('};');
  File(
    'lib/exercise_retirement_candidates.generated.dart',
  ).writeAsStringSync(dart.toString());

  final markdown = StringBuffer()
    ..writeln('# 冷门动作软删除清单（300 项）')
    ..writeln()
    ..writeln('> 生成日期：2026-08-30。编号是完整 catalog 中的稳定编号，软删除后不会重排。')
    ..writeln()
    ..writeln('## 怎样判定“冷门”')
    ..writeln()
    ..writeln('- 先保护项目手工筛选的基础动作，不进入候选。')
    ..writeln('- 稀有器械权重最高：训练锤、轮胎、滑雪机、波速球、雪橇、训练绳、泡沫轴等。')
    ..writeln('- 动作名包含单侧、交替、跪姿、转体、爆发、跳跃等过度细分特征时加分。')
    ..writeln('- 拉伸/热身、技术门槛高的抛掷与举重变式加分；常见力量模式减分。')
    ..writeln('- 分数只用于选出前 300 项，不冒充真实搜索量。若要用流量定标，需接入可审计的 Google Trends/站内搜索数据。')
    ..writeln()
    ..writeln('## 怎样删除且不破坏旧数据')
    ..writeln()
    ..writeln('1. `catalog` 仍保留全部动作，旧训练记录和旧计划仍能按 ID 解析。')
    ..writeln('2. 选择器和动作库只从 `selectableCatalog` 过滤这 300 个 ID。')
    ..writeln('3. 编号始终来自完整 `catalog` 的位置，因此用户后续报“删 425”不会因本次筛选而指向错动作。')
    ..writeln()
    ..writeln('## 300 项中文名清单')
    ..writeln()
    ..writeln('| # | 稳定编号 | 中文名 | 器械 | 冷门分 | 主要理由 |')
    ..writeln('|---:|---:|---|---|---:|---|');
  for (var row = 0; row < selected.length; row++) {
    final item = selected[row];
    final reasons = item.reasons.isEmpty ? '变式优先级低' : item.reasons.join('；');
    markdown.writeln(
      '| ${row + 1} | ${item.number} | ${item.exercise.name.replaceAll('|', '\\|')} | '
      '${item.exercise.equipment} | ${item.score} | ${reasons.replaceAll('|', '\\|')} |',
    );
  }
  File(
    '../docs/exercise-retirement-candidates-300-2026-08-30.md',
  ).writeAsStringSync(markdown.toString());
  stdout.writeln(
    'Wrote ${selected.length} candidates. Score range: '
    '${selected.last.score}-${selected.first.score}.',
  );
}
