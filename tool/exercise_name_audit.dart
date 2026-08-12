import 'dart:convert';
import 'dart:io';

import 'package:kilo_strength/exercise_name_zh.dart';

const equipmentLabels = <String, String>{
  'assisted': '辅助器械',
  'band': '弹力带',
  'barbell': '杠铃',
  'body weight': '自重',
  'bosu ball': '波速球',
  'cable': '绳索',
  'dumbbell': '哑铃',
  'ez barbell': '曲杆杠铃',
  'kettlebell': '壶铃',
  'leverage machine': '固定器械',
  'medicine ball': '药球',
  'resistance band': '阻力带',
  'smith machine': '史密斯机',
  'stability ball': '健身球',
  'weighted': '负重',
};

const targetLabels = <String, String>{
  'abs': '腹肌',
  'biceps': '肱二头肌',
  'calves': '小腿',
  'delts': '三角肌',
  'forearms': '前臂',
  'glutes': '臀肌',
  'hamstrings': '腘绳肌',
  'lats': '背阔肌',
  'pectorals': '胸肌',
  'quads': '股四头肌',
  'traps': '斜方肌',
  'triceps': '肱三头肌',
  'upper back': '上背部',
};

void main() {
  final source = File('../exercise-dataset-reference/data/exercises.json');
  final rows = (jsonDecode(source.readAsStringSync()) as List<dynamic>)
      .cast<Map<String, dynamic>>();
  final groups = <String, List<Map<String, dynamic>>>{};
  for (final row in rows) {
    final translated = chineseExerciseName(
      row['name'].toString(),
      equipment:
          equipmentLabels[row['equipment']] ?? row['equipment'].toString(),
      muscle: targetLabels[row['target']] ?? row['target'].toString(),
    );
    groups.putIfAbsent(translated, () => []).add(row);
  }
  final duplicates =
      groups.entries.where((entry) => entry.value.length > 1).toList()
        ..sort((a, b) => b.value.length.compareTo(a.value.length));
  stdout.writeln(
    'rows=${rows.length} duplicateNames=${duplicates.length} duplicateRows=${duplicates.fold<int>(0, (sum, item) => sum + item.value.length - 1)}',
  );
  for (final entry in duplicates.take(80)) {
    stdout.writeln(
      '${entry.key}\t${entry.value.map((row) => '${row['id']}:${row['name']}').join(' | ')}',
    );
  }
  // Raw translated-name collisions are expected audit findings. The app adds
  // stable English name + dataset ID disambiguators before display, so this
  // command reports the source quality without failing CI by default.
}
