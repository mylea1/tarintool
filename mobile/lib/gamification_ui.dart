import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'controller.dart';
import 'gamification.dart';
import 'models.dart';

const _paper = Color(0xFFFFF7F0);
const _surface = Colors.white;
const _primary = Color(0xFFD95718);
const _primaryContainer = Color(0xFFFFE3D2);
const _ink = Color(0xFF241A15);
const _quiet = Color(0xFF756156);
const _line = Color(0xFFEAD9CD);

class AvatarPreview extends StatelessWidget {
  const AvatarPreview({super.key, required this.progress, this.size = 112});

  final PlayerProgress progress;
  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: '训练角色，身体成长阶段 ${progress.physiqueStage}',
    child: SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _AvatarPainter(
          style: progress.avatar,
          physiqueStage: progress.physiqueStage,
          muscleLevels: {
            for (final group in MuscleGroup.values)
              group: progress.muscleLevel(group),
          },
        ),
      ),
    ),
  );
}

class _AvatarPainter extends CustomPainter {
  const _AvatarPainter({
    required this.style,
    required this.physiqueStage,
    required this.muscleLevels,
  });
  final AvatarStyle style;
  final int physiqueStage;
  final Map<MuscleGroup, int> muscleLevels;

  static const skins = [
    Color(0xFFC98967),
    Color(0xFFF0B88F),
    Color(0xFF8E5B43),
    Color(0xFF5F3B2D),
  ];
  static const tops = [
    Color(0xFFD95718),
    Color(0xFF25201D),
    Color(0xFF2F6DB2),
    Color(0xFF21845A),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 112;
    canvas.scale(scale, scale);
    final bg = Paint()..color = const Color(0xFFFFECDD);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(0, 0, 112, 112),
        const Radius.circular(22),
      ),
      bg,
    );
    final skin = Paint()..color = skins[style.skin % skins.length];
    final top = Paint()..color = tops[style.top % tops.length];
    final pants = Paint()
      ..color = style.pants.isEven
          ? const Color(0xFF2C2927)
          : const Color(0xFF4D667A);
    final baseMuscle = switch (style.base) {
      'power' => 3.0,
      'agile' => -1.2,
      _ => 0.0,
    };
    final torsoLevel = [
      MuscleGroup.chest,
      MuscleGroup.back,
      MuscleGroup.shoulders,
    ].map((group) => muscleLevels[group] ?? 1).reduce(math.max);
    final armLevel = muscleLevels[MuscleGroup.arms] ?? 1;
    final legLevel = muscleLevels[MuscleGroup.legs] ?? 1;
    final torsoMuscle =
        (physiqueStage * 1.1 + baseMuscle + (torsoLevel - 1) * .4)
            .clamp(-1.2, 12)
            .toDouble();
    final armMuscle =
        (physiqueStage * 1.0 + baseMuscle * .7 + (armLevel - 1) * .45)
            .clamp(-.8, 11)
            .toDouble();
    final legMuscle = ((legLevel - 1) * .35 + baseMuscle * .25)
        .clamp(0, 7)
        .toDouble();
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(37 - torsoMuscle, 45, 38 + torsoMuscle * 2, 38),
        const Radius.circular(13),
      ),
      top,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(26 - armMuscle, 48, 15 + armMuscle, 39),
        const Radius.circular(9),
      ),
      skin,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(71, 48, 15 + armMuscle, 39),
        const Radius.circular(9),
      ),
      skin,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(42, 78, 28, 21),
        const Radius.circular(7),
      ),
      pants,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(43 - legMuscle / 2, 94, 10 + legMuscle, 14),
        const Radius.circular(5),
      ),
      pants,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(59 - legMuscle / 2, 94, 10 + legMuscle, 14),
        const Radius.circular(5),
      ),
      pants,
    );
    final shoes = Paint()
      ..color = switch (style.shoes % 3) {
        1 => const Color(0xFFD95718),
        2 => const Color(0xFFF4EEE9),
        _ => const Color(0xFF241A15),
      };
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(39, 104, 17, 7),
        const Radius.circular(4),
      ),
      shoes,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(57, 104, 17, 7),
        const Radius.circular(4),
      ),
      shoes,
    );
    canvas.drawCircle(const Offset(56, 31), 17, skin);
    final hair = Paint()
      ..color = style.hair.isEven
          ? const Color(0xFF30221C)
          : const Color(0xFFB7682F);
    canvas.drawArc(
      const Rect.fromLTWH(39, 12, 34, 30),
      math.pi,
      math.pi,
      true,
      hair,
    );
    if (style.accessory.isOdd) {
      final accessory = Paint()
        ..color = const Color(0xFF241A15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawLine(const Offset(42, 30), const Offset(70, 30), accessory);
    }
    if (physiqueStage >= 4) {
      final glow = Paint()
        ..color = const Color(0xFFB7E34A).withValues(alpha: .45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(5, 5, 102, 102),
          const Radius.circular(19),
        ),
        glow,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _AvatarPainter oldDelegate) =>
      oldDelegate.style != style ||
      oldDelegate.physiqueStage != physiqueStage ||
      oldDelegate.muscleLevels.toString() != muscleLevels.toString();
}

