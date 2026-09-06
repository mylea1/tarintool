import 'package:flutter_test/flutter_test.dart';
import 'package:kilo_strength/models.dart';

void main() {
  test('unnamed sessions use date and time and custom names survive', () {
    final date = DateTime(2026, 9, 6, 14, 42);
    expect(trainingDisplayName('自由训练', date), '2026.09.06 14:42');
    expect(trainingDisplayName('', date), '2026.09.06 14:42');
    expect(trainingDisplayName('上肢力量', date), '上肢力量');
    expect(trainingDisplayName('自由训练 09月06日 14:42'), '09月06日 14:42');
    expect(trainingDisplayName('自由训练进阶'), '自由训练进阶');
    expect(trainingDisplayName(''), '未命名计划');
  });
}