class HomeGameLayer extends StatelessWidget {
  const HomeGameLayer({super.key, required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final progress = controller.playerProgress;
    final quest = progress.quest ?? questForDay(DateTime.now());
    final muscles = [...MuscleGroup.values]
      ..sort(
        (a, b) => progress.muscleLevel(b).compareTo(progress.muscleLevel(a)),
      );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          key: const Key('home-character-progress'),
          margin: EdgeInsets.zero,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => showAvatarEditor(context, controller),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  AvatarPreview(progress: progress, size: 94),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '训练者 Lv.${progress.trainingLevel}',
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: _quiet,
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        LinearProgressIndicator(
                          value: progress.levelProgress,
                          minHeight: 7,
                          borderRadius: BorderRadius.circular(8),
                          color: _primary,
                          backgroundColor: _primaryContainer,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${progress.trainingXp - progress.levelStartXp} / ${progress.nextLevelXp - progress.levelStartXp} XP',
                          style: const TextStyle(color: _quiet, fontSize: 11),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final muscle in muscles.take(3))
                              _MuscleChip(
                                label: muscle.label,
                                level: progress.muscleLevel(muscle),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final single =
                constraints.maxWidth < 330 ||
                MediaQuery.textScalerOf(context).scale(1) > 1.35;
            final items = [
              _CompactGameCard(
                icon: Icons.explore_outlined,
                title: quest.done ? '今日支线已完成' : '找到${quest.kind}',
                caption: quest.done ? '探索经验已结算' : '探索 XP +20',
                onTap: () => controller.selectPage(PageId.world),
              ),
              _CompactGameCard(
                icon: Icons.groups_2_outlined,
                title: progress.showAtVenue ? '训练场展示中' : '同场展示未开启',
                caption: progress.showAtVenue ? '仅匿名状态' : '默认保护隐私',
                onTap: () => controller.selectPage(PageId.world),
              ),
            ];
            return single
                ? Column(
                    children: [items[0], const SizedBox(height: 8), items[1]],
                  )
                : Row(
                    children: [
                      Expanded(child: items[0]),
                      const SizedBox(width: 8),
                      Expanded(child: items[1]),
                    ],
                  );
          },
        ),
      ],
    );
  }
}

class _MuscleChip extends StatelessWidget {
  const _MuscleChip({required this.label, required this.level});
  final String label;
  final int level;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: _paper,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      child: Text(
        '$label Lv.$level',
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
      ),
    ),
  );
}

class _CompactGameCard extends StatelessWidget {
  const _CompactGameCard({
    required this.icon,
    required this.title,
    required this.caption,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String caption;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: _surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: _line),
    ),
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(icon, color: _primary, size: 21),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _quiet, fontSize: 10),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class WorldPage extends StatefulWidget {
  const WorldPage({super.key, required this.controller});
  final AppController controller;
  @override
  State<WorldPage> createState() => _WorldPageState();
}

class _WorldPageState extends State<WorldPage> {
  var explore = false;
  @override
  Widget build(BuildContext context) {
    final progress = widget.controller.playerProgress;
    final quest = progress.quest ?? questForDay(DateTime.now());
    return ListView(
      key: const Key('world-page'),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 110),
      children: [
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(
              value: false,
              icon: Icon(Icons.groups_2_outlined),
              label: Text('训练场'),
            ),
            ButtonSegment(
              value: true,
              icon: Icon(Icons.explore_outlined),
              label: Text('探索'),
            ),
          ],
          selected: {explore},
          onSelectionChanged: (value) => setState(() => explore = value.first),
        ),
        const SizedBox(height: 14),
        if (explore)
          _ExplorationPanel(controller: widget.controller, quest: quest)
        else
          _VenuePanel(controller: widget.controller),
      ],
    );
  }
}

class _VenuePanel extends StatelessWidget {
  const _VenuePanel({required this.controller});
  final AppController controller;
  @override
  Widget build(BuildContext context) {
    final progress = controller.playerProgress;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  '同场训练者',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 5),
                const Text(
                  '不采集精确位置。输入同一场馆代号后，只分享匿名训练状态。',
                  style: TextStyle(color: _quiet),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: progress.venueCode,
                  decoration: const InputDecoration(
                    labelText: '训练场代号',
                    hintText: '例如：SONGJIANG-01',
                  ),
                  textCapitalization: TextCapitalization.characters,
                  onChanged: controller.updateVenueCodeDraft,
                  onFieldSubmitted: (_) => controller.commitVenueCode(),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton.icon(
                    onPressed: controller.commitVenueCode,
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('保存训练场'),
                  ),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('允许同场匿名展示'),
                  subtitle: const Text('默认关闭，可随时退出'),
                  value: progress.showAtVenue,
                  onChanged: (value) =>
                      controller.updateWorldPrivacy(showAtVenue: value),
                ),
                OutlinedButton.icon(
                  onPressed: controller.worldLoading
                      ? null
                      : controller.refreshWorldVenue,
                  icon: controller.worldLoading
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh_rounded),
                  label: const Text('刷新训练场'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (controller.worldError != null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Text('训练场暂时无法连接（${controller.worldError}），不影响本地训练。'),
            ),
          )
        else if (controller.worldActive.isEmpty &&
            controller.worldEchoes.isEmpty)
          const Card(
            key: Key('world-real-empty-state'),
            child: Padding(
              padding: EdgeInsets.all(18),
              child: Column(
                children: [
                  Icon(Icons.radar_rounded, size: 42, color: _primary),
                  SizedBox(height: 10),
                  Text(
                    '还没有真实同场记录',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  SizedBox(height: 5),
                  Text(
                    '这里仅显示真实在线训练者与今日到访回声，不会生成虚假用户。',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _quiet),
                  ),
                ],
              ),
            ),
          )
        else ...[
          if (controller.worldActive.isNotEmpty)
            Card(
              child: Column(
                children: [
                  for (final item in controller.worldActive)
                    ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: _primaryContainer,
                        child: Icon(
                          Icons.fitness_center_rounded,
                          color: _primary,
                        ),
                      ),
                      title: Text(
                        '${item['anonymousName'] ?? '匿名训练者'} · Lv.${item['trainingLevel'] ?? 1}',
                      ),
                      subtitle: Text(
                        '${item['trainingFocus'] ?? '训练中'} · ${item['elapsedMinutes'] ?? 0}min',
                      ),
                      trailing: item['self'] == true
                          ? const Text('我', style: TextStyle(color: _quiet))
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (item['allowFistBump'] == true)
                                  IconButton(
                                    tooltip: '碰拳',
                                    onPressed: () => _sendInteraction(
                                      context,
                                      item,
                                      'fist_bump',
                                    ),
                                    icon: const Text('👊'),
                                  ),
                                if (item['allowCheer'] == true)
                                  IconButton(
                                    tooltip: '加油',
                                    onPressed: () => _sendInteraction(
                                      context,
                                      item,
                                      'cheer',
                                    ),
                                    icon: const Text('🔥'),
                                  ),
                                IconButton(
                                  tooltip: '发起挑战',
                                  onPressed: () => _sendInteraction(
                                    context,
                                    item,
                                    'challenge',
                                  ),
                                  icon: const Icon(
                                    Icons.flag_rounded,
                                    color: _primary,
                                  ),
                                ),
                              ],
                            ),
                    ),
                ],
              ),
            ),
          if (controller.worldInteractions.isNotEmpty) ...[
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      '收到的互动',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: [
                        for (final item in controller.worldInteractions)
                          Chip(
                            avatar: Text(switch (item['type']) {
                              'fist_bump' => '👊',
                              'challenge' => '🏁',
                              _ => '🔥',
                            }),
                            label: Text(switch (item['type']) {
                              'fist_bump' => '有人向你碰拳',
                              'challenge' => '收到训练挑战',
                              _ => '有人为你加油',
                            }),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (controller.worldEchoes.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              '今天有 ${controller.worldEchoes.length} 位训练者来过',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 7),
            Card(
              child: Column(
                children: [
                  for (final item in controller.worldEchoes)
                    ListTile(
                      leading: const Icon(
                        Icons.history_rounded,
                        color: _primary,
                      ),
                      title: Text(
                        '${item['anonymousName'] ?? '匿名训练者'} · Lv.${item['trainingLevel'] ?? 1}',
                      ),
                      subtitle: Text(
                        '完成${item['trainingFocus'] ?? '训练'} · ${item['durationMinutes'] ?? 0}min',
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ],
    );
  }

  Future<void> _sendInteraction(
    BuildContext context,
    Map<String, dynamic> item,
    String type,
  ) async {
    final ok = await controller.sendWorldInteraction(
      (item['id'] ?? '').toString(),
      type,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? switch (type) {
                  'fist_bump' => '已碰拳 👊 · 同伴经验 +3',
                  'challenge' => '挑战已发出 · 同伴经验 +3',
                  _ => '已送出加油 🔥 · 同伴经验 +3',
                }
              : '发送失败，请稍后重试',
        ),
      ),
    );
  }
}

class _ExplorationPanel extends StatelessWidget {
  const _ExplorationPanel({required this.controller, required this.quest});
  final AppController controller;
  final DailyQuestState quest;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      DecoratedBox(
        decoration: BoxDecoration(
          color: _ink,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '探索者 Lv.${controller.playerProgress.explorerLevel}',
                style: const TextStyle(
                  color: Color(0xFFFFC5A4),
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                quest.done ? '今日支线已完成' : '找到现实中的${quest.kind}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                quest.done
                    ? '收藏已经保存。明天会出现新的观察任务。'
                    : '选择一张照片并由你确认完成。第一版不宣称 AI 自动验证。',
                style: const TextStyle(color: Color(0xFFDCCBC1)),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: quest.done
                    ? null
                    : () async {
                        final result = await FilePicker.platform.pickFiles(
                          type: FileType.image,
                          allowMultiple: false,
                        );
                        if (result == null || !context.mounted) return;
                        controller.completeDailyQuest();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('支线完成 · 探索 XP +20 · 火花币 +5'),
                          ),
                        );
                      },
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: _ink,
                ),
                icon: Icon(
                  quest.done
                      ? Icons.check_circle_rounded
                      : Icons.add_a_photo_outlined,
                ),
                label: Text(quest.done ? '已收藏' : '选择照片并确认'),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 14),
      const Text(
        '探索收藏',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
      ),
      const SizedBox(height: 8),
      if (controller.playerProgress.collections.isEmpty)
        const Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text('完成第一条支线后，收藏会出现在这里。', style: TextStyle(color: _quiet)),
          ),
        )
      else
        for (final item in controller.playerProgress.collections)
          ListTile(
            leading: const Icon(Icons.auto_awesome_rounded, color: _primary),
            title: Text(item),
          ),
    ],
  );
}

class ProfileGameLayer extends StatelessWidget {
  const ProfileGameLayer({super.key, required this.controller});
  final AppController controller;
  @override
  Widget build(BuildContext context) {
    final progress = controller.playerProgress;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          key: const Key('profile-character-card'),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => showAvatarEditor(context, controller),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  AvatarPreview(progress: progress, size: 88),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '角色与外观',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          '训练者 Lv.${progress.trainingLevel} · 探索者 Lv.${progress.explorerLevel} · 同伴 Lv.${progress.socialLevel}',
                          style: const TextStyle(color: _quiet, fontSize: 12),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${progress.unlockedCosmetics.length} 件外观 · ${progress.sparkCoins} 火花币',
                          style: const TextStyle(
                            color: _primary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  '身体成长',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    for (final group in MuscleGroup.values)
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: _primaryContainer,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 7,
                          ),
                          child: Text(
                            '${group.label} Lv.${progress.muscleLevel(group)}',
                            style: const TextStyle(
                              color: _primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                if (progress.collections.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    '探索收藏 ${progress.collections.length} · 训练成就 ${progress.processedWorkoutIds.length}',
                    style: const TextStyle(color: _quiet, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Card(
          child: Column(
            children: [
              SwitchListTile.adaptive(
                title: const Text('允许同场匿名展示'),
                subtitle: const Text('默认关闭，不上传精确位置'),
                value: progress.showAtVenue,
                onChanged: (value) =>
                    controller.updateWorldPrivacy(showAtVenue: value),
              ),
              const Divider(height: 1),
              SwitchListTile.adaptive(
                title: const Text('允许陌生用户碰拳'),
                value: progress.allowFistBump,
                onChanged: (value) =>
                    controller.updateWorldPrivacy(allowFistBump: value),
              ),
              const Divider(height: 1),
              SwitchListTile.adaptive(
                title: const Text('允许陌生用户加油'),
                value: progress.allowCheer,
                onChanged: (value) =>
                    controller.updateWorldPrivacy(allowCheer: value),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

Future<void> showAvatarEditor(
  BuildContext context,
  AppController controller,
) async {
  var draft = controller.playerProgress.avatar;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        final preview = controller.playerProgress.copyWith(avatar: draft);
        Widget selector(
          String title,
          int value,
          int count,
          void Function(int) update, [
          List<String>? labels,
        ]) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 7,
              children: [
                for (var i = 0; i < count; i++)
                  ChoiceChip(
                    label: Text(labels == null ? '${i + 1}' : labels[i]),
                    selected: value == i,
                    onSelected: (_) => setState(() => update(i)),
                  ),
              ],
            ),
          ],
        );
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: .88,
          minChildSize: .55,
          maxChildSize: .95,
          builder: (context, scrollController) => ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 30),
            children: [
              Center(child: AvatarPreview(progress: preview, size: 180)),
              const SizedBox(height: 16),
              const Text(
                '塑造你的训练角色',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
              ),
              const Text(
                '身体训练痕迹来自真实训练；装扮只影响外观。',
                style: TextStyle(color: _quiet),
              ),
              const SizedBox(height: 18),
              selector(
                '基础角色',
                switch (draft.base) {
                  'power' => 1,
                  'agile' => 2,
                  _ => 0,
                },
                3,
                (v) => draft = draft.copyWith(
                  base: switch (v) {
                    1 => 'power',
                    2 => 'agile',
                    _ => 'athlete',
                  },
                ),
                const ['均衡', '力量', '敏捷'],
              ),
              const SizedBox(height: 14),
              selector(
                '肤色',
                draft.skin,
                4,
                (v) => draft = draft.copyWith(skin: v),
              ),
              const SizedBox(height: 14),
              selector(
                '发型',
                draft.hair,
                4,
                (v) => draft = draft.copyWith(hair: v),
              ),
              const SizedBox(height: 14),
              selector(
                '上衣',
                draft.top,
                4,
                (v) => draft = draft.copyWith(top: v),
              ),
              const SizedBox(height: 14),
              selector(
                '裤子',
                draft.pants,
                3,
                (v) => draft = draft.copyWith(pants: v),
              ),
              const SizedBox(height: 14),
              selector(
                '鞋',
                draft.shoes,
                3,
                (v) => draft = draft.copyWith(shoes: v),
              ),
              const SizedBox(height: 14),
              selector(
                '配饰',
                draft.accessory,
                3,
                (v) => draft = draft.copyWith(accessory: v),
              ),
              const SizedBox(height: 22),
              FilledButton(
                onPressed: () {
                  controller.updateAvatar(draft);
                  Navigator.pop(context);
                },
                child: const Text('保存角色'),
              ),
            ],
          ),
        );
      },
    ),
  );
}

class GameSettlementCard extends StatelessWidget {
  const GameSettlementCard({super.key, required this.settlement});
  final WorkoutGameSettlement settlement;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF2B201B), Color(0xFF63351E)],
      ),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.bolt_rounded, color: Color(0xFFFFB27E)),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  settlement.leveledUp ? '训练者升级' : '本次成长',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                '+${settlement.xp} XP',
                style: const TextStyle(
                  color: Color(0xFFFFB27E),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (settlement.leveledUp)
            Text(
              'Lv.${settlement.previousLevel} → Lv.${settlement.currentLevel}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 27,
                fontWeight: FontWeight.w900,
              ),
            ),
          Text(
            '力量表现 ${settlement.performanceScore} · PR ${settlement.prCount} · 火花币 +${settlement.coins}',
            style: const TextStyle(color: Color(0xFFE7D7CE)),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              for (final entry in settlement.muscleXp.entries)
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .1),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 6,
                    ),
                    child: Text(
                      '${entry.key.label} +${entry.value}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          if (settlement.reward != null) ...[
            const SizedBox(height: 10),
            Text(
              '解锁外观：${settlement.reward}',
              style: const TextStyle(
                color: Color(0xFFFFC5A4),
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

class SetXpFeedback extends StatelessWidget {
  const SetXpFeedback({super.key, required this.label});
  final String? label;
  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      child: label == null
          ? const SizedBox.shrink()
          : DecoratedBox(
              key: ValueKey(label),
              decoration: BoxDecoration(
                color: _ink,
                borderRadius: BorderRadius.circular(999),
                boxShadow: const [
                  BoxShadow(color: Color(0x33000000), blurRadius: 16),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 9,
                ),
                child: Text(
                  label!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
    ),
  );
}
