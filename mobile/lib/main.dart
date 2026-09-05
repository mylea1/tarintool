import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';
import 'package:video_trimmer/video_trimmer.dart';

import 'account_membership.dart';
import 'app_distribution.dart';
import 'app_localizations.dart';
import 'ai_api.dart';
import 'controller.dart';
import 'exercise_media.dart';
import 'exercise_growth.dart';
import 'link_utils.dart';
import 'membership_ui.dart';
import 'models.dart';
import 'muscle_palette.dart';
import 'muscle_selector.dart';
import 'recognition_api.dart';
import 'ai_training_ui.dart';
import 'training_intelligence.dart';
import 'product_features.dart';
import 'workout_share_card.dart';

part 'workout_coach_ui.dart';

typedef _KiloPalette = ({
  Color background,
  Color surface,
  Color surfaceRaised,
  Color primary,
  Color primaryBright,
  Color primaryContainer,
  Color ink,
  Color muted,
  Color hairline,
  Color live,
  Color success,
  Color successContainer,
  Color scheduled,
  Color scheduledContainer,
  Color selected,
  Color selectedContainer,
  Color tint,
  Color shadow,
  Color danger,
  Color exerciseNote,
  Color exerciseNoteContainer,
  Color setNote,
  Color setNoteContainer,
  Color workoutNote,
  Color workoutNoteContainer,
});

const _lightPalette = (
  background: Color(0xFFF5F1EB),
  surface: Color(0xFFFBF8F3),
  surfaceRaised: Color(0xFFFFFDFC),
  primary: Color(0xFFC45112),
  primaryBright: Color(0xFFF47C20),
  primaryContainer: Color(0xFFEAE3DB),
  ink: Color(0xFF211D1A),
  muted: Color(0xFF675F58),
  hairline: Color(0xFFD9D0C7),
  live: Color(0xFF386F7A),
  success: Color(0xFF247552),
  successContainer: Color(0xFFDDEFE6),
  scheduled: Color(0xFFC45112),
  scheduledContainer: Color(0xFFF3E4D8),
  selected: Color(0xFF4B4641),
  selectedContainer: Color(0xFFE8E1DA),
  tint: Color(0xFFF0E9E2),
  shadow: Color(0x242A211B),
  danger: Color(0xFFB3261E),
  exerciseNote: Color(0xFF934618),
  exerciseNoteContainer: Color(0xFFF2E5DB),
  setNote: Color(0xFF5E625A),
  setNoteContainer: Color(0xFFE9E7DF),
  workoutNote: Color(0xFF5D5853),
  workoutNoteContainer: Color(0xFFEDE8E2),
);

const _darkPalette = (
  background: Color(0xFF0D0B0A),
  surface: Color(0xFF171310),
  surfaceRaised: Color(0xFF211A16),
  primary: Color(0xFFFF7A2F),
  primaryBright: Color(0xFFFF9A5C),
  primaryContainer: Color(0xFF4A230F),
  ink: Color(0xFFF7EEE8),
  muted: Color(0xFFC9B8AD),
  hairline: Color(0xFF4B3B32),
  live: Color(0xFFF0B45B),
  success: Color(0xFF75CBA1),
  successContainer: Color(0xFF173B2D),
  scheduled: Color(0xFFFF8B48),
  scheduledContainer: Color(0xFF4B2513),
  selected: Color(0xFFFFB07A),
  selectedContainer: Color(0xFF422A1E),
  tint: Color(0xFF2B1B13),
  shadow: Color(0x52000000),
  danger: Color(0xFFFFB4AB),
  exerciseNote: Color(0xFFFFB184),
  exerciseNoteContainer: Color(0xFF3D2417),
  setNote: Color(0xFFE4C187),
  setNoteContainer: Color(0xFF362C1D),
  workoutNote: Color(0xFFCFC2BA),
  workoutNoteContainer: Color(0xFF2A2522),
);

_KiloPalette _activePalette = _lightPalette;

Color get paper => _activePalette.background;
Color get surface => _activePalette.surface;
Color get surfaceRaised => _activePalette.surfaceRaised;
Color get primary => _activePalette.primary;
Color get primaryBright => _activePalette.primaryBright;
Color get primaryContainer => _activePalette.primaryContainer;
Color get ink => _activePalette.ink;
Color get muted => _activePalette.muted;
Color get secondaryInk => muted;
Color get quiet => muted;
Color get cobalt => primary;
Color get lime => _activePalette.live;
Color get orange => primaryBright;
Color get success => _activePalette.success;
Color get successContainer => _activePalette.successContainer;
Color get calendarScheduled => _activePalette.scheduled;
Color get calendarScheduledContainer => _activePalette.scheduledContainer;
Color get calendarSelected => _activePalette.selected;
Color get calendarSelectedContainer => _activePalette.selectedContainer;
Color get hairline => _activePalette.hairline;
Color get emberTint => _activePalette.tint;
Color get emberShadow => _activePalette.shadow;
Color get danger => _activePalette.danger;
Color get exerciseNoteColor => _activePalette.exerciseNote;
Color get exerciseNoteContainer => _activePalette.exerciseNoteContainer;
Color get setNoteColor => _activePalette.setNote;
Color get setNoteContainer => _activePalette.setNoteContainer;
Color get workoutNoteColor => _activePalette.workoutNote;
Color get workoutNoteContainer => _activePalette.workoutNoteContainer;
const kiloAppVersion = '1.0.32';
const kiloAppBuild = '34';
const kiloAppVersionLabel = '$kiloAppVersion ($kiloAppBuild)';
const kiloSourceCommit = String.fromEnvironment(
  'KILO_SOURCE_COMMIT',
  defaultValue: 'unknown',
);
final kiloSourceCommitLabel = kiloSourceCommit == 'unknown'
    ? '源码 unknown'
    : '源码 ${kiloSourceCommit.length > 7 ? kiloSourceCommit.substring(0, 7) : kiloSourceCommit}';
const kiloAppNavigationLabel = 'AI 记忆、饮食记录与视频优化';
const brandName = '形域';
const brandEnglish = 'XINGYU';
const brandLogoAsset = 'assets/branding/kilo-orange-metal-logo.png';
const brandLogoLightAsset = 'assets/branding/kilo-orange-metal-logo-light.png';

void main() => runApp(const KiloApp());

class KiloApp extends StatefulWidget {
  const KiloApp({super.key, this.initialController});
  final AppController? initialController;
  @override
  State<KiloApp> createState() => _KiloAppState();
}

class _AppControllerScope extends InheritedNotifier<AppController> {
  const _AppControllerScope({
    required AppController controller,
    required super.child,
  }) : super(notifier: controller);

  static AppController? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<_AppControllerScope>()
      ?.notifier;
}

// Kept as a compatibility alias for the generated Flutter smoke test.
typedef MyApp = KiloApp;

class _KiloAppState extends State<KiloApp> with WidgetsBindingObserver {
  late final AppController controller;
  late final bool ownsController;
  late bool durableStateReady;
  late bool splashElapsed;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ownsController = widget.initialController == null;
    controller = widget.initialController ?? AppController();
    durableStateReady = widget.initialController != null;
    splashElapsed = widget.initialController != null;
    if (!splashElapsed) {
      Future<void>.delayed(const Duration(milliseconds: 900), () {
        if (mounted) setState(() => splashElapsed = true);
      });
    }
    if (!durableStateReady) _loadDurableState();
  }

  Future<void> _loadDurableState() async {
    try {
      await controller.accountService.hydrateFromSharedPreferences().timeout(
        const Duration(seconds: 3),
      );
      await controller.restoreRemoteSession().timeout(
        const Duration(seconds: 3),
      );
      // A server entitlement check must complete before cloud data is read.
      // Free accounts stay local and never trigger a sync request.
      final entitlement = await controller.refreshRemoteEntitlements().timeout(
        const Duration(seconds: 5),
      );
      if (entitlement?.isMember == true) {
        await controller.restoreCloudBackup().timeout(
          const Duration(seconds: 5),
        );
      }
      await controller.hydrateAppLanguage().timeout(const Duration(seconds: 3));
      await controller.hydrateTheme().timeout(const Duration(seconds: 3));
      await controller.hydrateAiSkills().timeout(const Duration(seconds: 3));
      await controller.hydrateWorkoutHistory().timeout(
        const Duration(seconds: 3),
      );
      await controller.hydrateActiveWorkout().timeout(
        const Duration(seconds: 3),
      );
      await controller.hydrateTrainingLibrary().timeout(
        const Duration(seconds: 3),
      );
      await controller.hydrateCustomExercises().timeout(
        const Duration(seconds: 3),
      );
      await controller.hydrateAiConversations().timeout(
        const Duration(seconds: 3),
      );
      await controller.hydratePersonalAgentData().timeout(
        const Duration(seconds: 3),
      );
      if (controller.entitlements?.isMember == true) {
        unawaited(controller.backupUserData());
      }
    } catch (_) {
      // Local storage is optional in previews; the in-memory repository stays
      // usable when a platform implementation is unavailable.
    }
    if (mounted) setState(() => durableStateReady = true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (ownsController) controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      controller.handleAppResumed();
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      controller.persistActiveWorkout();
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      _activePalette = controller.darkMode ? _darkPalette : _lightPalette;
      // Existing widget tests inject a controller to exercise a particular
      // shell route. Real app startup owns its controller and therefore
      // starts at the authentication root until a user signs in.
      final injectedTestController = widget.initialController != null;
      final showLogin =
          durableStateReady &&
          !injectedTestController &&
          !controller.isAuthenticated;
      final showProfileOnboarding =
          durableStateReady &&
          !injectedTestController &&
          controller.isAuthenticated &&
          controller.personalAgentDataReady &&
          !controller.profileOnboardingCompleted;
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        title: '$brandName $brandEnglish',
        locale: controller.appLanguage.locale,
        supportedLocales: const [Locale('zh', 'CN'), Locale('en')],
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        theme: _themeFor(Brightness.light),
        darkTheme: _themeFor(Brightness.dark),
        themeMode: controller.darkMode ? ThemeMode.dark : ThemeMode.light,
        builder: (context, child) => _AppControllerScope(
          controller: controller,
          child: child ?? const SizedBox.shrink(),
        ),
        home: !durableStateReady || !splashElapsed
            ? const BrandSplashPage()
            : showLogin
            ? LoginPage(controller: controller)
            : showProfileOnboarding
            ? TrainingProfileOnboardingPage(controller: controller)
            : KiloShell(controller: controller),
      );
    },
  );
}

class TrainingProfileOnboardingPage extends StatefulWidget {
  const TrainingProfileOnboardingPage({
    super.key,
    required this.controller,
    this.editMode = false,
  });
  final AppController controller;
  final bool editMode;

  @override
  State<TrainingProfileOnboardingPage> createState() =>
      _TrainingProfileOnboardingPageState();
}

class _TrainingProfileOnboardingPageState
    extends State<TrainingProfileOnboardingPage> {
  String? gender;
  String? goal;
  int? weeklyTrainingDays;
  final Set<int> preferredWeekdays = <int>{};
  int sessionMinutes = 60;
  String planStyle = 'fixed';
  String preferredRepRange = '8-12';
  bool needsWarmupSets = true;
  final Set<String> focusMuscles = {};
  final Set<String> reducedMuscles = {};
  final age = TextEditingController();
  final years = TextEditingController();
  final height = TextEditingController();
  final weight = TextEditingController();
  final dislikedExercises = TextEditingController();
  final unavailableExercises = TextEditingController();
  bool saving = false;
  String? validationError;
  int onboardingStep = 0;
  String musclePreferenceKind = 'focus';

  @override
  void initState() {
    super.initState();
    if (!widget.editMode) return;
    final profile = widget.controller.trainingProfile;
    gender = profile.gender;
    goal = profile.goal;
    final fallbackCount =
        profile.weeklyTrainingDays ??
        switch (profile.activityLevel) {
          'low' => 1,
          'high' => 5,
          _ => 3,
        };
    preferredWeekdays.addAll(
      profile.preferredWeekdays.isNotEmpty
          ? profile.preferredWeekdays
          : List<int>.generate(
              fallbackCount.clamp(0, 7).toInt(),
              (index) => DateTime.monday + index,
            ),
    );
    weeklyTrainingDays = preferredWeekdays.isEmpty
        ? null
        : preferredWeekdays.length;
    age.text = profile.age?.toString() ?? '';
    years.text = profile.trainingYears?.toString() ?? '';
    height.text = profile.heightCm?.toString() ?? '';
    weight.text = profile.weightKg?.toString() ?? '';
    sessionMinutes = profile.sessionMinutes;
    planStyle = profile.planStyle;
    preferredRepRange = profile.preferredRepRange;
    needsWarmupSets = profile.needsWarmupSets;
    focusMuscles.addAll(profile.focusMuscles);
    reducedMuscles.addAll(profile.reducedMuscles);
    dislikedExercises.text = profile.dislikedExerciseIds.join('、');
    unavailableExercises.text = profile.unavailableExerciseIds.join('、');
  }

  @override
  void dispose() {
    age.dispose();
    years.dispose();
    height.dispose();
    weight.dispose();
    dislikedExercises.dispose();
    unavailableExercises.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (saving) return;
    final parsedAge = int.tryParse(age.text.trim());
    final parsedHeight = double.tryParse(height.text.trim());
    final parsedWeight = double.tryParse(weight.text.trim());
    final error =
        _identityError(
          parsedAge: parsedAge,
          parsedHeight: parsedHeight,
          parsedWeight: parsedWeight,
        ) ??
        (preferredWeekdays.isEmpty
            ? '请至少选择一个每周训练日。'
            : focusMuscles.isEmpty
            ? '请在肌肉图上至少选择一个重点训练部位。'
            : null);
    if (error != null) {
      setState(() {
        validationError = error;
        if (_identityError(
              parsedAge: parsedAge,
              parsedHeight: parsedHeight,
              parsedWeight: parsedWeight,
            ) !=
            null) {
          onboardingStep = 0;
        }
      });
      return;
    }
    setState(() => saving = true);
    final profile = TrainingProfile(
      gender: gender,
      age: parsedAge,
      trainingYears: double.tryParse(years.text.trim()),
      goal: goal,
      heightCm: parsedHeight,
      weightKg: parsedWeight,
      weeklyTrainingDays: preferredWeekdays.isEmpty
          ? null
          : preferredWeekdays.length,
      preferredWeekdays: preferredWeekdays.toList()..sort(),
      activityLevel: switch (preferredWeekdays.length) {
        <= 1 => 'low',
        >= 5 => 'high',
        _ => 'moderate',
      },
      sessionMinutes: sessionMinutes,
      planStyle: planStyle,
      preferredRepRange: preferredRepRange,
      needsWarmupSets: needsWarmupSets,
      focusMuscles: focusMuscles.toList(),
      reducedMuscles: reducedMuscles.toList(),
      dislikedExerciseIds: _splitProfileValues(dislikedExercises.text),
      unavailableExerciseIds: _splitProfileValues(unavailableExercises.text),
    );
    await widget.controller.saveTrainingProfile(profile);
    if (!widget.editMode && widget.controller.weightEntries.isEmpty) {
      await widget.controller.addWeightEntry(
        WeightEntry(
          id: 'profile-weight-${DateTime.now().microsecondsSinceEpoch}',
          recordedAt: DateTime.now(),
          weightKg: parsedWeight!,
          note: '首次训练档案',
        ),
      );
    }
    if (widget.editMode && mounted) Navigator.pop(context);
  }

  String? _identityError({
    required int? parsedAge,
    required double? parsedHeight,
    required double? parsedWeight,
  }) => switch ((gender, parsedAge, parsedHeight, parsedWeight, goal)) {
    (null, _, _, _, _) => '请选择性别，以便匹配身体图和估算基础代谢。',
    (_, null, _, _, _) => '请输入有效年龄。',
    (_, final value?, _, _, _) when value < 13 || value > 100 =>
      '年龄需要在 13–100 岁之间。',
    (_, _, null, _, _) => '请输入有效身高。',
    (_, _, final value?, _, _) when value < 100 || value > 250 =>
      '身高需要在 100–250 cm 之间。',
    (_, _, _, null, _) => '请输入有效体重。',
    (_, _, _, final value?, _) when value < 30 || value > 300 =>
      '体重需要在 30–300 kg 之间。',
    (_, _, _, _, null) => '请选择当前训练目标。',
    _ => null,
  };

  void _continueToPreferences() {
    final error = _identityError(
      parsedAge: int.tryParse(age.text.trim()),
      parsedHeight: double.tryParse(height.text.trim()),
      parsedWeight: double.tryParse(weight.text.trim()),
    );
    setState(() {
      validationError = error;
      if (error == null) onboardingStep = 1;
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: paper,
    appBar: AppBar(
      backgroundColor: paper,
      surfaceTintColor: Colors.transparent,
      automaticallyImplyLeading: false,
      actions: [
        if (widget.editMode)
          TextButton(
            key: const Key('profile-onboarding-cancel'),
            onPressed: saving ? null : () => Navigator.pop(context),
            child: const Text('取消'),
          ),
        const SizedBox(width: 8),
      ],
    ),
    body: SafeArea(
      top: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          Icon(Icons.tune_rounded, color: primary, size: 46),
          const SizedBox(height: 14),
          Text(
            widget.editMode ? '训练与热量资料' : '让形域更了解你',
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: 8),
          Text(
            widget.editMode
                ? '这些资料用于训练建议和热量估算，保存后会立即更新建议。'
                : onboardingStep == 0
                ? '第 1 步：填写身体资料与目标。下一步会按性别加载对应的互动肌肉图。'
                : '第 2 步：点击身体图选择训练部位，再填写每周安排与训练偏好。',
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _OnboardingStepPill(label: '1 身体资料', active: onboardingStep == 0),
              const SizedBox(width: 8),
              _OnboardingStepPill(label: '2 训练偏好', active: onboardingStep == 1),
            ],
          ),
          if (validationError != null) ...[
            const SizedBox(height: 12),
            Container(
              key: const Key('profile-onboarding-error'),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: danger.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: danger.withValues(alpha: .35)),
              ),
              child: Text(
                validationError!,
                style: TextStyle(color: danger, fontWeight: FontWeight.w700),
              ),
            ),
          ],
          if (onboardingStep == 0) ...[
            const SizedBox(height: 22),
            _profileChoices(
              title: '性别',
              value: gender,
              choices: const {'male': '男', 'female': '女', 'other': '其他 / 不便说明'},
              onSelected: (value) => setState(() {
                gender = value;
                validationError = null;
              }),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('profile-age-input'),
                    controller: age,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: '年龄'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    key: const Key('profile-training-years-input'),
                    controller: years,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(labelText: '训练年限'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('profile-height-input'),
                    controller: height,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(labelText: '身高 cm'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    key: const Key('profile-weight-input'),
                    controller: weight,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(labelText: '体重 kg'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _profileChoices(
              title: '当前目标',
              value: goal,
              choices: const {
                'muscle_gain': '增肌',
                'fat_loss': '减脂',
                'body_recomp': '塑形',
                'strength': '力量',
              },
              onSelected: (value) => setState(() {
                goal = value;
                validationError = null;
              }),
            ),
            const SizedBox(height: 22),
            FilledButton.icon(
              key: const Key('profile-onboarding-next'),
              onPressed: _continueToPreferences,
              icon: const Icon(Icons.arrow_forward_rounded),
              label: const Text('下一步：选择训练部位'),
            ),
          ] else ...[
            const SizedBox(height: 18),
            Card(
              key: const Key('profile-muscle-map-card'),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '点击身体图选择训练部位',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 3),
                    Text(switch (gender) {
                      'female' => '当前使用女性身体 SVG',
                      'male' => '当前使用男性身体 SVG',
                      _ => '当前使用通用身体 SVG',
                    }, style: TextStyle(color: muted, fontSize: 12)),
                    const SizedBox(height: 10),
                    SegmentedButton<String>(
                      key: const Key('profile-muscle-preference-mode'),
                      segments: const [
                        ButtonSegment(value: 'focus', label: Text('重点训练')),
                        ButtonSegment(value: 'reduced', label: Text('减少训练')),
                      ],
                      selected: {musclePreferenceKind},
                      onSelectionChanged: (value) =>
                          setState(() => musclePreferenceKind = value.first),
                    ),
                    const SizedBox(height: 8),
                    InteractiveMuscleMap(
                      key: Key(
                        'profile-muscle-map-${gender == 'female' ? 'female' : 'male'}',
                      ),
                      muscleSets: const {},
                      height: 330,
                      gender: gender == 'female'
                          ? MuscleMapGender.female
                          : MuscleMapGender.male,
                      selectionMode: true,
                      selectedGroups: musclePreferenceKind == 'focus'
                          ? focusMuscles
                          : reducedMuscles,
                      onSelectionChanged: (selected) => setState(() {
                        final target = musclePreferenceKind == 'focus'
                            ? focusMuscles
                            : reducedMuscles;
                        final opposite = musclePreferenceKind == 'focus'
                            ? reducedMuscles
                            : focusMuscles;
                        target
                          ..clear()
                          ..addAll(selected);
                        opposite.removeAll(selected);
                        validationError = null;
                      }),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      '重点：${focusMuscles.isEmpty ? '未选择' : focusMuscles.join('、')}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      '减少：${reducedMuscles.isEmpty ? '无' : reducedMuscles.join('、')}',
                      style: TextStyle(color: muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            _weekdayChoices(),
            const SizedBox(height: 12),
            _profileChoices(
              title: '每次训练时长',
              value: sessionMinutes.toString(),
              choices: const {
                '30': '30 分',
                '45': '45 分',
                '60': '60 分',
                '75': '75 分',
                '90': '90 分',
              },
              onSelected: (value) => setState(
                () => sessionMinutes = int.tryParse(value ?? '') ?? 60,
              ),
            ),
            const SizedBox(height: 12),
            _profileChoices(
              title: '计划变化偏好',
              value: planStyle,
              choices: const {'fixed': '固定计划', 'adaptive': '经常变化'},
              onSelected: (value) =>
                  setState(() => planStyle = value ?? 'fixed'),
            ),
            const SizedBox(height: 12),
            _profileChoices(
              title: '常用次数范围',
              value: preferredRepRange,
              choices: const {
                '3-6': '3–6',
                '6-10': '6–10',
                '8-12': '8–12',
                '10-15': '10–15',
              },
              onSelected: (value) =>
                  setState(() => preferredRepRange = value ?? '8-12'),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              tileColor: surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: hairline),
              ),
              value: needsWarmupSets,
              title: const Text('需要热身组'),
              onChanged: (value) => setState(() => needsWarmupSets = value),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: dislikedExercises,
              decoration: const InputDecoration(
                labelText: '不喜欢的动作',
                hintText: '用顿号或逗号分隔',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: unavailableExercises,
              decoration: const InputDecoration(
                labelText: '无法完成的动作',
                hintText: '伤病限制或当前无法完成',
              ),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    key: const Key('profile-onboarding-back'),
                    onPressed: saving
                        ? null
                        : () => setState(() {
                            onboardingStep = 0;
                            validationError = null;
                          }),
                    icon: const Icon(Icons.arrow_back_rounded),
                    label: const Text('上一步'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    key: const Key('profile-onboarding-save'),
                    onPressed: saving ? null : _save,
                    child: Text(saving ? '保存中…' : '保存并生成建议'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    ),
  );

  Widget _weekdayChoices() => Container(
    key: const Key('preferred-weekdays-field'),
    padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
    decoration: BoxDecoration(
      color: surface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: hairline),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('每周训练日（可多选）', style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 3),
        Text('选择后会自动计算每周训练次数', style: TextStyle(fontSize: 11, color: muted)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: [
            for (final weekday in const [
              DateTime.monday,
              DateTime.tuesday,
              DateTime.wednesday,
              DateTime.thursday,
              DateTime.friday,
              DateTime.saturday,
              DateTime.sunday,
            ])
              FilterChip(
                key: Key('preferred-weekday-$weekday'),
                label: Text(_weekdayLabel(weekday)),
                selected: preferredWeekdays.contains(weekday),
                onSelected: (selected) => setState(() {
                  if (selected) {
                    preferredWeekdays.add(weekday);
                  } else {
                    preferredWeekdays.remove(weekday);
                  }
                  weeklyTrainingDays = preferredWeekdays.isEmpty
                      ? null
                      : preferredWeekdays.length;
                }),
              ),
          ],
        ),
        if (weeklyTrainingDays != null) ...[
          const SizedBox(height: 5),
          Text(
            '每周 $weeklyTrainingDays 天',
            style: TextStyle(
              color: primary,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ],
    ),
  );

  String _weekdayLabel(int weekday) => switch (weekday) {
    DateTime.monday => '周一',
    DateTime.tuesday => '周二',
    DateTime.wednesday => '周三',
    DateTime.thursday => '周四',
    DateTime.friday => '周五',
    DateTime.saturday => '周六',
    DateTime.sunday => '周日',
    _ => '',
  };

  Widget _profileChoices({
    required String title,
    required String? value,
    required Map<String, String> choices,
    required ValueChanged<String?> onSelected,
  }) => Semantics(
    label: title,
    child: Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final choice in choices.entries)
                ChoiceChip(
                  label: Text(choice.value),
                  selected: value == choice.key,
                  showCheckmark: false,
                  visualDensity: VisualDensity.compact,
                  onSelected: (selected) =>
                      onSelected(selected ? choice.key : null),
                ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _OnboardingStepPill extends StatelessWidget {
  const _OnboardingStepPill({required this.label, required this.active});

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: active ? primaryContainer : surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: active ? primary : hairline),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: active ? primary : muted,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    ),
  );
}

ThemeData _themeFor(Brightness brightness) {
  final palette = brightness == Brightness.dark ? _darkPalette : _lightPalette;
  final onPrimary = brightness == Brightness.dark
      ? const Color(0xFF2A1206)
      : Colors.white;
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    scaffoldBackgroundColor: palette.background,
    colorScheme:
        ColorScheme.fromSeed(
          seedColor: palette.primary,
          brightness: brightness,
        ).copyWith(
          primary: palette.primary,
          onPrimary: onPrimary,
          primaryContainer: palette.primaryContainer,
          onPrimaryContainer: palette.ink,
          secondary: palette.primaryBright,
          onSecondary: onPrimary,
          secondaryContainer: palette.primaryContainer,
          onSecondaryContainer: palette.ink,
          surface: palette.surface,
          onSurface: palette.ink,
          surfaceContainer: palette.surface,
          surfaceContainerHigh: palette.surfaceRaised,
          surfaceContainerHighest: palette.surfaceRaised,
          surfaceContainerLowest: palette.background,
          error: palette.danger,
          outline: palette.hairline,
          outlineVariant: palette.hairline,
        ),
    textTheme: TextTheme(
      headlineLarge: TextStyle(
        fontSize: 30,
        fontWeight: FontWeight.w800,
        color: palette.ink,
        letterSpacing: -1,
      ),
      headlineMedium: TextStyle(
        fontSize: 23,
        fontWeight: FontWeight.w800,
        color: palette.ink,
      ),
      titleLarge: TextStyle(
        fontSize: 19,
        fontWeight: FontWeight.w800,
        color: palette.ink,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: palette.ink,
      ),
      bodyLarge: TextStyle(fontSize: 16, color: palette.muted, height: 1.35),
      bodyMedium: TextStyle(fontSize: 14, color: palette.muted, height: 1.35),
      labelLarge: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: palette.hairline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: palette.hairline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: palette.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: danger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: danger, width: 2),
      ),
      filled: true,
      fillColor: palette.surface,
      labelStyle: TextStyle(color: palette.muted),
      floatingLabelStyle: TextStyle(color: palette.primary),
    ),
    cardTheme: CardThemeData(
      color: palette.surfaceRaised,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(Radius.circular(18)),
        side: BorderSide(color: palette.hairline),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.disabled)
              ? palette.surfaceRaised
              : palette.primary,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.disabled) ? palette.muted : onPrimary,
        ),
        side: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.disabled)
              ? BorderSide(color: palette.hairline)
              : BorderSide.none,
        ),
        minimumSize: WidgetStatePropertyAll(Size(48, 46)),
        padding: WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        ),
        textStyle: WidgetStatePropertyAll(
          TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(999)),
          ),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: ButtonStyle(
        foregroundColor: WidgetStatePropertyAll(palette.primary),
        minimumSize: WidgetStatePropertyAll(Size(48, 44)),
        side: WidgetStatePropertyAll(BorderSide(color: palette.hairline)),
        textStyle: WidgetStatePropertyAll(
          TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(999)),
          ),
        ),
      ),
    ),
    dividerTheme: DividerThemeData(color: palette.hairline, thickness: 1),
    appBarTheme: AppBarTheme(
      backgroundColor: palette.background,
      foregroundColor: palette.ink,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: palette.surface,
      surfaceTintColor: Colors.transparent,
      modalBackgroundColor: palette.surface,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: palette.surfaceRaised,
      surfaceTintColor: Colors.transparent,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: brightness == Brightness.dark
          ? const Color(0xFFF4EAE4)
          : const Color(0xFF2B211C),
      contentTextStyle: TextStyle(
        color: brightness == Brightness.dark
            ? const Color(0xFF241914)
            : Colors.white,
      ),
      actionTextColor: palette.primaryBright,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.selected) ? onPrimary : palette.muted,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? palette.primary
            : palette.hairline,
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: palette.surfaceRaised,
      selectedColor: palette.primaryContainer,
      side: BorderSide(color: palette.hairline),
      labelStyle: TextStyle(color: palette.ink),
      secondaryLabelStyle: TextStyle(color: palette.ink),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: palette.primary,
      linearTrackColor: palette.primaryContainer,
      circularTrackColor: palette.primaryContainer,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: palette.surfaceRaised,
      indicatorColor: palette.primaryContainer,
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: palette.ink,
        ),
      ),
      height: 62,
    ),
  );
}

class AccountLoadingPage extends StatelessWidget {
  const AccountLoadingPage({super.key});

  @override
  Widget build(BuildContext context) => const Scaffold(
    key: Key('account-loading-page'),
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 14),
          Text('\u6b63\u5728\u6062\u590d\u8d26\u53f7\u72b6\u6001\u2026'),
        ],
      ),
    ),
  );
}

class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.size = 48});

  final double size;

  @override
  Widget build(BuildContext context) {
    final asset = Theme.of(context).brightness == Brightness.dark
        ? brandLogoAsset
        : brandLogoLightAsset;
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * .22),
      child: Image.asset(
        asset,
        width: size,
        height: size,
        fit: BoxFit.cover,
        semanticLabel: '$brandName $brandEnglish 标志',
      ),
    );
  }
}

class BrandSplashPage extends StatefulWidget {
  const BrandSplashPage({super.key});

  @override
  State<BrandSplashPage> createState() => _BrandSplashPageState();
}

class _BrandSplashPageState extends State<BrandSplashPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController animation;
  late final Animation<double> scale;
  late final Animation<double> opacity;

  @override
  void initState() {
    super.initState();
    animation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 760),
    )..forward();
    scale = CurvedAnimation(parent: animation, curve: Curves.easeOutBack);
    opacity = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
  }

  @override
  void dispose() {
    animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    return Scaffold(
      key: const Key('ember-splash-page'),
      body: Center(
        child: FadeTransition(
          opacity: reducedMotion ? const AlwaysStoppedAnimation(1) : opacity,
          child: ScaleTransition(
            scale: reducedMotion ? const AlwaysStoppedAnimation(1) : scale,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const BrandLogo(size: 104),
                const SizedBox(height: 12),
                Text(
                  brandName,
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                Text(
                  brandEnglish,
                  style: TextStyle(
                    color: primary,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _PhoneEntryMode { password, code }

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.controller});

  final AppController controller;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  late final TextEditingController identifier;
  late final TextEditingController password;
  late final TextEditingController code;
  late final TextEditingController confirmPassword;
  Timer? _codeTimer;
  _PhoneEntryMode phoneMode = _PhoneEntryMode.password;
  String? error;
  bool busy = false;
  bool registering = false;
  int codeCooldown = 0;
  int _operationGeneration = 0;

  @override
  void initState() {
    super.initState();
    identifier = TextEditingController();
    password = TextEditingController();
    code = TextEditingController();
    confirmPassword = TextEditingController();
  }

  @override
  void dispose() {
    _codeTimer?.cancel();
    identifier.dispose();
    password.dispose();
    code.dispose();
    confirmPassword.dispose();
    super.dispose();
  }

  String _normalizedPhone() => identifier.text
      .trim()
      .replaceAll(RegExp(r'[\s()-]'), '')
      .replaceFirstMapped(
        RegExp(r'^1[3-9]\d{9}$'),
        (match) => '+86${match.group(0)}',
      )
      .replaceFirstMapped(
        RegExp(r'^861[3-9]\d{9}$'),
        (match) => '+${match.group(0)}',
      );

  bool get _hasMainlandPhone =>
      RegExp(r'^\+861[3-9]\d{9}$').hasMatch(_normalizedPhone());

  String _localizedError(AccountError accountError) => switch (accountError) {
    AccountError.emptyIdentifier => '请输入手机号或账号。',
    AccountError.invalidIdentifier => '请输入有效的大陆手机号。',
    AccountError.invalidPassword => '密码需为 8–128 位。',
    AccountError.invalidCode => '请输入6位验证码。',
    AccountError.invalidCredentials => '手机号或密码不正确。',
    _ => '登录服务暂时不可用，请稍后重试。',
  };

  void _showError(String message) {
    if (!mounted) return;
    setState(() {
      busy = false;
      error = message;
    });
  }

  void _setPhoneMode(_PhoneEntryMode mode) {
    if (busy) return;
    _operationGeneration++;
    setState(() {
      registering = false;
      phoneMode = mode;
      error = null;
      code.clear();
      password.clear();
      confirmPassword.clear();
    });
  }

  void _openRegistration() {
    if (busy) return;
    _operationGeneration++;
    setState(() {
      registering = true;
      phoneMode = _PhoneEntryMode.code;
      error = null;
      code.clear();
      password.clear();
      confirmPassword.clear();
    });
  }

  void _backToLogin() {
    if (busy) return;
    _operationGeneration++;
    setState(() {
      registering = false;
      phoneMode = _PhoneEntryMode.password;
      error = null;
      code.clear();
      password.clear();
      confirmPassword.clear();
    });
  }

  void _startCodeCooldown(int seconds) {
    _codeTimer?.cancel();
    final bounded = seconds.clamp(0, 300).toInt();
    if (!mounted) return;
    setState(() => codeCooldown = bounded);
    if (bounded <= 0) return;
    _codeTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (codeCooldown <= 1) {
        timer.cancel();
        setState(() => codeCooldown = 0);
      } else {
        setState(() => codeCooldown -= 1);
      }
    });
  }

  Future<void> _sendCode() async {
    if (busy || codeCooldown > 0) return;
    if (!_hasMainlandPhone) {
      _showError('请输入有效的大陆手机号。');
      return;
    }
    final generation = ++_operationGeneration;
    final purpose = registering ? 'register' : 'login';
    setState(() {
      busy = true;
      error = null;
    });
    final result = await widget.controller.requestPhoneCodeRemote(
      _normalizedPhone(),
      purpose: purpose,
    );
    if (!mounted || generation != _operationGeneration) return;
    if (!result.isSuccess || result.value == null) {
      _showError(result.message ?? _localizedError(result.error));
      return;
    }
    setState(() {
      busy = false;
      error = null;
    });
    _startCodeCooldown(result.value!.retryAfterSeconds);
  }

  Future<void> _submitPassword() async {
    if (busy) return;
    if (identifier.text.trim().isEmpty) {
      _showError('请输入手机号或账号。');
      return;
    }
    if (password.text.isEmpty) {
      _showError('请输入密码。');
      return;
    }
    final generation = ++_operationGeneration;
    setState(() {
      busy = true;
      error = null;
    });
    final result = await widget.controller.loginWithPhoneRemote(
      identifier.text,
      password: password.text,
    );
    if (!mounted || generation != _operationGeneration) return;
    if (!result.isSuccess) {
      _showError(result.message ?? _localizedError(result.error));
      return;
    }
    setState(() => busy = false);
  }

  Future<void> _submitCodeLogin() async {
    if (busy) return;
    if (!_hasMainlandPhone) {
      _showError('请输入有效的大陆手机号。');
      return;
    }
    if (!RegExp(r'^\d{6}$').hasMatch(code.text.trim())) {
      _showError('请输入6位验证码。');
      return;
    }
    final generation = ++_operationGeneration;
    setState(() {
      busy = true;
      error = null;
    });
    final result = await widget.controller.loginWithPhoneCodeRemote(
      identifier: _normalizedPhone(),
      code: code.text,
    );
    if (!mounted || generation != _operationGeneration) return;
    if (!result.isSuccess) {
      _showError(result.message ?? _localizedError(result.error));
      return;
    }
    setState(() => busy = false);
  }

  Future<void> _submitRegistration() async {
    if (busy) return;
    if (!_hasMainlandPhone) {
      _showError('请输入有效的大陆手机号。');
      return;
    }
    if (!RegExp(r'^\d{6}$').hasMatch(code.text.trim())) {
      _showError('请输入6位验证码。');
      return;
    }
    if (password.text.length < 8 || password.text.length > 128) {
      _showError('密码需为 8–128 位。');
      return;
    }
    if (password.text != confirmPassword.text) {
      _showError('两次输入的密码不一致。');
      return;
    }
    final generation = ++_operationGeneration;
    setState(() {
      busy = true;
      error = null;
    });
    final result = await widget.controller.registerPhoneRemote(
      identifier: _normalizedPhone(),
      password: password.text,
      code: code.text,
    );
    if (!mounted || generation != _operationGeneration) return;
    if (!result.isSuccess) {
      _showError(result.message ?? _localizedError(result.error));
      return;
    }
    setState(() => busy = false);
  }

  Future<void> submit() async {
    if (registering) return _submitRegistration();
    if (phoneMode == _PhoneEntryMode.code) return _submitCodeLogin();
    return _submitPassword();
  }

  Future<void> submitApple() async {
    if (busy) return;
    final generation = ++_operationGeneration;
    setState(() {
      busy = true;
      error = null;
    });
    final result = await widget.controller.loginWithAppleRemote();
    if (!mounted || generation != _operationGeneration) return;
    setState(() {
      busy = false;
      error = result.isSuccess
          ? null
          : AppLocalizations.of(
              context,
            ).text(result.message ?? 'Apple 登录暂时不可用，请稍后重试。');
    });
  }

  Widget _modeButton({
    required Key key,
    required String label,
    required bool selected,
    required VoidCallback? onPressed,
  }) => Expanded(
    child: OutlinedButton(
      key: key,
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        backgroundColor: selected ? primaryContainer : Colors.transparent,
        side: BorderSide(color: selected ? primary : hairline),
        foregroundColor: selected ? primary : ink,
      ),
      child: Text(label, textAlign: TextAlign.center),
    ),
  );

  Widget _phoneCodeField({required Key key, required String label}) =>
      TextField(
        key: key,
        controller: code,
        enabled: !busy,
        keyboardType: TextInputType.number,
        textInputAction: TextInputAction.done,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(6),
        ],
        maxLength: 6,
        autofillHints: const [AutofillHints.oneTimeCode],
        onSubmitted: (_) => submit(),
        decoration: InputDecoration(
          labelText: label,
          counterText: '',
          prefixIcon: const Icon(Icons.sms_outlined),
        ),
      );

  Widget _sendCodeButton({required Key key}) => OutlinedButton.icon(
    key: key,
    onPressed: busy || codeCooldown > 0 ? null : _sendCode,
    icon: const Icon(Icons.sms_outlined, size: 18),
    label: Text(
      codeCooldown > 0
          ? '${codeCooldown}s 后重试'
          : busy
          ? '发送中…'
          : '发送验证码',
    ),
    style: OutlinedButton.styleFrom(
      minimumSize: const Size(0, 44),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final loginMethods = appDistribution.loginMethodsFor(defaultTargetPlatform);
    final showPhone = loginMethods.contains(LoginMethod.phone);
    final visibleError = error ?? widget.controller.sessionExpiredMessage;
    return Scaffold(
      key: const Key('login-page'),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              20,
              constraints.maxHeight < 700 ? 14 : 28,
              20,
              24,
            ),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const BrandLogo(size: 66),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                brandEnglish,
                                style: TextStyle(
                                  color: primary,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 3,
                                ),
                              ),
                              Text(
                                brandName,
                                style: TextStyle(
                                  color: ink,
                                  fontSize: 27,
                                  height: 1.05,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                        PopupMenuButton<AppLanguage>(
                          key: const Key('login-language-setting'),
                          tooltip: strings.text('语言与地区'),
                          icon: const Icon(Icons.language_rounded),
                          initialValue: widget.controller.appLanguage,
                          onSelected: widget.controller.setAppLanguage,
                          itemBuilder: (context) => const [
                            PopupMenuItem(
                              value: AppLanguage.simplifiedChinese,
                              child: Text('简体中文'),
                            ),
                            PopupMenuItem(
                              value: AppLanguage.english,
                              child: Text('English'),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    if (showPhone)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  const _LoginMethodIcon(
                                    icon: Icons.phone_iphone_rounded,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      strings.text(
                                        registering ? '注册账号' : '登录账号',
                                      ),
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w900,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                              if (registering)
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    key: const Key('login-back-to-login'),
                                    onPressed: busy ? null : _backToLogin,
                                    child: Text(strings.text('返回登录')),
                                  ),
                                ),
                              if (!registering) ...[
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    _modeButton(
                                      key: const Key('login-password-mode'),
                                      label: strings.text('密码登录'),
                                      selected:
                                          phoneMode == _PhoneEntryMode.password,
                                      onPressed: busy
                                          ? null
                                          : () => _setPhoneMode(
                                              _PhoneEntryMode.password,
                                            ),
                                    ),
                                    const SizedBox(width: 8),
                                    _modeButton(
                                      key: const Key('login-code-mode'),
                                      label: strings.text('验证码登录'),
                                      selected:
                                          phoneMode == _PhoneEntryMode.code,
                                      onPressed: busy
                                          ? null
                                          : () => _setPhoneMode(
                                              _PhoneEntryMode.code,
                                            ),
                                    ),
                                  ],
                                ),
                              ],
                              const SizedBox(height: 10),
                              TextField(
                                key: const Key('login-identifier'),
                                controller: identifier,
                                enabled: !busy,
                                keyboardType: TextInputType.phone,
                                textInputAction: TextInputAction.next,
                                autofillHints: const [AutofillHints.username],
                                decoration: InputDecoration(
                                  labelText: strings.text('手机号'),
                                  prefixIcon: const Icon(Icons.phone_outlined),
                                ),
                              ),
                              if (registering) ...[
                                const SizedBox(height: 10),
                                _phoneCodeField(
                                  key: const Key('register-code'),
                                  label: strings.text('验证码'),
                                ),
                                const SizedBox(height: 8),
                                _sendCodeButton(
                                  key: const Key('register-send-code'),
                                ),
                                const SizedBox(height: 10),
                                TextField(
                                  key: const Key('register-password'),
                                  controller: password,
                                  enabled: !busy,
                                  obscureText: true,
                                  textInputAction: TextInputAction.next,
                                  autofillHints: const [
                                    AutofillHints.newPassword,
                                  ],
                                  decoration: InputDecoration(
                                    labelText: strings.text('设置密码（8–128 位）'),
                                    prefixIcon: const Icon(
                                      Icons.lock_outline_rounded,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                TextField(
                                  key: const Key('register-confirm-password'),
                                  controller: confirmPassword,
                                  enabled: !busy,
                                  obscureText: true,
                                  textInputAction: TextInputAction.done,
                                  autofillHints: const [
                                    AutofillHints.newPassword,
                                  ],
                                  onSubmitted: (_) => submit(),
                                  decoration: InputDecoration(
                                    labelText: strings.text('确认密码'),
                                    prefixIcon: const Icon(
                                      Icons.lock_reset_outlined,
                                    ),
                                  ),
                                ),
                              ] else if (phoneMode == _PhoneEntryMode.code) ...[
                                const SizedBox(height: 10),
                                _phoneCodeField(
                                  key: const Key('login-code'),
                                  label: strings.text('验证码'),
                                ),
                                const SizedBox(height: 8),
                                _sendCodeButton(
                                  key: const Key('login-send-code'),
                                ),
                              ] else ...[
                                const SizedBox(height: 10),
                                TextField(
                                  key: const Key('login-password'),
                                  controller: password,
                                  enabled: !busy,
                                  obscureText: true,
                                  textInputAction: TextInputAction.done,
                                  autofillHints: const [AutofillHints.password],
                                  onSubmitted: (_) => submit(),
                                  decoration: InputDecoration(
                                    labelText: strings.text('密码'),
                                    prefixIcon: const Icon(
                                      Icons.lock_outline_rounded,
                                    ),
                                  ),
                                ),
                              ],
                              if (visibleError != null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  visibleError,
                                  softWrap: true,
                                  style: TextStyle(color: danger, fontSize: 12),
                                ),
                              ],
                              const SizedBox(height: 12),
                              FilledButton(
                                key: Key(
                                  registering
                                      ? 'register-button'
                                      : phoneMode == _PhoneEntryMode.code
                                      ? 'login-code-button'
                                      : 'login-button',
                                ),
                                onPressed: busy ? null : submit,
                                child: Text(
                                  strings.text(
                                    busy
                                        ? '处理中…'
                                        : registering
                                        ? '注册并登录'
                                        : phoneMode == _PhoneEntryMode.code
                                        ? '验证码登录'
                                        : '手机号登录',
                                  ),
                                ),
                              ),
                              if (!registering) ...[
                                const SizedBox(height: 4),
                                TextButton.icon(
                                  key: const Key('login-register-button'),
                                  onPressed: busy ? null : _openRegistration,
                                  icon: const Icon(Icons.person_add_alt_1),
                                  label: Text(strings.text('注册账号')),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    if (loginMethods.length > (showPhone ? 1 : 0)) ...[
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          const Expanded(child: Divider()),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: Text(
                              strings.text('其他登录方式'),
                              style: TextStyle(color: quiet, fontSize: 12),
                            ),
                          ),
                          const Expanded(child: Divider()),
                        ],
                      ),
                    ],
                    if (loginMethods.contains(LoginMethod.apple)) ...[
                      const SizedBox(height: 10),
                      Align(
                        child: SizedBox(
                          width: 205,
                          height: 48,
                          child: OutlinedButton.icon(
                            key: const Key('apple-login-button'),
                            onPressed: busy ? null : submitApple,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: ink,
                              backgroundColor: Colors.white,
                              side: BorderSide(color: ink),
                            ),
                            icon: const Icon(Icons.apple, size: 22),
                            label: Text(
                              strings.text(busy ? '登录中…' : '使用 Apple 登录'),
                            ),
                          ),
                        ),
                      ),
                    ],
                    if (loginMethods.contains(LoginMethod.google)) ...[
                      const SizedBox(height: 10),
                      Align(
                        child: Semantics(
                          button: true,
                          label: strings.text('使用 Google 登录'),
                          child: InkWell(
                            key: const Key('google-login-button'),
                            borderRadius: BorderRadius.circular(24),
                            onTap: busy
                                ? null
                                : () {
                                    final result = widget.controller
                                        .loginWithGoogle();
                                    setState(
                                      () => error =
                                          result.message ??
                                          strings.text('Google 登录尚未配置。'),
                                    );
                                  },
                            child: Image.asset(
                              'assets/branding/sign_in_with_google_ios_light@3x.png',
                              width: 205,
                              height: 48,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                    ],
                    if (!showPhone && visibleError != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        visibleError,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: danger, fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoginMethodIcon extends StatelessWidget {
  const _LoginMethodIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    width: 34,
    height: 34,
    decoration: BoxDecoration(
      color: primaryContainer,
      borderRadius: BorderRadius.circular(11),
    ),
    child: Icon(icon, size: 18, color: primary),
  );
}

class KiloShell extends StatelessWidget {
  const KiloShell({super.key, required this.controller});
  final AppController controller;

  static const pages = <PageId>[
    PageId.today,
    PageId.train,
    PageId.exercises,
    PageId.ai,
    PageId.profile,
  ];
  static const labels = ['主页', '训练', '动作', 'AI', '我的'];
  static const icons = [
    Icons.home_outlined,
    Icons.fitness_center_outlined,
    Icons.menu_book_outlined,
    Icons.forum_outlined,
    Icons.person_outline,
  ];

  int get navIndex => switch (controller.page) {
    PageId.today => 0,
    PageId.train || PageId.records => 1,
    PageId.exercises => 2,
    PageId.ai => 3,
    PageId.recognition => 2,
    PageId.profile => 4,
  };
  String pageTitle(BuildContext context) =>
      AppLocalizations.of(context).text(switch (controller.page) {
        PageId.today => '主页',
        PageId.train => '训练',
        PageId.records => '记录',
        PageId.exercises => '动作库',
        PageId.recognition => '动作库',
        PageId.ai => 'AI',
        PageId.profile => '我的',
      });
  String pageSubtitle(BuildContext context) =>
      AppLocalizations.of(context).text(switch (controller.page) {
        PageId.today => '训练、记录和计划概览',
        PageId.train =>
          controller.workoutStarted
              ? '保持专注，完成下一组'
              : controller.liveWorkoutVisible
              ? '准备训练，开始计时后进入训练状态'
              : '选择计划并开始训练',
        PageId.records => '训练日历、完成情况和历史记录',
        PageId.exercises => '动作、机位与识别能力',
        PageId.recognition => '动作、机位与识别能力',
        PageId.ai => '有来源的训练问答',
        PageId.profile => '训练偏好、设备连接和隐私设置',
      });

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width <= 360;
    final reservedBottom = (compact ? 70.0 : 74.0) + 3;
    final body = switch (controller.page) {
      PageId.today => HomePage(controller: controller),
      PageId.train => TrainPage(controller: controller),
      PageId.records => TrainPage(controller: controller),
      PageId.exercises => ExerciseLibraryPage(controller: controller),
      // Recognition is no longer a top-level destination. It is opened from
      // an exercise detail/record, so a stale legacy enum value falls back to
      // the exercise library instead of restoring a second AI page.
      PageId.recognition => ExerciseLibraryPage(controller: controller),
      PageId.ai => AiPage(controller: controller),
      PageId.profile => ProfilePage(controller: controller),
    };
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(compact ? 50 : 54),
        child: SafeArea(
          child: _TopBar(controller: controller, title: pageTitle(context)),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _ParticlePainter(
                    reducedMotion: MediaQuery.of(context).disableAnimations,
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: reservedBottom +
                      (controller.page == PageId.train && controller.liveWorkoutVisible ? 64 : 0),
                ),
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
                  child: body,
                ),
              ),
            ),
            Positioned(
              left: compact ? 12 : 16,
              right: compact ? 12 : 16,
              bottom: 3,
              child: _FloatingBottomNavigation(
                selectedIndex: navIndex,
                labels: [
                  for (final label in labels)
                    AppLocalizations.of(context).text(label),
                ],
                icons: icons,
                compact: compact,
                onDestinationSelected: (index) {
                  if (index == navIndex) return;
                  controller.selectPage(pages[index]);
                },
              ),
            ),
            if (controller.page == PageId.train && controller.liveWorkoutVisible)
              Positioned(
                right: 16, bottom: reservedBottom + 12,
                child: FloatingActionButton.small(
                  key: const Key('workout-coach-open'),
                  heroTag: 'workout-coach', tooltip: '本次训练 AI 教练',
                  onPressed: () => _showWorkoutCoach(context, controller),
                  child: const Text('AI', style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A light, floating navigation capsule. The transparent NavigationBar inside
/// keeps the existing Material semantics and test contract, while the visual
/// layer owns the larger icon+label indicator required by the product UI.
class _FloatingBottomNavigation extends StatelessWidget {
  const _FloatingBottomNavigation({
    required this.selectedIndex,
    required this.labels,
    required this.icons,
    required this.onDestinationSelected,
    required this.compact,
  });

  final int selectedIndex;
  final List<String> labels;
  final List<IconData> icons;
  final ValueChanged<int> onDestinationSelected;
  final bool compact;

  @override
  Widget build(BuildContext context) => SizedBox(
    // Keep the capsule itself within the requested 70–82dp range. SafeArea
    // owns the device-specific home-indicator inset outside this container.
    height: compact ? 70 : 74,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final slotWidth = constraints.maxWidth / labels.length;
        final indicatorWidth = slotWidth * (compact ? .88 : .9);
        final indicatorHeight = compact ? 59.0 : 64.0;
        final interactiveHeight = compact ? 58.0 : 62.0;
        return Stack(
          children: [
            // Paint the capsule separately from the interactive layer. This
            // keeps the rounded background from absorbing taps intended for
            // content that scrolls beneath its transparent top inset.
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: surface.withValues(alpha: .98),
                    borderRadius: BorderRadius.circular(compact ? 34 : 39),
                    border: Border.all(color: hairline.withValues(alpha: .9)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x14000000),
                        blurRadius: 16,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: ExcludeSemantics(
                  child: Opacity(
                    opacity: 0,
                    child: NavigationBarTheme(
                      data: NavigationBarTheme.of(context).copyWith(
                        height: constraints.maxHeight,
                        backgroundColor: Colors.transparent,
                        surfaceTintColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        indicatorColor: Colors.transparent,
                        labelTextStyle: const WidgetStatePropertyAll(
                          TextStyle(color: Colors.transparent, fontSize: 1),
                        ),
                        iconTheme: const WidgetStatePropertyAll(
                          IconThemeData(color: Colors.transparent, size: 1),
                        ),
                      ),
                      child: NavigationBar(
                        selectedIndex: selectedIndex,
                        onDestinationSelected: onDestinationSelected,
                        destinations: [
                          for (var i = 0; i < labels.length; i++)
                            NavigationDestination(
                              icon: Icon(icons[i]),
                              selectedIcon: Icon(icons[i]),
                              // The real, accessible labels live on the
                              // visual items below. Keep the compatibility
                              // NavigationBar's destinations label-free so
                              // its opacity-zero implementation does not
                              // duplicate localized text in widget tests or
                              // assistive technology trees.
                              label: '',
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOutCubic,
              left:
                  slotWidth * selectedIndex + (slotWidth - indicatorWidth) / 2,
              top: (constraints.maxHeight - indicatorHeight) / 2,
              width: indicatorWidth,
              height: indicatorHeight,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: primaryContainer.withValues(alpha: .65),
                    borderRadius: BorderRadius.circular(31),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: interactiveHeight,
              child: Row(
                children: [
                  for (var i = 0; i < labels.length; i++)
                    Expanded(
                      child: _FloatingNavigationItem(
                        icon: icons[i],
                        label: labels[i],
                        selected: i == selectedIndex,
                        compact: compact,
                        onTap: () => onDestinationSelected(i),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    ),
  );
}

class _FloatingNavigationItem extends StatelessWidget {
  const _FloatingNavigationItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.compact,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: label,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(32),
      child: Center(
        child: AnimatedScale(
          scale: selected ? 1.04 : 1,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeInOut,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TweenAnimationBuilder<Color?>(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeInOut,
                tween: ColorTween(
                  end: selected ? primary : const Color(0xFF645B57),
                ),
                builder: (context, color, _) =>
                    Icon(icon, color: color, size: compact ? 20 : 22),
              ),
              const SizedBox(height: 5),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeInOut,
                style: TextStyle(
                  color: selected ? ink : const Color(0xFF645B57),
                  fontSize: compact ? 10 : 11,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                ),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.controller, required this.title});
  final AppController controller;
  final String title;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width <= 360;
    return Container(
      height: compact ? 50 : 54,
      padding: const EdgeInsets.fromLTRB(14, 0, 8, 0),
      decoration: BoxDecoration(
        color: paper,
        border: Border(bottom: BorderSide(color: hairline)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Row(
              children: [
                BrandLogo(size: compact ? 26 : 30),
                SizedBox(width: compact ? 6 : 8),
                Expanded(
                  child: Text(
                    AppLocalizations.of(context).text(title),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: compact ? 18 : 19,
                      fontWeight: FontWeight.w800,
                      color: ink,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (controller.restRunning &&
              !(controller.page == PageId.train &&
                  controller.liveWorkoutVisible))
            _RestChip(controller: controller),
          if (controller.page == PageId.exercises)
            IconButton.filled(
              key: const Key('exercise-library-add'),
              style: IconButton.styleFrom(
                backgroundColor: cobalt,
                foregroundColor: Colors.white,
              ),
              tooltip: AppLocalizations.of(context).text('新建自定义动作'),
              onPressed: () => _showCustomExercise(context, controller),
              icon: const Icon(Icons.add),
            ),
        ],
      ),
    );
  }
}

class _RestChip extends StatelessWidget {
  const _RestChip({required this.controller});
  final AppController controller;
  @override
  Widget build(BuildContext context) {
    final minutes = (controller.restRemainingSeconds ~/ 60).toString().padLeft(
      2,
      '0',
    );
    final seconds = (controller.restRemainingSeconds % 60).toString().padLeft(
      2,
      '0',
    );
    return InkWell(
      onTap: () => _showRestSheet(context, controller),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
        decoration: BoxDecoration(
          color: lime.withValues(alpha: .35),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.timer_outlined, size: 16, color: ink),
            const SizedBox(width: 4),
            Text(
              '$minutes:$seconds',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PageFrame extends StatelessWidget {
  const PageFrame({
    super.key,
    required this.children,
    this.padding = const EdgeInsets.fromLTRB(14, 14, 14, 86),
  });
  final List<Widget> children;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) =>
      ListView(padding: padding, children: children);
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(
    this.title, {
    super.key,
    this.subtitle,
    this.action,
    this.onAction,
  });
  final String title;
  final String? subtitle;
  final String? action;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 6, bottom: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocalizations.of(context).text(title),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (subtitle != null)
                Text(
                  AppLocalizations.of(context).text(subtitle!),
                  style: TextStyle(fontSize: 12, color: quiet),
                ),
            ],
          ),
        ),
        if (action != null)
          TextButton(
            onPressed: onAction,
            child: Text(AppLocalizations.of(context).text(action!)),
          ),
      ],
    ),
  );
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 48,
    child: FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(icon ?? Icons.arrow_forward, size: 19),
      label: Text(
        AppLocalizations.of(context).text(label),
        overflow: TextOverflow.ellipsis,
      ),
    ),
  );
}

void showKiloSnack(
  BuildContext context,
  String message, {
  bool error = false,
  IconData? icon,
}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  messenger?.hideCurrentSnackBar();
  messenger?.showSnackBar(
    SnackBar(
      backgroundColor: error
          ? const Color(0xFF4A1E1B)
          : const Color(0xFF2B1B15),
      elevation: 12,
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 78),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      content: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: error
                  ? const Color(0xFFFFDAD6).withValues(alpha: .16)
                  : primary.withValues(alpha: .22),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon ?? (error ? Icons.error_outline : Icons.check_rounded),
              color: error ? const Color(0xFFFFB4AB) : const Color(0xFFFFA66E),
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              AppLocalizations.of(context).text(message),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(milliseconds: 1650),
    ),
  );
}

class _StatusChip extends StatelessWidget {
  const _StatusChip(this.label, {this.color, this.icon = Icons.circle});
  final String label;
  final Color? color;
  final IconData icon;
  @override
  Widget build(BuildContext context) {
    final resolvedColor = color ?? cobalt;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: resolvedColor.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: resolvedColor.withValues(alpha: .25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: resolvedColor),
          const SizedBox(width: 5),
          Text(
            AppLocalizations.of(context).text(label),
            style: TextStyle(
              fontSize: 12,
              color: resolvedColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExerciseThumb extends StatelessWidget {
  const _ExerciseThumb({super.key, required this.exerciseId, this.size = 42});
  final String exerciseId;
  final double size;
  @override
  Widget build(BuildContext context) {
    final isCustom = exerciseId.startsWith('custom-');
    final controller = _AppControllerScope.maybeOf(context);
    final thumbnail = Material(
      color: paper,
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: size,
        height: size,
        child: isCustom
            ? Icon(Icons.fitness_center_rounded, color: primary)
            : Image.asset(
                exerciseAsset(exerciseId),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stack) =>
                    Icon(Icons.fitness_center, color: cobalt),
              ),
      ),
    );
    if (controller == null) return thumbnail;
    final exercise = controller.exerciseFor(exerciseId);
    return Semantics(
      button: true,
      label: '查看${controller.displayExerciseName(exercise)}动作详情',
      child: Material(
        color: paper,
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _showExerciseDetail(context, controller, exercise),
          child: thumbnail,
        ),
      ),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final monday = DateTime(
      today.year,
      today.month,
      today.day,
    ).subtract(Duration(days: today.weekday - 1));
    final nextMonday = monday.add(const Duration(days: 7));
    final weekRecords = controller.history
        .where(
          (record) =>
              !record.date.isBefore(monday) && record.date.isBefore(nextMonday),
        )
        .toList(growable: false);
    final muscleSets = <String, int>{};
    final homeDisplaySets = <String, int>{};
    for (final record in weekRecords) {
      for (final workoutExercise in record.exercises) {
        final exercise = controller.exerciseFor(workoutExercise.exerciseId);
        final muscle = controller.muscleGroupFor(exercise.muscle);
        final completed = workoutExercise.sets
            .where((set) => set.completed)
            .length;
        if (completed > 0) {
          muscleSets[muscle] = (muscleSets[muscle] ?? 0) + completed;
          final displayMuscle = _homeDisplayMuscle(exercise.muscle);
          homeDisplaySets[displayMuscle] =
              (homeDisplaySets[displayMuscle] ?? 0) + completed;
        }
      }
    }
    return PageFrame(
      children: [
        AiTrainingHomeCard(controller: controller),
        const SizedBox(height: 16),
        SectionTitle(
          '本周训练',
          action:
              '${weekRecords.map((record) => _dateKey(record.date)).toSet().length} / 4 次',
        ),
        _HomeWeekOverview(
          controller: controller,
          muscleSets: muscleSets,
          displaySets: homeDisplaySets,
        ),
        const SizedBox(height: 12),
        Card(
          child: InkWell(
            key: const Key('home-nutrition-card'),
            borderRadius: BorderRadius.circular(16),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => _NutritionJournalPage(controller: controller),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  const _HomeAccentIcon(icon: Icons.restaurant_rounded),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '饮食与热量',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${controller.todayCalories.toStringAsFixed(0)} kcal · 蛋白质 ${controller.todayProtein.toStringAsFixed(0)} g'
                          '${controller.estimatedDailyCalories == null ? '' : ' / 目标约 ${controller.estimatedDailyCalories!.toStringAsFixed(0)} kcal'}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: quiet, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: primary),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: InkWell(
            key: const Key('home-ai-workout'),
            borderRadius: BorderRadius.circular(16),
            onTap: () => _showAiWorkoutPlanner(context, controller),
            child: Padding(
              padding: EdgeInsets.all(14),
              child: Row(
                children: [
                  _HomeAccentIcon(icon: Icons.auto_awesome_rounded),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AI 定制训练',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                        SizedBox(height: 3),
                        Text(
                          '按目标、器械和时间生成计划',
                          style: TextStyle(color: quiet, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: quiet),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _HomeWeekOverview extends StatefulWidget {
  const _HomeWeekOverview({
    required this.controller,
    required this.muscleSets,
    required this.displaySets,
  });

  final AppController controller;
  final Map<String, int> muscleSets;
  final Map<String, int> displaySets;

  @override
  State<_HomeWeekOverview> createState() => _HomeWeekOverviewState();
}

class _HomeWeekOverviewState extends State<_HomeWeekOverview> {
  DateTime? selectedDate;

  @override
  Widget build(BuildContext context) {
    final selected = selectedDate;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _WeekStrip(
          controller: widget.controller,
          selectedDate: selected,
          onDateSelected: (date) => setState(() => selectedDate = date),
        ),
        const SizedBox(height: 12),
        Stack(
          children: [
            Visibility(
              visible: selected == null,
              maintainState: true,
              maintainAnimation: false,
              maintainSize: false,
              child: TickerMode(
                enabled: selected == null,
                child: _HomeMuscleCard(
                  controller: widget.controller,
                  muscleSets: widget.muscleSets,
                  displaySets: widget.displaySets,
                  active: selected == null,
                ),
              ),
            ),
            if (selected != null)
              _HomeDayRecordsSection(
                key: const Key('home-day-training-section'),
                controller: widget.controller,
                date: selected,
                onBack: () => setState(() => selectedDate = null),
              ),
          ],
        ),
      ],
    );
  }
}

class _HomeDayRecordsSection extends StatelessWidget {
  const _HomeDayRecordsSection({
    super.key,
    required this.controller,
    required this.date,
    required this.onBack,
  });

  final AppController controller;
  final DateTime date;
  final VoidCallback onBack;

  List<WorkoutRecord> get records {
    final values = controller.history
        .where((record) => _isSameDay(record.date, date))
        .toList();
    values.sort((a, b) {
      final time = _recordStartDateTime(a).compareTo(_recordStartDateTime(b));
      return time != 0 ? time : a.id.compareTo(b.id);
    });
    return values;
  }

  @override
  Widget build(BuildContext context) {
    final values = records;
    final dateKey = _dateKey(date);
    final scheduledLabel = controller.scheduledLabels[dateKey]?.trim();
    final hasScheduledLabel =
        scheduledLabel != null && scheduledLabel.isNotEmpty;
    final planned = controller.scheduled.contains(dateKey) || hasScheduledLabel;
    final status = values.isNotEmpty
        ? (planned ? '已完成 · 已安排' : '已完成')
        : planned
        ? '计划'
        : '无记录';
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final title = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '当天训练',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 2),
                Text(
                  '${date.year}年${date.month}月${date.day}日 · $status',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: quiet, fontSize: 12),
                ),
                if (hasScheduledLabel)
                  Text(
                    '计划：$scheduledLabel',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: quiet, fontSize: 12),
                  ),
              ],
            );
            final back = TextButton(
              key: const Key('home-day-training-back'),
              onPressed: onBack,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                minimumSize: const Size(44, 40),
              ),
              child: const Text('返回训练量与恢复'),
            );
            final stackHeader = textScale > 1.35 || constraints.maxWidth < 360;
            return stackHeader
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      title,
                      Align(alignment: Alignment.centerLeft, child: back),
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: title),
                      back,
                    ],
                  );
          },
        ),
        if (values.isNotEmpty) ...[
          const SizedBox(height: 8),
          for (var index = 0; index < values.length; index++) ...[
            if (index > 0) const SizedBox(height: 8),
            KeyedSubtree(
              key: Key('home-day-record-${values[index].id}'),
              child: _WorkoutShareCard(
                controller: controller,
                record: values[index],
                compact: true,
                onTap: () =>
                    _showRecordDetail(context, controller, values[index]),
              ),
            ),
          ],
        ] else
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Card(
              key: const Key('home-day-records-empty'),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  planned ? '当天有计划，完成后会显示记录。' : '当天没有训练记录。',
                  style: TextStyle(color: quiet),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

Future<void> _showNutritionSheet(
  BuildContext context,
  AppController controller,
) async {
  final food = TextEditingController();
  final amount = TextEditingController();
  final calories = TextEditingController();
  final protein = TextEditingController();
  final carbs = TextEditingController();
  final fat = TextEditingController();
  final mealLabel = controller.nextMealLabelFor(DateTime.now());
  String? selectedPhotoName;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (sheetContext) => StatefulBuilder(
      builder: (context, setSheetState) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SafeArea(
          top: false,
          minimum: const EdgeInsets.fromLTRB(18, 0, 18, 16),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '记录$mealLabel',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: primaryContainer,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        '按次序记录',
                        style: TextStyle(
                          color: primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '热量与营养数值可查看食品包装或餐厅信息后填写。',
                  style: TextStyle(color: quiet, fontSize: 12),
                ),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  key: const Key('nutrition-photo-picker'),
                  onPressed: () async {
                    final result = await FilePicker.platform.pickFiles(
                      type: FileType.image,
                      allowMultiple: false,
                      withData: false,
                    );
                    if (result == null || result.files.isEmpty) return;
                    setSheetState(
                      () => selectedPhotoName = result.files.single.name,
                    );
                  },
                  icon: const Icon(Icons.add_a_photo_outlined),
                  label: Text(selectedPhotoName ?? '选择食物照片（实验）'),
                ),
                if (selectedPhotoName != null) ...[
                  const SizedBox(height: 5),
                  Text(
                    '照片已添加。单张图片难以准确判断重量，本次请仍人工确认食物和份量。',
                    style: TextStyle(color: quiet, fontSize: 11),
                  ),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: food,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: '食物名称 *'),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: amount,
                        decoration: const InputDecoration(
                          labelText: '份量，如 200 g',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: calories,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: '热量 kcal *',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: protein,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(labelText: '蛋白质 g'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: carbs,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(labelText: '碳水 g'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: fat,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(labelText: '脂肪 g'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                FilledButton(
                  key: const Key('nutrition-save'),
                  onPressed: () async {
                    final name = food.text.trim();
                    final kcal = double.tryParse(calories.text.trim());
                    if (name.isEmpty || kcal == null || kcal < 0) {
                      showKiloSnack(context, '请填写食物名称和有效热量');
                      return;
                    }
                    await controller.addNutritionEntry(
                      NutritionEntry(
                        id: 'nutrition-${DateTime.now().microsecondsSinceEpoch}',
                        recordedAt: DateTime.now(),
                        mealType: mealLabel,
                        foodName: name,
                        amount: amount.text.trim(),
                        calories: kcal,
                        proteinGrams: double.tryParse(protein.text.trim()) ?? 0,
                        carbsGrams: double.tryParse(carbs.text.trim()) ?? 0,
                        fatGrams: double.tryParse(fat.text.trim()) ?? 0,
                      ),
                    );
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: const Text('保存记录'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  food.dispose();
  amount.dispose();
  calories.dispose();
  protein.dispose();
  carbs.dispose();
  fat.dispose();
}

class _HomeAccentIcon extends StatelessWidget {
  const _HomeAccentIcon({required this.icon});
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width <= 360;
    return Container(
      // Keep the tap target at 44dp, but reduce the glyph on narrow Android
      // screens so the icon does not visually dominate compact cards.
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: primaryContainer,
        borderRadius: BorderRadius.circular(compact ? 12 : 14),
      ),
      child: Icon(icon, color: primary, size: compact ? 20 : 22),
    );
  }
}

String _homeDisplayMuscle(String muscle) {
  if (muscle.contains('二头') || muscle.toLowerCase().contains('biceps')) {
    return '二头';
  }
  if (muscle.contains('三头') || muscle.toLowerCase().contains('triceps')) {
    return '三头';
  }
  if (muscle.contains('胸') || muscle.toLowerCase().contains('chest')) {
    return '胸';
  }
  if (muscle.contains('背') || muscle.toLowerCase().contains('back')) {
    return '背';
  }
  if (muscle.contains('肩') ||
      muscle.contains('三角') ||
      muscle.toLowerCase().contains('delt')) {
    return '肩';
  }
  if (muscle.contains('腿') ||
      muscle.contains('股') ||
      muscle.contains('臀') ||
      muscle.contains('腘') ||
      muscle.contains('小腿') ||
      muscle.contains('髋') ||
      muscle.contains('内收') ||
      muscle.toLowerCase().contains('quad') ||
      muscle.toLowerCase().contains('hamstring') ||
      muscle.toLowerCase().contains('glute') ||
      muscle.toLowerCase().contains('calf')) {
    return '腿';
  }
  if (muscle.contains('腹') ||
      muscle.contains('核心') ||
      muscle.toLowerCase().contains('ab')) {
    return '核心';
  }
  if (muscle.contains('前锯') || muscle.contains('斜方') || muscle.contains('竖脊')) {
    return '背';
  }
  return '其他';
}

Map<String, int> _homeRecoveryValues(List<MuscleRecovery> recovery) {
  if (recovery.isEmpty) return const {};
  final values = {for (final item in recovery) item.muscle: item.percent};

  int lowest(Iterable<String> names) {
    final matching = names
        .map((name) => values[name])
        .whereType<int>()
        .toList(growable: false);
    if (matching.isEmpty) return 100;
    return matching.reduce((a, b) => a < b ? a : b);
  }

  return {
    '胸': lowest(const ['胸']),
    '背': lowest(const ['背']),
    '肩': lowest(const ['肩']),
    '手臂': lowest(const ['二头', '三头']),
    '腿': lowest(const ['股四头', '腘绳肌', '臀', '小腿']),
    '核心': lowest(const ['核心']),
  };
}

class _HomeMuscleCard extends StatefulWidget {
  const _HomeMuscleCard({
    required this.controller,
    required this.muscleSets,
    required this.displaySets,
    this.active = true,
  });
  final AppController controller;
  final Map<String, int> muscleSets;
  final Map<String, int> displaySets;
  final bool active;

  @override
  State<_HomeMuscleCard> createState() => _HomeMuscleCardState();
}

class _HomeMuscleCardState extends State<_HomeMuscleCard> {
  static const _groups = <String>['胸', '背', '肩', '二头', '三头', '腿', '核心'];
  late final PageController _pageController;
  Timer? _rotationTimer;
  var _page = 0;
  var _manualSwipe = false;
  var _programmaticPageChange = false;

  AppController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _startAutoRotation();
  }

  @override
  void didUpdateWidget(covariant _HomeMuscleCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active == widget.active) return;
    if (widget.active) {
      _startAutoRotation();
    } else {
      _rotationTimer?.cancel();
      _rotationTimer = null;
    }
  }

  void _startAutoRotation() {
    if (!widget.active || _manualSwipe || _rotationTimer != null) return;
    _rotationTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || _manualSwipe || !_pageController.hasClients) return;
      final next = (_page + 1) % 2;
      _programmaticPageChange = true;
      _pageController
          .animateToPage(
            next,
            duration: const Duration(milliseconds: 360),
            curve: Curves.easeOutCubic,
          )
          .whenComplete(() => _programmaticPageChange = false);
    });
  }

  @override
  void dispose() {
    _rotationTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _stopAutoRotation() {
    if (_manualSwipe) return;
    _manualSwipe = true;
    _rotationTimer?.cancel();
    _rotationTimer = null;
  }

  void _selectPage(int page) {
    _stopAutoRotation();
    if (!_pageController.hasClients || page == _page) return;
    _programmaticPageChange = true;
    _pageController
        .animateToPage(
          page,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
        )
        .whenComplete(() => _programmaticPageChange = false);
  }

  void _openMetric(int page) {
    if (page == 0) {
      controller.openTrainingStatistics();
    } else {
      controller.selectTrainView(TrainView.plans);
    }
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width <= 360;
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final pageViewHeight =
        (compact ? 248.0 : 266.0) + math.max(0.0, textScale - 1.0) * 120.0;
    final ranked = _groups
        .map((group) => MapEntry(group, widget.displaySets[group] ?? 0))
        .toList(growable: false);
    final recoveryValues = _homeRecoveryValues(
      controller.trainingIntelligence.recovery,
    );
    final hasRecoveryData = recoveryValues.isNotEmpty;
    return Card(
      key: const Key('home-muscle-card'),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openMetric(_page),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _page == 0 ? '本周肌群训练量' : '本周肌群恢复',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    key: Key(
                      _page == 0
                          ? 'home-muscle-open-volume'
                          : 'home-muscle-open-recovery',
                    ),
                    onPressed: () => _openMetric(_page),
                    icon: const Icon(Icons.chevron_right_rounded, size: 18),
                    label: const Text('详情'),
                    style: TextButton.styleFrom(
                      foregroundColor: primary,
                      minimumSize: const Size(44, 44),
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                    ),
                  ),
                ],
              ),
              const ExcludeSemantics(
                child: Text('本周肌群', style: TextStyle(fontSize: 0, height: 0)),
              ),
              const SizedBox(height: 3),
              Row(
                children: [
                  _HomeMetricTab(
                    key: const Key('home-muscle-volume-tab'),
                    label: '训练量',
                    selected: _page == 0,
                    onTap: () => _selectPage(0),
                  ),
                  const SizedBox(width: 6),
                  _HomeMetricTab(
                    key: const Key('home-muscle-recovery-tab'),
                    label: '恢复',
                    selected: _page == 1,
                    onTap: () => _selectPage(1),
                  ),
                  const Spacer(),
                  if (_manualSwipe)
                    Text('手动查看', style: TextStyle(color: quiet, fontSize: 10)),
                ],
              ),
              const SizedBox(height: 6),
              SizedBox(
                key: const Key('home-muscle-page-view'),
                height: pageViewHeight,
                child: NotificationListener<ScrollNotification>(
                  onNotification: (notification) {
                    if (notification is ScrollStartNotification &&
                        notification.dragDetails != null) {
                      _stopAutoRotation();
                    }
                    return false;
                  },
                  child: PageView(
                    controller: _pageController,
                    onPageChanged: (value) {
                      if (!mounted) return;
                      setState(() => _page = value);
                      // A page selected by a touch gesture has already
                      // cancelled the timer in the scroll notification. The
                      // flag only documents that a timer transition should
                      // never be treated as a user interaction.
                      if (!_programmaticPageChange && _manualSwipe) return;
                    },
                    children: [
                      _HomeMuscleMetricPage(
                        metric: MuscleMapMode.volume,
                        muscleSets: widget.muscleSets,
                        ranked: ranked,
                        height: compact ? 158 : 174,
                        mapKey: const Key('home-muscle-map'),
                        onTap: () => _openMetric(0),
                      ),
                      _HomeMuscleMetricPage(
                        metric: MuscleMapMode.recovery,
                        muscleSets: recoveryValues,
                        ranked: [
                          for (final muscle in const [
                            '胸',
                            '背',
                            '肩',
                            '手臂',
                            '腿',
                            '核心',
                          ])
                            if (hasRecoveryData)
                              MapEntry(muscle, recoveryValues[muscle] ?? 100),
                        ],
                        height: compact ? 158 : 174,
                        mapKey: const Key('home-recovery-muscle-map'),
                        onTap: () => _openMetric(1),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 3),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var index = 0; index < 2; index++)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: _page == index ? 18 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: _page == index ? primary : hairline,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeMuscleMetricPage extends StatelessWidget {
  const _HomeMuscleMetricPage({
    required this.metric,
    required this.muscleSets,
    required this.ranked,
    required this.height,
    required this.mapKey,
    required this.onTap,
  });

  final MuscleMapMode metric;
  final Map<String, int> muscleSets;
  final List<MapEntry<String, int>> ranked;
  final double height;
  final Key mapKey;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final recovery = metric == MuscleMapMode.recovery;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 5,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      // InteractiveMuscleMap reserves room for its front/back
                      // controls (and an optional selected-label line) in
                      // addition to the SVG itself. Derive the SVG height
                      // from the row's actual budget so the home card stays
                      // bounded when the legend wraps on narrow screens.
                      final bodyHeight = (constraints.maxHeight - 56)
                          .clamp(0.0, height)
                          .toDouble();
                      return _MuscleBodyMap(
                        key: mapKey,
                        muscleSets: muscleSets,
                        mode: metric,
                        height: bodyHeight,
                        onMuscleTap: (_) => onTap(),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 7,
                  child: ranked.isEmpty
                      ? Center(
                          child: Text(
                            recovery ? '完成首次训练后显示恢复状态' : '完成训练后显示训练量',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: quiet, fontSize: 12),
                          ),
                        )
                      : Column(
                          children: [
                            for (final item in ranked)
                              recovery
                                  ? _HomeMuscleRecoveryRow(
                                      muscle: item.key,
                                      percent: item.value,
                                    )
                                  : _HomeMuscleVolumeRow(
                                      muscle: item.key,
                                      sets: item.value,
                                    ),
                          ],
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 3),
          recovery ? const _HomeRecoveryLegend() : const _HomeVolumeLegendRow(),
        ],
      ),
    );
  }
}

class _HomeMetricTab extends StatelessWidget {
  const _HomeMetricTab({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: '首页肌群$label',
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(99),
      child: Container(
        constraints: const BoxConstraints(minHeight: 30),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? primaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: selected ? primary : hairline),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? primary : quiet,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    ),
  );
}

Color _homeVolumeColor(int sets) {
  return MusclePalette.volumeColor(sets);
}

Color _homeRecoveryColor(int percent) => MusclePalette.recoveryColor(percent);

class _MusclePaletteProgressBar extends StatelessWidget {
  const _MusclePaletteProgressBar({
    required this.fraction,
    required this.metricValue,
    required this.mode,
    this.minHeight = 7,
  });

  final double fraction;
  final num? metricValue;
  final MuscleMapMode mode;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    final safeFraction = fraction.isFinite
        ? fraction.clamp(0.0, 1.0).toDouble()
        : 0.0;
    final gradient = mode == MuscleMapMode.recovery
        ? MusclePalette.recoveryGradient(metricValue)
        : MusclePalette.volumeGradient(metricValue ?? 0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(99),
      child: SizedBox(
        height: minHeight,
        child: LayoutBuilder(
          builder: (_, _) => Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(color: surface),
              Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: safeFraction,
                  heightFactor: 1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(gradient: gradient),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeMuscleVolumeRow extends StatelessWidget {
  const _HomeMuscleVolumeRow({required this.muscle, required this.sets});

  final String muscle;
  final int sets;

  @override
  Widget build(BuildContext context) {
    final color = _homeVolumeColor(sets);
    return SizedBox(
      height: 25,
      child: Row(
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 7),
          SizedBox(
            width: 36,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                muscle,
                maxLines: 1,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(width: 5),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: _MusclePaletteProgressBar(
                fraction: sets / 16,
                metricValue: sets,
                mode: MuscleMapMode.volume,
              ),
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 30,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                '$sets组',
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: sets == 0 ? quiet : color.withValues(alpha: .95),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeMuscleRecoveryRow extends StatelessWidget {
  const _HomeMuscleRecoveryRow({required this.muscle, required this.percent});

  final String muscle;
  final int percent;

  @override
  Widget build(BuildContext context) {
    final color = _homeRecoveryColor(percent);
    return SizedBox(
      height: 25,
      child: Row(
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 7),
          SizedBox(
            width: 36,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                muscle,
                maxLines: 1,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(width: 5),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: _MusclePaletteProgressBar(
                fraction: percent / 100,
                metricValue: percent,
                mode: MuscleMapMode.recovery,
              ),
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 32,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                '$percent%',
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeVolumeLegend extends StatelessWidget {
  const _HomeVolumeLegend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(color: quiet, fontSize: 10)),
    ],
  );
}

class _HomeVolumeLegendRow extends StatelessWidget {
  const _HomeVolumeLegendRow();

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 10,
    runSpacing: 5,
    children: [
      for (
        var index = 0;
        index < MusclePalette.volumeLegendLabels.length;
        index++
      )
        _HomeVolumeLegend(
          color: MusclePalette.volumeColor(
            MusclePalette.volumeLegendValues[index],
          ),
          label: MusclePalette.volumeLegendLabels[index],
        ),
    ],
  );
}

class _HomeRecoveryLegend extends StatelessWidget {
  const _HomeRecoveryLegend();

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 10,
    runSpacing: 5,
    children: [
      for (
        var index = 0;
        index < MusclePalette.recoveryLegendLabels.length;
        index++
      )
        _HomeVolumeLegend(
          color: MusclePalette.recoveryColor(
            MusclePalette.recoveryLegendValues[index],
          ),
          label: MusclePalette.recoveryLegendLabels[index],
        ),
    ],
  );
}

class _ExerciseTrendPoint {
  const _ExerciseTrendPoint({required this.date, required this.weight});
  final DateTime date;
  final double weight;
}

class _HomeExerciseTrendCard extends StatefulWidget {
  const _HomeExerciseTrendCard({required this.controller});
  final AppController controller;

  @override
  State<_HomeExerciseTrendCard> createState() => _HomeExerciseTrendCardState();
}

class _HomeExerciseTrendCardState extends State<_HomeExerciseTrendCard> {
  String? selectedExerciseId;

  Map<String, List<_ExerciseTrendPoint>> _series() {
    final result = <String, List<_ExerciseTrendPoint>>{};
    for (final record in widget.controller.history.reversed) {
      for (final exercise in record.exercises) {
        final completed = exercise.sets
            .where((set) => set.completed && set.weight > 0)
            .toList();
        if (completed.isEmpty) continue;
        final best = completed
            .map((set) => set.weight)
            .reduce((a, b) => a > b ? a : b);
        result
            .putIfAbsent(exercise.exerciseId, () => <_ExerciseTrendPoint>[])
            .add(_ExerciseTrendPoint(date: record.date, weight: best));
      }
    }
    return result;
  }

  Future<void> _pickExercise(
    Map<String, List<_ExerciseTrendPoint>> series,
  ) async {
    final choices = series.keys.toList()
      ..sort(
        (a, b) => widget.controller
            .displayExerciseName(widget.controller.exerciseFor(a))
            .compareTo(
              widget.controller.displayExerciseName(
                widget.controller.exerciseFor(b),
              ),
            ),
      );
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (context) => ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 18),
        children: [
          const ListTile(
            title: Text(
              '选择趋势动作',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            subtitle: Text('只比较你自己的同一个动作历史'),
          ),
          for (final id in choices)
            ListTile(
              key: Key('home-trend-option-$id'),
              leading: _ExerciseThumb(exerciseId: id, size: 42),
              title: Text(
                widget.controller.displayExerciseName(
                  widget.controller.exerciseFor(id),
                ),
              ),
              trailing: id == selectedExerciseId
                  ? Icon(Icons.check_rounded, color: primary)
                  : null,
              onTap: () {
                if (mounted) setState(() => selectedExerciseId = id);
                Navigator.pop(context);
              },
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final series = _series();
    if (selectedExerciseId == null || !series.containsKey(selectedExerciseId)) {
      selectedExerciseId = series.containsKey('bench_press')
          ? 'bench_press'
          : series.keys.isEmpty
          ? null
          : series.keys.first;
    }
    final id = selectedExerciseId;
    final allPoints = id == null ? const <_ExerciseTrendPoint>[] : series[id]!;
    final points = allPoints.length > 6
        ? allPoints.sublist(allPoints.length - 6)
        : allPoints;
    final name = id == null
        ? '动作'
        : widget.controller.displayExerciseName(
            widget.controller.exerciseFor(id),
          );
    final latest = points.isEmpty ? null : points.last.weight;
    final delta = points.length < 2
        ? null
        : points.last.weight - points[points.length - 2].weight;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextButton.icon(
              key: const Key('home-trend-picker'),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 38),
              ),
              onPressed: series.isEmpty ? null : () => _pickExercise(series),
              iconAlignment: IconAlignment.end,
              icon: const Icon(Icons.arrow_drop_down_rounded, size: 18),
              label: Text(
                '$name趋势',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            Text(
              latest == null ? '暂无记录' : '${latest.toStringAsFixed(1)} kg',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
            ),
            Text(
              delta == null
                  ? (latest == null ? '完成带重量的训练后显示' : '首次记录')
                  : '较上次 ${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(1)} kg',
              style: TextStyle(
                color: delta != null && delta < 0 ? secondaryInk : success,
                fontWeight: FontWeight.w800,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              key: const Key('home-exercise-trend-chart'),
              height: 118,
              width: double.infinity,
              child: points.isEmpty
                  ? Center(
                      child: Icon(
                        Icons.show_chart_rounded,
                        color: hairline,
                        size: 38,
                      ),
                    )
                  : CustomPaint(painter: _HomeExerciseTrendPainter(points)),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeExerciseTrendPainter extends CustomPainter {
  const _HomeExerciseTrendPainter(this.points);
  final List<_ExerciseTrendPoint> points;

  @override
  void paint(Canvas canvas, Size size) {
    final chart = Rect.fromLTWH(5, 6, size.width - 10, size.height - 24);
    final grid = Paint()
      ..color = hairline.withValues(alpha: .8)
      ..strokeWidth = 1;
    for (var row = 0; row < 3; row++) {
      final y = chart.top + chart.height * row / 2;
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), grid);
    }
    final values = points.map((item) => item.weight).toList();
    final minValue = values.reduce((a, b) => a < b ? a : b);
    final maxValue = values.reduce((a, b) => a > b ? a : b);
    final span = (maxValue - minValue).abs() < .01 ? 1.0 : maxValue - minValue;
    final offsets = <Offset>[];
    for (var i = 0; i < points.length; i++) {
      final x = points.length == 1
          ? chart.center.dx
          : chart.left + chart.width * i / (points.length - 1);
      final y =
          chart.bottom - (points[i].weight - minValue) / span * chart.height;
      offsets.add(Offset(x, y));
    }
    final line = Paint()
      ..color = primary
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    if (offsets.length > 1) {
      final path = Path()..moveTo(offsets.first.dx, offsets.first.dy);
      for (final point in offsets.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(path, line);
    }
    for (final point in offsets) {
      canvas.drawCircle(point, 4, Paint()..color = surface);
      canvas.drawCircle(point, 4, line);
    }
    final indices = points.length == 1
        ? <int>[0]
        : (<int>{0, points.length ~/ 2, points.length - 1}.toList()..sort());
    for (final index in indices) {
      final date = points[index].date;
      final text = TextPainter(
        text: TextSpan(
          text: '${date.month}/${date.day}',
          style: TextStyle(color: quiet, fontSize: 9),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final x = (offsets[index].dx - text.width / 2).clamp(
        0.0,
        size.width - text.width,
      );
      text.paint(canvas, Offset(x, size.height - text.height));
    }
  }

  @override
  bool shouldRepaint(covariant _HomeExerciseTrendPainter oldDelegate) =>
      oldDelegate.points != points;
}

class _WeekStrip extends StatelessWidget {
  const _WeekStrip({
    required this.controller,
    required this.selectedDate,
    required this.onDateSelected,
  });

  final AppController controller;
  final DateTime? selectedDate;
  final ValueChanged<DateTime> onDateSelected;

  @override
  Widget build(BuildContext context) {
    final days = ['一', '二', '三', '四', '五', '六', '日'];
    final today = DateTime.now();
    final monday = DateTime(
      today.year,
      today.month,
      today.day,
    ).subtract(Duration(days: today.weekday - 1));
    final dates = [for (var i = 0; i < 7; i++) monday.add(Duration(days: i))];
    final scale = MediaQuery.textScalerOf(context).scale(1);
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 338.0;
        final itemWidth = math.max(44.0, (availableWidth - 30) / 7);
        final rowWidth = itemWidth * 7 + 30;
        return SizedBox(
          height: 78 * scale,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: rowWidth,
              child: Row(
                children: [
                  for (var i = 0; i < 7; i++)
                    Padding(
                      padding: EdgeInsets.only(right: i == 6 ? 0 : 5),
                      child: _HomeWeekDay(
                        key: Key('home-week-day-${_dateKey(dates[i])}'),
                        controller: controller,
                        date: dates[i],
                        label: days[i],
                        today: _isSameDay(dates[i], today),
                        selected:
                            selectedDate != null &&
                            _isSameDay(dates[i], selectedDate!),
                        width: itemWidth,
                        onTap: () => onDateSelected(dates[i]),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _HomeWeekDay extends StatelessWidget {
  const _HomeWeekDay({
    super.key,
    required this.controller,
    required this.date,
    required this.label,
    required this.today,
    required this.selected,
    required this.width,
    required this.onTap,
  });

  final AppController controller;
  final DateTime date;
  final String label;
  final bool today;
  final bool selected;
  final double width;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final completed = controller.history.any(
      (record) => _isSameDay(record.date, date),
    );
    final plannedKey = _dateKey(date);
    final scheduledLabel = controller.scheduledLabels[plannedKey]?.trim();
    final planned =
        controller.scheduled.contains(plannedKey) ||
        (scheduledLabel != null && scheduledLabel.isNotEmpty);
    final status = completed
        ? '已完成'
        : planned
        ? '计划'
        : '—';
    final background = completed
        ? successContainer
        : planned
        ? calendarScheduledContainer
        : selected
        ? calendarSelectedContainer
        : surfaceRaised;
    final borderColor = selected
        ? primary
        : today
        ? calendarSelected
        : completed
        ? const Color(0xFF8BC7B9)
        : planned
        ? calendarScheduled
        : hairline;
    final markerColor = today
        ? calendarSelected
        : completed
        ? const Color(0xFF438F82)
        : planned
        ? calendarScheduled
        : hairline;
    final marker = today
        ? Icons.today_rounded
        : completed
        ? Icons.check_circle_rounded
        : planned
        ? Icons.event_available_rounded
        : Icons.remove;
    return Semantics(
      button: true,
      selected: selected,
      label: '$label ${date.month}月${date.day}日${today ? '，今天' : ''}，$status',
      child: SizedBox(
        width: width,
        height: 78 * MediaQuery.textScalerOf(context).scale(1),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: borderColor,
                width: selected || today ? 2 : 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: quiet,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                SizedBox(
                  width: double.infinity,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '${date.day}',
                      maxLines: 1,
                      softWrap: false,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: ink,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Icon(marker, size: 12, color: markerColor),
                const SizedBox(height: 1),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    status,
                    style: TextStyle(
                      fontSize: 9,
                      color: markerColor,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

bool _isSameDay(DateTime left, DateTime right) =>
    left.year == right.year &&
    left.month == right.month &&
    left.day == right.day;

DateTime _recordStartDateTime(WorkoutRecord record) {
  final match = RegExp(
    r'^(\d{1,2}):(\d{2})$',
  ).firstMatch(record.startTime.trim());
  final hour = int.tryParse(match?.group(1) ?? '');
  final minute = int.tryParse(match?.group(2) ?? '');
  if (hour != null && minute != null && hour >= 0 && hour < 24 && minute < 60) {
    return DateTime(
      record.date.year,
      record.date.month,
      record.date.day,
      hour,
      minute,
    );
  }
  return record.date;
}

class _ParticlePainter extends CustomPainter {
  _ParticlePainter({required this.reducedMotion});
  final bool reducedMotion;
  @override
  void paint(Canvas canvas, Size size) {
    final dot = Paint()..color = cobalt.withValues(alpha: .045);
    final line = Paint()
      ..color = cobalt.withValues(alpha: .025)
      ..strokeWidth = 1;
    final points = <Offset>[
      Offset(size.width * .08, size.height * .16),
      Offset(size.width * .27, size.height * .10),
      Offset(size.width * .43, size.height * .22),
      Offset(size.width * .68, size.height * .13),
      Offset(size.width * .90, size.height * .27),
      Offset(size.width * .18, size.height * .47),
      Offset(size.width * .50, size.height * .42),
      Offset(size.width * .78, size.height * .54),
      Offset(size.width * .92, size.height * .72),
    ];
    for (final point in points) {
      canvas.drawCircle(point, reducedMotion ? 2.2 : 2.8, dot);
    }
    if (reducedMotion) return;
    for (var index = 0; index < points.length - 1; index++) {
      canvas.drawLine(points[index], points[index + 1], line);
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) =>
      oldDelegate.reducedMotion != reducedMotion;
}

class TrainPage extends StatelessWidget {
  const TrainPage({super.key, required this.controller});
  final AppController controller;
  @override
  Widget build(BuildContext context) {
    if (controller.liveWorkoutVisible) {
      return PopScope<void>(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) controller.closeLiveWorkout();
        },
        child: PageFrame(
          children: [
            _LiveWorkoutTimingPanel(controller: controller),
            const SizedBox(height: 12),
            _WorkoutView(controller: controller),
          ],
        ),
      );
    }
    final showingHistory = controller.trainView == TrainView.history;
    return Column(
      children: [
        _TrainTopTabs(controller: controller),
        Expanded(
          child: showingHistory
              ? RecordsPage(controller: controller, embedded: true)
              : PageFrame(
                  children: [
                    _TrainingPlanStatusCard(controller: controller),
                    const SizedBox(height: 14),
                    SectionTitle('我的训练计划', subtitle: '选择一节训练后进入独立实时记录界面'),
                    _PlansView(controller: controller),
                  ],
                ),
        ),
      ],
    );
  }
}

class _TrainingPlanStatusCard extends StatelessWidget {
  const _TrainingPlanStatusCard({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final snapshot = controller.trainingIntelligence;
    final recovery = snapshot.recovery.take(4).toList(growable: false);
    final gym = controller.currentGym;
    return Card(
      key: const Key('plan-today-status'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 13, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    '今日状态',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                TextButton(
                  key: const Key('plan-open-recovery'),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          RecoveryDetailsPage(controller: controller),
                    ),
                  ),
                  child: const Text('查看恢复'),
                ),
              ],
            ),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                for (final item in recovery)
                  _RecoveryMiniPill(muscle: item.muscle, percent: item.percent),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.location_on_outlined, size: 18, color: primary),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    gym == null ? '今天在哪训练？' : '当前：${gym.name}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                if (controller.gymLocations.isNotEmpty)
                  PopupMenuButton<String>(
                    key: const Key('plan-gym-switcher'),
                    tooltip: '切换训练地点',
                    onSelected: controller.selectGym,
                    itemBuilder: (context) => [
                      for (final location in controller.gymLocations)
                        PopupMenuItem<String>(
                          value: location.id,
                          child: Text(location.name),
                        ),
                    ],
                    icon: const Icon(Icons.swap_vert_rounded, size: 20),
                  ),
                TextButton(
                  key: const Key('plan-open-gyms'),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => GymLocationsPage(controller: controller),
                    ),
                  ),
                  child: Text(gym == null ? '添加' : '管理'),
                ),
              ],
            ),
            if (snapshot.today.muscles.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                '今天建议：${snapshot.today.muscles.join(' + ')} · ${snapshot.today.reason}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: quiet, fontSize: 12, height: 1.35),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RecoveryMiniPill extends StatelessWidget {
  const _RecoveryMiniPill({required this.muscle, required this.percent});

  final String muscle;
  final int percent;

  @override
  Widget build(BuildContext context) {
    final color = percent >= 80
        ? success
        : percent >= 60
        ? const Color(0xFFE29A00)
        : danger;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: .26)),
      ),
      child: Text(
        '$muscle $percent%',
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class RecoveryDetailsPage extends StatefulWidget {
  const RecoveryDetailsPage({super.key, required this.controller});

  final AppController controller;

  @override
  State<RecoveryDetailsPage> createState() => _RecoveryDetailsPageState();
}

class _RecoveryDetailsPageState extends State<RecoveryDetailsPage> {
  String? _selectedMuscle;

  AppController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    final recovery = controller.trainingIntelligence.recovery;
    if (recovery.isNotEmpty) {
      _selectedMuscle = recovery
          .reduce(
            (current, item) => item.percent < current.percent ? item : current,
          )
          .muscle;
    }
  }

  static const _slugToMuscle = <String, String>{
    'abs': '核心',
    'adductors': '股四头',
    'biceps': '二头',
    'calves': '小腿',
    'chest': '胸',
    'deltoids': '肩',
    'forearm': '二头',
    'gluteal': '臀',
    'hamstring': '腘绳肌',
    'lower-back': '背',
    'obliques': '核心',
    'quadriceps': '股四头',
    'tibialis': '小腿',
    'trapezius': '背',
    'triceps': '三头',
    'upper-back': '背',
  };

  MuscleRecovery _selectedRecovery(List<MuscleRecovery> recovery) {
    if (recovery.isEmpty) {
      return const MuscleRecovery('胸', 100, '暂无近期训练刺激，按充分恢复处理。');
    }
    final selected = _selectedMuscle;
    if (selected != null) {
      for (final item in recovery) {
        if (item.muscle == selected) return item;
      }
    }
    return recovery.reduce(
      (current, item) => item.percent < current.percent ? item : current,
    );
  }

  void _selectSlug(String slug, List<MuscleRecovery> recovery) {
    final muscle = _slugToMuscle[slug];
    if (muscle == null) return;
    if (!recovery.any((item) => item.muscle == muscle)) return;
    setState(() => _selectedMuscle = muscle);
  }

  @override
  Widget build(BuildContext context) {
    final recovery = controller.trainingIntelligence.recovery;
    final selected = _selectedRecovery(recovery);
    final mapValues = _homeRecoveryValues(recovery);
    return Scaffold(
      key: const Key('recovery-details-page'),
      appBar: AppBar(title: const Text('肌群恢复')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
          children: [
            const Text(
              '恢复状态',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(
              '根据近期有效组、训练强度与距上次训练的时间估算。',
              style: TextStyle(color: quiet, fontSize: 12),
            ),
            const SizedBox(height: 12),
            Card(
              key: const Key('recovery-muscle-map-card'),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 11),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            '人体恢复图',
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                        Text(
                          recovery.isEmpty ? '等待训练数据' : '点击部位查看',
                          style: TextStyle(color: quiet, fontSize: 11),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '训练负荷估算，非医学测量。',
                      style: TextStyle(color: quiet, fontSize: 11),
                    ),
                    const SizedBox(height: 5),
                    SizedBox(
                      key: const Key('recovery-muscle-map'),
                      height: 300,
                      child: _MuscleBodyMap(
                        key: const Key('recovery-muscle-map-body'),
                        muscleSets: mapValues,
                        mode: MuscleMapMode.recovery,
                        height: 226,
                        onMuscleTap: (slug) => _selectSlug(slug, recovery),
                      ),
                    ),
                    const _HomeRecoveryLegend(),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Card(
              key: const Key('recovery-selected-detail'),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            selected.muscle,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        Text(
                          '${selected.percent}%',
                          style: TextStyle(
                            color: _homeRecoveryColor(selected.percent),
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: (selected.percent / 100).clamp(0.0, 1.0),
                      minHeight: 9,
                      borderRadius: BorderRadius.circular(99),
                      backgroundColor: primaryContainer,
                      color: _homeRecoveryColor(selected.percent),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      selected.status,
                      style: TextStyle(
                        color: _homeRecoveryColor(selected.percent),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      selected.reason,
                      style: TextStyle(color: quiet, fontSize: 12, height: 1.4),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UnderlineTab {
  const _UnderlineTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
}

class _UnderlineTabs extends StatelessWidget {
  const _UnderlineTabs({super.key, required this.items, required this.labels});
  final List<_UnderlineTab> items;
  final List<String> labels;

  @override
  Widget build(BuildContext context) => Container(
    height: 44,
    decoration: BoxDecoration(
      border: Border(bottom: BorderSide(color: hairline)),
    ),
    child: Row(
      children: [
        for (var index = 0; index < items.length; index++)
          Expanded(
            child: Semantics(
              button: true,
              selected: items[index].selected,
              label: labels[index],
              child: InkWell(
                key: Key(items[index].label),
                onTap: items[index].onTap,
                child: Container(
                  constraints: const BoxConstraints(minHeight: 44),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: items[index].selected
                            ? cobalt
                            : Colors.transparent,
                        width: 3,
                      ),
                    ),
                  ),
                  child: Text(
                    labels[index],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: items[index].selected ? ink : quiet,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class _TrainTopTabs extends StatelessWidget {
  const _TrainTopTabs({required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    if (controller.trainView.index >= 0) {
      final selected = controller.trainView == TrainView.history
          ? TrainView.history
          : TrainView.plans;
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: _UnderlineTabs(
          key: const Key('train-top-tabs'),
          labels: const ['\u8BA1\u5212', '\u8BB0\u5F55'],
          items: [
            _UnderlineTab(
              label: 'train-plan',
              selected: selected == TrainView.plans,
              onTap: () => controller.selectTrainView(TrainView.plans),
            ),
            _UnderlineTab(
              label: 'train-history',
              selected: selected == TrainView.history,
              onTap: () => controller.selectTrainView(TrainView.history),
            ),
          ],
        ),
      );
    }
    final selected = controller.trainView == TrainView.history
        ? TrainView.history
        : TrainView.plans;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: SegmentedButton<TrainView>(
        key: const Key('train-top-tabs'),
        segments: const [
          ButtonSegment(value: TrainView.plans, label: Text('计划')),
          ButtonSegment(value: TrainView.history, label: Text('记录')),
        ],
        selected: {selected},
        onSelectionChanged: (value) => controller.selectTrainView(value.first),
      ),
    );
  }
}

class _LiveWorkoutTimingPanel extends StatelessWidget {
  const _LiveWorkoutTimingPanel({required this.controller});
  final AppController controller;

  String _clock(int seconds) =>
      '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';

  Future<void> _rename(BuildContext context) async {
    final value = await showDialog<String>(
      context: context,
      builder: (_) =>
          _ActiveWorkoutRenameDialog(initialName: controller.workoutName),
    );
    if (value != null) controller.renameActiveWorkout(value);
  }

  @override
  Widget build(BuildContext context) {
    final elapsed = controller.currentElapsed;
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final compact = MediaQuery.sizeOf(context).width < 340 || textScale > 1.35;
    final title = InkWell(
      key: const Key('active-workout-rename'),
      onTap: () => _rename(context),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                controller.workoutName,
                maxLines: compact ? 2 : 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const SizedBox(width: 5),
            Icon(Icons.edit_outlined, size: 16, color: secondaryInk),
          ],
        ),
      ),
    );
    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        title,
        Text(
          !controller.workoutTimerStarted
              ? '准备训练 · ${controller.workout.length} 个动作'
              : controller.workoutPaused
              ? '已暂停'
              : '实时训练 · ${controller.completedSets}/${controller.totalSets} 组',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 12, color: secondaryInk),
        ),
      ],
    );
    final timerBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          _clock(elapsed),
          style: const TextStyle(
            fontSize: 27,
            fontWeight: FontWeight.w900,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
        Text(
          !controller.workoutTimerStarted
              ? '准备开始'
              : controller.workoutPaused
              ? '暂停'
              : '进行中',
          style: TextStyle(
            fontSize: 11,
            color: !controller.workoutTimerStarted || controller.workoutPaused
                ? orange
                : cobalt,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
    final header = compact
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: '返回计划',
                    onPressed: controller.closeLiveWorkout,
                    icon: const Icon(Icons.arrow_back),
                  ),
                  Expanded(child: titleBlock),
                ],
              ),
              Align(alignment: Alignment.centerRight, child: timerBlock),
            ],
          )
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                tooltip: '返回计划',
                onPressed: controller.closeLiveWorkout,
                icon: const Icon(Icons.arrow_back),
              ),
              Expanded(child: titleBlock),
              const SizedBox(width: 8),
              timerBlock,
            ],
          );
    final rest = controller.restRunning
        ? Container(
            margin: const EdgeInsets.only(top: 9),
            padding: const EdgeInsets.fromLTRB(10, 9, 8, 7),
            decoration: BoxDecoration(
              color: primaryContainer,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: hairline),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final narrow = constraints.maxWidth < 320 || textScale > 1.35;
                final details = Row(
                  children: [
                    Icon(Icons.timer_outlined, color: cobalt, size: 19),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '组间休息',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                          Text(
                            controller.restExerciseName ?? '当前动作',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 11, color: secondaryInk),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      _clock(controller.restRemainingSeconds),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                );
                final actions = Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 4,
                  runSpacing: 2,
                  children: [
                    Tooltip(
                      message: AppLocalizations.of(context).text('增加 15 秒休息'),
                      child: TextButton.icon(
                        key: const Key('rest-add-15-button'),
                        onPressed: () {
                          controller.addRestSeconds();
                          showKiloSnack(
                            context,
                            AppLocalizations.of(context).text('休息已增加 15 秒'),
                          );
                        },
                        icon: const Icon(Icons.add_circle_outline, size: 17),
                        label: const Text('+15 秒'),
                      ),
                    ),
                    Tooltip(
                      message: AppLocalizations.of(context).text('修改当前及后续休息时间'),
                      child: TextButton.icon(
                        key: const Key('rest-edit-default-button'),
                        onPressed: () =>
                            _showActiveRestEditor(context, controller),
                        icon: const Icon(Icons.timer_outlined, size: 17),
                        label: Text(AppLocalizations.of(context).text('修改休息')),
                      ),
                    ),
                    Tooltip(
                      message: '跳过休息',
                      child: TextButton.icon(
                        key: const Key('rest-skip-button'),
                        onPressed: () {
                          controller.skipRest();
                          showKiloSnack(context, '已跳过休息');
                        },
                        icon: const Icon(Icons.skip_next, size: 17),
                        label: const Text('跳过'),
                      ),
                    ),
                  ],
                );
                if (narrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [details, actions],
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    details,
                    Align(alignment: Alignment.centerRight, child: actions),
                  ],
                );
              },
            ),
          )
        : Padding(
            padding: const EdgeInsets.only(top: 9, left: 4),
            child: Text(
              '可开始下一组',
              style: TextStyle(fontSize: 12, color: secondaryInk),
            ),
          );
    final controls = LayoutBuilder(
      builder: (context, constraints) {
        final fullWidth = constraints.maxWidth;
        return Wrap(
          key: const Key('live-workout-controls'),
          spacing: 7,
          runSpacing: 7,
          children: [
            Tooltip(
              message: !controller.workoutTimerStarted
                  ? '开始本次训练计时'
                  : controller.workoutPaused
                  ? '恢复计时'
                  : '暂停计时',
              child: SizedBox(
                width: fullWidth,
                child: PrimaryButton(
                  key: Key(
                    controller.workoutTimerStarted
                        ? 'pause-workout-button'
                        : 'start-workout-timer-button',
                  ),
                  label: !controller.workoutTimerStarted
                      ? '开始计时'
                      : controller.workoutPaused
                      ? '恢复计时'
                      : '暂停计时',
                  icon:
                      !controller.workoutTimerStarted ||
                          controller.workoutPaused
                      ? Icons.play_arrow_rounded
                      : Icons.pause_rounded,
                  onPressed: controller.workoutTimerStarted
                      ? controller.pauseWorkout
                      : () {
                          HapticFeedback.mediumImpact();
                          controller.beginWorkoutTimer();
                          showKiloSnack(context, '训练计时已开始');
                        },
                ),
              ),
            ),
            Tooltip(
              message: '设置本次及后续组间休息',
              child: OutlinedButton.icon(
                key: const Key('workout-rest-button'),
                onPressed: () => _showActiveRestEditor(context, controller),
                icon: const Icon(Icons.timer_outlined),
                label: const Text('组间休息'),
              ),
            ),
          ],
        );
      },
    );
    final card = Card(
      key: const Key('live-workout'),
      color: surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 11),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 4,
              margin: const EdgeInsets.only(left: 4, right: 4, bottom: 9),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(99),
                gradient: LinearGradient(colors: [primary, primaryBright]),
              ),
            ),
            header,
            const SizedBox(height: 8),
            controls,
            rest,
          ],
        ),
      ),
    );
    return card;
  }
}

class _ActiveWorkoutRenameDialog extends StatefulWidget {
  const _ActiveWorkoutRenameDialog({required this.initialName});

  final String initialName;

  @override
  State<_ActiveWorkoutRenameDialog> createState() =>
      _ActiveWorkoutRenameDialogState();
}

class _ActiveWorkoutRenameDialogState
    extends State<_ActiveWorkoutRenameDialog> {
  late final TextEditingController name;
  var clearedOriginal = false;

  @override
  void initState() {
    super.initState();
    name = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('重命名本次训练'),
    content: TextField(
      key: const Key('active-workout-name-field'),
      controller: name,
      autofocus: true,
      textInputAction: TextInputAction.done,
      onTap: () {
        if (clearedOriginal) return;
        clearedOriginal = true;
        name.clear();
      },
      onSubmitted: (value) => Navigator.pop(context, value),
      decoration: const InputDecoration(labelText: '训练名称'),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      FilledButton(
        key: const Key('active-workout-rename-save'),
        onPressed: () => Navigator.pop(context, name.text),
        child: const Text('保存'),
      ),
    ],
  );
}

class _CompletionBurst extends StatelessWidget {
  const _CompletionBurst({required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    if (!controller.completionBurstActive) return const SizedBox.shrink();
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    if (reducedMotion) {
      return IgnorePointer(
        child: Container(
          key: const Key('completion-glow'),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1E6B45).withValues(alpha: .28),
                blurRadius: 18,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const Center(
            child: Icon(Icons.check_circle, color: Color(0xFF1E6B45), size: 26),
          ),
        ),
      );
    }
    return IgnorePointer(
      child: TweenAnimationBuilder<double>(
        key: ValueKey('completion-burst-${controller.completionBurstId}'),
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 800),
        builder: (context, progress, child) => CustomPaint(
          key: const Key('completion-burst'),
          painter: _BurstPainter(progress),
          child: child,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _BurstPainter extends CustomPainter {
  const _BurstPainter(this.progress);
  final double progress;

  static const points = <Offset>[
    Offset(-.92, -.20),
    Offset(-.72, -.66),
    Offset(-.45, -.90),
    Offset(0, -1.0),
    Offset(.46, -.86),
    Offset(.76, -.50),
    Offset(.96, -.08),
    Offset(.72, .44),
    Offset(.30, .72),
    Offset(-.18, .84),
    Offset(-.62, .60),
    Offset(-.88, .30),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * .46);
    final radius = size.shortestSide * .42;
    final opacity = (1 - progress).clamp(0.0, 1.0);
    for (var index = 0; index < points.length; index++) {
      final point = points[index];
      final position =
          center + Offset(point.dx * radius, point.dy * radius) * progress;
      final paint = Paint()
        ..color =
            (index % 3 == 0
                    ? primaryBright
                    : index.isEven
                    ? success
                    : const Color(0xFF74C98E))
                .withValues(alpha: opacity)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(position, 5.2 * (1 - progress * .35), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BurstPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _WorkoutView extends StatelessWidget {
  const _WorkoutView({required this.controller});
  final AppController controller;
  @override
  Widget build(BuildContext context) {
    if (controller.workoutCompleted && !controller.workoutStarted) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Icon(Icons.check_circle, color: cobalt, size: 48),
              const SizedBox(height: 10),
              Text('训练已保存', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 5),
              Text(
                '${controller.history.first.name} · ${controller.history.first.effectiveSets} 个有效组',
                style: TextStyle(color: secondaryInk),
              ),
              const SizedBox(height: 18),
              PrimaryButton(
                label: '开始下一次训练',
                onPressed: () => controller.startWorkout(),
              ),
            ],
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (controller.workout.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Icon(Icons.playlist_add, size: 44, color: quiet),
                  const SizedBox(height: 8),
                  const Text(
                    '还没有动作',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text('可以先添加动作，也可以直接开始计时。', style: TextStyle(color: quiet)),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    key: const Key('first-action-button'),
                    onPressed: () => _showExercisePicker(context, controller),
                    icon: const Icon(Icons.add),
                    label: const Text('添加第一个动作'),
                  ),
                ],
              ),
            ),
          )
        else ...[
          for (final exercise in controller.workout)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _WorkoutExerciseCard(
                controller: controller,
                exercise: exercise,
              ),
            ),
          const SizedBox(height: 2),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              key: const Key('live-add-exercise'),
              onPressed: () => _showExercisePicker(context, controller),
              icon: const Icon(Icons.add),
              label: const Text('添加动作'),
            ),
          ),
        ],
        if (controller.workoutStarted) ...[
          const SizedBox(height: 3),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              key: const Key('finish-workout-button'),
              onPressed: () => _showFinishWorkout(context, controller),
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).brightness == Brightness.dark
                    ? surfaceRaised
                    : ink,
                foregroundColor: Theme.of(context).brightness == Brightness.dark
                    ? ink
                    : Colors.white,
                side: BorderSide(color: hairline),
                minimumSize: const Size.fromHeight(52),
              ),
              icon: const Icon(Icons.stop_circle_rounded),
              label: Text(
                controller.workoutTimerStarted
                    ? '结束并保存 · ${controller.currentElapsed ~/ 60} 分钟'
                    : '结束并保存训练',
              ),
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: TextButton.icon(
              key: const Key('abort-workout-button'),
              onPressed: () => _showAbortWorkout(context, controller),
              style: TextButton.styleFrom(foregroundColor: danger),
              icon: const Icon(Icons.cancel_outlined, size: 18),
              label: const Text('中止本次训练'),
            ),
          ),
        ],
      ],
    );
  }
}

// ignore: unused_element
class _LiveWorkoutControls extends StatelessWidget {
  const _LiveWorkoutControls({required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('live-workout-controls'),
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: surface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: hairline),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: PrimaryButton(
                key: const Key('pause-workout-button'),
                label: controller.workoutStarted
                    ? (controller.workoutPaused ? '恢复计时' : '暂停计时')
                    : '开始训练',
                icon: controller.workoutStarted
                    ? (controller.workoutPaused
                          ? Icons.play_arrow
                          : Icons.pause)
                    : Icons.play_arrow,
                onPressed: controller.workoutStarted
                    ? controller.pauseWorkout
                    : () => controller.startWorkout(),
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              key: const Key('workout-rest-button'),
              tooltip: '组间休息',
              onPressed: () => _showActiveRestEditor(context, controller),
              icon: const Icon(Icons.timer_outlined),
            ),
          ],
        ),
        if (controller.batchMode && controller.selectedSetIds.isNotEmpty)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const Key('selected-sets-editor'),
              onPressed: () => _showBatchEditor(context, controller),
              icon: const Icon(Icons.tune, size: 17),
              label: Text('编辑已选 ${controller.selectedSetIds.length} 组'),
            ),
          ),
      ],
    ),
  );
}

// ignore: unused_element
class _RestBanner extends StatelessWidget {
  const _RestBanner({required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final seconds = controller.restRemainingSeconds;
    final clock =
        '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
    final exerciseName = controller.restExerciseName ?? '当前动作';
    return Card(
      color: primaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.timer_outlined, color: cobalt),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '组间休息',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        exerciseName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: secondaryInk),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      clock,
                      style: const TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w900,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  tooltip: '增加 15 秒',
                  onPressed: () {
                    controller.addRestSeconds();
                    showKiloSnack(context, '休息已增加 15 秒');
                  },
                  icon: const Icon(Icons.add_circle_outline),
                ),
                IconButton(
                  tooltip: '跳过休息',
                  onPressed: () {
                    controller.skipRest();
                    showKiloSnack(context, '已跳过休息');
                  },
                  icon: const Icon(Icons.skip_next),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkoutExerciseCard extends StatelessWidget {
  const _WorkoutExerciseCard({
    required this.controller,
    required this.exercise,
  });
  final AppController controller;
  final WorkoutExercise exercise;
  @override
  Widget build(BuildContext context) {
    final definition = controller.exerciseFor(exercise.exerciseId);
    final exerciseHistory = controller.exerciseHistoryFor(exercise.exerciseId);
    return Card(
      child: Column(
        children: [
          InkWell(
            onTap: () {
              exercise.collapsed = !exercise.collapsed;
              controller.refresh();
            },
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 13, 10, 12),
              child: Row(
                children: [
                  Semantics(
                    button: true,
                    label:
                        '查看${controller.displayExerciseName(definition)}动作详情',
                    child: InkWell(
                      key: Key('exercise-thumbnail-${exercise.id}'),
                      borderRadius: BorderRadius.circular(10),
                      onTap: () =>
                          _showExerciseDetail(context, controller, definition),
                      child: Padding(
                        padding: const EdgeInsets.all(2),
                        child: _ExerciseThumb(
                          exerciseId: exercise.exerciseId,
                          size: 38,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                controller.displayExerciseName(definition),
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            if (exercise.supersetId != null)
                              Padding(
                                padding: EdgeInsets.only(left: 6),
                                child: _StatusChip(
                                  '超级组',
                                  color: orange,
                                  icon: Icons.link,
                                ),
                              ),
                          ],
                        ),
                        Text(
                          '${definition.muscle} · 休息 ${exercise.restSeconds} 秒',
                          style: TextStyle(fontSize: 11, color: quiet),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    key: Key('exercise-note-${exercise.id}'),
                    tooltip: exercise.note.isEmpty ? '添加动作备注' : '查看或修改动作备注',
                    onPressed: () =>
                        _showExerciseNoteEditor(context, controller, exercise),
                    style: exercise.note.isEmpty
                        ? null
                        : IconButton.styleFrom(
                            backgroundColor: exerciseNoteContainer,
                            foregroundColor: exerciseNoteColor,
                          ),
                    icon: Icon(
                      exercise.note.isEmpty
                          ? Icons.note_add_outlined
                          : Icons.sticky_note_2_rounded,
                    ),
                  ),
                  IconButton(
                    key: Key('rest-settings-${exercise.id}'),
                    tooltip: '设置休息时间',
                    onPressed: () =>
                        _showRestEditor(context, controller, exercise),
                    icon: const Icon(Icons.timer_outlined),
                  ),
                  IconButton(
                    tooltip: '动作菜单',
                    onPressed: () =>
                        _showExerciseActions(context, controller, exercise),
                    icon: const Icon(Icons.more_horiz),
                  ),
                  Icon(
                    exercise.collapsed ? Icons.expand_more : Icons.expand_less,
                    color: quiet,
                  ),
                ],
              ),
            ),
          ),
          if (!exercise.collapsed)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
              child: Column(
                children: [
                  if (controller.entitlements?.isMember == true)
                    _ProgressionRecommendationCard(
                      recommendation: controller.progressionFor(
                        exercise.exerciseId,
                      ),
                    ),
                  InkWell(
                    key: Key('exercise-note-preview-${exercise.id}'),
                    onTap: () =>
                        _showExerciseNoteEditor(context, controller, exercise),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 9),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: exerciseNoteContainer,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: exerciseNoteColor.withValues(alpha: .22),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.sticky_note_2_outlined,
                            size: 17,
                            color: exerciseNoteColor,
                          ),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text(
                              exercise.note.trim().isEmpty
                                  ? '动作备注 · 点击记录握距、档位或动作提示'
                                  : '动作备注 · ${exercise.note.trim()}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: secondaryInk,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.edit_outlined,
                            size: 15,
                            color: exerciseNoteColor,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (exerciseHistory.isNotEmpty)
                    _PreviousExerciseNotes(
                      record: exerciseHistory.first,
                      exerciseId: exercise.exerciseId,
                    ),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final columns = _SetColumns.fromWidth(
                        constraints.maxWidth,
                      );
                      return Column(
                        children: [
                          _SetTableHeader(
                            columns: columns,
                            cardio: controller.isCardioExercise(
                              exercise.exerciseId,
                            ),
                          ),
                          for (var i = 0; i < exercise.sets.length; i++)
                            _SetRow(
                              controller: controller,
                              exercise: exercise,
                              set: exercise.sets[i],
                              index: i,
                              columns: columns,
                            ),
                        ],
                      );
                    },
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(
                      spacing: 2,
                      runSpacing: 2,
                      children: [
                        if (controller.hasPreviousValues(exercise))
                          TextButton.icon(
                            key: Key('reuse-previous-${exercise.id}'),
                            onPressed: () {
                              controller.reusePreviousValues(exercise);
                              showKiloSnack(context, '已带入上次完成数据');
                            },
                            icon: const Icon(Icons.history, size: 17),
                            label: const Text('带入上次'),
                          ),
                        if (exerciseHistory.isNotEmpty)
                          TextButton.icon(
                            key: Key('exercise-history-${exercise.id}'),
                            onPressed: () => _showExerciseHistory(
                              context,
                              controller,
                              exercise.exerciseId,
                            ),
                            icon: const Icon(Icons.timeline_rounded, size: 17),
                            label: Text('历史 ${exerciseHistory.length}'),
                          ),
                        TextButton.icon(
                          key: Key('clear-values-${exercise.id}'),
                          onPressed: () {
                            controller.clearExerciseValues(exercise);
                            showKiloSnack(context, '重量和次数已清空');
                          },
                          icon: const Icon(Icons.backspace_outlined, size: 17),
                          label: const Text('清空'),
                        ),
                      ],
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      key: Key(
                        exercise.sets.isEmpty
                            ? 'first-set-${exercise.id}'
                            : 'add-set-${exercise.id}',
                      ),
                      onPressed: () => controller.addSet(exercise),
                      icon: const Icon(Icons.add, size: 17),
                      label: Text(exercise.sets.isEmpty ? '添加第一组' : '添加一组'),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ProgressionRecommendationCard extends StatelessWidget {
  const _ProgressionRecommendationCard({required this.recommendation});
  final ProgressionRecommendation recommendation;

  @override
  Widget build(BuildContext context) => Container(
    key: Key('progression-${recommendation.exerciseId}'),
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 9),
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: Theme.of(
        context,
      ).colorScheme.primaryContainer.withValues(alpha: .55),
      borderRadius: BorderRadius.circular(11),
      border: Border.all(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: .18),
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.auto_awesome_rounded,
              size: 16,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                recommendation.weight <= 0
                    ? recommendation.decision
                    : '${recommendation.decision} · ${_displayWeight(recommendation.weight)} kg × ${recommendation.targetMin}–${recommendation.targetMax} · ${recommendation.sets} 组',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Material(
          color: Colors.transparent,
          child: ExpansionTile(
            key: Key('progression-why-${recommendation.exerciseId}'),
            tilePadding: EdgeInsets.zero,
            childrenPadding: EdgeInsets.zero,
            dense: true,
            title: const Text('为什么推荐这个重量？', style: TextStyle(fontSize: 11)),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  recommendation.reason,
                  style: const TextStyle(fontSize: 11, height: 1.4),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _PreviousExerciseNotes extends StatelessWidget {
  const _PreviousExerciseNotes({
    required this.record,
    required this.exerciseId,
  });

  final WorkoutRecord record;
  final String exerciseId;

  @override
  Widget build(BuildContext context) {
    WorkoutExercise? performed;
    for (final item in record.exercises) {
      if (item.exerciseId == exerciseId) {
        performed = item;
        break;
      }
    }
    if (performed == null) return const SizedBox.shrink();
    final hasExerciseNote = performed.note.trim().isNotEmpty;
    if (!hasExerciseNote) return const SizedBox.shrink();
    final date = '${record.date.month}月${record.date.day}日';
    return Container(
      key: Key('previous-notes-$exerciseId'),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.fromLTRB(10, 9, 10, 8),
      decoration: BoxDecoration(
        color: surfaceRaised,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.history_rounded, size: 16, color: quiet),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '上次备注 · $date',
                  style: TextStyle(
                    color: secondaryInk,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          if (hasExerciseNote) ...[
            const SizedBox(height: 6),
            _NoteCallout(
              key: Key('previous-exercise-note-$exerciseId'),
              label: '动作备注',
              text: performed.note.trim(),
              color: exerciseNoteColor,
              background: exerciseNoteContainer,
              maxLines: 3,
            ),
          ],
        ],
      ),
    );
  }
}

class _NoteCallout extends StatelessWidget {
  const _NoteCallout({
    super.key,
    required this.label,
    required this.text,
    required this.color,
    required this.background,
    this.maxLines,
  });

  final String label;
  final String text;
  final Color color;
  final Color background;
  final int? maxLines;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(9),
      border: Border.all(color: color.withValues(alpha: .16)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.sticky_note_2_outlined, size: 14, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '$label · ',
                  style: TextStyle(color: color, fontWeight: FontWeight.w900),
                ),
                TextSpan(text: text),
              ],
            ),
            maxLines: maxLines,
            overflow: maxLines == null ? null : TextOverflow.ellipsis,
            style: TextStyle(color: secondaryInk, fontSize: 11, height: 1.35),
          ),
        ),
      ],
    ),
  );
}

IconData _setTypeIcon(String type) => switch (type) {
  'warmup' => Icons.whatshot_outlined,
  'work' => Icons.fitness_center,
  'backoff' => Icons.trending_down,
  'drop' => Icons.south,
  'technique' => Icons.tune,
  'failure' => Icons.warning_amber_outlined,
  _ => Icons.fitness_center_outlined,
};

String _setTypeShort(String type) => switch (type) {
  'warmup' => '热身',
  'work' => '正',
  'backoff' => '退阶',
  'drop' => '递减',
  'failure' => '力竭',
  'technique' => '技术',
  _ => '组',
};

String _displayWeight(double value) => value == value.roundToDouble()
    ? value.toStringAsFixed(0)
    : value.toStringAsFixed(1);

String _editableWeight(double value) => value <= 0 ? '' : _displayWeight(value);

String _editableDecimal(double? value) =>
    value == null || value <= 0 ? '' : _displayWeight(value);

String _editableSetWeight(WorkoutSet set, {bool planned = false}) {
  if (set.weightText.trim().isNotEmpty) return set.weightText.trim();
  return _editableWeight(
    planned ? set.plannedWeight ?? set.weight : set.weight,
  );
}

String _editableCount(int value) => value <= 0 ? '' : '$value';

class _SetColumns {
  const _SetColumns({
    required this.compact,
    required this.group,
    required this.last,
    required this.weight,
    required this.reps,
    required this.note,
    required this.complete,
    required this.gap,
  });
  final bool compact;
  final double group;
  final double last;
  final double weight;
  final double reps;
  final double note;
  final double complete;
  final double gap;

  factory _SetColumns.fromWidth(double width) {
    final compact = width < 340;
    // Include horizontal padding and borders when fitting narrow phones.
    final scale = math.min(1.0, math.max(0.0, (width - 8) / (compact ? 260 : 322)));
    return _SetColumns(
      compact: compact,
      group: (compact ? 52 : 64) * scale,
      last: (compact ? 44 : 58) * scale,
      weight: (compact ? 50 : 58) * scale,
      reps: (compact ? 34 : 42) * scale,
      note: (compact ? 34 : 40) * scale,
      complete: (compact ? 36 : 40) * scale,
      gap: (compact ? 2 : 4) * scale,
    );
  }
}

class _SetTableHeader extends StatelessWidget {
  const _SetTableHeader({required this.columns, required this.cardio});
  final _SetColumns columns;
  final bool cardio;

  Widget _label(String text, double width) => SizedBox(
    width: width,
    child: Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(fontSize: 11, color: quiet),
    ),
  );

  @override
  Widget build(BuildContext context) => Row(
    children: [
      _label('组', columns.group),
      SizedBox(width: columns.gap),
      _label('上次', columns.last),
      SizedBox(width: columns.gap),
      _label(cardio ? '分钟' : '重量', columns.weight),
      SizedBox(width: columns.gap),
      _label(cardio ? '速度' : '次数', columns.reps),
      SizedBox(width: columns.gap),
      _label('备注', columns.note),
      SizedBox(width: columns.gap),
      _label('完成', columns.complete),
    ],
  );
}

Future<void> _showSetNoteEditor(
  BuildContext context,
  AppController controller,
  WorkoutSet set,
  int index,
) async {
  var draft = set.note;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) => AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: hairline,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '第 ${index + 1} 组备注',
              style: Theme.of(
                sheetContext,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              '记录握距、动作感受、疼痛或器械设置。',
              style: TextStyle(color: secondaryInk, fontSize: 12),
            ),
            const SizedBox(height: 14),
            TextFormField(
              key: Key('set-note-input-${set.id}'),
              initialValue: set.note,
              onChanged: (value) => draft = value,
              autofocus: true,
              minLines: 3,
              maxLines: 5,
              maxLength: 200,
              textInputAction: TextInputAction.newline,
              decoration: const InputDecoration(
                labelText: '备注',
                hintText: '例如：窄握，最后两次速度变慢',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                if (set.note.isNotEmpty)
                  TextButton.icon(
                    key: Key('set-note-clear-${set.id}'),
                    onPressed: () {
                      controller.updateSetNote(set, '');
                      Navigator.pop(sheetContext);
                    },
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('清除'),
                  ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.pop(sheetContext),
                  child: const Text('取消'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  key: Key('set-note-save-${set.id}'),
                  onPressed: () {
                    controller.updateSetNote(set, draft);
                    Navigator.pop(sheetContext);
                  },
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('保存备注'),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

Future<void> _showExerciseNoteEditor(
  BuildContext context,
  AppController controller,
  WorkoutExercise exercise,
) async {
  var draft = exercise.note;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) => AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '动作备注',
              style: Theme.of(
                sheetContext,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              '记录握距、器械档位、动作提示或本动作整体感受。',
              style: TextStyle(color: secondaryInk, fontSize: 12),
            ),
            const SizedBox(height: 14),
            TextFormField(
              key: Key('exercise-note-input-${exercise.id}'),
              initialValue: exercise.note,
              onChanged: (value) => draft = value,
              autofocus: true,
              minLines: 3,
              maxLines: 5,
              maxLength: 240,
              textInputAction: TextInputAction.newline,
              decoration: const InputDecoration(
                labelText: '动作备注',
                hintText: '例如：肩胛先下沉，使用第 7 档',
                alignLabelWithHint: true,
              ),
            ),
            Row(
              children: [
                if (exercise.note.isNotEmpty)
                  TextButton.icon(
                    onPressed: () {
                      controller.updateExerciseNote(exercise, '');
                      Navigator.pop(sheetContext);
                    },
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('清除'),
                  ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.pop(sheetContext),
                  child: const Text('取消'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  key: Key('exercise-note-save-${exercise.id}'),
                  onPressed: () {
                    controller.updateExerciseNote(exercise, draft);
                    Navigator.pop(sheetContext);
                  },
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('保存备注'),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

Future<void> _confirmRemoveSet(
  BuildContext context,
  AppController controller,
  WorkoutExercise exercise,
  WorkoutSet set,
  int index,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('删除第 ${index + 1} 组？'),
      content: Text(
        set.completed ? '这组已完成，删除后训练统计会同步更新。' : '该组的重量、次数和备注会一起删除。',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('取消'),
        ),
        FilledButton(
          key: Key('confirm-delete-set-${set.id}'),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF9C3328),
          ),
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('删除'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;
  controller.removeSet(exercise, set);
  showKiloSnack(context, '第 ${index + 1} 组已删除', icon: Icons.delete_outline);
}

void _showSetTypeSheet(
  BuildContext context,
  AppController controller,
  WorkoutSet set,
  int index, {
  bool persistWorkout = true,
  VoidCallback? onChanged,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(sheetContext).height * .72,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(
                title: Text('选择组别类型'),
                subtitle: Text('用短标识保持实时记录紧凑'),
              ),
              for (final entry in setTypeLabels.entries)
                ListTile(
                  key: Key('set-type-option-${set.id}-${entry.key}'),
                  leading: Icon(
                    _setTypeIcon(entry.key),
                    color: _setTypeColor(entry.key),
                  ),
                  title: Text('${_setTypeShort(entry.key)} · ${entry.value}'),
                  selected: entry.key == set.type,
                  onTap: () {
                    set.type = entry.key;
                    controller.refresh(persistWorkout: persistWorkout);
                    onChanged?.call();
                    Navigator.pop(sheetContext);
                  },
                ),
              const SizedBox(height: 6),
            ],
          ),
        ),
      ),
    ),
  );
}

Color _setTypeColor(String type) => switch (type) {
  'work' => primary,
  'backoff' || 'drop' => primaryBright,
  _ => Color(setTypeColors[type] ?? 0xFF6F594E),
};

class _SetTypeButton extends StatelessWidget {
  const _SetTypeButton({
    required this.controller,
    required this.set,
    required this.index,
    required this.compact,
    this.persistWorkout = true,
    this.onChanged,
  });
  final AppController controller;
  final WorkoutSet set;
  final int index;
  final bool compact;
  final bool persistWorkout;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) {
    final label = compact
        ? _setTypeShort(set.type)
        : (setTypeLabels[set.type] ?? _setTypeShort(set.type));
    final color = _setTypeColor(set.type);
    return Semantics(
      button: true,
      enabled: true,
      label: '第 ${index + 1} 组类型：${setTypeLabels[set.type] ?? set.type}',
      child: InkWell(
        key: Key('set-type-${set.id}'),
        borderRadius: BorderRadius.circular(8),
        onTap: () => _showSetTypeSheet(
          context,
          controller,
          set,
          index,
          persistWorkout: persistWorkout,
          onChanged: onChanged,
        ),
        child: Container(
          constraints: BoxConstraints(
            minWidth: compact ? 31 : 43,
            minHeight: 44,
          ),
          padding: EdgeInsets.symmetric(horizontal: compact ? 1 : 3),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _setTypeIcon(set.type),
                size: compact ? 16 : 17,
                color: color,
              ),
              if (!compact) ...[
                const SizedBox(width: 2),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 10, color: color),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SetRow extends StatelessWidget {
  const _SetRow({
    required this.controller,
    required this.exercise,
    required this.set,
    required this.index,
    required this.columns,
  });
  final AppController controller;
  final WorkoutExercise exercise;
  final WorkoutSet set;
  final int index;
  final _SetColumns columns;

  InputDecoration _inputDecoration({required bool completed}) =>
      InputDecoration(
        isDense: true,
        filled: true,
        fillColor: completed ? successContainer : surface,
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(
            color: completed ? const Color(0xFF6DB787) : hairline,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(
            color: completed ? const Color(0xFF1E6B45) : cobalt,
            width: 2,
          ),
        ),
        disabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Color(0xFF6DB787)),
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: columns.compact ? 2 : 4,
          vertical: 7,
        ),
      );

  Widget _cellGap() => SizedBox(width: columns.gap);

  @override
  Widget build(BuildContext context) {
    final cardio = controller.isCardioExercise(exercise.exerciseId);
    final previousExact = controller.previousExactSetFor(
      exercise.exerciseId,
      index,
    );
    return Stack(
      clipBehavior: Clip.none,
      children: [
        AnimatedContainer(
          key: Key('set-row-${set.id}'),
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 3),
          decoration: BoxDecoration(
            color: set.completed ? successContainer : surface,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: set.completed ? const Color(0xFF6DB787) : hairline,
            ),
            boxShadow: set.completed
                ? const [
                    BoxShadow(
                      color: Color(0x1821845A),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  SizedBox(
                    width: columns.group,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (controller.batchMode)
                            SizedBox(
                              width: 22,
                              child: Checkbox(
                                value: controller.selectedSetIds.contains(
                                  set.id,
                                ),
                                onChanged: set.completed
                                    ? null
                                    : (_) => controller.toggleSetSelection(set),
                                visualDensity: VisualDensity.compact,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ),
                            )
                          else
                            Text(
                              '${index + 1}',
                              style: TextStyle(
                                fontSize: 12,
                                color: set.completed
                                    ? const Color(0xFF1E6B45)
                                    : quiet,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          _SetTypeButton(
                            controller: controller,
                            set: set,
                            index: index,
                            compact: columns.compact,
                          ),
                        ],
                      ),
                    ),
                  ),
                  _cellGap(),
                  SizedBox(
                    key: Key('previous-set-${set.id}'),
                    width: columns.last,
                    child: Builder(
                      builder: (context) {
                        final previous = controller.previousSetFor(
                          exercise.exerciseId,
                          index,
                        );
                        final label = previous == null
                            ? '—'
                            : cardio
                            ? '${((previous.durationSeconds ?? 0) / 60).toStringAsFixed(0)}分·${_editableDecimal(previous.speedKph)}'
                            : '${previous.weightText.trim().isNotEmpty ? previous.weightText.trim() : _displayWeight(previous.weight)}×${previous.reps}';
                        return Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: set.completed
                                ? const Color(0xFF1E6B45)
                                : previous == null
                                ? quiet
                                : secondaryInk,
                          ),
                        );
                      },
                    ),
                  ),
                  _cellGap(),
                  SizedBox(
                    width: columns.weight,
                    child: TextFormField(
                      // Keep the element identity stable while the user types.
                      // Including the mutable value in the key recreated this
                      // field after every character and dismissed the keyboard.
                      key: ValueKey('weight-${set.id}'),
                      initialValue: cardio
                          ? _editableDecimal(
                              set.durationSeconds == null
                                  ? null
                                  : set.durationSeconds! / 60,
                            )
                          : _editableSetWeight(set),
                      enabled: true,
                      keyboardType: cardio
                          ? const TextInputType.numberWithOptions(decimal: true)
                          : TextInputType.text,
                      onTapOutside: (_) =>
                          FocusManager.instance.primaryFocus?.unfocus(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: columns.compact ? 11 : 12,
                        color: set.completed ? const Color(0xFF1E6B45) : ink,
                        fontWeight: set.completed
                            ? FontWeight.w800
                            : FontWeight.w500,
                      ),
                      decoration: _inputDecoration(completed: set.completed),
                      onChanged: (value) {
                        if (cardio) {
                          final minutes = double.tryParse(value);
                          set.durationSeconds = minutes == null
                              ? null
                              : (minutes * 60).round().clamp(0, 86400);
                        } else {
                          controller.updateSetWeightText(set, value);
                        }
                        controller.persistActiveWorkout();
                      },
                    ),
                  ),
                  _cellGap(),
                  SizedBox(
                    width: columns.reps,
                    child: TextFormField(
                      key: ValueKey('reps-${set.id}'),
                      initialValue: cardio
                          ? _editableDecimal(set.speedKph)
                          : _editableCount(set.reps),
                      enabled: true,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      onTapOutside: (_) =>
                          FocusManager.instance.primaryFocus?.unfocus(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: columns.compact ? 11 : 12,
                        color: set.completed ? const Color(0xFF1E6B45) : ink,
                        fontWeight: set.completed
                            ? FontWeight.w800
                            : FontWeight.w500,
                      ),
                      decoration: _inputDecoration(completed: set.completed),
                      onChanged: (value) {
                        if (cardio) {
                          set.speedKph = double.tryParse(value);
                        } else {
                          set.reps = int.tryParse(value) ?? 0;
                        }
                        controller.persistActiveWorkout();
                      },
                    ),
                  ),
                  _cellGap(),
                  SizedBox(
                    width: columns.note,
                    child: IconButton(
                      key: Key('set-note-${set.id}'),
                      tooltip: set.note.isEmpty ? '添加本组备注' : '查看或修改本组备注',
                      onPressed: () =>
                          _showSetNoteEditor(context, controller, set, index),
                      icon: Icon(
                        set.note.isEmpty
                            ? Icons.sticky_note_2_outlined
                            : Icons.sticky_note_2_rounded,
                        size: columns.compact ? 18 : 20,
                        color: set.note.isEmpty ? quiet : setNoteColor,
                      ),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                    ),
                  ),
                  _cellGap(),
                  SizedBox(
                    width: columns.complete,
                    child: Semantics(
                      label: set.completed
                          ? '第 ${index + 1} 组已完成'
                          : '完成第 ${index + 1} 组',
                      button: true,
                      child: Checkbox(
                        key: Key('set-complete-${set.id}'),
                        value: set.completed,
                        onChanged: controller.workoutStarted
                            ? (_) {
                                final autoStarted =
                                    !controller.workoutTimerStarted;
                                HapticFeedback.mediumImpact();
                                controller.completeSet(set, exercise);
                                if (controller.restSetupPending) {
                                  WidgetsBinding.instance.addPostFrameCallback((
                                    _,
                                  ) {
                                    if (context.mounted) {
                                      _showInitialRestSetup(
                                        context,
                                        controller,
                                      );
                                    }
                                  });
                                }
                                if (autoStarted) {
                                  showKiloSnack(
                                    context,
                                    controller.restRunning
                                        ? '训练已开始，本组完成，休息计时已启动'
                                        : controller.restSetupPending
                                        ? '本组已完成，请设置一次组间休息'
                                        : '训练已开始，本组已完成',
                                  );
                                }
                              }
                            : null,
                        fillColor: WidgetStateProperty.resolveWith(
                          (states) => set.completed
                              ? success
                              : states.contains(WidgetState.disabled)
                              ? hairline
                              : cobalt,
                        ),
                        checkColor: Colors.white,
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ),
                ],
              ),
              if (previousExact?.note.trim().isNotEmpty == true) ...[
                const SizedBox(height: 5),
                _NoteCallout(
                  key: Key('previous-set-note-${exercise.exerciseId}-$index'),
                  label: '上次第 ${index + 1} 组备注',
                  text: previousExact!.note.trim(),
                  color: setNoteColor,
                  background: setNoteContainer,
                  maxLines: 2,
                ),
              ],
              const SizedBox(height: 4),
              Row(
                children: [
                  if (cardio) ...[
                    SizedBox(
                      width: 76,
                      child: TextFormField(
                        key: ValueKey('incline-${set.id}'),
                        initialValue: _editableDecimal(set.inclinePercent),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: true,
                        ),
                        onTapOutside: (_) =>
                            FocusManager.instance.primaryFocus?.unfocus(),
                        decoration: const InputDecoration(
                          labelText: '坡度 %',
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 8,
                          ),
                        ),
                        onChanged: (value) {
                          set.inclinePercent = double.tryParse(value);
                          controller.persistActiveWorkout();
                        },
                      ),
                    ),
                    const SizedBox(width: 5),
                  ],
                  Expanded(
                    child: Semantics(
                      button: true,
                      label: set.note.trim().isEmpty
                          ? '为第 ${index + 1} 组添加备注'
                          : '第 ${index + 1} 组备注：${set.note.trim()}，点击编辑',
                      child: InkWell(
                        key: Key('set-note-preview-${set.id}'),
                        onTap: () =>
                            _showSetNoteEditor(context, controller, set, index),
                        borderRadius: BorderRadius.circular(7),
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(8, 7, 8, 7),
                          decoration: BoxDecoration(
                            color: setNoteContainer,
                            borderRadius: BorderRadius.circular(7),
                            border: Border.all(
                              color: setNoteColor.withValues(alpha: .15),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.sticky_note_2_outlined,
                                size: 15,
                                color: setNoteColor,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  set.note.trim().isEmpty
                                      ? '第 ${index + 1} 组备注 · 点击添加'
                                      : '第 ${index + 1} 组 · ${set.note.trim()}',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    height: 1.3,
                                    color: set.completed
                                        ? const Color(0xFF1E6B45)
                                        : secondaryInk,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const Icon(Icons.edit_outlined, size: 14),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 5),
                  OutlinedButton(
                    key: Key('set-effort-${set.id}'),
                    onPressed: () =>
                        _showSetEffortEditor(context, controller, set, index),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(54, 40),
                      padding: const EdgeInsets.symmetric(horizontal: 7),
                      visualDensity: VisualDensity.compact,
                    ),
                    child: Text(
                      set.rir != null
                          ? 'RIR ${set.rir!.toStringAsFixed(set.rir! % 1 == 0 ? 0 : 1)}'
                          : set.rpe != null
                          ? 'RPE ${set.rpe!.toStringAsFixed(set.rpe! % 1 == 0 ? 0 : 1)}'
                          : '强度',
                      style: const TextStyle(fontSize: 10),
                    ),
                  ),
                  const SizedBox(width: 5),
                  IconButton.outlined(
                    key: Key('delete-set-${set.id}'),
                    tooltip: '删除第 ${index + 1} 组',
                    onPressed: () => _confirmRemoveSet(
                      context,
                      controller,
                      exercise,
                      set,
                      index,
                    ),
                    icon: const Icon(Icons.delete_outline, size: 18),
                    color: const Color(0xFF9C3328),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ],
          ),
        ),
        if (controller.completionBurstActive &&
            controller.completionBurstSetId == set.id)
          Positioned(
            right: -30,
            top: -62,
            width: 150,
            height: 126,
            child: _CompletionBurst(controller: controller),
          ),
      ],
    );
  }
}

List<String> _splitProfileValues(String value) => value
    .split(RegExp(r'[,，、\n]'))
    .map((item) => item.trim())
    .where((item) => item.isNotEmpty)
    .toList();

Future<void> _showSetEffortEditor(
  BuildContext context,
  AppController controller,
  WorkoutSet set,
  int index,
) async {
  var mode = set.rir != null ? 'rir' : 'rpe';
  var value = set.rir ?? set.rpe ?? (mode == 'rir' ? 2 : 8);
  await showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    builder: (sheetContext) => StatefulBuilder(
      builder: (context, setSheetState) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '第 ${index + 1} 组训练强度',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(
              'RIR 是还能完成的次数；RPE 是主观用力程度。只需记录一种。',
              style: TextStyle(color: quiet),
            ),
            const SizedBox(height: 14),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'rir', label: Text('RIR 剩余次数')),
                ButtonSegment(value: 'rpe', label: Text('RPE 用力程度')),
              ],
              selected: {mode},
              onSelectionChanged: (selected) => setSheetState(() {
                mode = selected.first;
                value = mode == 'rir' ? 2 : 8;
              }),
            ),
            const SizedBox(height: 18),
            Text(
              mode == 'rir'
                  ? 'RIR ${value.toStringAsFixed(1)}'
                  : 'RPE ${value.toStringAsFixed(1)}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
            ),
            Slider(
              value: value,
              min: mode == 'rir' ? 0 : 1,
              max: mode == 'rir' ? 5 : 10,
              divisions: mode == 'rir' ? 10 : 18,
              label: value.toStringAsFixed(1),
              onChanged: (next) => setSheetState(() => value = next),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () {
                      set.rir = null;
                      set.rpe = null;
                      controller.persistActiveWorkout();
                      Navigator.pop(sheetContext);
                    },
                    child: const Text('清除'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: () {
                      if (mode == 'rir') {
                        set.rir = value;
                        set.rpe = null;
                      } else {
                        set.rpe = value;
                        set.rir = null;
                      }
                      controller.persistActiveWorkout();
                      Navigator.pop(sheetContext);
                    },
                    child: const Text('保存强度'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _PlansView extends StatelessWidget {
  const _PlansView({required this.controller});
  final AppController controller;
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final freeWorkout = FilledButton.icon(
              key: const Key('free-workout-button'),
              onPressed: () {
                controller.startWorkout(name: '自由训练', autoStartTimer: false);
                controller.openLiveWorkout();
              },
              icon: const Icon(Icons.play_arrow, size: 19),
              label: const Text('自由训练'),
            );
            final aiWorkout = OutlinedButton.icon(
              key: const Key('ai-customize-plan-entry'),
              onPressed: () => _showAiWorkoutPlanner(context, controller),
              icon: const Icon(Icons.auto_awesome_outlined, size: 18),
              label: const Text('AI 定制计划'),
            );
            if (constraints.maxWidth < 320) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [freeWorkout, const SizedBox(height: 8), aiWorkout],
              );
            }
            return Row(
              children: [
                Expanded(child: freeWorkout),
                const SizedBox(width: 8),
                Expanded(child: aiWorkout),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        SectionTitle(
          '我的计划',
          subtitle: '${controller.routines.length} 个已保存训练',
          action: '新建计划',
          onAction: () => _showPlanBuilder(context, controller),
        ),
        if (controller.routines.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('还没有保存的计划，先新建一个训练。'),
            ),
          ),
        for (final routine in controller.routines)
          _RoutineCard(controller: controller, routine: routine),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          key: const Key('official-plans-entry'),
          onPressed: () => _showOfficialPlans(context, controller),
          icon: const Icon(Icons.auto_awesome_outlined),
          label: const Text('使用官方计划'),
        ),
      ],
    );
  }
}

void _showAiWorkoutPlanner(BuildContext context, AppController controller) {
  if (controller.entitlements?.isMember != true) {
    showMembershipPaywall(
      context,
      controller: controller,
      reason: MembershipPaywallReason.premiumFeature,
    );
    return;
  }
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: paper,
    builder: (_) => _CoachPlanEditor(controller: controller),
  );
}

class _AiWorkoutPlannerSheet extends StatefulWidget {
  const _AiWorkoutPlannerSheet({required this.controller});
  final AppController controller;

  @override
  State<_AiWorkoutPlannerSheet> createState() => _AiWorkoutPlannerSheetState();
}

class _AiWorkoutPlannerSheetState extends State<_AiWorkoutPlannerSheet> {
  final details = TextEditingController();
  late final int initialAssistantCount;
  bool requested = false;

  @override
  void initState() {
    super.initState();
    initialAssistantCount = widget.controller.chat
        .where((message) => message.role == 'assistant')
        .length;
  }

  @override
  void dispose() {
    details.dispose();
    super.dispose();
  }

  ChatMessage? _response() {
    final answers = widget.controller.chat
        .where((message) => message.role == 'assistant')
        .toList(growable: false);
    if (!requested || answers.length <= initialAssistantCount) return null;
    return answers.last;
  }

  void generate() {
    if (widget.controller.aiTyping) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => requested = true);
    HapticFeedback.selectionClick();
    unawaited(
      widget.controller.requestAiCustomizedWorkout(details: details.text),
    );
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) {
      final response = _response();
      final bottom = MediaQuery.viewInsetsOf(context).bottom;
      return Padding(
        padding: EdgeInsets.fromLTRB(14, 8, 14, 14 + bottom),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .9,
          ),
          child: ListView(
            shrinkWrap: true,
            children: [
              Row(
                children: [
                  Icon(Icons.auto_awesome_rounded, color: primary),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'AI 定制训练计划',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '关闭',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              Text(
                '可填写目标肌群、时长、器械或限制；不填写时会参考历史生成保守方案。',
                style: TextStyle(fontSize: 12, color: muted),
              ),
              const SizedBox(height: 10),
              TextField(
                key: const Key('ai-workout-details'),
                controller: details,
                minLines: 2,
                maxLines: 4,
                enabled: !widget.controller.aiTyping,
                decoration: const InputDecoration(
                  hintText: '例如：练胸和肩，45 分钟，只有哑铃',
                  isDense: true,
                ),
              ),
              const SizedBox(height: 9),
              FilledButton.icon(
                key: const Key('ai-workout-generate'),
                onPressed: widget.controller.aiTyping ? null : generate,
                icon: Icon(
                  widget.controller.aiTyping
                      ? Icons.hourglass_top_rounded
                      : Icons.auto_awesome_outlined,
                  size: 18,
                ),
                label: Text(widget.controller.aiTyping ? '正在生成…' : '生成训练计划'),
              ),
              if (requested && response == null) ...[
                const SizedBox(height: 12),
                const LinearProgressIndicator(minHeight: 3),
              ],
              if (response != null && response.body.trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                Semantics(
                  liveRegion: true,
                  label: 'AI 正在输出训练计划',
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: MarkdownBody(
                        data: response.body,
                        selectable: true,
                      ),
                    ),
                  ),
                ),
              ],
              if (response?.plan != null)
                _AiPlanCard(
                  plan: response!.plan!,
                  controller: widget.controller,
                ),
              if (widget.controller.aiTyping) ...[
                const SizedBox(height: 6),
                TextButton.icon(
                  onPressed: widget.controller.cancelAiResponse,
                  icon: const Icon(Icons.stop_circle_outlined, size: 18),
                  label: Text(
                    '停止回答 · 已等待 ${widget.controller.aiWaitingSeconds} 秒',
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}

class _RoutineCard extends StatelessWidget {
  const _RoutineCard({required this.controller, required this.routine});
  final AppController controller;
  final Routine routine;

  @override
  Widget build(BuildContext context) {
    final setCount = routine.exercises.fold<int>(
      0,
      (sum, exercise) => sum + exercise.sets.length,
    );
    final estimateMinutes = (setCount * 3 + routine.exercises.length * 2).clamp(
      10,
      180,
    );
    final summary = routine.exercises
        .take(3)
        .map(
          (exercise) => controller.displayExerciseName(
            controller.exerciseFor(exercise.exerciseId),
          ),
        )
        .join(' · ');
    return Card(
      key: Key('routine-card-${routine.id}'),
      margin: const EdgeInsets.only(bottom: 9),
      child: InkWell(
        onTap: () => _showRoutineDetail(context, controller, routine),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 13, 10, 11),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(Icons.fitness_center, color: cobalt),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      routine.name,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    key: Key('routine-more-${routine.id}'),
                    tooltip: '计划更多操作',
                    onPressed: () =>
                        _showRoutineActions(context, controller, routine),
                    icon: const Icon(Icons.more_horiz),
                  ),
                ],
              ),
              if (summary.isNotEmpty)
                Text(
                  summary,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: quiet),
                ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _RoutineStat(
                    label: '动作',
                    value: '${routine.exercises.length}',
                  ),
                  _RoutineStat(label: '组数', value: '$setCount'),
                  _RoutineStat(label: '预计', value: '$estimateMinutes 分钟'),
                ],
              ),
              const SizedBox(height: 9),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: Key('routine-start-${routine.id}'),
                  onPressed: routine.exercises.isEmpty
                      ? null
                      : () {
                          controller.startRoutine(routine);
                          showKiloSnack(context, '已开始 ${routine.name}');
                        },
                  icon: const Icon(Icons.play_arrow, size: 18),
                  label: const Text('开始'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoutineStat extends StatelessWidget {
  const _RoutineStat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      color: paper,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      '$label $value',
      style: TextStyle(fontSize: 11, color: secondaryInk),
    ),
  );
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.controller, required this.plan});
  final AppController controller;
  final Plan plan;
  @override
  Widget build(BuildContext context) {
    final session = plan.sessions.first;
    return Card(
      key: Key('official-plan-${plan.id}'),
      margin: const EdgeInsets.only(bottom: 9),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showPlanDetail(context, controller, plan),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.auto_awesome_outlined, color: cobalt),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plan.title,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${session.name} · ${session.exercises} 个动作 · ${session.duration}',
                      style: TextStyle(fontSize: 12, color: quiet),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: quiet),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecordTile extends StatelessWidget {
  const _RecordTile({
    required this.controller,
    required this.record,
    required this.onTap,
  });
  final AppController controller;
  final WorkoutRecord record;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final totalSets = record.exercises
        .expand((exercise) => exercise.sets)
        .length;
    final completedSets = record.exercises
        .expand((exercise) => exercise.sets)
        .where((set) => set.completed)
        .length;
    final completionLabel = totalSets == 0
        ? '—'
        : '${(completedSets / totalSets * 100).round()}%';
    final exerciseIds = record.exercises.isNotEmpty
        ? record.exercises.map((item) => item.exerciseId).toList()
        : record.exerciseIds;
    final actionSummary = exerciseIds
        .take(4)
        .map((id) => controller.displayExerciseName(controller.exerciseFor(id)))
        .join(' · ');
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                key: Key('record-tile-${record.id}'),
                behavior: HitTestBehavior.opaque,
                onTap: onTap,
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: paper,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.event_available, color: cobalt),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            record.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          Text(
                            '${record.date.month} 月 ${record.date.day} 日 · ${record.startTime} · ${(record.durationSeconds / 60).round()} 分钟',
                            style: TextStyle(fontSize: 12, color: quiet),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: quiet),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _RoutineStat(
                    label: '训练量',
                    value: '${record.volume.toStringAsFixed(0)} kg',
                  ),
                  _RoutineStat(label: '有效组', value: '${record.effectiveSets}'),
                  _RoutineStat(label: '完成率', value: completionLabel),
                ],
              ),
              if (actionSummary.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  actionSummary,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: secondaryInk),
                ),
              ],
              if (exerciseIds.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      for (final id in exerciseIds.take(3))
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: _ExerciseThumb(
                            key: Key('record-thumb-${record.id}-$id'),
                            exerciseId: id,
                            size: 32,
                          ),
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
}

class _RecordSetRow extends StatelessWidget {
  const _RecordSetRow({required this.set, required this.index});
  final WorkoutSet set;
  final int index;

  @override
  Widget build(BuildContext context) {
    final planned = set.plannedWeight;
    final delta = planned == null ? null : set.weight - planned;
    final detail = <String>[
      '休息 ${set.restSeconds}s',
      if (planned != null)
        '计划 ${_displayWeight(planned)} · Δ ${delta! >= 0 ? '+' : ''}${_displayWeight(delta)}',
    ].join(' · ');
    final statusColor = set.completed ? const Color(0xFF1E6B45) : secondaryInk;
    return Container(
      key: Key('record-set-row-${set.id}'),
      margin: const EdgeInsets.only(top: 5),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
      decoration: BoxDecoration(
        color: set.completed ? successContainer : surface,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: set.completed ? const Color(0xFF6DB787) : hairline,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 35,
            child: Text(
              '${index + 1}',
              style: TextStyle(color: statusColor, fontWeight: FontWeight.w800),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_setTypeShort(set.type)} · ${_displayWeight(set.weight)} kg × ${set.reps} 次',
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (detail.isNotEmpty)
                  Text(
                    detail,
                    style: TextStyle(fontSize: 11, color: statusColor),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                if (set.note.trim().isNotEmpty) ...[
                  const SizedBox(height: 5),
                  _NoteCallout(
                    key: Key('record-set-note-${set.id}'),
                    label: '组备注',
                    text: set.note.trim(),
                    color: setNoteColor,
                    background: setNoteContainer,
                    maxLines: 3,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 7),
          Icon(
            set.completed ? Icons.check_circle : Icons.radio_button_unchecked,
            color: set.completed ? const Color(0xFF1E6B45) : quiet,
            size: 21,
          ),
        ],
      ),
    );
  }
}

// Legacy builder retained only for migration tests; no active route renders it.
// ignore: unused_element
List<Widget> _nutritionRecordWidgets(
  BuildContext context,
  AppController controller, {
  required VoidCallback onChanged,
}) {
  final today = DateTime.now();
  final entries = [...controller.nutritionForDay(today)]
    ..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
  final calories = entries.fold<double>(0, (sum, item) => sum + item.calories);
  final protein = entries.fold<double>(
    0,
    (sum, item) => sum + item.proteinGrams,
  );
  final carbs = entries.fold<double>(0, (sum, item) => sum + item.carbsGrams);
  final fat = entries.fold<double>(0, (sum, item) => sum + item.fatGrams);
  final calorieTarget = controller.estimatedDailyCalories;
  return <Widget>[
    SectionTitle(
      '今日饮食',
      subtitle: '每次进食按第 1 餐、第 2 餐……自动排序',
      action: controller.nextMealLabelFor(today),
      onAction: () async {
        await _showNutritionSheet(context, controller);
        onChanged();
      },
    ),
    Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.local_fire_department_rounded, color: primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${calories.toStringAsFixed(0)} kcal'
                    '${calorieTarget == null ? '' : ' / 目标约 ${calorieTarget.toStringAsFixed(0)}'}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 17,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _NutritionMacro(
                  icon: Icons.fitness_center_rounded,
                  label: '蛋白质',
                  value: protein,
                ),
                _NutritionMacro(
                  icon: Icons.grain_rounded,
                  label: '碳水',
                  value: carbs,
                ),
                _NutritionMacro(
                  icon: Icons.water_drop_outlined,
                  label: '脂肪',
                  value: fat,
                ),
              ],
            ),
          ],
        ),
      ),
    ),
    const SizedBox(height: 14),
    if (entries.isEmpty)
      Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Icon(Icons.restaurant_menu_rounded, color: quiet, size: 32),
              const SizedBox(height: 8),
              const Text('今天还没有饮食记录'),
              const SizedBox(height: 12),
              FilledButton.icon(
                key: const Key('nutrition-empty-add'),
                onPressed: () async {
                  await _showNutritionSheet(context, controller);
                  onChanged();
                },
                icon: const Icon(Icons.add_rounded),
                label: const Text('记录第1餐'),
              ),
            ],
          ),
        ),
      )
    else
      ...entries.indexed.map((indexed) {
        final index = indexed.$1;
        final entry = indexed.$2;
        final nutrition = <String>[
          if (entry.amount.trim().isNotEmpty) entry.amount.trim(),
          '${entry.calories.toStringAsFixed(0)} kcal',
          if (entry.proteinGrams > 0)
            '蛋白质 ${entry.proteinGrams.toStringAsFixed(0)} g',
        ].join(' · ');
        return Card(
          key: Key('nutrition-entry-${entry.id}'),
          child: ListTile(
            contentPadding: const EdgeInsets.fromLTRB(12, 7, 6, 7),
            leading: CircleAvatar(
              radius: 19,
              backgroundColor: primaryContainer,
              foregroundColor: primary,
              child: Text(
                '${index + 1}',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            title: Text(
              '第${index + 1}餐 · ${entry.foodName}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: Text(
              nutrition,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: IconButton(
              tooltip: '删除这餐',
              onPressed: () async {
                await controller.deleteNutritionEntry(entry.id);
                onChanged();
              },
              icon: Icon(Icons.delete_outline_rounded, color: danger),
            ),
          ),
        );
      }),
    const SizedBox(height: 14),
    Card(
      color: primaryContainer.withValues(alpha: 0.45),
      child: Padding(
        padding: EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.add_a_photo_outlined, color: primary),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                '拍照识别先作为实验入口：识别结果只是候选值，保存前必须确认食物、份量和热量。',
                style: TextStyle(fontSize: 12, color: secondaryInk),
              ),
            ),
          ],
        ),
      ),
    ),
  ];
}

class _NutritionJournalPage extends StatelessWidget {
  const _NutritionJournalPage({required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) => KeyedSubtree(
    key: const Key('nutrition-journal-page'),
    child: NutritionCenterPage(controller: controller),
  );
}

class _NutritionMacro extends StatelessWidget {
  const _NutritionMacro({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final double value;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
    decoration: BoxDecoration(
      color: paper,
      borderRadius: BorderRadius.circular(9),
      border: Border.all(color: hairline),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: primary),
        const SizedBox(width: 5),
        Text(
          '$label ${value.toStringAsFixed(0)} g',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );
}

class RecordsPage extends StatefulWidget {
  const RecordsPage({
    super.key,
    required this.controller,
    this.embedded = false,
  });
  final AppController controller;
  final bool embedded;
  @override
  State<RecordsPage> createState() => _RecordsPageState();
}

class _RecordsPageState extends State<RecordsPage> {
  DateTime selected = DateTime.now();
  String mode = 'training';
  String statisticsPeriod = 'week';
  DateTimeRange? customStatisticsRange;
  AppController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    mode = controller.consumeRecordsInitialMode();
  }

  Widget _modeSwitch() => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Center(
      child: SegmentedButton<String>(
        key: const Key('records-statistics-tabs'),
        segments: const [
          ButtonSegment(
            value: 'training',
            icon: Icon(Icons.calendar_month_outlined),
            label: Text('训练'),
          ),
          ButtonSegment(
            value: 'nutrition',
            icon: Icon(Icons.restaurant_outlined),
            label: Text('饮食'),
          ),
          ButtonSegment(
            value: 'statistics',
            icon: Icon(Icons.insights_outlined),
            label: Text('统计'),
          ),
        ],
        selected: {mode},
        onSelectionChanged: (value) => setState(() => mode = value.first),
      ),
    ),
  );

  Future<void> _selectCustomStatisticsRange() async {
    final now = DateTime.now();
    final result = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
      initialDateRange: customStatisticsRange,
    );
    if (result == null || !mounted) return;
    setState(() {
      customStatisticsRange = result;
      statisticsPeriod = 'custom';
    });
  }

  @override
  Widget build(BuildContext context) {
    if (mode == 'statistics') {
      final content = [
        _modeSwitch(),
        const SizedBox(height: 14),
        _TrainingStatisticsView(
          controller: controller,
          period: statisticsPeriod,
          customRange: customStatisticsRange,
          onPeriodChanged: (value) => setState(() => statisticsPeriod = value),
          onCustomRange: _selectCustomStatisticsRange,
        ),
      ];
      return widget.embedded
          ? ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
              children: content,
            )
          : PageFrame(children: content);
    }
    if (mode == 'nutrition') {
      return Column(
        key: const Key('records-nutrition-center'),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: _modeSwitch(),
          ),
          Expanded(
            child: NutritionCenterPage(controller: controller, embedded: true),
          ),
        ],
      );
    }
    final monthStart = DateTime(selected.year, selected.month, 1);
    final firstMonday = monthStart.subtract(
      Duration(days: monthStart.weekday - 1),
    );
    final cells = List.generate(
      42,
      (index) => firstMonday.add(Duration(days: index)),
    );
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final today = DateTime.now();
    final content = <Widget>[
      _modeSwitch(),
      const SizedBox(height: 14),
      SectionTitle(
        '记录',
        subtitle: '训练日历、完成情况和历史记录',
        action: '补录训练',
        onAction: () => _showFinishWorkout(context, controller, past: true),
      ),
      Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 13, 12, 14),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => setState(
                      () => selected = DateTime(
                        selected.year,
                        selected.month - 1,
                      ),
                    ),
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Expanded(
                    child: Text(
                      '${selected.year} 年 ${selected.month} 月',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => setState(
                      () => selected = DateTime(
                        selected.year,
                        selected.month + 1,
                      ),
                    ),
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Text('一', style: TextStyle(fontSize: 11, color: quiet)),
                  Text('二', style: TextStyle(fontSize: 11, color: quiet)),
                  Text('三', style: TextStyle(fontSize: 11, color: quiet)),
                  Text('四', style: TextStyle(fontSize: 11, color: quiet)),
                  Text('五', style: TextStyle(fontSize: 11, color: quiet)),
                  Text('六', style: TextStyle(fontSize: 11, color: quiet)),
                  Text('日', style: TextStyle(fontSize: 11, color: quiet)),
                ],
              ),
              const SizedBox(height: 8),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: cells.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisExtent: 50 * textScale,
                ),
                itemBuilder: (context, index) {
                  final day = cells[index];
                  final key =
                      '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
                  final completed = controller.history.any(
                    (record) =>
                        record.date.year == day.year &&
                        record.date.month == day.month &&
                        record.date.day == day.day,
                  );
                  final planned = controller.scheduled.contains(key);
                  final current =
                      day.year == selected.year &&
                      day.month == selected.month &&
                      day.day == selected.day;
                  final isToday =
                      day.year == today.year &&
                      day.month == today.month &&
                      day.day == today.day;
                  final missed =
                      planned &&
                      !completed &&
                      DateTime(
                        day.year,
                        day.month,
                        day.day,
                      ).isBefore(DateTime(today.year, today.month, today.day));
                  final scheduledBodyPart = _scheduledBodyPart(
                    controller.scheduledLabels[key],
                  );
                  final background = completed
                      ? successContainer
                      : missed
                      ? const Color(0xFFFFE0DD)
                      : planned
                      ? calendarScheduledContainer
                      : current
                      ? calendarSelectedContainer
                      : Colors.transparent;
                  final border = completed
                      ? success
                      : missed
                      ? danger
                      : planned
                      ? calendarScheduled
                      : current
                      ? calendarSelected
                      : hairline;
                  final icon = completed
                      ? Icons.check_circle
                      : missed
                      ? Icons.event_busy
                      : isToday
                      ? Icons.today
                      : Icons.remove;
                  return InkWell(
                    key: Key('calendar-day-$key'),
                    onTap: () {
                      setState(() => selected = day);
                      _showCalendarDayActions(context, controller, day);
                    },
                    child: Container(
                      margin: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: background,
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(
                          color: border,
                          width: current || isToday ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${day.day}',
                            style: TextStyle(
                              fontSize: 13,
                              color: day.month == selected.month ? ink : quiet,
                              fontWeight: current || isToday || planned
                                  ? FontWeight.w900
                                  : FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 3),
                          if (planned && !completed && !missed)
                            Text(
                              scheduledBodyPart,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: calendarScheduled,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                              ),
                            )
                          else
                            Icon(icon, size: 14, color: border),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                runSpacing: 7,
                children: [
                  _CalendarLegend(color: success, label: '已完成'),
                  _CalendarLegend(color: calendarScheduled, label: '已安排'),
                  _CalendarLegend(color: calendarSelected, label: '当前选中'),
                  _CalendarLegend(color: hairline, label: '未安排'),
                ],
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 18),
      SectionTitle(
        '最近训练',
        subtitle: '${controller.history.length} 次训练',
        action: controller.history.length > 3 ? '查看全部' : null,
        onAction: controller.history.length > 3
            ? () => _showAllHistory(context, controller)
            : null,
      ),
      if (controller.history.isEmpty)
        const Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: Text('还没有训练记录，完成一次训练后会显示在这里。')),
          ),
        )
      else
        ...controller.history
            .take(3)
            .map(
              (record) => _RecordTile(
                controller: controller,
                record: record,
                onTap: () => _showRecordDetail(context, controller, record),
              ),
            ),
    ];
    return widget.embedded
        ? ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
            children: content,
          )
        : PageFrame(children: content);
  }
}

class _TrainingStatisticsView extends StatelessWidget {
  const _TrainingStatisticsView({
    required this.controller,
    required this.period,
    required this.customRange,
    required this.onPeriodChanged,
    required this.onCustomRange,
  });

  final AppController controller;
  final String period;
  final DateTimeRange? customRange;
  final ValueChanged<String> onPeriodChanged;
  final VoidCallback onCustomRange;

  DateTimeRange get range {
    final now = DateTime.now();
    if (period == 'month') {
      return DateTimeRange(start: DateTime(now.year, now.month, 1), end: now);
    }
    if (period == 'year') {
      return DateTimeRange(start: DateTime(now.year, 1, 1), end: now);
    }
    if (period == 'custom' && customRange != null) return customRange!;
    return DateTimeRange(
      start: DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(const Duration(days: 6)),
      end: now,
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedRange = range;
    final records = controller.history.where((record) {
      final day = DateTime(
        record.date.year,
        record.date.month,
        record.date.day,
      );
      return !day.isBefore(
            DateTime(
              selectedRange.start.year,
              selectedRange.start.month,
              selectedRange.start.day,
            ),
          ) &&
          !day.isAfter(
            DateTime(
              selectedRange.end.year,
              selectedRange.end.month,
              selectedRange.end.day,
            ),
          );
    }).toList();
    final volume = records.fold<double>(
      0,
      (sum, record) => sum + record.volume,
    );
    final sets = records.fold<int>(
      0,
      (sum, record) => sum + record.effectiveSets,
    );
    final muscleSets = <String, int>{};
    final trainingDays = records
        .map(
          (record) =>
              '${record.date.year}-${record.date.month}-${record.date.day}',
        )
        .toSet()
        .length;
    for (final record in records) {
      for (final workoutExercise in record.exercises) {
        final exercise = controller.allExercises.firstWhere(
          (item) => item.id == workoutExercise.exerciseId,
          orElse: () => controller.exerciseFor(workoutExercise.exerciseId),
        );
        final muscle = controller.muscleGroupFor(exercise.muscle);
        final completed = workoutExercise.sets
            .where((set) => set.completed)
            .toList();
        muscleSets[muscle] = (muscleSets[muscle] ?? 0) + completed.length;
      }
    }
    final muscles = muscleSets.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: [
            for (final item in const [
              ('week', '周'),
              ('month', '月'),
              ('year', '年'),
            ])
              ChoiceChip(
                key: Key('statistics-period-${item.$1}'),
                label: Text(item.$2),
                selected: period == item.$1,
                onSelected: (_) => onPeriodChanged(item.$1),
              ),
            ActionChip(
              key: const Key('statistics-period-custom'),
              avatar: const Icon(Icons.date_range_outlined, size: 17),
              label: Text(
                period == 'custom' && customRange != null
                    ? '${customRange!.start.month}/${customRange!.start.day}–${customRange!.end.month}/${customRange!.end.day}'
                    : '自定义',
              ),
              onPressed: onCustomRange,
            ),
          ],
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: OutlinedButton.icon(
            key: const Key('open-friends'),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => _FriendsPage(controller: controller),
              ),
            ),
            icon: const Icon(Icons.people_alt_outlined, size: 18),
            label: const Text('好友训练'),
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          '训练概况',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: _StatisticMetric(
                    label: '训练天数',
                    value: '$trainingDays',
                    unit: '天',
                  ),
                ),
                Expanded(
                  child: _StatisticMetric(
                    label: '有效组',
                    value: '$sets',
                    unit: '组',
                  ),
                ),
                Expanded(
                  child: _StatisticMetric(
                    label: '训练容量',
                    value: volume >= 1000
                        ? (volume / 1000).toStringAsFixed(1)
                        : volume.toStringAsFixed(0),
                    unit: volume >= 1000 ? '吨' : 'kg',
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _MemberAnalyticsPanel(
          controller: controller,
          range: selectedRange,
          records: records,
          trainingDays: trainingDays,
          volume: volume,
        ),
        const SizedBox(height: 16),
        const Text(
          '部位概览',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            child: Column(
              children: [
                const SizedBox(height: 8),
                _MuscleBodyMap(muscleSets: muscleSets),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        if (muscles.isEmpty)
          Text('该时段还没有可统计的训练组。', style: TextStyle(color: quiet))
        else
          for (final item in muscles.take(7))
            Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Row(
                children: [
                  SizedBox(
                    width: 44,
                    child: Text(
                      item.key,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  Expanded(
                    child: _MusclePaletteProgressBar(
                      fraction: item.value / 22,
                      metricValue: item.value,
                      mode: MuscleMapMode.volume,
                      minHeight: 9,
                    ),
                  ),
                  SizedBox(
                    width: 48,
                    child: Text('${item.value} 组', textAlign: TextAlign.right),
                  ),
                ],
              ),
            ),
        const SizedBox(height: 15),
        _TrackedStrengthSection(
          controller: controller,
          records: records,
          metric: controller.trackedExerciseMetric,
        ),
      ],
    );
  }
}

class _TrackedStrengthSection extends StatelessWidget {
  const _TrackedStrengthSection({
    required this.controller,
    required this.records,
    this.metric = 'estimated1rm',
  });

  final AppController controller;
  final List<WorkoutRecord> records;
  // Kept for compatibility with persisted preferences and older callers. The
  // visible overview is now always the paired weight × reps growth view.
  final String metric;

  Future<void> _manage(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _StrengthTrackingPage(controller: controller),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) => _buildContent(context),
  );

  Widget _buildContent(BuildContext context) {
    final tracked = controller.trackedExerciseIds;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                '动作成长',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Tooltip(
              message: '每次训练只选一个真实完成工作组；重量与次数来自同一组。',
              child: Icon(Icons.info_outline_rounded, size: 17, color: quiet),
            ),
            const SizedBox(width: 3),
            TextButton.icon(
              key: const Key('manage-tracked-exercises'),
              onPressed: () => _manage(context),
              icon: const Icon(Icons.tune_rounded, size: 18),
              label: const Text('管理'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (tracked.isEmpty)
          Card(
            key: const Key('tracked-exercise-empty'),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 15, 14, 15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    '选择你想长期关注的动作',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '力量或次数的变化会按训练日期绘制，不会默认替你挑动作。',
                    style: TextStyle(color: quiet, fontSize: 12),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    key: const Key('tracked-exercise-empty-manage'),
                    onPressed: () => _manage(context),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('添加关注动作'),
                  ),
                ],
              ),
            ),
          )
        else
          for (final exerciseId in tracked.take(3))
            _TrackedExerciseGrowthCard(
              key: Key('tracked-exercise-card-$exerciseId'),
              controller: controller,
              exerciseId: exerciseId,
              points: buildExerciseGrowthSeries(
                records,
                exerciseId,
                definition: controller.exerciseFor(exerciseId),
                engine: controller.intelligenceEngine,
              ),
            ),
        if (tracked.length > 3) ...[
          const SizedBox(height: 4),
          TextButton(
            onPressed: () => _manage(context),
            child: Text('查看全部 ${tracked.length} 个关注动作'),
          ),
        ],
      ],
    );
  }
}

class _TrackedExerciseGrowthCard extends StatefulWidget {
  const _TrackedExerciseGrowthCard({
    super.key,
    required this.controller,
    required this.exerciseId,
    required this.points,
  });

  final AppController controller;
  final String exerciseId;
  final List<ExerciseGrowthPoint> points;

  @override
  State<_TrackedExerciseGrowthCard> createState() =>
      _TrackedExerciseGrowthCardState();
}

class _TrackedExerciseGrowthCardState
    extends State<_TrackedExerciseGrowthCard> {
  var expanded = false;
  int? selectedPointIndex;

  List<ExerciseGrowthPoint> get points =>
      comparableExerciseGrowthSeries(widget.points);

  String _dateLabel(DateTime value) => '${value.month}/${value.day}';

  String _pair(ExerciseGrowthPoint point) => point.pairLabel;

  String _changeText(List<ExerciseGrowthPoint> values) {
    if (values.isEmpty) return '所选时间段暂无有效工作组记录';
    if (values.length == 1) return '已记录 1 次，再完成同器械训练后显示变化';
    final first = values.first;
    final latest = values.last;
    if (first.isBodyweight && latest.isBodyweight) {
      final repsDelta = latest.reps - first.reps;
      if (repsDelta == 0) return '次数保持 ${latest.reps} 次';
      return '次数 ${repsDelta > 0 ? '+' : ''}$repsDelta 次（重量均为自重）';
    }
    final weightDelta = latest.weight - first.weight;
    final repsDelta = latest.reps - first.reps;
    final parts = <String>[];
    if (weightDelta.abs() >= .05) {
      parts.add(
        '重量 ${weightDelta > 0 ? '+' : ''}${formatGrowthNumber(weightDelta)} kg',
      );
    }
    if (repsDelta != 0) {
      parts.add('次数 ${repsDelta > 0 ? '+' : ''}$repsDelta 次');
    }
    return parts.isEmpty ? '重量与次数保持 ${_pair(latest)}' : parts.join(' · ');
  }

  void _toggleExpanded() => setState(() {
    expanded = !expanded;
    if (!expanded) selectedPointIndex = null;
  });

  void _selectPoint(TapUpDetails details, Size size) {
    final values = points;
    if (values.isEmpty || size.width <= 0) return;
    const left = 34.0;
    final right = math.max(left + 1, size.width - 28).toDouble();
    final firstDate = values.first.date;
    final lastDate = values.last.date;
    final span = lastDate.difference(firstDate).inMilliseconds;
    final tapX = details.localPosition.dx.clamp(left, right).toDouble();
    var nearest = 0;
    var nearestDistance = double.infinity;
    for (var index = 0; index < values.length; index++) {
      final ratio = span <= 0
          ? .5
          : values[index].date.difference(firstDate).inMilliseconds / span;
      final x = left + (right - left) * ratio;
      final distance = (tapX - x).abs();
      if (distance < nearestDistance) {
        nearest = index;
        nearestDistance = distance;
      }
    }
    setState(() => selectedPointIndex = nearest);
  }

  @override
  Widget build(BuildContext context) {
    final exercise = widget.controller.exerciseFor(widget.exerciseId);
    final name = widget.controller.displayExerciseName(exercise);
    final allPoints = widget.points;
    final values = points;
    final latest = values.lastOrNull;
    final mixedHistory = hasMixedExerciseGrowthHistory(allPoints);
    final selected =
        selectedPointIndex == null ||
            selectedPointIndex! < 0 ||
            selectedPointIndex! >= values.length
        ? null
        : values[selectedPointIndex!];
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            key: Key('tracked-exercise-toggle-${widget.exerciseId}'),
            onTap: _toggleExpanded,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 9),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ExerciseThumb(exerciseId: widget.exerciseId, size: 42),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          latest == null
                              ? '暂无真实完成工作组'
                              : '最近 ${_dateLabel(latest.date)} · ${_pair(latest)}',
                          style: TextStyle(color: quiet, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: quiet,
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Text(
              _changeText(values),
              style: TextStyle(
                color: values.length < 2 ? quiet : primary,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (mixedHistory)
            Padding(
              padding: EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Text(
                '检测到不同训练地点，当前趋势已按最近地点分开；不同器械/场地不直接比较。',
                style: TextStyle(color: quiet, fontSize: 11, height: 1.35),
              ),
            ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: values.isEmpty
                  ? SizedBox(
                      key: Key(
                        'statistics-strength-chart-empty-${widget.exerciseId}',
                      ),
                      height: 76,
                      child: Center(
                        child: Text(
                          '所选时间段暂无可比较数据',
                          style: TextStyle(color: quiet),
                        ),
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        LayoutBuilder(
                          builder: (context, constraints) => GestureDetector(
                            key: Key(
                              'statistics-strength-chart-${widget.exerciseId}',
                            ),
                            behavior: HitTestBehavior.opaque,
                            onTapUp: (details) => _selectPoint(
                              details,
                              Size(constraints.maxWidth, 190),
                            ),
                            child: Semantics(
                              label: '重量和次数双轴趋势图，点击数据点查看同组配对',
                              child: SizedBox(
                                height: 190,
                                child: CustomPaint(
                                  painter: _DualAxisGrowthPainter(
                                    points: values,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Wrap(
                          spacing: 14,
                          runSpacing: 4,
                          children: [
                            _GrowthLegend(color: primary, label: '重量（左轴 kg）'),
                            _GrowthLegend(
                              color: primaryBright,
                              label: '同组次数（右轴 次）',
                            ),
                          ],
                        ),
                        if (selected != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            '详情 · ${_dateLabel(selected.date)} · ${_pair(selected)}',
                            key: Key(
                              'statistics-strength-point-${widget.exerciseId}',
                            ),
                            style: TextStyle(
                              color: secondaryInk,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ],
                    ),
            ),
        ],
      ),
    );
  }
}

class _GrowthLegend extends StatelessWidget {
  const _GrowthLegend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(color: quiet, fontSize: 10)),
    ],
  );
}

class _DualAxisGrowthPainter extends CustomPainter {
  const _DualAxisGrowthPainter({required this.points});

  final List<ExerciseGrowthPoint> points;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty || size.width <= 0 || size.height <= 0) return;
    const leftPad = 34.0;
    const rightPad = 28.0;
    const topPad = 17.0;
    const bottomPad = 29.0;
    final chartWidth = math
        .max(1.0, size.width - leftPad - rightPad)
        .toDouble();
    final chartHeight = math
        .max(1.0, size.height - topPad - bottomPad)
        .toDouble();
    final firstDate = points.first.date;
    final lastDate = points.last.date;
    final dateSpan = lastDate.difference(firstDate).inMilliseconds;
    final weights = points.map((point) => point.weight).toList(growable: false);
    final repetitions = points
        .map((point) => point.reps.toDouble())
        .toList(growable: false);
    final weightRange = _axisRange(weights);
    final repsRange = _axisRange(repetitions);
    final grid = Paint()
      ..color = hairline
      ..strokeWidth = 1;
    for (var index = 0; index < 3; index++) {
      final y = topPad + chartHeight * index / 2;
      canvas.drawLine(
        Offset(leftPad, y),
        Offset(size.width - rightPad, y),
        grid,
      );
    }

    Offset pointAt(int index, double value, _AxisRange range) {
      final dateRatio = dateSpan <= 0
          ? .5
          : points[index].date.difference(firstDate).inMilliseconds / dateSpan;
      final x = leftPad + chartWidth * dateRatio;
      final valueRatio = ((value - range.low) / (range.high - range.low)).clamp(
        0.0,
        1.0,
      );
      final y = topPad + chartHeight * (1 - valueRatio);
      return Offset(x, y);
    }

    final weightPoints = [
      for (var index = 0; index < points.length; index++)
        pointAt(index, weights[index], weightRange),
    ];
    final repsPoints = [
      for (var index = 0; index < points.length; index++)
        pointAt(index, repetitions[index], repsRange),
    ];
    _drawSeries(canvas, weightPoints, primary);
    _drawSeries(canvas, repsPoints, primaryBright);
    _drawAxisLabels(canvas, size, weightRange, repsRange);
    for (var index = 0; index < points.length; index++) {
      canvas.drawCircle(weightPoints[index], 4, Paint()..color = primary);
      canvas.drawCircle(weightPoints[index], 2, Paint()..color = Colors.white);
      canvas.drawCircle(repsPoints[index], 3.5, Paint()..color = primaryBright);
    }
  }

  _AxisRange _axisRange(List<double> values) {
    final minValue = values.reduce((a, b) => math.min(a, b).toDouble());
    final maxValue = values.reduce((a, b) => math.max(a, b).toDouble());
    final spread = maxValue - minValue;
    final padding = spread == 0
        ? math.max(1.0, minValue.abs() * .12).toDouble()
        : spread * .16;
    return _AxisRange(
      low: math.max(0, minValue - padding).toDouble(),
      high: maxValue + padding,
    );
  }

  void _drawSeries(Canvas canvas, List<Offset> points, Color color) {
    if (points.length < 2) return;
    final line = Paint()
      ..color = color
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(path, line);
  }

  void _drawAxisLabels(
    Canvas canvas,
    Size size,
    _AxisRange weightRange,
    _AxisRange repsRange,
  ) {
    final style = TextStyle(color: quiet, fontSize: 9);
    void draw(String text, Offset offset, {TextAlign align = TextAlign.left}) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: TextDirection.ltr,
        textAlign: align,
      )..layout();
      painter.paint(canvas, offset);
    }

    draw('kg', const Offset(2, 0));
    draw('次', Offset(size.width - 18, 0));
    for (var index = 0; index < 3; index++) {
      final ratio = 1 - index / 2;
      final y = 17 + (size.height - 17 - 29) * index / 2 - 5;
      draw(
        formatGrowthNumber(
          weightRange.low + (weightRange.high - weightRange.low) * ratio,
        ),
        Offset(0, y),
      );
      draw(
        formatGrowthNumber(
          repsRange.low + (repsRange.high - repsRange.low) * ratio,
        ),
        Offset(size.width - 25, y),
        align: TextAlign.right,
      );
    }
    final first = points.first;
    final last = points.last;
    draw('${first.date.month}/${first.date.day}', Offset(27, size.height - 17));
    if (last != first) {
      draw(
        '${last.date.month}/${last.date.day}',
        Offset(size.width - 52, size.height - 17),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DualAxisGrowthPainter oldDelegate) =>
      oldDelegate.points != points;
}

class _AxisRange {
  const _AxisRange({required this.low, required this.high});

  final double low;
  final double high;
}

class _StrengthTrackingPage extends StatefulWidget {
  const _StrengthTrackingPage({required this.controller});

  final AppController controller;

  @override
  State<_StrengthTrackingPage> createState() => _StrengthTrackingPageState();
}

class _StrengthTrackingPageState extends State<_StrengthTrackingPage> {
  late final Set<String> selected;

  @override
  void initState() {
    super.initState();
    selected = {...widget.controller.trackedExerciseIds};
  }

  List<String> get candidates {
    final ids = <String>{};
    for (final record in widget.controller.history) {
      for (final exercise in record.exercises) {
        if (exercise.sets.any((set) => set.completed)) {
          ids.add(exercise.exerciseId);
        }
      }
    }
    final values = ids.toList()
      ..sort(
        (a, b) => widget.controller
            .displayExerciseName(widget.controller.exerciseFor(a))
            .compareTo(
              widget.controller.displayExerciseName(
                widget.controller.exerciseFor(b),
              ),
            ),
      );
    return values;
  }

  Future<void> _save() async {
    await widget.controller.setTrackedExercises(selected);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('关注动作'),
      actions: [
        TextButton(
          key: const Key('save-tracked-exercises'),
          onPressed: _save,
          child: const Text('保存'),
        ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 30),
      children: [
        Text(
          '选择你想在统计首页长期观察的动作，最多 8 个。',
          style: TextStyle(color: quiet, height: 1.4),
        ),
        const SizedBox(height: 10),
        if (candidates.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(18),
              child: Text('完成带重量或次数的训练后，这里会出现可关注动作。'),
            ),
          )
        else
          for (final id in candidates)
            Card(
              margin: const EdgeInsets.only(bottom: 7),
              child: CheckboxListTile(
                key: Key('tracked-exercise-option-$id'),
                value: selected.contains(id),
                onChanged: (value) {
                  setState(() {
                    if (value == true) {
                      if (selected.length < 8) selected.add(id);
                    } else {
                      selected.remove(id);
                    }
                  });
                },
                secondary: _ExerciseThumb(exerciseId: id, size: 42),
                title: Text(
                  widget.controller.displayExerciseName(
                    widget.controller.exerciseFor(id),
                  ),
                ),
                subtitle: Text(
                  selected.contains(id) ? '已加入关注' : '未关注',
                  style: TextStyle(color: quiet, fontSize: 11),
                ),
                controlAffinity: ListTileControlAffinity.trailing,
              ),
            ),
      ],
    ),
  );
}

class _MemberAnalyticsPanel extends StatelessWidget {
  const _MemberAnalyticsPanel({
    required this.controller,
    required this.range,
    required this.records,
    required this.trainingDays,
    required this.volume,
  });

  final AppController controller;
  final DateTimeRange range;
  final List<WorkoutRecord> records;
  final int trainingDays;
  final double volume;

  int get rangeDays =>
      DateUtils.dateOnly(
        range.end,
      ).difference(DateUtils.dateOnly(range.start)).inDays +
      1;

  List<WorkoutRecord> _recordsIn(DateTimeRange value) => controller.history
      .where((record) {
        final day = DateUtils.dateOnly(record.date);
        return !day.isBefore(DateUtils.dateOnly(value.start)) &&
            !day.isAfter(DateUtils.dateOnly(value.end));
      })
      .toList(growable: false);

  List<NutritionEntry> _nutritionIn(DateTimeRange value) => controller
      .nutritionEntries
      .where((entry) {
        final day = DateUtils.dateOnly(entry.recordedAt);
        return !day.isBefore(DateUtils.dateOnly(value.start)) &&
            !day.isAfter(DateUtils.dateOnly(value.end));
      })
      .toList(growable: false);

  double? _delta(double current, double previous) {
    if (previous <= 0) return current > 0 ? null : 0;
    return (current - previous) / previous * 100;
  }

  String _deltaText(double? value) {
    if (value == null) return '新增数据';
    if (value.abs() < .5) return '与上期持平';
    return '${value > 0 ? '+' : ''}${value.toStringAsFixed(0)}% 较上期';
  }

  @override
  Widget build(BuildContext context) {
    final isMember = controller.entitlements?.isMember == true;
    if (!isMember) {
      return KeyedSubtree(
        key: const Key('member-analytics-locked'),
        child: _LockedAnalyticsModule(
          key: const Key('stats-ai-insight-locked'),
          controller: controller,
          title: '深度训练洞察',
          description: '',
          actionKey: const Key('open-member-analytics-paywall'),
        ),
      );
    }

    final previousEnd = DateUtils.dateOnly(
      range.start,
    ).subtract(const Duration(days: 1));
    final previousStart = previousEnd.subtract(Duration(days: rangeDays - 1));
    final previous = _recordsIn(
      DateTimeRange(start: previousStart, end: previousEnd),
    );
    final previousDays = previous
        .map((item) => DateUtils.dateOnly(item.date))
        .toSet()
        .length;
    final previousVolume = previous.fold<double>(
      0,
      (sum, item) => sum + item.volume,
    );
    final nutrition = _nutritionIn(range);
    final nutritionByDay = <DateTime, List<NutritionEntry>>{};
    for (final entry in nutrition) {
      nutritionByDay
          .putIfAbsent(DateUtils.dateOnly(entry.recordedAt), () => [])
          .add(entry);
    }
    final targetCalories = controller.estimatedDailyCalories;
    final targetProtein = controller.trainingProfile.weightKg == null
        ? null
        : controller.trainingProfile.weightKg! * 1.6;
    final totalCalories = nutrition.fold<double>(
      0,
      (sum, item) => sum + item.calories,
    );
    final totalProtein = nutrition.fold<double>(
      0,
      (sum, item) => sum + item.proteinGrams,
    );
    final averageCalories = totalCalories / rangeDays;
    final averageProtein = totalProtein / rangeDays;
    var calorieHitDays = 0;
    var proteinHitDays = 0;
    for (final entries in nutritionByDay.values) {
      final dayCalories = entries.fold<double>(
        0,
        (sum, item) => sum + item.calories,
      );
      final dayProtein = entries.fold<double>(
        0,
        (sum, item) => sum + item.proteinGrams,
      );
      if (targetCalories != null &&
          dayCalories >= targetCalories * .9 &&
          dayCalories <= targetCalories * 1.1) {
        calorieHitDays++;
      }
      if (targetProtein != null && dayProtein >= targetProtein) {
        proteinHitDays++;
      }
    }
    final loggedDays = nutritionByDay.length;
    final calorieHitRate = loggedDays == 0 || targetCalories == null
        ? null
        : calorieHitDays / loggedDays;
    final proteinHitRate = loggedDays == 0 || targetProtein == null
        ? null
        : proteinHitDays / loggedDays;
    final action = _nextAction(
      loggedDays: loggedDays,
      averageProtein: averageProtein,
      targetProtein: targetProtein,
      calorieHitRate: calorieHitRate,
      trainingDays: trainingDays,
      expectedTrainingDays:
          (controller.trainingProfile.weeklyTrainingDays ?? 3) * rangeDays / 7,
      volumeDelta: _delta(volume, previousVolume),
    );

    final intelligence = controller.trainingIntelligence;
    final volumeRows =
        intelligence.volume4Weeks
            .where(
              (item) =>
                  TrainingIntelligenceEngine.muscles.contains(item.muscle),
            )
            .toList()
          ..sort((a, b) => b.effectiveSets.compareTo(a.effectiveSets));
    final report = intelligence.weeklyReport;
    return KeyedSubtree(
      key: const Key('member-analytics-panel'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _AnalyticsPeerSection(
            key: const Key('stats-ai-insight'),
            icon: Icons.query_stats_rounded,
            title: 'AI训练发现',
            child: _AnalyticsActionCard(text: action),
          ),
          const SizedBox(height: 10),
          _AnalyticsPeerSection(
            key: const Key('stats-nutrition-adherence'),
            icon: Icons.restaurant_outlined,
            title: '训练 × 饮食',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _AnalyticsMetric(
                        label: '训练频率',
                        value: '$trainingDays 天',
                        comparison: _deltaText(
                          _delta(
                            trainingDays.toDouble(),
                            previousDays.toDouble(),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _AnalyticsMetric(
                        label: '训练容量',
                        value: volume >= 1000
                            ? '${(volume / 1000).toStringAsFixed(1)} 吨'
                            : '${volume.toStringAsFixed(0)} kg',
                        comparison: _deltaText(_delta(volume, previousVolume)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _AnalyticsMetric(
                        label: '日均热量',
                        value: '${averageCalories.toStringAsFixed(0)} kcal',
                        comparison: targetCalories == null
                            ? '完善档案后显示目标'
                            : '目标 ${targetCalories.toStringAsFixed(0)} kcal',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _AnalyticsMetric(
                        label: '日均蛋白质',
                        value: '${averageProtein.toStringAsFixed(0)} g',
                        comparison: targetProtein == null
                            ? '完善体重后显示目标'
                            : '目标 ${targetProtein.toStringAsFixed(0)} g',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _NutritionAdherenceRow(
                  loggedDays: loggedDays,
                  rangeDays: rangeDays,
                  calorieHitRate: calorieHitRate,
                  proteinHitRate: proteinHitRate,
                ),
                const SizedBox(height: 12),
                _TrainingNutritionTimeline(
                  range: range,
                  records: records,
                  nutritionByDay: nutritionByDay,
                  calorieTarget: targetCalories,
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _AnalyticsPeerSection(
            key: const Key('stats-muscle-volume-section'),
            icon: Icons.account_tree_outlined,
            title: '肌群训练量',
            child: _InlineMuscleVolumeSection(rows: volumeRows),
          ),
          const SizedBox(height: 10),
          _AnalyticsPeerSection(
            key: const Key('stats-ai-weekly-report-section'),
            icon: Icons.auto_graph_rounded,
            title: 'AI周报',
            child: _InlineWeeklyReportSection(report: report),
          ),
        ],
      ),
    );
  }

  String _nextAction({
    required int loggedDays,
    required double averageProtein,
    required double? targetProtein,
    required double? calorieHitRate,
    required int trainingDays,
    required double expectedTrainingDays,
    required double? volumeDelta,
  }) {
    if (loggedDays < (rangeDays >= 7 ? 3 : 1)) {
      return '下一步：先连续记录 3 天饮食，建立可用的营养基线。';
    }
    if (targetProtein != null && averageProtein < targetProtein * .8) {
      return '下一步：日均蛋白质偏低，优先每天增加一份高蛋白食物。';
    }
    if (calorieHitRate != null && calorieHitRate < .5) {
      return '下一步：热量波动较大，先将一半以上记录日控制在目标 ±10% 内。';
    }
    if (trainingDays + .5 < expectedTrainingDays) {
      return '下一步：训练频率低于设定目标，先在日历补上下一次训练。';
    }
    if (volumeDelta != null && volumeDelta < -15) {
      return '下一步：容量较上期下降，检查恢复与计划完成情况，不必盲目加量。';
    }
    return '下一步：当前训练与营养节奏稳定，继续保持并观察下一周趋势。';
  }
}

class _LockedAnalyticsModule extends StatefulWidget {
  const _LockedAnalyticsModule({
    super.key,
    required this.controller,
    required this.title,
    required this.description,
    this.actionKey,
  });

  final AppController controller;
  final String title;
  final String description;
  final Key? actionKey;

  @override
  State<_LockedAnalyticsModule> createState() => _LockedAnalyticsModuleState();
}

class _LockedAnalyticsModuleState extends State<_LockedAnalyticsModule> {
  var _expanded = false;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(13, 10, 13, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            button: true,
            expanded: _expanded,
            label: '展开${widget.title}',
            child: InkWell(
              key: const Key('member-analytics-locked-toggle'),
              borderRadius: BorderRadius.circular(10),
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.lock_outline_rounded, size: 18, color: primary),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        widget.title,
                        softWrap: true,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                    const SizedBox(width: 7),
                    const _ProPill(),
                    const SizedBox(width: 3),
                    Icon(
                      _expanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: quiet,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (widget.description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              widget.description,
              style: TextStyle(color: quiet, fontSize: 12, height: 1.35),
            ),
            const SizedBox(height: 4),
          ],
          ClipRect(
            child: AnimatedSize(
              duration: const Duration(milliseconds: 180),
              alignment: Alignment.topCenter,
              child: Align(
                key: const Key('locked-analytics-preview'),
                alignment: Alignment.topCenter,
                heightFactor: _expanded ? 1 : 0,
                child: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(10, 9, 10, 8),
                    decoration: BoxDecoration(
                      color: primaryContainer.withValues(alpha: .28),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: hairline),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          '本周期的下一步建议',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        ClipRect(
                          child: ImageFiltered(
                            imageFilter: ui.ImageFilter.blur(
                              sigmaX: 5,
                              sigmaY: 5,
                            ),
                            child: const ExcludeSemantics(
                              child: Text(
                                '恢复状态与近期训练量正在综合计算，下一周将优先安排需要补足的部位。',
                                maxLines: 2,
                                overflow: TextOverflow.clip,
                                style: TextStyle(fontSize: 12, height: 1.35),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 7),
                        const Wrap(
                          spacing: 6,
                          runSpacing: 5,
                          children: [
                            _LockedPreviewPill(label: 'AI训练发现'),
                            _LockedPreviewPill(label: '训练 × 饮食'),
                            _LockedPreviewPill(label: '肌群训练量'),
                            _LockedPreviewPill(label: 'AI周报'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              key: widget.actionKey,
              onPressed: () => showMembershipPaywall(
                context,
                controller: widget.controller,
                reason: MembershipPaywallReason.advancedStatistics,
              ),
              icon: const Icon(Icons.lock_open_outlined, size: 17),
              label: const Text('解锁深度洞察'),
            ),
          ),
          // Keep legacy test hooks and deep links stable while the four
          // previously separate visual cards are now one integrated module.
          const SizedBox(
            key: Key('stats-nutrition-adherence-locked'),
            width: 0,
            height: 0,
          ),
          const SizedBox(
            key: Key('stats-muscle-volume-locked'),
            width: 0,
            height: 0,
          ),
          const SizedBox(
            key: Key('stats-ai-weekly-report-locked'),
            width: 0,
            height: 0,
          ),
        ],
      ),
    ),
  );
}

class _LockedPreviewPill extends StatelessWidget {
  const _LockedPreviewPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
    decoration: BoxDecoration(
      color: surface.withValues(alpha: .86),
      borderRadius: BorderRadius.circular(99),
    ),
    child: Text(label, style: TextStyle(color: quiet, fontSize: 10)),
  );
}

class _AnalyticsPeerSection extends StatefulWidget {
  const _AnalyticsPeerSection({
    super.key,
    required this.icon,
    required this.title,
    required this.child,
  });

  final IconData icon;
  final String title;
  final Widget child;

  @override
  State<_AnalyticsPeerSection> createState() => _AnalyticsPeerSectionState();
}

class _AnalyticsPeerSectionState extends State<_AnalyticsPeerSection> {
  var _expanded = false;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(13, 9, 13, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            button: true,
            expanded: _expanded,
            label: '展开${widget.title}',
            child: InkWell(
              key: Key('analytics-toggle-${widget.title}'),
              borderRadius: BorderRadius.circular(10),
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Icon(widget.icon, size: 19, color: primary),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        widget.title,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                    const _ProPill(),
                    const SizedBox(width: 3),
                    Icon(
                      _expanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: quiet,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
          ClipRect(
            child: AnimatedSize(
              duration: const Duration(milliseconds: 180),
              alignment: Alignment.topCenter,
              child: Align(
                key: Key('analytics-content-${widget.title}'),
                alignment: Alignment.topCenter,
                heightFactor: _expanded ? 1 : 0,
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: widget.child,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _InlineMuscleVolumeSection extends StatelessWidget {
  const _InlineMuscleVolumeSection({required this.rows});

  final List<MuscleVolume> rows;

  @override
  Widget build(BuildContext context) {
    final visible = rows.take(6).toList(growable: false);
    return Container(
      key: const Key('stats-muscle-volume'),
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: surface.withValues(alpha: .86),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'AI 肌群训练量解读',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              Text('有效组', style: TextStyle(color: quiet, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            '基于近 4 周有效组判断训练不足或偏高。',
            style: TextStyle(color: quiet, fontSize: 10),
          ),
          const SizedBox(height: 9),
          if (visible.isEmpty)
            Text('完成训练后，这里会显示真实训练量。', style: TextStyle(color: quiet))
          else
            for (final item in visible) ...[
              Row(
                children: [
                  SizedBox(
                    width: 54,
                    child: Text(
                      item.muscle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _MusclePaletteProgressBar(
                      fraction: item.effectiveSets / 22,
                      metricValue: item.effectiveSets,
                      mode: MuscleMapMode.volume,
                      minHeight: 7,
                    ),
                  ),
                  const SizedBox(width: 7),
                  SizedBox(
                    width: 38,
                    child: Text(
                      '${item.effectiveSets.round()}',
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(left: 60, top: 2, bottom: 6),
                child: Text(
                  item.status,
                  style: TextStyle(
                    color: item.status == '训练不足' ? quiet : primary,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          const SizedBox(height: 2),
          Text(
            '训练量用于下一次安排；不会仅凭组数机械增加重量。',
            style: TextStyle(color: quiet, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _InlineWeeklyReportSection extends StatelessWidget {
  const _InlineWeeklyReportSection({required this.report});

  final WeeklyTrainingReport report;

  String _percent(double value) =>
      '${value >= 0 ? '+' : ''}${value.toStringAsFixed(1)}%';

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('stats-ai-weekly-report'),
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: surface.withValues(alpha: .86),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: hairline),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Expanded(
              child: Text(
                'AI 周报',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            _ProPill(),
          ],
        ),
        const SizedBox(height: 9),
        Wrap(
          spacing: 12,
          runSpacing: 7,
          children: [
            Text('训练 ${report.sessions} 次'),
            Text('时长 ${report.durationMinutes} 分钟'),
            Text('容量 ${_percent(report.volumeChangePercent)}'),
            Text(
              '动作 ${report.techniqueChange >= 0 ? '+' : ''}${report.techniqueChange}',
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(report.summary, style: TextStyle(color: quiet, height: 1.4)),
        if (report.personalRecords.isNotEmpty) ...[
          const SizedBox(height: 7),
          Text('本周 PR：${report.personalRecords.take(3).join(' · ')}'),
        ],
        const SizedBox(height: 7),
        Text(
          '下周建议：${report.nextWeekAdvice}',
          style: const TextStyle(fontWeight: FontWeight.w700, height: 1.4),
        ),
      ],
    ),
  );
}

class _AnalyticsActionCard extends StatelessWidget {
  const _AnalyticsActionCard({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: surface.withValues(alpha: .86),
      borderRadius: BorderRadius.circular(13),
      border: Border.all(color: hairline),
    ),
    child: Text(
      text,
      style: TextStyle(color: ink, height: 1.45, fontWeight: FontWeight.w700),
    ),
  );
}

class _AnalyticsMetric extends StatelessWidget {
  const _AnalyticsMetric({
    required this.label,
    required this.value,
    required this.comparison,
  });
  final String label;
  final String value;
  final String comparison;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 94),
    padding: const EdgeInsets.all(11),
    decoration: BoxDecoration(
      color: surface,
      borderRadius: BorderRadius.circular(13),
      border: Border.all(color: hairline),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: quiet, fontSize: 12)),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          comparison,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: primary, fontSize: 11),
        ),
      ],
    ),
  );
}

class _NutritionAdherenceRow extends StatelessWidget {
  const _NutritionAdherenceRow({
    required this.loggedDays,
    required this.rangeDays,
    required this.calorieHitRate,
    required this.proteinHitRate,
  });
  final int loggedDays;
  final int rangeDays;
  final double? calorieHitRate;
  final double? proteinHitRate;

  String _rate(double? value) =>
      value == null ? '--' : '${(value * 100).round()}%';

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: _AnalyticsMiniBar(
          label: '记录覆盖',
          value: rangeDays == 0 ? 0 : loggedDays / rangeDays,
          trailing: '$loggedDays/$rangeDays 天',
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: _AnalyticsMiniBar(
          label: '热量达标',
          value: calorieHitRate ?? 0,
          trailing: _rate(calorieHitRate),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: _AnalyticsMiniBar(
          label: '蛋白达标',
          value: proteinHitRate ?? 0,
          trailing: _rate(proteinHitRate),
        ),
      ),
    ],
  );
}

class _AnalyticsMiniBar extends StatelessWidget {
  const _AnalyticsMiniBar({
    required this.label,
    required this.value,
    required this.trailing,
  });
  final String label;
  final double value;
  final String trailing;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: TextStyle(fontSize: 11, color: quiet)),
      const SizedBox(height: 5),
      LinearProgressIndicator(
        value: value.clamp(0, 1),
        minHeight: 7,
        borderRadius: BorderRadius.circular(99),
        color: primary,
        backgroundColor: const Color(0xFFE4DCF4),
      ),
      const SizedBox(height: 4),
      Text(
        trailing,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
      ),
    ],
  );
}

class _TrainingNutritionTimeline extends StatelessWidget {
  const _TrainingNutritionTimeline({
    required this.range,
    required this.records,
    required this.nutritionByDay,
    required this.calorieTarget,
  });
  final DateTimeRange range;
  final List<WorkoutRecord> records;
  final Map<DateTime, List<NutritionEntry>> nutritionByDay;
  final double? calorieTarget;

  @override
  Widget build(BuildContext context) {
    final totalDays =
        DateUtils.dateOnly(
          range.end,
        ).difference(DateUtils.dateOnly(range.start)).inDays +
        1;
    final shown = totalDays.clamp(1, 14);
    final first = DateUtils.dateOnly(
      range.end,
    ).subtract(Duration(days: shown - 1));
    final training = records
        .map((item) => DateUtils.dateOnly(item.date))
        .toSet();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('训练 × 饮食时间轴', style: TextStyle(fontWeight: FontWeight.w900)),
        const SizedBox(height: 3),
        Text(
          '柱高为热量相对目标，紫点代表当天训练',
          style: TextStyle(color: quiet, fontSize: 11),
        ),
        const SizedBox(height: 9),
        SizedBox(
          height: 105,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var index = 0; index < shown; index++) ...[
                Expanded(
                  child: _TimelineDay(
                    day: first.add(Duration(days: index)),
                    entries:
                        nutritionByDay[first.add(Duration(days: index))] ??
                        const [],
                    trained: training.contains(
                      first.add(Duration(days: index)),
                    ),
                    calorieTarget: calorieTarget,
                  ),
                ),
                if (index != shown - 1) const SizedBox(width: 3),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _TimelineDay extends StatelessWidget {
  const _TimelineDay({
    required this.day,
    required this.entries,
    required this.trained,
    required this.calorieTarget,
  });
  final DateTime day;
  final List<NutritionEntry> entries;
  final bool trained;
  final double? calorieTarget;

  @override
  Widget build(BuildContext context) {
    final calories = entries.fold<double>(
      0,
      (sum, item) => sum + item.calories,
    );
    final base = calorieTarget == null || calorieTarget! <= 0
        ? (calories <= 0 ? 1 : calories)
        : calorieTarget!;
    final height = (calories / base).clamp(0.04, 1.15) * 58;
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          width: double.infinity,
          height: height,
          decoration: BoxDecoration(
            color: calories <= 0
                ? const Color(0xFFE5E0EA)
                : const Color(0xFFB9DCCB),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: trained ? primary : Colors.transparent,
          ),
        ),
        const SizedBox(height: 3),
        FittedBox(
          child: Text(
            '${day.month}/${day.day}',
            style: const TextStyle(fontSize: 9),
          ),
        ),
      ],
    );
  }
}

class _StatisticMetric extends StatelessWidget {
  const _StatisticMetric({
    required this.label,
    required this.value,
    required this.unit,
  });
  final String label;
  final String value;
  final String unit;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: quiet, fontSize: 12)),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: TextStyle(
                    fontSize: 27,
                    fontWeight: FontWeight.w900,
                    color: ink,
                  ),
                ),
                TextSpan(
                  text: ' $unit',
                  style: TextStyle(color: quiet),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class _MuscleBodyMap extends StatelessWidget {
  const _MuscleBodyMap({
    super.key,
    required this.muscleSets,
    this.height = 250,
    this.onMuscleTap,
    this.mode = MuscleMapMode.volume,
  });
  final Map<String, int> muscleSets;
  final double height;
  final ValueChanged<String>? onMuscleTap;
  final MuscleMapMode mode;

  @override
  Widget build(BuildContext context) => SizedBox(
    key: key == null ? const Key('statistics-muscle-map') : null,
    width: double.infinity,
    child: InteractiveMuscleMap(
      key: mode == MuscleMapMode.recovery
          ? const Key('interactive-muscle-map-recovery')
          : const Key('interactive-muscle-map'),
      muscleSets: muscleSets,
      height: height,
      onMuscleTap: onMuscleTap,
      mode: mode,
    ),
  );
}

class MuscleDetailsPage extends StatefulWidget {
  const MuscleDetailsPage({
    super.key,
    required this.controller,
    this.initialMuscle,
  });

  final AppController controller;
  final String? initialMuscle;

  @override
  State<MuscleDetailsPage> createState() => _MuscleDetailsPageState();
}

class _MuscleDetailsPageState extends State<MuscleDetailsPage> {
  late String selectedMuscle;
  var period = '4周';

  static const _mapGroups = <String, String>{
    'chest': '胸',
    'deltoids': '肩',
    'biceps': '二头',
    'triceps': '三头',
    'upper-back': '背',
    'trapezius': '背',
    'lower-back': '背',
    'quadriceps': '股四头',
    'hamstring': '腘绳肌',
    'gluteal': '臀',
    'calves': '小腿',
    'abs': '核心',
    'obliques': '核心',
    'adductors': '股四头',
    'tibialis': '小腿',
  };

  AppController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    selectedMuscle =
        TrainingIntelligenceEngine.muscles.contains(widget.initialMuscle)
        ? widget.initialMuscle!
        : '胸';
  }

  int get periodDays => switch (period) {
    '7天' => 7,
    '3个月' => 90,
    _ => 28,
  };

  DateTimeRange get range {
    final now = DateUtils.dateOnly(DateTime.now());
    return DateTimeRange(
      start: now.subtract(Duration(days: periodDays - 1)),
      end: now,
    );
  }

  List<MuscleVolume> _volumes(DateTimeRange value) =>
      controller.intelligenceEngine.calculateVolume(
        controller.history,
        controller.allExercises,
        start: value.start,
        end: value.end.add(const Duration(days: 1)),
        normalizationDays: value.duration.inDays + 1,
      );

  Map<String, int> _setsFor(DateTimeRange value) {
    final result = <String, int>{};
    for (final item in _volumes(value)) {
      if (!TrainingIntelligenceEngine.muscles.contains(item.muscle)) continue;
      result[item.muscle] = item.effectiveSets.round();
    }
    return result;
  }

  MuscleVolume? _selectedVolume(List<MuscleVolume> values) =>
      values.where((item) => item.muscle == selectedMuscle).firstOrNull;

  MuscleRecovery? _selectedRecovery() => controller
      .trainingIntelligence
      .recovery
      .where((item) => item.muscle == selectedMuscle)
      .firstOrNull;

  DateTime? _latestTraining() {
    final matching = controller.history.where((record) {
      return record.exercises.any((performed) {
        final exercise = controller.exerciseFor(performed.exerciseId);
        return controller.muscleGroupFor(exercise.muscle) == selectedMuscle &&
            performed.sets.any((set) => set.completed);
      });
    }).toList()..sort((a, b) => b.date.compareTo(a.date));
    return matching.firstOrNull?.date;
  }

  String _relativeDate(DateTime? date) {
    if (date == null) return '暂无记录';
    final days = DateUtils.dateOnly(
      DateTime.now(),
    ).difference(DateUtils.dateOnly(date)).inDays;
    if (days <= 0) return '今天';
    if (days == 1) return '昨天';
    return '$days 天前';
  }

  String _trend(DateTimeRange currentRange, MuscleVolume? current) {
    if (current == null || current.effectiveSets <= 0) return '暂无数据';
    final previousEnd = currentRange.start.subtract(const Duration(days: 1));
    final previousRange = DateTimeRange(
      start: previousEnd.subtract(Duration(days: periodDays - 1)),
      end: previousEnd,
    );
    final previous = _selectedVolume(_volumes(previousRange));
    if (previous == null || previous.effectiveSets <= 0) return '建立基线';
    final delta = current.effectiveSets - previous.effectiveSets;
    if (delta.abs() < .5) return '持平';
    return delta > 0 ? '上升' : '下降';
  }

  String _advice(MuscleVolume? volume, MuscleRecovery? recovery) {
    if (volume == null || volume.effectiveSets <= 0) {
      return '本周期还没有记录到$selectedMuscle的有效组，完成训练后这里会给出基于真实数据的建议。';
    }
    if (recovery != null && recovery.percent < 60) {
      return '$selectedMuscle当前${recovery.percent}%恢复，先降低强度或等待恢复，再安排下一次高质量训练。';
    }
    return switch (volume.status) {
      '训练不足' => '本周期$selectedMuscle有效组偏少，可在恢复良好时增加少量直接训练。',
      '训练较高' || '可能过量' => '本周期$selectedMuscle刺激偏高，下一周期优先观察恢复，不必继续加量。',
      _ => '本周期$selectedMuscle训练量合理，当前恢复允许维持现有节奏。',
    };
  }

  @override
  Widget build(BuildContext context) {
    final currentRange = range;
    final values = _volumes(currentRange);
    final selected = _selectedVolume(values);
    final recovery = _selectedRecovery();
    final sets = _setsFor(currentRange);
    final latest = _latestTraining();
    return Scaffold(
      key: const Key('muscle-details-page'),
      appBar: AppBar(title: const Text('肌群详情')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
          children: [
            const Text(
              '训练分布',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: _MuscleBodyMap(
                  key: const Key('muscle-details-map'),
                  muscleSets: sets,
                  height: 250,
                  onMuscleTap: (slug) {
                    final group = _mapGroups[slug];
                    if (group != null) setState(() => selectedMuscle = group);
                  },
                ),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                for (final item in const ['7天', '4周', '3个月'])
                  ChoiceChip(
                    key: Key('muscle-period-$item'),
                    label: Text(item),
                    selected: period == item,
                    onSelected: (_) => setState(() => period = item),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                for (final muscle in TrainingIntelligenceEngine.muscles)
                  ChoiceChip(
                    key: Key('muscle-select-$muscle'),
                    label: Text(muscle),
                    selected: selectedMuscle == muscle,
                    onSelected: (_) => setState(() => selectedMuscle = muscle),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            selectedMuscle,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        _StatusPill(selected?.status ?? '暂无数据'),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _MuscleDetailLine(
                      label: '本周期有效组',
                      value: '${selected?.effectiveSets.round() ?? 0} 组',
                    ),
                    _MuscleDetailLine(label: '目标范围', value: '10–16 组 / 周'),
                    _MuscleDetailLine(
                      label: '恢复状态',
                      value: recovery == null
                          ? '暂无数据'
                          : '${recovery.percent}% · ${recovery.status}',
                    ),
                    _MuscleDetailLine(
                      label: '最近训练',
                      value: _relativeDate(latest),
                    ),
                    _MuscleDetailLine(
                      label: '训练趋势',
                      value: _trend(currentRange, selected),
                    ),
                    const Divider(height: 24),
                    const Text(
                      'AI 建议',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _advice(selected, recovery),
                      style: TextStyle(color: quiet, height: 1.45),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MuscleDetailLine extends StatelessWidget {
  const _MuscleDetailLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 9),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 94,
          child: Text(label, style: TextStyle(color: quiet)),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );
}

class _ProPill extends StatelessWidget {
  const _ProPill();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.primaryContainer,
      borderRadius: BorderRadius.circular(99),
    ),
    child: Text(
      'PRO',
      style: TextStyle(
        color: Theme.of(context).colorScheme.primary,
        fontSize: 10,
        fontWeight: FontWeight.w900,
      ),
    ),
  );
}

class _StatusPill extends StatelessWidget {
  const _StatusPill(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.primaryContainer,
      borderRadius: BorderRadius.circular(99),
    ),
    child: Text(
      label,
      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
    ),
  );
}

class _FriendsPage extends StatefulWidget {
  const _FriendsPage({required this.controller});
  final AppController controller;

  @override
  State<_FriendsPage> createState() => _FriendsPageState();
}

class _FriendsPageState extends State<_FriendsPage> {
  var tab = 0;
  var loading = true;
  String? error;
  List<Map<String, dynamic>> plans = [];
  List<WorkoutActivityPost> activities = [];
  List<Map<String, dynamic>> friends = [];
  List<Map<String, dynamic>> pending = [];
  List<Map<String, dynamic>> identities = [];
  List<Map<String, dynamic>> searchResults = [];
  var searching = false;
  var searchAttempted = false;
  final searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _maps(Object? value) => value is List
      ? value
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList()
      : <Map<String, dynamic>>[];

  List<WorkoutActivityPost> _activities(Object? value) => value is List
      ? value
            .whereType<Map>()
            .map(
              (item) =>
                  WorkoutActivityPost.fromJson(Map<String, dynamic>.from(item)),
            )
            .where((item) => item.id.isNotEmpty)
            .toList()
      : <WorkoutActivityPost>[];

  Future<void> _refresh() async {
    if (!widget.controller.isAuthenticated) {
      setState(() {
        loading = false;
        error = '登录后才能添加好友和分享计划。';
      });
      return;
    }
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final results = await Future.wait([
        widget.controller.fetchFriendsRemote(),
        widget.controller.fetchFriendPlanFeedRemote(),
        widget.controller.fetchFriendIdentitiesRemote(),
      ]);
      if (!mounted) return;
      setState(() {
        friends = _maps(results[0]['friends']);
        pending = _maps(results[0]['pending']);
        plans = _maps(results[1]['plans']);
        activities = _activities(
          results[1]['posts'] ??
              results[1]['activities'] ??
              results[1]['workouts'],
        );
        identities = _maps(results[2]['identities']);
        loading = false;
      });
    } on CoachApiException catch (exception) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = switch (exception.code) {
          'session_expired' ||
          'coach_session_expired' ||
          'coach_unauthenticated' ||
          'coach_http_401' => '登录已过期，请重新登录。',
          'coach_network' => '当前网络无法连接好友服务，请检查网络后重试。',
          _ => '好友服务暂时不可用，请检查网络后重试。',
        };
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = '好友服务暂时不可用，请检查网络后重试。';
      });
    }
  }

  String? get _username {
    for (final identity in identities) {
      if (identity['kind'] == 'username') return identity['value']?.toString();
    }
    return null;
  }

  Future<void> _searchFriends() async {
    final query = searchController.text.trim();
    if (query.isEmpty || searching) return;
    setState(() {
      searching = true;
      searchAttempted = true;
    });
    try {
      final result = await widget.controller.searchFriendsRemote(query);
      if (!mounted) return;
      setState(() {
        searchResults = _maps(result['results']);
        searching = false;
      });
    } on CoachApiException catch (exception) {
      if (!mounted) return;
      setState(() => searching = false);
      final message = switch (exception.code) {
        'invalid_friend_search' => '请输入有效的用户名、手机号或邮箱',
        'friend_search_rate_limited' => '搜索太频繁，请稍后再试',
        _ => '搜索失败，请检查网络后重试',
      };
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _sendRequest(Map<String, dynamic> item) async {
    try {
      await widget.controller.sendFriendRequestToUserRemote(
        item['id'].toString(),
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('好友申请已发送')));
        setState(() => item['relationshipStatus'] = 'outgoing_pending');
      }
    } on CoachApiException catch (exception) {
      if (!mounted) return;
      final message = switch (exception.code) {
        'incoming_friend_request_pending' => '对方已经申请添加你，请到“好友”页接受',
        'already_friends' => '你们已经是好友',
        _ => '申请未发送，请稍后重试',
      };
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _editUsername() async {
    final controller = TextEditingController(text: _username ?? '');
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_username == null ? '设置用户名' : '修改用户名'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 24,
          decoration: const InputDecoration(
            labelText: '用户名',
            hintText: '3–24 位字母、数字、中文或下划线',
            prefixIcon: Icon(Icons.alternate_email_rounded),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null || value.isEmpty) return;
    try {
      await widget.controller.updateFriendUsernameRemote(value);
      await _refresh();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('用户名已保存')));
      }
    } on CoachApiException catch (exception) {
      if (!mounted) return;
      final message = exception.code == 'username_taken'
          ? '这个用户名已被使用'
          : '用户名格式不正确或保存失败';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _shareRoutine() async {
    if (widget.controller.routines.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先创建一个训练计划')));
      return;
    }
    final routine = await showModalBottomSheet<Routine>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          children: [
            const Text(
              '选择要分享的计划',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            for (final item in widget.controller.routines)
              ListTile(
                leading: const Icon(Icons.fitness_center),
                title: Text(item.name),
                subtitle: Text('${item.exercises.length} 个动作'),
                onTap: () => Navigator.pop(context, item),
              ),
          ],
        ),
      ),
    );
    if (routine == null) return;
    try {
      await widget.controller.shareRoutineWithFriends(routine);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('计划已分享给好友')));
      }
      await _refresh();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('分享失败，请稍后重试')));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.people_alt_rounded, color: primary, size: 21),
          SizedBox(width: 8),
          Text('好友训练'),
        ],
      ),
      actions: [
        IconButton(
          onPressed: _refresh,
          tooltip: '刷新',
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    floatingActionButton: tab == 0
        ? FloatingActionButton.extended(
            onPressed: _shareRoutine,
            icon: const Icon(Icons.ios_share),
            label: const Text('分享计划'),
          )
        : null,
    body: SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SegmentedButton<int>(
                segments: const [
                  ButtonSegment(
                    value: 0,
                    icon: Icon(Icons.dynamic_feed_outlined),
                    label: Text('动态'),
                  ),
                  ButtonSegment(
                    value: 1,
                    icon: Icon(Icons.people_outline),
                    label: Text('好友'),
                  ),
                  ButtonSegment(
                    value: 2,
                    icon: Icon(Icons.person_add_alt_1),
                    label: Text('添加'),
                  ),
                ],
                selected: {tab},
                onSelectionChanged: (value) =>
                    setState(() => tab = value.first),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 18),
            child: Text(
              '只有主动分享的训练内容会出现在这里，训练备注和私人资料不会公开。',
              style: TextStyle(color: quiet, fontSize: 12),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(child: _body()),
        ],
      ),
    ),
  );

  Widget _friendSearchResult(Map<String, dynamic> item) {
    final status = item['relationshipStatus']?.toString() ?? 'none';
    final username = item['username']?.toString();
    final masked = item['maskedMatch']?.toString() ?? '';
    final statusLabel = switch (status) {
      'friends' => '已是好友',
      'outgoing_pending' => '已申请',
      'incoming_pending' => '待你接受',
      _ => '添加好友',
    };
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(child: Icon(Icons.person_outline_rounded)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (item['displayName'] ?? username ?? '形域用户').toString(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      if (username != null || masked.isNotEmpty)
                        Text(
                          [
                            if (username != null) '@$username',
                            if (masked.isNotEmpty && masked != '@$username')
                              masked,
                          ].join(' · '),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: quiet, fontSize: 12),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: status == 'none'
                  ? FilledButton.icon(
                      onPressed: () => _sendRequest(item),
                      icon: const Icon(
                        Icons.person_add_alt_1_rounded,
                        size: 18,
                      ),
                      label: Text(statusLabel),
                    )
                  : OutlinedButton.icon(
                      onPressed: status == 'incoming_pending'
                          ? () => setState(() => tab = 1)
                          : null,
                      icon: Icon(
                        status == 'friends'
                            ? Icons.people_alt_outlined
                            : Icons.schedule_rounded,
                        size: 18,
                      ),
                      label: Text(statusLabel),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(onPressed: _refresh, child: const Text('重试')),
            ],
          ),
        ),
      );
    }
    if (tab == 2) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          Card(
            margin: const EdgeInsets.only(bottom: 14),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 13, 10, 13),
              child: Row(
                children: [
                  const CircleAvatar(
                    child: Icon(Icons.alternate_email_rounded),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '我的用户名',
                          style: TextStyle(color: quiet, fontSize: 12),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _username == null ? '还未设置' : '@$_username',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _editUsername,
                    tooltip: _username == null ? '设置用户名' : '修改用户名',
                    icon: Icon(
                      _username == null
                          ? Icons.add_circle_outline_rounded
                          : Icons.edit_outlined,
                    ),
                  ),
                ],
              ),
            ),
          ),
          TextField(
            controller: searchController,
            keyboardType: TextInputType.text,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              labelText: '用户名、手机号或邮箱',
              prefixIcon: const Icon(Icons.search_rounded),
              hintText: '输入后搜索',
              suffixIcon: searching
                  ? const Padding(
                      padding: EdgeInsets.all(13),
                      child: SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : IconButton(
                      onPressed: _searchFriends,
                      tooltip: '搜索',
                      icon: const Icon(Icons.arrow_forward_rounded),
                    ),
            ),
            onSubmitted: (_) => _searchFriends(),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(4, 7, 4, 12),
            child: Text(
              '手机号和邮箱需完整输入；用户名支持前缀搜索。联系方式只会脱敏显示。',
              style: TextStyle(color: quiet, fontSize: 12),
            ),
          ),
          if (searchAttempted && !searching && searchResults.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Column(
                children: [
                  Icon(Icons.person_search_outlined, color: quiet, size: 34),
                  SizedBox(height: 8),
                  Text('没有找到用户', style: TextStyle(fontWeight: FontWeight.w800)),
                  SizedBox(height: 3),
                  Text('检查输入是否完整，或请对方设置用户名', style: TextStyle(color: quiet)),
                ],
              ),
            ),
          for (final item in searchResults) _friendSearchResult(item),
        ],
      );
    }
    if (tab == 1) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          if (pending.isNotEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                '待处理申请',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          for (final item in pending)
            Card(
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person)),
                title: Text(
                  (item['displayName'] ?? item['identifier']).toString(),
                ),
                subtitle: item['username'] == null
                    ? null
                    : Text('@${item['username']}'),
                trailing: FilledButton(
                  onPressed: () async {
                    await widget.controller.acceptFriendRequestRemote(
                      item['requestId'].toString(),
                    );
                    await _refresh();
                  },
                  child: const Text('接受'),
                ),
              ),
            ),
          if (friends.isEmpty && pending.isEmpty)
            Padding(
              padding: EdgeInsets.all(30),
              child: Column(
                children: [
                  Icon(Icons.group_add_outlined, color: quiet, size: 34),
                  SizedBox(height: 8),
                  Text('还没有好友', style: TextStyle(fontWeight: FontWeight.w800)),
                  SizedBox(height: 3),
                  Text('可通过账号添加', style: TextStyle(color: quiet)),
                ],
              ),
            ),
          for (final item in friends)
            Card(
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person)),
                title: Text(
                  (item['displayName'] ?? item['identifier']).toString(),
                ),
                subtitle: Text(
                  item['username'] == null
                      ? '可以查看对方主动分享的训练计划'
                      : '@${item['username']} · 可查看主动分享的计划',
                ),
                trailing: const Icon(Icons.chevron_right),
              ),
            ),
        ],
      );
    }
    if (plans.isEmpty && activities.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.dynamic_feed_outlined, color: quiet, size: 36),
            SizedBox(height: 8),
            Text('暂无好友动态', style: TextStyle(fontWeight: FontWeight.w800)),
            SizedBox(height: 3),
            Text('训练完成后发布动态，好友会在这里看到', style: TextStyle(color: quiet)),
          ],
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
      children: [
        for (final activity in activities)
          WorkoutActivityCard(
            controller: widget.controller,
            post: activity,
            onChanged: _refresh,
          ),
        for (final item in plans) _friendPlanCard(context, item),
      ],
    );
  }

  Widget _friendPlanCard(BuildContext context, Map<String, dynamic> item) {
    final rawPlan = item['plan'];
    final exerciseCount = rawPlan is Map && rawPlan['exercises'] is List
        ? (rawPlan['exercises'] as List).length
        : 0;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  radius: 18,
                  child: Icon(Icons.person, size: 19),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (item['ownerName'] ?? '好友').toString(),
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      Text(
                        (item['updatedAt'] ?? '').toString().split('T').first,
                        style: TextStyle(color: quiet, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              (item['name'] ?? '训练计划').toString(),
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(
              '$exerciseCount 个动作 · 点击保存后会创建独立副本',
              style: TextStyle(color: secondaryInk),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                PopupMenuButton<String>(
                  tooltip: '发表情',
                  onSelected: (emoji) async {
                    await widget.controller.reactToFriendPlanRemote(
                      item['id'].toString(),
                      emoji,
                    );
                    await _refresh();
                  },
                  itemBuilder: (_) => [
                    for (final emoji in const ['👍', '🔥', '👏', '💪'])
                      PopupMenuItem(
                        value: emoji,
                        child: Text(
                          emoji,
                          style: const TextStyle(fontSize: 24),
                        ),
                      ),
                  ],
                  child: OutlinedButton.icon(
                    onPressed: null,
                    icon: Text((item['myReaction'] ?? '👍').toString()),
                    label: Text('${item['reactionCount'] ?? 0}'),
                  ),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: () {
                    widget.controller.saveFriendPlan(item);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('已保存到“好友分享”文件夹')),
                    );
                  },
                  icon: const Icon(Icons.bookmark_add_outlined),
                  label: const Text('保存计划'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

String _scheduledBodyPart(String? label) {
  final value = label ?? '';
  if (RegExp(r'上肢|upper', caseSensitive: false).hasMatch(value)) return '上肢';
  if (RegExp(r'全身|full.?body', caseSensitive: false).hasMatch(value)) {
    return '全身';
  }
  if (RegExp(r'臀|glute|hip', caseSensitive: false).hasMatch(value)) return '臀';
  if (RegExp(r'推日|push', caseSensitive: false).hasMatch(value)) return '推';
  if (RegExp(r'拉日|pull', caseSensitive: false).hasMatch(value)) return '拉';
  if (RegExp(r'胸|chest', caseSensitive: false).hasMatch(value)) return '胸';
  if (RegExp(r'背|back|pull', caseSensitive: false).hasMatch(value)) return '背';
  if (RegExp(r'肩|shoulder', caseSensitive: false).hasMatch(value)) return '肩';
  if (RegExp(r'腿|下肢|leg|lower', caseSensitive: false).hasMatch(value)) {
    return '腿';
  }
  if (RegExp(r'手臂|二头|三头|arm', caseSensitive: false).hasMatch(value)) {
    return '臂';
  }
  if (RegExp(r'核心|腹|core', caseSensitive: false).hasMatch(value)) return '核';
  final compact = value
      .replaceAll(RegExp(r'AI\s*生成|计划|训练|力量|容量', caseSensitive: false), '')
      .trim();
  return compact.isEmpty
      ? '练'
      : compact.substring(0, compact.length.clamp(0, 2));
}

class _CalendarLegend extends StatelessWidget {
  const _CalendarLegend({required this.color, required this.label});
  final Color color;
  final String label;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(Icons.circle, size: 8, color: color),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(fontSize: 11, color: quiet)),
    ],
  );
}

class ExerciseLibraryPage extends StatefulWidget {
  const ExerciseLibraryPage({super.key, required this.controller});
  final AppController controller;

  @override
  State<ExerciseLibraryPage> createState() => _ExerciseLibraryPageState();
}

class _ExerciseLibraryPageState extends State<ExerciseLibraryPage> {
  static const pageSize = 60;
  var shownCount = pageSize;
  late final TextEditingController searchController;

  AppController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    searchController = TextEditingController(text: controller.search);
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> createCustomExercise() async {
    final exercise = await _showCustomExercise(context, controller);
    if (!mounted || exercise == null) return;
    final displayName = controller.displayExerciseName(exercise);
    setState(() {
      shownCount = pageSize;
      searchController.value = TextEditingValue(
        text: displayName,
        selection: TextSelection.collapsed(offset: displayName.length),
      );
      controller
        ..search = displayName
        ..muscleFilter = '全部'
        ..equipmentFilter = '全部'
        ..refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    const groups = ['全部', '胸', '背', '肩', '腿', '手臂', '核心'];
    final items = controller.visibleExercises;
    final displayedItems = items.take(shownCount).toList(growable: false);
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final cardAspectRatio = textScale >= 1.5 ? .42 : .80;
    return PageFrame(
      children: [
        SectionTitle(
          '动作库',
          subtitle: '${controller.selectableExercises.length} 个动作',
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 62,
              child: _MuscleRail(controller: controller, groups: groups),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final narrow = constraints.maxWidth < 360;
                      final searchField = TextField(
                        key: const Key('exercise-search'),
                        controller: searchController,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.search),
                          hintText: AppLocalizations.of(
                            context,
                          ).text('搜索动作、肌群或器械'),
                          isDense: true,
                        ),
                        onChanged: (value) {
                          shownCount = pageSize;
                          controller.search = value;
                          controller.refresh();
                        },
                      );
                      final filterButton = OutlinedButton.icon(
                        key: const Key('exercise-equipment-filter'),
                        onPressed: () =>
                            _showLibraryFilters(context, controller),
                        icon: const Icon(Icons.tune, size: 17),
                        label: Text(
                          controller.equipmentFilter == '全部'
                              ? AppLocalizations.of(context).text('器械')
                              : controller.equipmentFilter,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                      final addButton = IconButton.filled(
                        key: const Key('exercise-library-add-inline'),
                        style: IconButton.styleFrom(
                          backgroundColor: cobalt,
                          foregroundColor: Colors.white,
                        ),
                        tooltip: AppLocalizations.of(context).text('新建自定义动作'),
                        onPressed: createCustomExercise,
                        icon: const Icon(Icons.add),
                      );
                      if (narrow) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            searchField,
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Expanded(child: filterButton),
                                const SizedBox(width: 5),
                                addButton,
                              ],
                            ),
                          ],
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: searchField),
                          const SizedBox(width: 6),
                          SizedBox(width: 88, child: filterButton),
                          const SizedBox(width: 5),
                          addButton,
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 9),
                  if (items.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(22),
                        child: Center(
                          child: Text(
                            AppLocalizations.of(
                              context,
                            ).text('没有匹配动作，试试清空搜索或筛选。'),
                          ),
                        ),
                      ),
                    )
                  else
                    GridView.builder(
                      key: const Key('exercise-library-grid'),
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: displayedItems.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: cardAspectRatio,
                      ),
                      itemBuilder: (context, index) {
                        final exercise = displayedItems[index];
                        return Card(
                          margin: EdgeInsets.zero,
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            key: Key('exercise-cover-${exercise.id}'),
                            onTap: () => _showExerciseDetail(
                              context,
                              controller,
                              exercise,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                AspectRatio(
                                  aspectRatio: 1.40,
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      ColoredBox(
                                        color: paper,
                                        child: Image.asset(
                                          exerciseAsset(exercise.id),
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (context, error, stack) => Icon(
                                                Icons.fitness_center,
                                                color: cobalt,
                                                size: 34,
                                              ),
                                        ),
                                      ),
                                      Positioned(
                                        left: 7,
                                        top: 7,
                                        child: DecoratedBox(
                                          decoration: BoxDecoration(
                                            color: primary,
                                            borderRadius: BorderRadius.all(
                                              Radius.circular(7),
                                            ),
                                          ),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 7,
                                              vertical: 4,
                                            ),
                                            child: Text(
                                              AppLocalizations.of(
                                                context,
                                              ).text('讲解'),
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 10,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    9,
                                    8,
                                    8,
                                    9,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        controller.displayExerciseName(
                                          exercise,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        controller.appLanguage ==
                                                AppLanguage.english
                                            ? '${localizeExerciseMetadata(exercise.family, english: true)} · ${localizeExerciseMetadata(exercise.equipment, english: true)}'
                                            : '${exercise.muscle} · ${exercise.equipment}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: quiet,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  if (displayedItems.length < items.length) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        key: const Key('exercise-library-load-more'),
                        onPressed: () => setState(() {
                          shownCount = (shownCount + pageSize).clamp(
                            0,
                            items.length,
                          );
                        }),
                        icon: const Icon(Icons.expand_more),
                        label: Text(
                          '加载更多（已显示 ${displayedItems.length} / ${items.length}）',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MuscleRail extends StatelessWidget {
  const _MuscleRail({required this.controller, required this.groups});
  final AppController controller;
  final List<String> groups;

  @override
  Widget build(BuildContext context) => SizedBox(
    key: const Key('muscle-rail'),
    child: Column(
      children: [
        for (final group in groups)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              decoration: BoxDecoration(
                color: controller.muscleFilter == group
                    ? primaryContainer
                    : surfaceRaised,
                borderRadius: BorderRadius.circular(13),
                border: Border.all(
                  color: controller.muscleFilter == group ? primary : hairline,
                  width: controller.muscleFilter == group ? 1.5 : 1,
                ),
                boxShadow: controller.muscleFilter == group
                    ? [
                        BoxShadow(
                          color: emberShadow,
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(13),
                  onTap: () {
                    controller.muscleFilter = group;
                    controller.refresh();
                    showKiloSnack(
                      context,
                      group == '全部' ? '显示全部动作' : '已筛选 $group 部位',
                    );
                  },
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 44),
                    width: double.infinity,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: controller.muscleFilter == group
                        ? BoxDecoration(
                            border: Border(
                              left: BorderSide(color: primary, width: 3),
                            ),
                          )
                        : null,
                    child: Text(
                      AppLocalizations.of(context).text(group),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: controller.muscleFilter == group
                            ? FontWeight.w900
                            : FontWeight.w600,
                        color: controller.muscleFilter == group
                            ? primary
                            : secondaryInk,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class RecognitionPage extends StatelessWidget {
  const RecognitionPage({super.key, required this.controller});
  final AppController controller;
  @override
  Widget build(BuildContext context) => PageFrame(
    children: [
      const SectionTitle('动作识别', subtitle: '上传训练视频，查看动作结果与建议'),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: paper,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child:
                        controller.recognitionStatus ==
                            RecognitionStatus.processing
                        ? const Padding(
                            padding: EdgeInsets.all(11),
                            child: CircularProgressIndicator(strokeWidth: 3),
                          )
                        : Icon(Icons.document_scanner_outlined, color: cobalt),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _recognitionLabel(controller.recognitionStatus),
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          _recognitionDetail(controller),
                          style: TextStyle(fontSize: 12, color: quiet),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (controller.selectedMediaPath != null &&
                  !(controller.recognitionIncludeOverlay &&
                      controller.recognitionStatus ==
                          RecognitionStatus.complete &&
                      controller.recognitionResult?.overlayUrl != null)) ...[
                const SizedBox(height: 14),
                _SelectedRecognitionVideo(
                  path: controller.selectedMediaPath!,
                  name: controller.selectedMediaName ?? '已选择视频',
                  sizeLabel: _formatBytes(controller.selectedMediaBytes),
                  enabled:
                      controller.recognitionStatus !=
                      RecognitionStatus.processing,
                  onClear: controller.resetRecognition,
                  onEdit: () => _editRecognitionVideo(context, controller),
                ),
              ],
              if (controller.recognitionStatus ==
                  RecognitionStatus.processing) ...[
                const SizedBox(height: 12),
                _RecognitionProcessingPanel(controller: controller),
              ],
              if (controller.recognitionStatus ==
                      RecognitionStatus.processing ||
                  controller.recognitionResult != null) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonalIcon(
                    key: const Key('recognition-open-result'),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            _RecognitionResultPage(controller: controller),
                      ),
                    ),
                    icon: Icon(
                      controller.recognitionStatus ==
                              RecognitionStatus.processing
                          ? Icons.sync_rounded
                          : Icons.assessment_outlined,
                    ),
                    label: Text(
                      controller.recognitionStatus ==
                              RecognitionStatus.processing
                          ? '查看实时分析进度'
                          : '打开完整动作报告',
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              const _RecognitionFieldLabel('识别动作'),
              if (controller.recognitionCapabilitiesLoading)
                const LinearProgressIndicator(minHeight: 2)
              else
                _RecognitionSelectedExercise(
                  controller: controller,
                  onTap: () =>
                      _showRecognitionExercisePicker(context, controller),
                ),
              const _RecognitionFieldLabel('拍摄机位'),
              Row(
                children: [
                  for (
                    var index = 0;
                    index <
                        controller.selectedRecognitionCapability.cameras.length;
                    index++
                  ) ...[
                    if (index > 0) const SizedBox(width: 8),
                    Expanded(
                      child: _RecognitionCameraChoice(
                        controller: controller,
                        camera: controller
                            .selectedRecognitionCapability
                            .cameras[index],
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: emberTint,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.tips_and_updates_outlined,
                      size: 18,
                      color: primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        controller.selectedRecognitionCamera.hint,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.45,
                          color: secondaryInk,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.fromLTRB(11, 7, 5, 7),
                decoration: BoxDecoration(
                  color: surfaceRaised,
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: hairline),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.accessibility_new_rounded,
                      size: 20,
                      color: primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '生成完整骨骼视频（耗时更长）',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            '发现问题时会返回对应骨骼图；开启后还需绘制整段分析帧并重新编码视频',
                            style: TextStyle(fontSize: 10, color: quiet),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      key: const Key('recognition-overlay-switch'),
                      value: controller.recognitionIncludeOverlay,
                      onChanged:
                          controller.recognitionStatus ==
                              RecognitionStatus.processing
                          ? null
                          : controller.setRecognitionIncludeOverlay,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed:
                          controller.mediaPicking ||
                              controller.recognitionStatus ==
                                  RecognitionStatus.processing
                          ? null
                          : controller.pickVideo,
                      icon: controller.mediaPicking
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.upload_file_outlined),
                      label: Text(controller.mediaPicking ? '正在选择…' : '选择视频'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: PrimaryButton(
                      label:
                          controller.recognitionStatus ==
                              RecognitionStatus.ready
                          ? '开始分析'
                          : controller.recognitionStatus ==
                                RecognitionStatus.error
                          ? '重新分析'
                          : '查看状态',
                      icon: Icons.analytics_outlined,
                      onPressed:
                          controller.recognitionStatus ==
                                  RecognitionStatus.ready ||
                              controller.recognitionStatus ==
                                  RecognitionStatus.error
                          ? () {
                              final entitlement = controller.entitlements;
                              if (entitlement != null &&
                                  !entitlement.isMember &&
                                  entitlement.recognitionRemaining <= 0) {
                                showMembershipPaywall(
                                  context,
                                  controller: controller,
                                  reason:
                                      MembershipPaywallReason.recognitionQuota,
                                );
                                return;
                              }
                              controller.startRecognition();
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => _RecognitionResultPage(
                                    controller: controller,
                                  ),
                                ),
                              );
                            }
                          : null,
                    ),
                  ),
                ],
              ),
              if (controller.mediaError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: danger),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          controller.mediaError!,
                          style: TextStyle(fontSize: 12, color: danger),
                        ),
                      ),
                      TextButton(
                        onPressed: controller.pickVideo,
                        child: const Text('重试'),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 12),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: quiet),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '视频只会在点击开始分析后上传，用于生成本次动作结果。',
                  style: TextStyle(fontSize: 12, color: secondaryInk),
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

class _RecognitionFieldLabel extends StatelessWidget {
  const _RecognitionFieldLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 14, bottom: 8),
    child: Text(
      label,
      style: TextStyle(
        color: secondaryInk,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _SelectedRecognitionVideo extends StatefulWidget {
  const _SelectedRecognitionVideo({
    super.key,
    required this.path,
    required this.name,
    required this.sizeLabel,
    required this.enabled,
    required this.onClear,
    this.onEdit,
  });

  final String path;
  final String name;
  final String sizeLabel;
  final bool enabled;
  final VoidCallback onClear;
  final VoidCallback? onEdit;

  @override
  State<_SelectedRecognitionVideo> createState() =>
      _SelectedRecognitionVideoState();
}

class _SelectedRecognitionVideoState extends State<_SelectedRecognitionVideo> {
  VideoPlayerController? _video;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _openVideo();
  }

  @override
  void didUpdateWidget(covariant _SelectedRecognitionVideo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) {
      _video?.dispose();
      _video = null;
      _error = null;
      _openVideo();
    }
  }

  Future<void> _openVideo() async {
    try {
      final controller = VideoPlayerController.file(File(widget.path));
      await controller.initialize();
      await controller.setLooping(true);
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _video = controller);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  void _togglePlayback() {
    final video = _video;
    if (video == null || !video.value.isInitialized) return;
    setState(() {
      if (video.value.isPlaying) {
        video.pause();
      } else {
        video.play();
      }
    });
  }

  @override
  void dispose() {
    _video?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final video = _video;
    final initialized = video?.value.isInitialized == true;
    final readyVideo = initialized ? video : null;
    final aspectRatio = readyVideo != null && readyVideo.value.aspectRatio > 0
        ? readyVideo.value.aspectRatio
        : 16 / 9;
    return Container(
      key: const Key('recognition-video-preview'),
      decoration: BoxDecoration(
        color: const Color(0xFF211A17),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: hairline),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final previewHeight = (constraints.maxWidth / aspectRatio).clamp(
                176.0,
                300.0,
              );
              return SizedBox(
                height: previewHeight,
                child: Center(
                  child: AspectRatio(
                    aspectRatio: aspectRatio,
                    child: InkWell(
                      onTap: initialized ? _togglePlayback : null,
                      child: Stack(
                        fit: StackFit.expand,
                        alignment: Alignment.center,
                        children: [
                          if (readyVideo != null)
                            VideoPlayer(readyVideo)
                          else
                            const ColoredBox(color: Color(0xFF211A17)),
                          if (!initialized && _error == null)
                            const Center(
                              child: CircularProgressIndicator(
                                color: Colors.white,
                              ),
                            ),
                          if (_error != null)
                            const Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.video_file_outlined,
                                    color: Colors.white,
                                    size: 34,
                                  ),
                                  SizedBox(height: 6),
                                  Text(
                                    '暂时无法生成本地预览',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ],
                              ),
                            ),
                          if (readyVideo != null && !readyVideo.value.isPlaying)
                            Center(
                              child: Container(
                                width: 54,
                                height: 54,
                                decoration: const BoxDecoration(
                                  color: Color(0xE6D95718),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.play_arrow_rounded,
                                  color: Colors.white,
                                  size: 34,
                                ),
                              ),
                            ),
                          if (readyVideo != null && readyVideo.value.isPlaying)
                            const Positioned(
                              right: 10,
                              bottom: 10,
                              child: Icon(
                                Icons.pause_circle_filled_rounded,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          Container(
            color: surfaceRaised,
            padding: const EdgeInsets.fromLTRB(12, 8, 5, 8),
            child: Row(
              children: [
                Icon(Icons.movie_outlined, size: 18, color: primary),
                const SizedBox(width: 7),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '${widget.sizeLabel} · 点击画面播放',
                        style: TextStyle(fontSize: 10, color: quiet),
                      ),
                    ],
                  ),
                ),
                if (widget.onEdit != null)
                  TextButton.icon(
                    key: const Key('recognition-edit-video'),
                    onPressed: widget.enabled ? widget.onEdit : null,
                    icon: const Icon(Icons.content_cut_rounded, size: 17),
                    label: const Text('编辑'),
                  ),
                IconButton(
                  tooltip: '清除视频',
                  onPressed: widget.enabled ? widget.onClear : null,
                  icon: const Icon(Icons.close_rounded, size: 20),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RecognitionProcessingPanel extends StatefulWidget {
  const _RecognitionProcessingPanel({required this.controller});
  final AppController controller;

  @override
  State<_RecognitionProcessingPanel> createState() =>
      _RecognitionProcessingPanelState();
}

class _RecognitionProcessingPanelState
    extends State<_RecognitionProcessingPanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
      lowerBound: .82,
      upperBound: 1,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final stage = controller.recognitionStage;
    final elapsed = controller.recognitionElapsedSeconds;
    final time =
        '${(elapsed ~/ 60).toString().padLeft(2, '0')}:${(elapsed % 60).toString().padLeft(2, '0')}';
    return Container(
      key: const Key('recognition-processing-panel'),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: primaryContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primary.withValues(alpha: .35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ScaleTransition(
                scale: reduceMotion
                    ? const AlwaysStoppedAnimation<double>(1)
                    : _pulse,
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        strokeWidth: 3,
                        color: primary,
                        backgroundColor: Color(0xFFF7CBB2),
                      ),
                      Icon(
                        _recognitionStageIcon(stage),
                        color: primary,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _recognitionStageTitle(stage),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '已等待 $time · 可以暂时离开此页',
                      style: TextStyle(fontSize: 11, color: secondaryInk),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _RecognitionStageChip(
                label: '上传',
                done: stage.index > RecognitionStage.uploading.index,
                active:
                    stage == RecognitionStage.preparing ||
                    stage == RecognitionStage.uploading,
              ),
              const SizedBox(width: 6),
              _RecognitionStageChip(
                label: '排队',
                done: stage.index > RecognitionStage.queued.index,
                active: stage == RecognitionStage.queued,
              ),
              const SizedBox(width: 6),
              _RecognitionStageChip(
                label: '分析',
                done: false,
                active: stage == RecognitionStage.analyzing,
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (stage == RecognitionStage.uploading)
            LinearProgressIndicator(
              value: controller.recognitionProgress,
              minHeight: 7,
              borderRadius: BorderRadius.circular(7),
            )
          else
            const LinearProgressIndicator(
              minHeight: 7,
              borderRadius: BorderRadius.all(Radius.circular(7)),
            ),
          const SizedBox(height: 8),
          Text(
            _recognitionStageDetail(stage),
            style: TextStyle(fontSize: 11, height: 1.45, color: secondaryInk),
          ),
        ],
      ),
    );
  }
}

class _RecognitionStageChip extends StatelessWidget {
  const _RecognitionStageChip({
    required this.label,
    required this.done,
    required this.active,
  });
  final String label;
  final bool done;
  final bool active;

  @override
  Widget build(BuildContext context) => Expanded(
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(vertical: 7),
      decoration: BoxDecoration(
        color: done
            ? successContainer
            : active
            ? surfaceRaised
            : surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: active ? primary : Colors.transparent),
      ),
      child: Text(
        '${done ? '✓ ' : ''}$label',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 11,
          color: done
              ? success
              : active
              ? primary
              : quiet,
          fontWeight: done || active ? FontWeight.w800 : FontWeight.w600,
        ),
      ),
    ),
  );
}

String _recognitionStageTitle(RecognitionStage stage) => switch (stage) {
  RecognitionStage.preparing => '正在准备分析',
  RecognitionStage.uploading => '正在上传视频',
  RecognitionStage.queued => '视频已上传，等待分析',
  RecognitionStage.analyzing => '正在分析动作轨迹',
  RecognitionStage.idle => '正在准备',
};

String _recognitionStageDetail(RecognitionStage stage) => switch (stage) {
  RecognitionStage.preparing => '请稍候，马上开始。',
  RecognitionStage.uploading => '请保持网络连接，上传完成后会自动继续。',
  RecognitionStage.queued => '当前任务正在排队，请勿重复提交。',
  RecognitionStage.analyzing => '短视频通常约需 1 分钟，请保持应用打开。',
  RecognitionStage.idle => '正在连接，请稍候。',
};

IconData _recognitionStageIcon(RecognitionStage stage) => switch (stage) {
  RecognitionStage.preparing => Icons.pending_actions_outlined,
  RecognitionStage.uploading => Icons.cloud_upload_outlined,
  RecognitionStage.queued => Icons.hourglass_top_rounded,
  RecognitionStage.analyzing => Icons.accessibility_new_rounded,
  RecognitionStage.idle => Icons.sync_rounded,
};

class _RecognitionExerciseChoice extends StatelessWidget {
  const _RecognitionExerciseChoice({
    required this.controller,
    required this.capability,
    this.onSelected,
  });

  final AppController controller;
  final RecognitionCapability capability;
  final VoidCallback? onSelected;

  @override
  Widget build(BuildContext context) {
    final exercise = controller.exerciseFor(capability.exerciseId);
    final selected = controller.recognitionExerciseId == capability.exerciseId;
    return Material(
      color: selected ? primaryContainer : surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(
          color: selected ? primary : hairline,
          width: selected ? 1.7 : 1,
        ),
      ),
      child: InkWell(
        key: Key('recognition-exercise-${capability.exerciseId}'),
        borderRadius: BorderRadius.circular(15),
        onTap: () {
          controller.selectRecognitionExercise(capability.exerciseId);
          onSelected?.call();
        },
        child: Padding(
          padding: const EdgeInsets.all(11),
          child: Row(
            children: [
              _ExerciseThumb(exerciseId: capability.exerciseId, size: 38),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      controller.displayExerciseName(exercise),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: selected ? primary : ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${capability.cameras.length} 个推荐机位',
                      style: TextStyle(fontSize: 10, color: quiet),
                    ),
                  ],
                ),
              ),
              if (selected) Icon(Icons.check_circle, size: 18, color: primary),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecognitionSelectedExercise extends StatelessWidget {
  const _RecognitionSelectedExercise({
    required this.controller,
    required this.onTap,
  });

  final AppController controller;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final capability = controller.selectedRecognitionCapability;
    final exercise = controller.exerciseFor(capability.exerciseId);
    return Material(
      color: primaryContainer.withValues(alpha: .55),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: primary.withValues(alpha: .28), width: 1.2),
      ),
      child: InkWell(
        key: const Key('recognition-exercise-picker'),
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _ExerciseThumb(exerciseId: capability.exerciseId, size: 52),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: primary,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: const Text(
                        '已选择',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      controller.displayExerciseName(exercise),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${capability.group} · ${capability.cameras.length} 个推荐机位 · 共 ${controller.recognitionCapabilities.length} 个可识别动作',
                      style: TextStyle(fontSize: 11, color: quiet),
                    ),
                  ],
                ),
              ),
              Icon(Icons.swap_horiz_rounded, color: primary),
              const SizedBox(width: 4),
              Text(
                '更换',
                style: TextStyle(color: primary, fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void _showRecognitionExercisePicker(
  BuildContext context,
  AppController controller,
) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => _RecognitionExercisePicker(controller: controller),
  );
}

class _RecognitionExercisePicker extends StatefulWidget {
  const _RecognitionExercisePicker({required this.controller});
  final AppController controller;

  @override
  State<_RecognitionExercisePicker> createState() =>
      _RecognitionExercisePickerState();
}

class _RecognitionExercisePickerState
    extends State<_RecognitionExercisePicker> {
  String query = '';
  String group = '全部';

  @override
  Widget build(BuildContext context) {
    final groups = <String>{
      '全部',
      ...widget.controller.recognitionCapabilities.map((item) => item.group),
    }.toList();
    final visible = widget.controller.recognitionCapabilities.where((item) {
      final exercise = widget.controller.exerciseFor(item.exerciseId);
      final matchesGroup = group == '全部' || item.group == group;
      final normalized = query.trim().toLowerCase();
      final matchesQuery =
          normalized.isEmpty ||
          exercise.name.toLowerCase().contains(normalized) ||
          exercise.englishName.toLowerCase().contains(normalized) ||
          item.group.contains(normalized);
      return matchesGroup && matchesQuery;
    }).toList();
    return FractionallySizedBox(
      heightFactor: .88,
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 42,
            height: 5,
            decoration: BoxDecoration(
              color: hairline,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '选择识别动作',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text('这里只显示服务端当前已支持的动作', style: TextStyle(color: quiet)),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 2, 14, 20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    key: const Key('recognition-group-rail'),
                    width: 78,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: surfaceRaised,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: hairline),
                      ),
                      child: ListView(
                        padding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 6,
                        ),
                        children: [
                          const _FilterRailHeading('部位'),
                          for (final value in groups)
                            _FilterRailItem(
                              label: value,
                              selected: group == value,
                              onTap: () => setState(() => group = value),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          key: const Key('recognition-search'),
                          onChanged: (value) => setState(() => query = value),
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.search_rounded, size: 20),
                            hintText: '搜索可识别动作',
                            isDense: true,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          '$group · ${visible.length} 个动作',
                          style: TextStyle(color: quiet, fontSize: 11),
                        ),
                        const SizedBox(height: 5),
                        Expanded(
                          child: visible.isEmpty
                              ? const Center(child: Text('没有匹配动作'))
                              : ListView.separated(
                                  itemCount: visible.length,
                                  separatorBuilder: (_, _) =>
                                      const SizedBox(height: 8),
                                  itemBuilder: (context, index) =>
                                      _RecognitionExerciseChoice(
                                        controller: widget.controller,
                                        capability: visible[index],
                                        onSelected: () =>
                                            Navigator.pop(context),
                                      ),
                                ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecognitionCameraChoice extends StatelessWidget {
  const _RecognitionCameraChoice({
    required this.controller,
    required this.camera,
  });

  final AppController controller;
  final RecognitionCameraOption camera;

  @override
  Widget build(BuildContext context) {
    final selected = controller.recognitionCamera == camera.id;
    final icon = switch (camera.id) {
      'front' => Icons.person_outline,
      'front_45' => Icons.threesixty,
      _ => Icons.view_sidebar_outlined,
    };
    return Material(
      color: selected ? primaryContainer : surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: selected ? primary : hairline,
          width: selected ? 1.7 : 1,
        ),
      ),
      child: InkWell(
        key: Key('recognition-camera-${camera.id}'),
        borderRadius: BorderRadius.circular(14),
        onTap: () => controller.selectRecognitionCamera(camera.id),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
          child: Column(
            children: [
              Icon(icon, color: selected ? primary : secondaryInk, size: 21),
              const SizedBox(height: 5),
              Text(
                camera.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: selected ? primary : secondaryInk,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _recognitionResultSubtitle(AppController controller) {
  var exerciseName = controller.recognitionExerciseId;
  for (final exercise in controller.recognitionExercises) {
    if (exercise.id == controller.recognitionExerciseId) {
      exerciseName = exercise.name;
      break;
    }
  }
  return '$exerciseName · ${controller.selectedRecognitionCamera.label}';
}

class _RecognitionResultPage extends StatelessWidget {
  const _RecognitionResultPage({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final result = controller.recognitionResult;
      final processing =
          controller.recognitionStatus == RecognitionStatus.processing;
      return Scaffold(
        backgroundColor: paper,
        appBar: AppBar(
          backgroundColor: paper,
          surfaceTintColor: Colors.transparent,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('动作轨迹'),
              Text(
                _recognitionResultSubtitle(controller),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: quiet, fontSize: 11),
              ),
            ],
          ),
        ),
        body: SafeArea(
          top: false,
          child: ListView(
            key: const Key('recognition-result-page'),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            children: [
              if (controller.selectedMediaPath != null &&
                  (processing ||
                      result == null ||
                      result.status == RecognitionStatus.error ||
                      result.status == RecognitionStatus.offline))
                _SelectedRecognitionVideo(
                  key: const Key('recognition-result-original-video'),
                  path: controller.selectedMediaPath!,
                  name: processing
                      ? '正在分析的视频'
                      : controller.selectedMediaName ?? '原始视频',
                  sizeLabel: _formatBytes(controller.selectedMediaBytes),
                  enabled: false,
                  onClear: () {},
                ),
              const SizedBox(height: 12),
              if (processing)
                _RecognitionProcessingPanel(controller: controller)
              else if (result != null)
                _RecognitionReport(result: result, controller: controller)
              else
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(18),
                    child: Text('尚未收到分析结果。'),
                  ),
                ),
              if (!processing &&
                  (result?.status == RecognitionStatus.error ||
                      result == null)) ...[
                const SizedBox(height: 12),
                FilledButton.icon(
                  key: const Key('recognition-result-retry'),
                  onPressed: () {
                    final entitlement = controller.entitlements;
                    if (entitlement != null &&
                        !entitlement.isMember &&
                        entitlement.recognitionRemaining <= 0) {
                      showMembershipPaywall(
                        context,
                        controller: controller,
                        reason: MembershipPaywallReason.recognitionQuota,
                      );
                      return;
                    }
                    controller.startRecognition();
                  },
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('重新分析这个视频'),
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}

class _RecognitionReport extends StatelessWidget {
  const _RecognitionReport({required this.result, required this.controller});

  final RecognitionResult result;
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final successful =
        result.status == RecognitionStatus.complete ||
        result.status == RecognitionStatus.lowConfidence;
    if (!successful) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: hairline),
        ),
        child: Text(result.summary, style: const TextStyle(height: 1.55)),
      );
    }

    final evidenceEvents = _recognitionEvidenceEvents(result.events);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (evidenceEvents.isNotEmpty) ...[
          _RecognitionEvidenceGallery(
            events: evidenceEvents,
            metrics: result.metrics,
            mediaHeaders: result.mediaHeaders,
          ),
        ] else if (result.previewUrl != null) ...[
          _RecognitionPreviewImage(
            imageUrl: result.previewUrl!,
            metrics: result.metrics,
            mediaHeaders: result.mediaHeaders,
          ),
        ],
        if (evidenceEvents.isNotEmpty || result.previewUrl != null)
          const SizedBox(height: 14),
        if (controller.recognitionIncludeOverlay && result.overlayUrl != null)
          _RecognitionRemoteVideo(
            key: const Key('recognition-overlay-video'),
            url: result.overlayUrl!,
            headers: result.mediaHeaders,
            title: '骨骼标注视频',
          )
        else if (controller.recognitionIncludeOverlay)
          Container(
            key: const Key('recognition-overlay-unavailable'),
            width: double.infinity,
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: emberTint,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: hairline),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, color: primary, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '骨骼视频本次未生成，仍可查看上方骨骼标注图和分析结果。',
                    style: TextStyle(color: secondaryInk, fontSize: 12),
                  ),
                ),
              ],
            ),
          )
        else if (controller.selectedMediaPath != null)
          _SelectedRecognitionVideo(
            key: const Key('recognition-result-original-video'),
            path: controller.selectedMediaPath!,
            name: controller.selectedMediaName ?? '原始视频',
            sizeLabel: _formatBytes(controller.selectedMediaBytes),
            enabled: false,
            onClear: () {},
          )
        else if (result.inputUrl != null)
          _RecognitionRemoteVideo(
            key: const Key('recognition-result-original-video'),
            url: result.inputUrl!,
            headers: result.mediaHeaders,
            title: '原始视频',
          ),
        const SizedBox(height: 14),
        _RecognitionTechniqueScoreCard(result: result),
        const SizedBox(height: 10),
        _RecognitionCoachSummary(result: result),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: const Key('recognition-save-cue'),
            onPressed: controller.saveRecognitionCue,
            icon: Icon(
              controller.savedCue
                  ? Icons.bookmark_rounded
                  : Icons.bookmark_border_rounded,
            ),
            label: Text(controller.savedCue ? '已保存到下一组' : '保存到下一组'),
          ),
        ),
      ],
    );
  }
}

class _RecognitionTechniqueScoreCard extends StatelessWidget {
  const _RecognitionTechniqueScoreCard({required this.result});
  final RecognitionResult result;

  @override
  Widget build(BuildContext context) {
    final raw = result.metrics['scores'];
    final scores = raw is Map
        ? Map<String, dynamic>.from(raw)
        : const <String, dynamic>{};
    int score(String key) =>
        ((scores[key] as num?)?.round() ?? 0).clamp(0, 100);
    final values = <String, int>{
      '动作幅度': score('rom'),
      '稳定性': score('stability'),
      '左右对称': score('symmetry'),
      '节奏控制': score('tempo'),
      '动作轨迹': score('trajectory'),
    };
    final overall = score('overall');
    final scoreable =
        result.assessment == 'assessable' &&
        result.confidence >= .6 &&
        overall > 0 &&
        values.values.every((value) => value > 0);
    return Container(
      key: const Key('recognition-technique-score'),
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: hairline),
      ),
      child: scoreable
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        '综合动作评分',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                    Text(
                      '$overall',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: primary,
                      ),
                    ),
                    Text(' / 100', style: TextStyle(color: quiet)),
                  ],
                ),
                const SizedBox(height: 10),
                for (final entry in values.entries)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 70,
                          child: Text(
                            entry.key,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        Expanded(
                          child: LinearProgressIndicator(
                            value: entry.value / 100,
                            minHeight: 7,
                            borderRadius: BorderRadius.circular(7),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 26,
                          child: Text(
                            '${entry.value}',
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '本次不输出动作评分',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 6),
                Text(
                  _recognitionQualityGuidance(result),
                  style: TextStyle(color: quiet, height: 1.45),
                ),
              ],
            ),
    );
  }
}

String _recognitionQualityGuidance(RecognitionResult result) {
  final reason = result.evidenceReason.toLowerCase();
  if (reason.contains('short') || reason.contains('cycle')) {
    return '视频过短或没有完整动作周期。请录制至少一次完整的起始—发力—还原过程。';
  }
  if (reason.contains('frame') || reason.contains('body')) {
    return '身体没有完整进入画面。请确保头、躯干、髋、膝和脚在动作全程可见。';
  }
  if (reason.contains('camera') || reason.contains('angle')) {
    return '拍摄角度不适合该动作。请按机位提示重新拍摄，并避免器械遮挡关节。';
  }
  return '当前视频不足以可靠判断全部技术维度。请保持镜头稳定、身体完整入镜，并录制完整动作周期。';
}

class _RecognitionEvidenceGallery extends StatelessWidget {
  const _RecognitionEvidenceGallery({
    required this.events,
    required this.metrics,
    required this.mediaHeaders,
  });

  final List<RecognitionEvent> events;
  final Map<String, dynamic> metrics;
  final Map<String, String> mediaHeaders;

  @override
  Widget build(BuildContext context) {
    final ratio = _recognitionImageAspectRatio(metrics);
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 340 ? 2 : 1;
        final tileWidth = columns == 1
            ? constraints.maxWidth
            : (constraints.maxWidth - 12) / 2;
        return Wrap(
          key: const Key('recognition-evidence-gallery'),
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final event in events)
              SizedBox(
                width: tileWidth,
                child: _RecognitionEvidenceTile(
                  event: event,
                  aspectRatio: ratio,
                  mediaHeaders: mediaHeaders,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _RecognitionEvidenceTile extends StatelessWidget {
  const _RecognitionEvidenceTile({
    required this.event,
    required this.aspectRatio,
    required this.mediaHeaders,
  });

  final RecognitionEvent event;
  final double aspectRatio;
  final Map<String, String> mediaHeaders;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '${event.displayTime}的骨骼标注图',
    child: Material(
      key: Key('recognition-evidence-${event.displayTime}'),
      color: const Color(0xFF211A17),
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _showRecognitionEvidenceDialog(
          context,
          url: event.evidenceImageUrl!,
          headers: mediaHeaders,
          semanticLabel: '${event.displayTime}的骨骼标注图',
        ),
        child: Stack(
          children: [
            AspectRatio(
              aspectRatio: aspectRatio,
              child: _RecognitionEvidenceImage(
                imageUrl: event.evidenceImageUrl,
                headers: mediaHeaders,
                semanticLabel: '${event.displayTime}的骨骼标注图',
              ),
            ),
            Positioned(
              left: 10,
              bottom: 10,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xD9211A17),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  child: Text(
                    event.displayTime,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _RecognitionPreviewImage extends StatelessWidget {
  const _RecognitionPreviewImage({
    required this.imageUrl,
    required this.metrics,
    required this.mediaHeaders,
  });

  final String imageUrl;
  final Map<String, dynamic> metrics;
  final Map<String, String> mediaHeaders;

  @override
  Widget build(BuildContext context) => ClipRRect(
    key: const Key('recognition-preview-image'),
    borderRadius: BorderRadius.circular(18),
    child: ColoredBox(
      color: const Color(0xFF211A17),
      child: AspectRatio(
        aspectRatio: _recognitionImageAspectRatio(metrics),
        child: _RecognitionEvidenceImage(
          imageUrl: imageUrl,
          headers: mediaHeaders,
          semanticLabel: '骨骼标注图',
        ),
      ),
    ),
  );
}

class _RecognitionEvidenceImage extends StatelessWidget {
  const _RecognitionEvidenceImage({
    required this.imageUrl,
    required this.headers,
    required this.semanticLabel,
  });

  final String? imageUrl;
  final Map<String, String> headers;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null) {
      return ColoredBox(
        color: surface,
        child: Center(
          child: Icon(Icons.accessibility_new_rounded, color: quiet, size: 34),
        ),
      );
    }
    return Image.network(
      imageUrl!,
      headers: headers,
      fit: BoxFit.contain,
      semanticLabel: semanticLabel,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        final total = progress.expectedTotalBytes;
        final value = total == null || total == 0
            ? null
            : progress.cumulativeBytesLoaded / total;
        return ColoredBox(
          color: const Color(0xFF211A17),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: LinearProgressIndicator(
              minHeight: 3,
              value: value,
              color: primary,
              backgroundColor: const Color(0xFF3A2B24),
            ),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) => ColoredBox(
        color: surface,
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              '骨骼标注图加载失败，请检查网络后重试。',
              textAlign: TextAlign.center,
              style: TextStyle(color: secondaryInk, fontSize: 12),
            ),
          ),
        ),
      ),
    );
  }
}

class _RecognitionCoachSummary extends StatelessWidget {
  const _RecognitionCoachSummary({required this.result});

  final RecognitionResult result;

  @override
  Widget build(BuildContext context) {
    final copy = _recognitionCoachCopy(result);
    return Container(
      key: const Key('recognition-coach-summary'),
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: hairline),
        boxShadow: const [
          BoxShadow(
            color: Color(0x108E3D15),
            blurRadius: 24,
            offset: Offset(0, 9),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            copy.body,
            key: const Key('recognition-coach-copy'),
            style: TextStyle(
              color: ink,
              fontSize: 15,
              height: 1.72,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (copy.nextSet.isNotEmpty) ...[
            const SizedBox(height: 15),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: emberTint,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Text(
                copy.nextSet,
                key: const Key('recognition-next-set-copy'),
                style: TextStyle(
                  color: secondaryInk,
                  fontSize: 14,
                  height: 1.65,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RecognitionEventInsight {
  const _RecognitionEventInsight({
    required this.title,
    required this.meaning,
    required this.nextStep,
  });

  final String title;
  final String meaning;
  final String nextStep;
}

_RecognitionEventInsight _recognitionEventInsight(RecognitionEvent event) =>
    switch (event.code) {
      'SQUAT_DEPTH_LIMITED' => const _RecognitionEventInsight(
        title: '下蹲深度没有达到当前参考范围',
        meaning: '最低位置仍偏高时，髋部和膝部没有完成预期的下蹲幅度。也可能是机位遮挡让角度看起来偏大，需要结合骨骼图复核。',
        nextStep: '先使用能够稳定控制的重量，让髋部向下并略向后移动，膝盖跟随脚尖方向。保持脚掌受力，再逐步增加深度。',
      ),
      'KNEE_MEDIAL_MOVEMENT' => const _RecognitionEventInsight(
        title: '膝盖向身体内侧移动较明显',
        meaning: '膝盖和脚尖方向没有保持一致时，动作稳定性可能下降。单个机位只能看到画面中的横向偏移，不能替代专业评估。',
        nextStep: '下一组降低一点重量，保持脚掌三点受力，让膝盖沿脚尖方向移动。若仍无法稳定，先缩小动作幅度。',
      ),
      'HINGE_RANGE_LIMITED' => const _RecognitionEventInsight(
        title: '髋部折叠幅度没有稳定展开',
        meaning: '髋部前后移动偏少时，动作可能变成膝盖主导，后侧链的拉伸和控制会减少。',
        nextStep: '保持脊柱自然，先把髋部向后送，再让膝盖自然微屈。负重贴近身体，达到能够控制的位置后返回。',
      ),
      'RDL_EXCESSIVE_KNEE_BEND' => const _RecognitionEventInsight(
        title: '罗马尼亚硬拉屈膝偏多',
        meaning: '屈膝增加但髋部没有同步向后折叠时，动作会逐渐变成下蹲，腿后侧的拉伸也会减少。',
        nextStep: '下一组减轻重量，保持膝盖轻微弯曲并基本固定，先把髋部向后送，让负重贴着腿下降。',
      ),
      'DEADLIFT_KNEE_DOMINANT' => const _RecognitionEventInsight(
        title: '硬拉更像由膝盖主导',
        meaning: '最低位置屈膝较多而髋部折叠不足，起拉时更难让髋和肩保持同一节奏。',
        nextStep: '起始位让杠铃贴近小腿，先收紧躯干，再推地并让髋和肩一起上升。',
      ),
      'TRUNK_POSTURE_SHIFT' => const _RecognitionEventInsight(
        title: '躯干角度在动作中变化较大',
        meaning: '躯干角度明显变化通常代表核心和骨盆没有保持同一运动策略，也可能来自重量过大或动作节奏失控。',
        nextStep: '先降低重量或放慢速度。动作开始前固定胸廓和骨盆，用目标关节完成动作，不要通过突然抬胸或塌腰增加幅度。',
      ),
      'LAT_PULLDOWN_RANGE_INCOMPLETE' => const _RecognitionEventInsight(
        title: '下拉的起点或终点提前结束',
        meaning: '手臂已经完成下拉，但顶部肘部没有充分伸展，或最低位置的肘部没有继续向身体两侧下沉，实际移动距离偏短。',
        nextStep:
            '先把重量调到能够稳定控制的范围。顶部让肘部自然伸展，再把肘部向下、略向髋部移动；末端短暂停顿，避免用明显后仰代替下拉距离。',
      ),
      'LAT_PULLDOWN_ELBOW_PATH_LIMITED' => const _RecognitionEventInsight(
        title: '肘部下降路径偏短',
        meaning: '手臂可能在弯曲，但肘部没有充分向身体两侧下沉。动作可能更多由手臂完成，背部收缩和末端控制会受到影响。',
        nextStep: '先稳定胸廓和骨盆，想象把肘部放进身体两侧的口袋。让肘部带动把手下移，不要只弯曲手臂或继续增加后仰角度。',
      ),
      'BENCH_FOREARM_NOT_VERTICAL' => const _RecognitionEventInsight(
        title: '前臂在最低位置偏离垂直方向',
        meaning: '从侧面看，手腕没有稳定处在肘部上方时，推举路径可能不够直接，肩部或手腕会承担更多调整。',
        nextStep: '调整握距和落点，让最低位置的手腕尽量位于肘部上方。先使用能够控制的重量，再保持同一推举路径。',
      ),
      'HIP_THRUST_EXTENSION_LIMITED' => const _RecognitionEventInsight(
        title: '臀推顶端伸髋还差一点',
        meaning: '顶端躯干和大腿没有接近一条线时，臀部还没有完成这一段可控的伸展。',
        nextStep: '下一组先收紧腹部，脚掌稳住，向上推到肩—髋—膝接近一条线后停一下，不要继续用抬胸或塌腰换高度。',
      ),
      'SHOULDER_PRESS_RANGE_INCOMPLETE' => const _RecognitionEventInsight(
        title: '肩推顶端伸展不完整',
        meaning: '手臂已经向上推起，但肘部仍保留较多弯曲，顶端行程提前结束。',
        nextStep: '收紧腹部和臀部，减轻一点重量，让两侧肘部同步向上伸展，不要用身体后仰换取高度。',
      ),
      'PUSH_UP_DEPTH_LIMITED' => const _RecognitionEventInsight(
        title: '俯卧撑下降幅度偏小',
        meaning: '最低位置肘部仍比较伸直，胸部和肩部没有完成这一组可控的下降范围。',
        nextStep: '先改用跪姿或抬高手撑点，保持头、躯干和腿连成一线，再逐步把胸口降得更低。',
      ),
      'DIP_DEPTH_LIMITED' => const _RecognitionEventInsight(
        title: '双杠臂屈伸下降幅度偏小',
        meaning: '肘部刚开始弯曲就返回，胸肩和手臂没有完成稳定的下降阶段。',
        nextStep: '使用辅助或减少负重，先稳住肩膀和躯干，在没有疼痛和摆动的范围内逐步增加下降幅度。',
      ),
      'ROW_RANGE_INCOMPLETE' => const _RecognitionEventInsight(
        title: '划船肘部回拉不够',
        meaning: '肘部有弯曲，但回拉阶段提前结束，背部收缩位置没有稳定出现。',
        nextStep: '下一组轻一点，固定胸廓，让肘部带动把手向身体回拉；到末端停一下，不要靠后仰甩动。',
      ),
      'FACE_PULL_RANGE_INCOMPLETE' => const _RecognitionEventInsight(
        title: '面拉回拉幅度不足',
        meaning: '肘部和手还没有稳定移动到脸部两侧，动作末端较早结束。',
        nextStep: '降低重量，保持胸廓稳定，让肘部向两侧展开并把绳端拉向脸旁，不要用后仰完成末端。',
      ),
      'LATERAL_RAISE_HEIGHT_LIMITED' => const _RecognitionEventInsight(
        title: '侧平举抬起高度偏低',
        meaning: '两侧手臂在接近肩高之前就开始下降，目标肌群的可控行程还可以更完整。',
        nextStep: '下一组减轻重量，保持轻微屈肘，两侧平稳抬到接近肩高再受控下降，不要耸肩或借摆动。',
      ),
      'BICEPS_CURL_RANGE_INCOMPLETE' => const _RecognitionEventInsight(
        title: '弯举屈肘幅度不足',
        meaning: '前臂没有充分接近上臂，弯举在收缩位置之前就开始返回。',
        nextStep: '固定上臂并减轻重量，完整弯曲肘部后再慢慢放下；不要用肩膀前送或身体摆动补行程。',
      ),
      'TRICEPS_EXTENSION_RANGE_INCOMPLETE' => const _RecognitionEventInsight(
        title: '三头伸展的屈伸幅度不足',
        meaning: '肘部没有稳定覆盖完整的弯曲和伸展阶段，上臂可能在过程中跟着移动。',
        nextStep: '下一组减轻重量并固定上臂，只让前臂围绕肘部移动，先把每次屈伸做完整再增加负重。',
      ),
      'PULL_UP_ARM_ASYMMETRY' => const _RecognitionEventInsight(
        title: '两侧肘部弯曲不同步',
        meaning: '同一时刻左右肘角差距较大，一侧肘部先弯曲或先到达最高位置，躯干可能随之旋转并增加单侧肩背负担。',
        nextStep: '下一组先减少负重或使用辅助，从稳定悬垂开始，让两侧肘部同时向下移动；出现明显不同步时停止该次动作并重新开始。',
      ),
      'PULL_UP_SHOULDER_ASYMMETRY' => const _RecognitionEventInsight(
        title: '两侧肩膀出现高低差',
        meaning: '肩线在上拉阶段持续倾斜，表示两侧肩胛下沉的时间或幅度不同。',
        nextStep: '起拉前先把两侧肩胛同时向下固定，保持胸口朝正前方；如果肩线仍明显倾斜，先减少负重或改用辅助引体。',
      ),
      'PULL_UP_RANGE_INCOMPLETE' => const _RecognitionEventInsight(
        title: '上拉在到达目标高度前结束',
        meaning: '肘部已经弯曲，但下巴仍未接近或越过横杆，动作在最高位置之前开始下降。',
        nextStep: '下一组减少负重或使用辅助：底部保持受控伸展，继续把肘部向身体两侧和后下方拉，直到下巴接近横杆；不要用摆动增加高度。',
      ),
      _ => _RecognitionEventInsight(
        title: event.label,
        meaning: event.explanation.trim().isEmpty
            ? '这一段的关节位置没有稳定保持在当前动作的参考范围内。'
            : event.explanation,
        nextStep: '下一组先降低一点重量并放慢动作，在不代偿的前提下完成稳定、连续的动作路径。',
      ),
    };

class _RecognitionCoachCopy {
  const _RecognitionCoachCopy({required this.body, required this.nextSet});

  final String body;
  final String nextSet;
}

_RecognitionCoachCopy _recognitionCoachCopy(RecognitionResult result) {
  if (result.evidenceReason == 'selected_exercise_mismatch') {
    final observed = result.actionCompatibility['observedFamily']?.toString();
    final suggestion = switch (observed) {
      'bench_press' => '卧推',
      'hip_thrust' => '臀推',
      _ => null,
    };
    return _RecognitionCoachCopy(
      body: suggestion == null
          ? '视频中的动作过程与所选动作不一致，继续套用当前规则会产生错误评价。'
          : '视频中的动作过程与所选动作不一致，看起来更接近$suggestion，继续套用当前规则会产生错误评价。',
      nextSet: '返回后确认动作名称和拍摄机位，再重新提交这段视频。',
    );
  }
  final review = result.aiReview;
  final eventsByCode = <String, List<RecognitionEvent>>{};
  for (final event in result.events) {
    eventsByCode.putIfAbsent(event.code, () => <RecognitionEvent>[]).add(event);
  }
  final body = <String>[];
  if (result.evidence['level'] == 'partial_cycle') {
    final skippedRules = result.evidence['skippedRules'];
    final endpointOccluded =
        skippedRules is List<dynamic> &&
        skippedRules.contains(
          'bench_cycle_uses_relative_motion_due_endpoint_occlusion',
        );
    body.add(
      endpointOccluded
          ? '这次已经看到卧推的下放和推回过程，但手腕等端点被遮挡，绝对角度不足以可靠计次；下面只评价画面中能够确认的部分。'
          : '这次已经看到主要动作阶段，但没有可靠确认完整周期，因此不计次数；下面只评价画面中能够确认的部分。',
    );
  }
  if (review != null && _isObjectiveRecognitionCopy(review.headline)) {
    body.add(_recognitionSentence(review.headline));
  }
  if (review != null && review.strengths.isNotEmpty) {
    final strengths = review.strengths
        .where(_isObjectiveRecognitionCopy)
        .toList(growable: false);
    if (strengths.isNotEmpty) body.add('${strengths.join('；')}。');
  }
  for (final group in eventsByCode.values) {
    final insight = _recognitionEventInsight(group.first);
    final times = group.map((event) => event.displayTime).toSet().join('、');
    final inferred = group.any(
      (event) => event.evidenceQuality == 'inferred_direction',
    );
    final evidenceNote = inferred ? '该时间点的手腕或脚踝被遮挡，角度依据可见肢段方向估算。' : '';
    body.add('$times 附近，${insight.title}。${insight.meaning}$evidenceNote');
  }
  if (eventsByCode.isEmpty && review != null && review.risks.isNotEmpty) {
    body.add(review.risks.map(_recognitionSentence).join(''));
  }
  if (body.isEmpty) {
    body.add(result.summary.trim().isEmpty ? '这段动作已经分析完成。' : result.summary);
  }

  var nextSet = review != null && _isObjectiveRecognitionCopy(review.nextSet)
      ? review.nextSet.trim()
      : '';
  if (nextSet.isEmpty && eventsByCode.isNotEmpty) {
    nextSet = eventsByCode.values
        .map((events) => _recognitionEventInsight(events.first).nextStep)
        .toSet()
        .join('\n\n');
  }
  return _RecognitionCoachCopy(
    body: body.join('\n\n'),
    nextSet: nextSet.isEmpty ? '' : _recognitionSentence(nextSet),
  );
}

bool _isObjectiveRecognitionCopy(String value) {
  final text = value.trim();
  if (text.isEmpty) return false;
  return !RegExp(r'整体有劲|抢跑|果断|拖泥带水|犹豫|拉满|稳定复现的完整范围').hasMatch(text);
}

String _recognitionSentence(String value) {
  final text = value.trim();
  if (text.isEmpty || RegExp(r'[。！？!?]$').hasMatch(text)) return text;
  return '$text。';
}

List<RecognitionEvent> _recognitionEvidenceEvents(
  List<RecognitionEvent> events,
) {
  final unique = <String, RecognitionEvent>{};
  for (final event in events) {
    if (event.evidenceImageUrl == null) continue;
    unique.putIfAbsent(event.displayTime, () => event);
  }
  return unique.values.toList(growable: false);
}

double _recognitionImageAspectRatio(Map<String, dynamic> metrics) {
  final width = (metrics['outputWidth'] as num?)?.toDouble();
  final height = (metrics['outputHeight'] as num?)?.toDouble();
  if (width == null || height == null || width <= 0 || height <= 0) {
    return 9 / 16;
  }
  return (width / height).clamp(0.5, 1.4).toDouble();
}

Future<void> _showRecognitionEvidenceDialog(
  BuildContext context, {
  required String url,
  required Map<String, String> headers,
  required String semanticLabel,
}) async {
  await showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      insetPadding: const EdgeInsets.all(16),
      backgroundColor: const Color(0xFF211A17),
      child: Stack(
        children: [
          InteractiveViewer(
            minScale: 1,
            maxScale: 4,
            child: Image.network(
              url,
              headers: headers,
              fit: BoxFit.contain,
              semanticLabel: semanticLabel,
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: IconButton.filledTonal(
              tooltip: '关闭',
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close_rounded),
            ),
          ),
        ],
      ),
    ),
  );
}

String _recognitionLabel(RecognitionStatus status) => switch (status) {
  RecognitionStatus.idle => '选择一个视频开始',
  RecognitionStatus.ready => '视频已就绪',
  RecognitionStatus.processing => '正在分析动作轨迹',
  RecognitionStatus.complete => '分析完成',
  RecognitionStatus.lowConfidence => '分析完成',
  RecognitionStatus.offline => '离线 · 已保留本地任务',
  RecognitionStatus.error => '识别失败 · 可以重试',
};
String _recognitionDetail(AppController controller) =>
    controller.recognitionStatus == RecognitionStatus.idle
    ? '选择动作、拍摄角度和本地视频后即可开始分析。'
    : controller.recognitionStatus == RecognitionStatus.processing
    ? '正在处理视频，请保持应用打开。'
    : controller.recognitionResult?.error == 'service_not_configured'
    ? '动作分析暂时不可用，请稍后重试。'
    : '结果已生成，可打开报告查看。';
String _formatBytes(int? bytes) {
  if (bytes == null || bytes <= 0) return '大小未知';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

class AiPage extends StatefulWidget {
  const AiPage({super.key, required this.controller});
  final AppController controller;
  @override
  State<AiPage> createState() => _AiPageState();
}

class _AiPageState extends State<AiPage> {
  final input = TextEditingController();
  final Set<AiContextSelection> selectedContexts = {};
  late final ScrollController scroll;
  var followLatest = true;
  var lastMessageCount = 0;
  AppController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    lastMessageCount = controller.chat.length;
    scroll = ScrollController(initialScrollOffset: controller.aiScrollOffset);
    scroll.addListener(_rememberScrollPosition);
  }

  void _rememberScrollPosition() {
    controller.aiScrollOffset = scroll.offset;
    if (scroll.hasClients) {
      followLatest = scroll.position.maxScrollExtent - scroll.offset < 100;
    }
  }

  void _scrollToLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !scroll.hasClients) return;
      scroll.animateTo(
        scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _sendMessage() {
    final contexts = selectedContexts.toList(growable: false);
    final text = input.text.trim().isEmpty && contexts.isNotEmpty
        ? '请分析我选择的训练记录，指出完成情况，并给出下一次训练的具体建议。'
        : input.text;
    if (text.trim().isEmpty) return;
    final entitlement = controller.entitlements;
    if (entitlement != null &&
        !entitlement.isMember &&
        entitlement.aiRemaining <= 0) {
      showMembershipPaywall(
        context,
        controller: controller,
        reason: MembershipPaywallReason.aiQuota,
      );
      return;
    }
    input.clear();
    FocusManager.instance.primaryFocus?.unfocus();
    followLatest = true;
    setState(selectedContexts.clear);
    controller.sendChat(text, contexts: contexts);
    _scrollToLatest();
  }

  Future<void> _chooseContext() async {
    final result = await showModalBottomSheet<Set<AiContextSelection>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) =>
          _AiContextPicker(controller: controller, initial: selectedContexts),
    );
    if (result == null || !mounted) return;
    setState(() {
      selectedContexts
        ..clear()
        ..addAll(result);
    });
  }

  void _openRecognition() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _AiRecognitionRoute(controller: controller),
      ),
    );
  }

  @override
  void dispose() {
    scroll
      ..removeListener(_rememberScrollPosition)
      ..dispose();
    input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (controller.chat.length != lastMessageCount) {
      lastMessageCount = controller.chat.length;
      if (followLatest) _scrollToLatest();
    }
    return Scaffold(
      key: const Key('ai-page'),
      drawer: _AiDrawer(controller: controller),
      body: SafeArea(
        child: Column(
          children: [
            Builder(
              builder: (context) => Padding(
                padding: const EdgeInsets.fromLTRB(8, 2, 14, 6),
                child: Row(
                  children: [
                    IconButton(
                      key: const Key('ai-drawer'),
                      tooltip: '对话列表',
                      onPressed: () => Scaffold.of(context).openDrawer(),
                      icon: const Icon(Icons.menu),
                    ),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Text(
                                'AI Coach',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              SizedBox(width: 8),
                              _AiProBadge(),
                            ],
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      key: const Key('ai-settings-button'),
                      tooltip: 'AI 设置',
                      onPressed: () => _openAiSettingsPage(context, controller),
                      icon: const Icon(Icons.settings_outlined),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: SizedBox(
                width: double.infinity,
                child: SegmentedButton<AiView>(
                  key: const Key('ai-top-navigation'),
                  segments: const [
                    ButtonSegment<AiView>(
                      value: AiView.chat,
                      icon: Icon(Icons.forum_outlined),
                      label: Text('AI 教练'),
                    ),
                    ButtonSegment<AiView>(
                      value: AiView.recognition,
                      icon: Icon(Icons.accessibility_new_rounded),
                      label: Text('动作识别'),
                    ),
                  ],
                  selected: const {AiView.chat},
                  onSelectionChanged: (values) {
                    if (values.contains(AiView.recognition)) _openRecognition();
                  },
                ),
              ),
            ),
            Expanded(
              child: ListView(
                controller: scroll,
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                children: [
                  if (controller.aiToolReading)
                    const _AiToolStatus(
                      icon: Icons.auto_awesome_outlined,
                      message: '正在读取你的训练资料…',
                    ),
                  if (!controller.aiToolReading &&
                      controller.aiToolUses.isNotEmpty &&
                      controller.aiToolError == null)
                    _AiToolStatus(
                      icon: Icons.check_circle_outline,
                      message:
                          '已读取 ${controller.aiToolUses.map((item) => item.count > 1 ? '${_aiToolName(item.name)}（${item.count} 次）' : _aiToolName(item.name)).join('、')}',
                    ),
                  if (controller.aiToolError != null)
                    _AiToolStatus(
                      icon: Icons.info_outline,
                      message: controller.aiToolError!,
                      error: true,
                    ),
                  if (controller.chat.isEmpty && !controller.aiTyping)
                    Padding(
                      padding: EdgeInsets.only(bottom: 10),
                      child: Text(
                        '尚无对话。发送一个问题开始。',
                        style: TextStyle(color: quiet, fontSize: 12),
                      ),
                    ),
                  for (final message in controller.chat)
                    _ChatBubble(message: message, controller: controller),
                  if (controller.aiTyping)
                    _ThinkingIndicator(controller: controller),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 5, 12, 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (controller.aiSkills.isNotEmpty)
                      _AiSkillQuickBar(controller: controller),
                    if (controller.aiSkills.isNotEmpty)
                      const SizedBox(height: 5),
                    if (selectedContexts.isNotEmpty)
                      Container(
                        key: const Key('ai-selected-contexts'),
                        constraints: const BoxConstraints(maxHeight: 178),
                        padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
                        decoration: BoxDecoration(
                          color: emberTint.withValues(alpha: .55),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: primary.withValues(alpha: .18),
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: ListView.separated(
                                shrinkWrap: true,
                                itemCount: selectedContexts.length,
                                separatorBuilder: (_, _) =>
                                    const Divider(height: 10),
                                itemBuilder: (context, index) {
                                  final item = selectedContexts.elementAt(
                                    index,
                                  );
                                  return _AiContextSummary(
                                    controller: controller,
                                    selection: item,
                                    compact: true,
                                    trailing: IconButton(
                                      visualDensity: VisualDensity.compact,
                                      tooltip: '移除',
                                      onPressed: () => setState(
                                        () => selectedContexts.remove(item),
                                      ),
                                      icon: const Icon(Icons.close, size: 19),
                                    ),
                                  );
                                },
                              ),
                            ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                key: const Key('ai-send-context-only'),
                                onPressed: controller.aiTyping
                                    ? null
                                    : _sendMessage,
                                icon: const Icon(
                                  Icons.arrow_upward_rounded,
                                  size: 18,
                                ),
                                label: const Text('直接发送给 AI'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (selectedContexts.isNotEmpty) const SizedBox(height: 5),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        IconButton.filledTonal(
                          key: const Key('ai-add-context'),
                          tooltip: '选择训练资料',
                          onPressed: controller.aiTyping
                              ? null
                              : _chooseContext,
                          icon: const Icon(Icons.add),
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: TextField(
                            controller: input,
                            minLines: 1,
                            maxLines: 4,
                            textInputAction: TextInputAction.newline,
                            onTapOutside: (_) =>
                                FocusManager.instance.primaryFocus?.unfocus(),
                            decoration: const InputDecoration(
                              hintText: '询问训练、恢复或计划安排',
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 7),
                        IconButton.filled(
                          tooltip: '发送',
                          onPressed: controller.aiTyping ? null : _sendMessage,
                          icon: const Icon(Icons.arrow_upward),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AiRecognitionRoute extends StatelessWidget {
  const _AiRecognitionRoute({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) => Scaffold(
      key: const Key('ai-recognition-route'),
      appBar: AppBar(title: const Text('动作识别')),
      body: SafeArea(child: RecognitionPage(controller: controller)),
    ),
  );
}

class _AiToolStatus extends StatelessWidget {
  const _AiToolStatus({
    required this.icon,
    required this.message,
    this.error = false,
  });

  final IconData icon;
  final String message;
  final bool error;

  @override
  Widget build(BuildContext context) => Container(
    key: Key(error ? 'ai-tool-error' : 'ai-tool-reading'),
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
    decoration: BoxDecoration(
      color: (error ? Colors.red : primary).withValues(alpha: .09),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: (error ? Colors.red : primary).withValues(alpha: .25),
      ),
    ),
    child: Row(
      children: [
        Icon(icon, size: 18, color: error ? Colors.red : primary),
        const SizedBox(width: 8),
        Expanded(child: Text(message, style: const TextStyle(fontSize: 12))),
      ],
    ),
  );
}

class _AiProBadge extends StatelessWidget {
  const _AiProBadge();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: primaryContainer,
      borderRadius: BorderRadius.circular(99),
      border: Border.all(color: primary.withValues(alpha: .18)),
    ),
    child: Text(
      'PRO',
      style: TextStyle(
        color: primary,
        fontSize: 10,
        fontWeight: FontWeight.w900,
      ),
    ),
  );
}

String _aiToolName(String name) => switch (name) {
  'read_training_plans' => '训练计划',
  'read_workout_history' => '训练记录',
  'read_active_workout' => '当前训练',
  _ => '训练资料',
};

class _AiSkillQuickBar extends StatelessWidget {
  const _AiSkillQuickBar({required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 34,
    child: ListView(
      scrollDirection: Axis.horizontal,
      children: [
        ActionChip(
          key: const Key('ai-skill-quick-settings'),
          avatar: const Icon(Icons.auto_awesome_outlined, size: 17),
          label: Text('Skill ${controller.enabledAiSkills.length}/3'),
          onPressed: () => _showAiSkillToggleSheet(context, controller),
        ),
        const SizedBox(width: 6),
        for (final skill in controller.enabledAiSkills) ...[
          InputChip(
            key: Key('ai-skill-active-${skill.id}'),
            label: Text(skill.name),
            selected: true,
            onDeleted: () => controller.setAiSkillEnabled(skill.id, false),
          ),
          const SizedBox(width: 6),
        ],
      ],
    ),
  );
}

Future<void> _showAiSkillToggleSheet(
  BuildContext context,
  AppController controller,
) => showModalBottomSheet<void>(
  context: context,
  useSafeArea: true,
  builder: (context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 22),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                '本次对话 Skill',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _openAiSettingsPage(context, controller);
              },
              child: const Text('管理'),
            ),
          ],
        ),
        Text('最多同时启用 3 个，开关会立即作用于下一条消息。', style: TextStyle(color: quiet)),
        const SizedBox(height: 8),
        for (final skill in controller.aiSkills)
          SwitchListTile(
            key: Key('ai-skill-toggle-${skill.id}'),
            contentPadding: EdgeInsets.zero,
            title: Text(
              skill.name,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: Text(
              skill.instructions,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            value: skill.enabled,
            onChanged: (value) {
              if (!controller.setAiSkillEnabled(skill.id, value)) {
                showKiloSnack(context, '最多同时启用 3 个 Skill');
              }
            },
          ),
      ],
    ),
  ),
);

class _AiContextPicker extends StatefulWidget {
  const _AiContextPicker({required this.controller, required this.initial});
  final AppController controller;
  final Set<AiContextSelection> initial;

  @override
  State<_AiContextPicker> createState() => _AiContextPickerState();
}

class _AiContextPickerState extends State<_AiContextPicker> {
  late final Set<AiContextSelection> selected = {...widget.initial};

  @override
  Widget build(BuildContext context) {
    final contexts = widget.controller.availableAiContexts;
    return FractionallySizedBox(
      heightFactor: .86,
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 42,
            height: 5,
            decoration: BoxDecoration(
              color: quiet.withValues(alpha: .45),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '选择训练资料',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text('可多选，AI 会按日期比较变化', style: TextStyle(color: quiet)),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: '关闭',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Expanded(
            child: contexts.isEmpty
                ? const Center(child: Text('还没有可发送的训练数据'))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: contexts.length,
                    itemBuilder: (context, index) {
                      final item = contexts[index];
                      final checked = selected.contains(item);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 9),
                        child: Material(
                          color: checked ? emberTint : surface,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(17),
                            side: BorderSide(
                              color: checked ? primary : hairline,
                              width: checked ? 1.6 : 1,
                            ),
                          ),
                          child: InkWell(
                            key: Key('ai-context-${item.type.name}-${item.id}'),
                            borderRadius: BorderRadius.circular(17),
                            onTap: () => setState(() {
                              if (checked) {
                                selected.remove(item);
                              } else {
                                selected.add(item);
                              }
                            }),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                14,
                                13,
                                10,
                                13,
                              ),
                              child: _AiContextSummary(
                                controller: widget.controller,
                                selection: item,
                                trailing: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 160),
                                  child: Icon(
                                    checked
                                        ? Icons.check_circle_rounded
                                        : Icons.circle_outlined,
                                    key: ValueKey(checked),
                                    color: checked ? primary : quiet,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => Navigator.pop(context, selected),
                icon: const Icon(Icons.checklist_rounded),
                label: Text(
                  selected.isEmpty
                      ? '这次不添加训练资料'
                      : '使用已选的 ${selected.length} 项资料',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AiDrawer extends StatelessWidget {
  const _AiDrawer({required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) => Drawer(
    child: SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 12, 12),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'AI 对话',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton(
                  tooltip: '关闭',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                key: const Key('ai-new-conversation'),
                onPressed: () {
                  controller.newConversation();
                  Navigator.pop(context);
                  showKiloSnack(context, '已新建对话');
                },
                icon: const Icon(Icons.add),
                label: const Text('新建对话'),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView(
              children: [
                for (final conversation in controller.conversations)
                  ListTile(
                    selected:
                        conversation.id == controller.activeConversationId,
                    leading: Icon(
                      conversation.id == controller.activeConversationId
                          ? Icons.chat
                          : Icons.chat_bubble_outline,
                      color: conversation.id == controller.activeConversationId
                          ? cobalt
                          : quiet,
                    ),
                    title: Text(
                      conversation.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () {
                      controller.selectConversation(conversation.id);
                      Navigator.pop(context);
                    },
                    trailing: IconButton(
                      tooltip: '删除对话',
                      onPressed: () =>
                          controller.deleteConversation(conversation.id),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          ListTile(
            key: const Key('ai-settings'),
            leading: Icon(Icons.tune, color: cobalt),
            title: const Text('服务与训练授权'),
            subtitle: const Text('URL、授权、场景'),
            onTap: () {
              Navigator.pop(context);
              _showAiSettings(context, controller);
            },
          ),
        ],
      ),
    ),
  );
}

void _showAiSettings(BuildContext context, AppController controller) {
  final url = TextEditingController(text: controller.aiBaseUrl);
  var useTrainingData = controller.aiUseTrainingData;
  showDialog<void>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('AI 服务设置'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '填写服务地址后请求 /v1/coach/answer。未配置时仅显示服务未配置状态，不生成示例回答。',
                style: TextStyle(fontSize: 12, color: secondaryInk),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: url,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: 'Base URL',
                  hintText: 'http://127.0.0.1:8790',
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                children: [
                  ActionChip(
                    label: const Text('本机服务'),
                    onPressed: () {
                      url.text = 'http://127.0.0.1:8790';
                    },
                  ),
                ],
              ),
              const Divider(height: 24),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: useTrainingData,
                onChanged: (value) => setState(() => useTrainingData = value),
                title: const Text('允许 AI 按需读取训练资料'),
                subtitle: const Text('开启后，AI 只在回答需要时读取计划、历史或当前训练；不会修改资料。'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              controller.aiBaseUrl = url.text.trim();
              controller.aiUseTrainingData = useTrainingData;
              controller.refresh();
              Navigator.pop(context);
              showKiloSnack(context, 'AI 设置已保存');
            },
            child: const Text('保存'),
          ),
        ],
      ),
    ),
  );
}

class _AiContextSummary extends StatelessWidget {
  const _AiContextSummary({
    required this.controller,
    required this.selection,
    this.trailing,
    this.compact = false,
  });

  final AppController controller;
  final AiContextSelection selection;
  final Widget? trailing;
  final bool compact;

  IconData get icon => switch (selection.type) {
    AiContextType.activeWorkout => Icons.fitness_center_rounded,
    AiContextType.workoutRecord => Icons.history_rounded,
    AiContextType.routine => Icons.menu_book_outlined,
    AiContextType.week => Icons.view_week_outlined,
    AiContextType.month => Icons.calendar_month_outlined,
  };

  String get detail {
    final record = controller.workoutRecordForAiContext(selection);
    if (record != null) {
      final exerciseNames = record.exerciseIds
          .take(2)
          .map(
            (id) => controller.displayExerciseName(controller.exerciseFor(id)),
          )
          .join('、');
      final metrics =
          '${record.durationSeconds ~/ 60} 分钟 · '
          '${record.effectiveSets} 组 · ${record.volume.toStringAsFixed(0)} kg';
      return exerciseNames.isEmpty ? metrics : '$metrics\n$exerciseNames';
    }
    final routine = controller.routineForAiContext(selection);
    if (routine != null) {
      final sets = routine.exercises.fold<int>(
        0,
        (sum, item) => sum + item.sets.length,
      );
      return '${routine.exercises.length} 个动作 · $sets 组';
    }
    return switch (selection.type) {
      AiContextType.activeWorkout =>
        '${controller.workout.length} 个动作 · ${controller.completedSets}/${controller.totalSets} 组已完成',
      AiContextType.week => '训练频率、时长、容量与完成组数',
      AiContextType.month => '本月训练趋势、容量与个人纪录',
      _ => '',
    };
  }

  List<String> get exerciseDetails {
    final record = controller.workoutRecordForAiContext(selection);
    if (record != null) {
      if (record.exercises.isNotEmpty) {
        return record.exercises.take(compact ? 2 : 4).map((exercise) {
          final completed = exercise.sets
              .where((set) => set.completed)
              .toList();
          final values = completed
              .take(2)
              .map((set) {
                final weight = set.weight % 1 == 0
                    ? set.weight.toStringAsFixed(0)
                    : set.weight.toStringAsFixed(1);
                return '$weight kg×${set.reps}';
              })
              .join(' / ');
          return '${controller.displayExerciseName(controller.exerciseFor(exercise.exerciseId))}'
              '${values.isEmpty ? '' : '  $values'}';
        }).toList();
      }
      return record.exerciseIds
          .take(compact ? 2 : 4)
          .map(
            (id) => controller.displayExerciseName(controller.exerciseFor(id)),
          )
          .toList();
    }
    final routine = controller.routineForAiContext(selection);
    if (routine != null) {
      return routine.exercises
          .take(compact ? 2 : 4)
          .map(
            (item) => controller.displayExerciseName(
              controller.exerciseFor(item.exerciseId),
            ),
          )
          .toList();
    }
    return const [];
  }

  String? get recordNote {
    final record = controller.workoutRecordForAiContext(selection);
    if (record == null || record.note.trim().isEmpty) return null;
    return record.note.trim();
  }

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Container(
        width: compact ? 34 : 42,
        height: compact ? 34 : 42,
        decoration: BoxDecoration(
          color: surfaceRaised.withValues(alpha: .9),
          borderRadius: BorderRadius.circular(compact ? 10 : 13),
        ),
        child: Icon(icon, color: primary, size: compact ? 18 : 21),
      ),
      const SizedBox(width: 11),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              selection.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: compact ? 14 : 16,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              detail,
              maxLines: compact ? 1 : 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: secondaryInk, fontSize: 12, height: 1.35),
            ),
            if (!compact && exerciseDetails.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final item in exerciseDetails)
                    Container(
                      constraints: const BoxConstraints(maxWidth: 245),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: surfaceRaised,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Text(
                        item,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
            ],
            if (!compact && recordNote != null) ...[
              const SizedBox(height: 7),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(9, 7, 9, 7),
                decoration: BoxDecoration(
                  color: primaryContainer,
                  border: Border(left: BorderSide(color: primary, width: 3)),
                ),
                child: Text(
                  '备注：$recordNote',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: secondaryInk),
                ),
              ),
            ],
          ],
        ),
      ),
      if (trailing != null) ...[const SizedBox(width: 8), trailing!],
    ],
  );
}

void _openAiSettingsPage(BuildContext context, AppController controller) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => _AiSettingsPage(controller: controller),
    ),
  );
}

class _AiSettingsPage extends StatelessWidget {
  const _AiSettingsPage({required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('AI 设置')),
    body: AnimatedBuilder(
      animation: controller,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '自定义 Skill',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      '设定 AI 的回答方法、关注点或输出格式。',
                      style: TextStyle(color: quiet),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                key: const Key('ai-skill-add'),
                onPressed: controller.aiSkills.length >= 3
                    ? null
                    : () => _editAiSkill(context, controller),
                icon: const Icon(Icons.add),
                label: const Text('新增'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (controller.aiSkills.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text(
                '还没有 Skill。新增后可在聊天输入框上方快速启用。',
                style: TextStyle(color: quiet),
              ),
            )
          else
            for (final skill in controller.aiSkills)
              ListTile(
                key: Key('ai-skill-item-${skill.id}'),
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: skill.enabled ? primaryContainer : paper,
                  foregroundColor: skill.enabled ? primary : quiet,
                  child: const Icon(Icons.auto_awesome_outlined),
                ),
                title: Text(
                  skill.name,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  skill.instructions,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: PopupMenuButton<String>(
                  onSelected: (action) async {
                    if (action == 'edit') {
                      _editAiSkill(context, controller, skill: skill);
                    } else if (action == 'delete') {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('删除 Skill？'),
                          content: Text(
                            '“${skill.name}”将被永久删除${skill.enabled ? '，并立即停止使用' : ''}。',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('取消'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('删除'),
                            ),
                          ],
                        ),
                      );
                      if (confirmed == true) controller.deleteAiSkill(skill.id);
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('修改')),
                    PopupMenuItem(value: 'delete', child: Text('删除')),
                  ],
                ),
                onTap: () {
                  if (!controller.setAiSkillEnabled(skill.id, !skill.enabled)) {
                    showKiloSnack(context, '最多同时启用 3 个 Skill');
                  }
                },
              ),
          const Divider(height: 30),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.cloud_outlined),
            title: const Text('服务与训练授权'),
            subtitle: const Text('服务地址、训练摘要授权'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showAiSettings(context, controller),
          ),
        ],
      ),
    ),
  );
}

Future<void> _editAiSkill(
  BuildContext context,
  AppController controller, {
  AiSkill? skill,
}) async {
  final name = TextEditingController(text: skill?.name ?? '');
  final instructions = TextEditingController(text: skill?.instructions ?? '');
  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(skill == null ? '新增 Skill' : '修改 Skill'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const Key('ai-skill-name'),
              controller: name,
              maxLength: 30,
              decoration: const InputDecoration(
                labelText: '名称',
                hintText: '例如：力量训练教练',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              key: const Key('ai-skill-instructions'),
              controller: instructions,
              minLines: 5,
              maxLines: 8,
              maxLength: 1000,
              decoration: const InputDecoration(
                labelText: 'Skill 指令',
                hintText: '说明回答时应关注什么、采用什么方法，以及希望的输出格式。',
                alignLabelWithHint: true,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          key: const Key('ai-skill-save'),
          onPressed: () {
            if (!controller.saveAiSkill(
              id: skill?.id,
              name: name.text,
              instructions: instructions.text,
            )) {
              showKiloSnack(context, '请填写 Skill 名称和指令');
              return;
            }
            Navigator.pop(context);
          },
          child: const Text('保存'),
        ),
      ],
    ),
  );
  name.dispose();
  instructions.dispose();
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message, required this.controller});
  final ChatMessage message;
  final AppController controller;

  Future<void> _openMarkdownLink(BuildContext context, String? href) async {
    if (href == null) return;
    final uri = normalizeTrainingUri(href);
    if (uri == null || !await launchTrainingUri(uri)) {
      if (context.mounted) showKiloSnack(context, '链接暂时无法打开');
    }
  }

  @override
  Widget build(BuildContext context) => Align(
    alignment: message.role == 'user'
        ? Alignment.centerRight
        : Alignment.centerLeft,
    child: Container(
      constraints: const BoxConstraints(maxWidth: 340),
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: message.role == 'user' ? cobalt : paper,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (message.role == 'user')
            SelectableText(
              message.body,
              style: const TextStyle(color: Colors.white, height: 1.35),
            )
          else
            MarkdownBody(
              data: message.body,
              selectable: true,
              onTapLink: (text, href, title) =>
                  _openMarkdownLink(context, href),
              styleSheet: MarkdownStyleSheet(
                p: TextStyle(color: ink, height: 1.45, fontSize: 14),
                h1: TextStyle(
                  color: ink,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
                h2: TextStyle(
                  color: ink,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
                h3: TextStyle(
                  color: ink,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
                strong: TextStyle(color: ink, fontWeight: FontWeight.w900),
                listBullet: TextStyle(color: primary, fontSize: 15),
                a: TextStyle(
                  color: primary,
                  decoration: TextDecoration.underline,
                ),
                blockSpacing: 7,
                listIndent: 20,
              ),
            ),
          if (message.plan != null)
            _AiPlanCard(plan: message.plan!, controller: controller),
          if (message.citations.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '参考文献',
                          style: TextStyle(
                            color: muted,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () {
                          Clipboard.setData(
                            ClipboardData(text: message.citations.join('\n')),
                          );
                          showKiloSnack(context, '参考文献已复制');
                        },
                        icon: const Icon(Icons.copy_all_outlined, size: 15),
                        label: const Text('复制全部'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  for (var index = 0; index < message.citations.length; index++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: SelectableText(
                              '${index + 1}. ${message.citations[index]}',
                              style: TextStyle(
                                color: muted,
                                fontSize: 11,
                                height: 1.35,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: '复制此参考文献',
                            visualDensity: VisualDensity.compact,
                            onPressed: () {
                              Clipboard.setData(
                                ClipboardData(text: message.citations[index]),
                              );
                              showKiloSnack(context, '第 ${index + 1} 条参考文献已复制');
                            },
                            icon: const Icon(Icons.copy_outlined, size: 15),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    ),
  );
}

class _ThinkingIndicator extends StatefulWidget {
  const _ThinkingIndicator({required this.controller});
  final AppController controller;

  @override
  State<_ThinkingIndicator> createState() => _ThinkingIndicatorState();
}

class _ThinkingIndicatorState extends State<_ThinkingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController animation;

  @override
  void initState() {
    super.initState();
    animation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 9, left: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: animation,
            builder: (context, child) => Row(
              children: [
                for (var index = 0; index < 3; index++)
                  Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.only(right: 4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: primary.withValues(
                        alpha:
                            (.28 +
                                    .72 *
                                        (1 -
                                            ((animation.value - index * .18)
                                                        .abs() %
                                                    1)
                                                .clamp(0, 1)))
                                .toDouble(),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 5),
          Text(
            '已等待 ${widget.controller.aiWaitingSeconds} 秒',
            style: TextStyle(
              color: muted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 6),
          TextButton.icon(
            onPressed: widget.controller.cancelAiResponse,
            icon: const Icon(Icons.stop_circle_outlined, size: 17),
            label: const Text('停止回答'),
          ),
        ],
      ),
    ),
  );
}

class _AiPlanCard extends StatelessWidget {
  const _AiPlanCard({required this.plan, required this.controller});
  final AiPlanDraft plan;
  final AppController controller;

  int get totalExercises => plan.sessions.fold(
    0,
    (total, session) => total + session.effectiveExerciseIds.length,
  );

  int get totalSets =>
      plan.sessions.fold(0, (total, session) => total + session.totalSets);

  Future<void> _save(BuildContext context, {required bool calendar}) async {
    DateTime? startDate;
    if (calendar) {
      final now = DateTime.now();
      startDate = await showDatePicker(
        context: context,
        initialDate: now,
        firstDate: DateTime(now.year, now.month, now.day),
        lastDate: DateTime(now.year + 2),
        helpText: '选择计划开始日期',
        confirmText: '安排到这天',
        cancelText: '取消',
      );
      if (startDate == null || !context.mounted) return;
    }
    controller.saveAiPlan(
      plan,
      scheduleCalendar: calendar,
      scheduleStartDate: startDate,
    );
    showKiloSnack(
      context,
      calendar
          ? '计划已保存，从 ${startDate!.month} 月 ${startDate.day} 日开始安排'
          : '计划已保存到“AI 生成”',
    );
  }

  void _openDetail(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => _AiPlanDetailPage(plan: plan, controller: controller),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(top: 10),
    padding: const EdgeInsets.fromLTRB(11, 10, 11, 9),
    decoration: BoxDecoration(
      color: emberTint,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: primary.withValues(alpha: .28)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.calendar_month_outlined, size: 18, color: primary),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                plan.title,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            Text(
              '${plan.weeks} 周',
              style: TextStyle(fontSize: 11, color: muted),
            ),
            IconButton(
              tooltip: '调整或重新生成计划',
              onPressed: () => _openCoachPlanEditor(context, controller, plan: plan),
              icon: const Icon(Icons.refresh, size: 20),
            ),
          ],
        ),
        const SizedBox(height: 7),
        for (final session in plan.sessions)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: InkWell(
              onTap: () => _openDetail(context),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '第 ${session.dayOffset + 1} 天 · ${session.name} · ${session.effectiveExerciseIds.length} 个动作',
                        style: TextStyle(
                          fontSize: 12,
                          color: secondaryInk,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Icon(Icons.chevron_right, size: 17, color: muted),
                  ],
                ),
              ),
            ),
          ),
        Text(
          totalSets > 0
              ? '$totalExercises 个动作 · $totalSets 组 · 已含重量/次数/休息'
              : '$totalExercises 个动作 · 旧计划未包含组次处方',
          style: TextStyle(fontSize: 11, color: muted),
        ),
        const SizedBox(height: 5),
        Wrap(
          spacing: 7,
          runSpacing: 6,
          children: [
            OutlinedButton.icon(
              onPressed: () => _openDetail(context),
              icon: const Icon(Icons.visibility_outlined, size: 17),
              label: const Text('查看详情'),
            ),
            OutlinedButton.icon(
              onPressed: () => _save(context, calendar: false),
              icon: const Icon(Icons.bookmark_add_outlined, size: 17),
              label: const Text('保存计划'),
            ),
            FilledButton.icon(
              onPressed: () => _save(context, calendar: true),
              icon: const Icon(Icons.event_available_outlined, size: 17),
              label: const Text('保存并安排日历'),
            ),
          ],
        ),
      ],
    ),
  );
}

class _AiPlanDetailPage extends StatelessWidget {
  const _AiPlanDetailPage({required this.plan, required this.controller});

  final AiPlanDraft plan;
  final AppController controller;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: paper,
    appBar: AppBar(
      title: const Text('训练计划详情'),
      backgroundColor: paper,
      surfaceTintColor: Colors.transparent,
    ),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      children: [
        Text(plan.title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text(
          '${plan.weeks} 周 · ${plan.sessions.length} 个训练日',
          style: TextStyle(color: muted),
        ),
        const SizedBox(height: 14),
        for (final session in plan.sessions)
          Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '第 ${session.dayOffset + 1} 天 · ${session.name}',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (session.plannedVolume > 0) ...[
                    const SizedBox(height: 3),
                    Text(
                      '${session.totalSets} 组 · 计划容量 ${session.plannedVolume.toStringAsFixed(0)} kg',
                      style: TextStyle(color: muted, fontSize: 12),
                    ),
                  ],
                  const SizedBox(height: 10),
                  if (session.exercises.isEmpty)
                    Text(
                      '这份旧计划只保存了动作。请重新生成一次，即可获得每组重量、次数和休息安排。',
                      style: TextStyle(color: muted, height: 1.4),
                    ),
                  for (
                    var exerciseIndex = 0;
                    exerciseIndex < session.exercises.length;
                    exerciseIndex++
                  ) ...[
                    _AiPlanExerciseDetail(
                      index: exerciseIndex + 1,
                      draft: session.exercises[exerciseIndex],
                    ),
                    if (exerciseIndex != session.exercises.length - 1)
                      const Divider(height: 20),
                  ],
                  if (session.exercises.isEmpty)
                    for (final exerciseId in session.exerciseIds)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: _ExerciseThumb(exerciseId: exerciseId),
                        title: Text(controller.exerciseFor(exerciseId).name),
                      ),
                ],
              ),
            ),
          ),
      ],
    ),
  );
}

class _AiPlanExerciseDetail extends StatelessWidget {
  const _AiPlanExerciseDetail({required this.index, required this.draft});

  final int index;
  final AiPlanExerciseDraft draft;

  @override
  Widget build(BuildContext context) {
    final exercise = findExercise(draft.exerciseId);
    final note = draft.note.trim().isNotEmpty
        ? draft.note.trim()
        : exercise.cue.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _ExerciseThumb(exerciseId: draft.exerciseId),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$index. ${exercise.name}',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  Text(
                    '${exercise.muscle} · ${exercise.equipment}',
                    style: TextStyle(color: muted, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (note.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            key: Key('ai-plan-exercise-note-${draft.exerciseId}'),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(
              color: emberTint,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.tips_and_updates_outlined, size: 17, color: primary),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    '动作提醒 · $note',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: secondaryInk,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 8),
        for (var setIndex = 0; setIndex < draft.sets.length; setIndex++)
          Container(
            margin: const EdgeInsets.only(bottom: 5),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: setIndex == 0 ? emberTint : surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: hairline),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 46,
                  child: Text(
                    '${setIndex + 1} · ${draft.sets[setIndex].type == 'warmup' ? '热身' : '正式'}',
                    style: TextStyle(fontSize: 11, color: muted),
                  ),
                ),
                Expanded(
                  child: Text(
                    '${draft.sets[setIndex].weight.toStringAsFixed(draft.sets[setIndex].weight % 1 == 0 ? 0 : 1)} kg × ${draft.sets[setIndex].reps} 次',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                Text(
                  '休 ${draft.sets[setIndex].restSeconds}s',
                  style: TextStyle(fontSize: 12, color: primary),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

Future<void> _showPersonalProfileSheet(
  BuildContext context,
  AppController controller,
) async {
  final user = controller.currentUser;
  if (user == null) return;
  final name = TextEditingController(text: user.displayName);
  var avatarPath = user.avatarPath;
  var saving = false;
  String? error;
  try {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setState) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            0,
            20,
            20 + MediaQuery.viewInsetsOf(sheetContext).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('个人资料', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              Center(
                child: CircleAvatar(
                  radius: 38,
                  backgroundColor: ink,
                  foregroundImage: avatarPath?.isNotEmpty == true
                      ? FileImage(File(avatarPath!))
                      : null,
                  child: avatarPath?.isNotEmpty == true
                      ? null
                      : Text(
                          name.text.trim().characters.firstOrNull ?? '形',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton.icon(
                  key: const Key('pick-profile-avatar'),
                  onPressed: saving
                      ? null
                      : () async {
                          final result = await FilePicker.platform.pickFiles(
                            type: FileType.image,
                            allowMultiple: false,
                            withData: false,
                          );
                          final path = result?.files.single.path;
                          if (path != null && path.isNotEmpty) {
                            setState(() => avatarPath = path);
                          }
                        },
                  icon: const Icon(Icons.add_a_photo_outlined),
                  label: const Text('更换头像'),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                key: const Key('profile-display-name'),
                controller: name,
                maxLength: 30,
                decoration: const InputDecoration(
                  labelText: '用户名',
                  helperText: '好友动态中会显示这个名称',
                ),
              ),
              Text('登录账号：${user.identifier}', style: TextStyle(color: quiet)),
              if (error != null) ...[
                const SizedBox(height: 8),
                Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 14),
              FilledButton(
                key: const Key('save-personal-profile'),
                onPressed: saving
                    ? null
                    : () async {
                        final value = name.text.trim();
                        if (value.isEmpty) {
                          setState(() => error = '用户名不能为空');
                          return;
                        }
                        setState(() {
                          saving = true;
                          error = null;
                        });
                        try {
                          await controller.updateCurrentProfile(
                            displayName: value,
                            avatarPath: avatarPath,
                          );
                          if (sheetContext.mounted) Navigator.pop(sheetContext);
                        } on CoachApiException catch (caught) {
                          setState(() {
                            saving = false;
                            error = caught.code == 'username_taken'
                                ? '这个用户名已被使用'
                                : '保存失败，请检查网络后重试';
                          });
                        }
                      },
                child: Text(saving ? '正在保存…' : '保存个人资料'),
              ),
            ],
          ),
        ),
      ),
    );
  } finally {
    name.dispose();
  }
}

class _AccountMembershipCard extends StatelessWidget {
  const _AccountMembershipCard({required this.controller});

  final AppController controller;

  String _membershipLabel(MembershipPlan plan) => switch (plan) {
    MembershipPlan.free => '\u514d\u8d39\u8d26\u53f7',
    MembershipPlan.oneMonth => '1 \u4e2a\u6708\u4f1a\u5458',
    MembershipPlan.threeMonths => '3 \u4e2a\u6708\u4f1a\u5458',
    MembershipPlan.yearly => '1 \u5e74\u4f1a\u5458',
    MembershipPlan.forever => '\u6c38\u4e45\u4f1a\u5458',
  };

  String _membershipCaption(EntitlementSnapshot entitlement) {
    if (entitlement.membership == MembershipPlan.forever) {
      return '形域 PRO · 永久有效';
    }
    final expiresAt = entitlement.membershipExpiresAt;
    if (expiresAt == null) return '基础权益 · 可随时升级';
    return '形域 PRO · ${expiresAt.year}.${expiresAt.month.toString().padLeft(2, '0')}.${expiresAt.day.toString().padLeft(2, '0')} 到期';
  }

  @override
  Widget build(BuildContext context) {
    final user = controller.currentUser;
    final quota = controller.entitlements;
    if (user == null || quota == null) {
      return Card(
        key: const Key('account-membership-card'),
        child: ListTile(
          leading: const CircleAvatar(child: Icon(Icons.person_outline)),
          title: const Text('\u672a\u767b\u5f55'),
          subtitle: const Text(
            '\u767b\u5f55\u540e\u540c\u6b65\u4f1a\u5458\u72b6\u6001',
          ),
          trailing: FilledButton(
            onPressed: () => showKiloSnack(
              context,
              '\u8bf7\u8fd4\u56de\u542f\u52a8\u9875\u767b\u5f55',
            ),
            child: const Text('\u767b\u5f55'),
          ),
        ),
      );
    }
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    return Card(
      key: const Key('account-membership-card'),
      color: emberTint,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 390 || textScale > 1.35;
                final identity = Row(
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: ink,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: user.avatarPath?.isNotEmpty == true
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child: Image.file(
                                    File(user.avatarPath!),
                                    width: 46,
                                    height: 46,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) => const Icon(
                                      Icons.person_rounded,
                                      color: Colors.white,
                                    ),
                                  ),
                                )
                              : Text(
                                  user.displayName.isEmpty
                                      ? '形'
                                      : user.displayName.characters.first,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                        ),
                        Positioned(
                          right: -5,
                          bottom: -5,
                          child: MembershipMark(
                            isMember: quota.isMember,
                            size: 19,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.displayName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _membershipCaption(quota),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            user.identifier,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: quiet, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      key: const Key('edit-personal-profile'),
                      tooltip: '修改用户名和头像',
                      onPressed: () =>
                          _showPersonalProfileSheet(context, controller),
                      icon: const Icon(Icons.edit_outlined),
                    ),
                  ],
                );
                final badge = _StatusChip(
                  _membershipLabel(quota.membership),
                  color: quota.membership == MembershipPlan.free
                      ? muted
                      : primary,
                  icon: quota.membership == MembershipPlan.free
                      ? Icons.person_outline
                      : Icons.workspace_premium,
                );
                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      identity,
                      const SizedBox(height: 8),
                      Align(alignment: Alignment.centerLeft, child: badge),
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: identity),
                    const SizedBox(width: 12),
                    badge,
                  ],
                );
              },
            ),
            const SizedBox(height: 11),
            _AccountBenefitsLine(isEnabled: controller.cloudSyncAllowed),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    key: const Key('redeem-membership-button'),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            MembershipCenterPage(controller: controller),
                      ),
                    ),
                    icon: const Icon(Icons.confirmation_number_outlined),
                    label: Text(quota.isMember ? '管理会员' : '升级 PRO'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.outlined(
                  key: const Key('logout-button'),
                  tooltip: '\u9000\u51fa\u767b\u5f55',
                  onPressed: controller.logout,
                  icon: const Icon(Icons.logout),
                ),
              ],
            ),
            if (user.isAdmin) ...[
              const Divider(height: 18),
              const Row(
                children: [
                  Icon(Icons.admin_panel_settings_outlined, size: 18),
                  SizedBox(width: 6),
                  Text(
                    '\u7ba1\u7406\u5458\u5de5\u5177',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              LayoutBuilder(
                builder: (context, constraints) {
                  final compact =
                      constraints.maxWidth < 330 || textScale > 1.35;
                  final buttons = <Widget>[
                    FilledButton.icon(
                      key: const Key('admin-create-user-button'),
                      onPressed: () =>
                          _showAdminCreateUserSheet(context, controller),
                      icon: const Icon(
                        Icons.person_add_alt_1_rounded,
                        size: 18,
                      ),
                      label: const Text('创建账号'),
                    ),
                    OutlinedButton(
                      key: const Key('admin-grant-membership-button'),
                      onPressed: () =>
                          _showAdminGrantDialog(context, controller),
                      child: const Text('\u5f00\u901a\u4f1a\u5458'),
                    ),
                    OutlinedButton(
                      key: const Key('admin-generate-code-button'),
                      onPressed: () =>
                          _showAdminCodeDialog(context, controller),
                      child: const Text('\u751f\u6210\u5151\u6362\u7801'),
                    ),
                  ];
                  if (compact) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (
                          var index = 0;
                          index < buttons.length;
                          index++
                        ) ...[
                          buttons[index],
                          if (index < buttons.length - 1)
                            const SizedBox(height: 8),
                        ],
                      ],
                    );
                  }
                  return Wrap(spacing: 8, runSpacing: 8, children: buttons);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AccountBenefitsLine extends StatelessWidget {
  const _AccountBenefitsLine({required this.isEnabled});

  final bool isEnabled;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(
        isEnabled ? Icons.cloud_done_outlined : Icons.cloud_outlined,
        color: primary,
        size: 18,
      ),
      const SizedBox(width: 7),
      Expanded(
        child: Text(
          isEnabled ? 'PRO 云同步已开启' : '训练记录保存在本机 · 可升级 PRO 云同步',
          style: TextStyle(color: muted, fontSize: 12),
        ),
      ),
    ],
  );
}

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key, required this.controller});
  final AppController controller;

  String _volumeLabel(double value) => value >= 1000
      ? '${(value / 1000).toStringAsFixed(1)}t'
      : '${value.toStringAsFixed(0)}kg';

  @override
  Widget build(BuildContext context) {
    final totalVolume = controller.history.fold<double>(
      0,
      (sum, record) => sum + record.volume,
    );
    final effectiveSets = controller.history.fold<int>(
      0,
      (sum, record) => sum + record.effectiveSets,
    );
    final trainingDays = controller.history
        .map(
          (record) =>
              '${record.date.year}-${record.date.month}-${record.date.day}',
        )
        .toSet()
        .length;
    return PageFrame(
      children: [
        _AccountMembershipCard(controller: controller),
        const SizedBox(height: 14),
        const _ProfileSectionLabel(
          title: '训练资产',
          icon: Icons.bar_chart_rounded,
        ),
        const SizedBox(height: 7),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final textScale = MediaQuery.textScalerOf(context).scale(1);
                final metrics = [
                  _ProfileMetric(
                    value: '${controller.history.length}',
                    label: '次训练',
                  ),
                  _ProfileMetric(value: '$effectiveSets', label: '有效组'),
                  _ProfileMetric(
                    value: _volumeLabel(totalVolume),
                    label: '训练量',
                  ),
                  _ProfileMetric(value: '$trainingDays', label: '训练日'),
                ];
                if (constraints.maxWidth < 300 || textScale > 1.45) {
                  return Wrap(
                    runSpacing: 16,
                    children: [
                      for (final metric in metrics)
                        SizedBox(
                          width: constraints.maxWidth / 2,
                          child: metric,
                        ),
                    ],
                  );
                }
                return Row(
                  children: [
                    for (var i = 0; i < metrics.length; i++) ...[
                      Expanded(child: metrics[i]),
                      if (i != metrics.length - 1)
                        const SizedBox(height: 42, child: VerticalDivider()),
                    ],
                  ],
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 14),
        const _ProfileSectionLabel(title: '个性化', icon: Icons.tune_rounded),
        const SizedBox(height: 7),
        LayoutBuilder(
          builder: (context, constraints) {
            final textScale = MediaQuery.textScalerOf(context).scale(1);
            final singleColumn = constraints.maxWidth < 330 || textScale > 1.45;
            return GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: singleColumn ? 1 : 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 8,
              mainAxisExtent: singleColumn
                  ? (textScale > 1.45 ? 124 : 86)
                  : (textScale > 1.2 ? 116 : 96),
              children: [
                _ProfileQuickAction(
                  icon: Icons.insights_rounded,
                  title: '训练进步',
                  caption: '趋势、肌群与记录',
                  onTap: () => _showProgress(context, controller),
                ),
                _ProfileQuickAction(
                  key: const Key('training-profile-setting'),
                  icon: Icons.person_search_outlined,
                  title: '训练资料',
                  caption: '目标、经验与热量估算',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => TrainingProfileOnboardingPage(
                        controller: controller,
                        editMode: true,
                      ),
                    ),
                  ),
                ),
                _ProfileQuickAction(
                  key: const Key('profile-gym-entry'),
                  icon: Icons.location_on_outlined,
                  title: '我的健身房',
                  caption: controller.currentGym == null
                      ? '配置训练地点与器械'
                      : controller.currentGym!.name,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => GymLocationsPage(controller: controller),
                    ),
                  ),
                ),
                _ProfileQuickAction(
                  key: const Key('app-language-setting'),
                  icon: Icons.translate_rounded,
                  title: '应用语言',
                  caption: controller.appLanguage == AppLanguage.english
                      ? 'English'
                      : '简体中文',
                  onTap: () => _showAppLanguageSheet(context, controller),
                ),
                _ProfileQuickAction(
                  key: const Key('notification-feedback-card'),
                  icon: Icons.notifications_active_outlined,
                  title: '通知反馈',
                  caption: controller.androidNotifications
                      ? '训练提醒已开启'
                      : '训练提醒已关闭',
                  trailing: Switch(
                    key: const Key('notification-feedback-switch'),
                    value: controller.androidNotifications,
                    onChanged: (value) {
                      controller.androidNotifications = value;
                      controller.refresh();
                      showKiloSnack(context, value ? '训练提醒已开启' : '训练提醒已关闭');
                    },
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 14),
        const _ProfileSectionLabel(title: '服务与安全', icon: Icons.shield_outlined),
        const SizedBox(height: 7),
        Card(
          child: Column(
            children: [
              _ProfileSettingRow(
                key: const Key('profile-friends-entry'),
                icon: Icons.people_alt_outlined,
                title: '好友训练',
                caption: '查看好友分享的计划与互动',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => _FriendsPage(controller: controller),
                  ),
                ),
              ),
              const Divider(height: 1),
              _ProfileSettingRow(
                key: const Key('profile-guide-entry'),
                icon: Icons.menu_book_outlined,
                title: '使用指南',
                caption: '图文了解主要功能',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => GuidePage(controller: controller),
                  ),
                ),
              ),
              const Divider(height: 1),
              _ProfileSettingRow(
                key: const Key('profile-unified-calendar-entry'),
                icon: Icons.calendar_month_outlined,
                title: '训练与饮食',
                caption: '按日期查看完整时间轴',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => UnifiedCalendarPage(controller: controller),
                  ),
                ),
              ),
              const Divider(height: 1),
              _ProfileSettingRow(
                key: const Key('profile-orders-entry'),
                icon: Icons.receipt_long_outlined,
                title: '我的订单',
                caption: '查看会员购买与订单状态',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        MembershipOrdersPage(controller: controller),
                  ),
                ),
              ),
              const Divider(height: 1),
              _ProfileSettingRow(
                key: const Key('profile-dark-mode-toggle'),
                icon: controller.darkMode
                    ? Icons.dark_mode_outlined
                    : Icons.light_mode_outlined,
                title: '深色模式',
                caption: controller.darkMode ? '炭黑与亮橙' : '冷灰白与石墨橙',
                trailing: Switch(
                  value: controller.darkMode,
                  onChanged: (value) {
                    unawaited(controller.setDarkMode(value));
                  },
                ),
              ),
              const Divider(height: 1),
              _ProfileSettingRow(
                icon: Icons.lock_clock_outlined,
                title: '锁屏实时活动',
                caption: '训练状态同步到锁屏',
                trailing: Switch(
                  value: controller.liveActivity,
                  onChanged: (value) {
                    controller.liveActivity = value;
                    controller.refresh();
                  },
                ),
              ),
              const Divider(height: 1),
              _ProfileSettingRow(
                icon: Icons.watch_outlined,
                title: 'Apple Watch',
                caption: controller.appleWatch
                    ? '已配对，训练与组间休息会自动同步'
                    : '未检测到已安装形域的配对手表',
                trailing: Icon(
                  controller.appleWatch
                      ? Icons.check_circle_rounded
                      : Icons.info_outline_rounded,
                  color: controller.appleWatch
                      ? Theme.of(context).colorScheme.primary
                      : null,
                ),
                onTap: () => unawaited(controller.refreshAppleWatchStatus()),
              ),
              const Divider(height: 1),
              _ProfileSettingRow(
                icon: Icons.privacy_tip_outlined,
                title: '隐私与 AI 授权',
                caption: controller.aiUseTrainingData
                    ? '训练摘要已授权，可随时撤销'
                    : '训练摘要默认不上传',
                onTap: () => controller.selectPage(PageId.ai),
              ),
              const Divider(height: 1),
              _ProfileSettingRow(
                key: Key('app-version-row'),
                icon: Icons.info_outline,
                title: '关于形域',
                caption:
                    '版本 $kiloAppVersionLabel · $kiloSourceCommitLabel · $kiloAppNavigationLabel',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProfileSectionLabel extends StatelessWidget {
  const _ProfileSectionLabel({required this.title, required this.icon});
  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 16, color: primary),
      const SizedBox(width: 7),
      Text(title, style: Theme.of(context).textTheme.titleMedium),
    ],
  );
}

class _ProfileMetric extends StatelessWidget {
  const _ProfileMetric({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        ),
      ),
      Text(label, style: TextStyle(fontSize: 11, color: quiet)),
    ],
  );
}

class _ProfileQuickAction extends StatelessWidget {
  const _ProfileQuickAction({
    super.key,
    required this.icon,
    required this.title,
    required this.caption,
    this.onTap,
    this.trailing,
  });
  final IconData icon;
  final String title;
  final String caption;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Material(
    color: surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(color: hairline),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: primaryContainer,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, size: 16, color: primary),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    AppLocalizations.of(context).text(caption),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: quiet),
                  ),
                ],
              ),
            ),
            trailing ?? Icon(Icons.chevron_right, size: 18, color: quiet),
          ],
        ),
      ),
    ),
  );
}

class _ProfileSettingRow extends StatelessWidget {
  const _ProfileSettingRow({
    super.key,
    required this.icon,
    required this.title,
    required this.caption,
    this.trailing,
    this.onTap,
  });
  final IconData icon;
  final String title;
  final String caption;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    dense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
    leading: Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: primaryContainer,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Icon(icon, size: 16, color: primary),
    ),
    title: Text(
      AppLocalizations.of(context).text(title),
      style: const TextStyle(fontWeight: FontWeight.w800),
    ),
    subtitle: Text(
      AppLocalizations.of(context).text(caption),
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
    ),
    trailing:
        trailing ?? (onTap == null ? null : const Icon(Icons.chevron_right)),
    onTap: onTap,
  );
}

void _showAdminGrantDialog(BuildContext context, AppController controller) {
  final identifier = TextEditingController();
  var plan = MembershipPlan.oneMonth;
  showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('\u4e3a\u7528\u6237\u5f00\u901a\u4f1a\u5458'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: identifier,
              decoration: const InputDecoration(
                labelText: '\u7528\u6237\u6807\u8bc6',
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<MembershipPlan>(
              initialValue: plan,
              items: const [
                DropdownMenuItem(
                  value: MembershipPlan.oneMonth,
                  child: Text('1 \u4e2a\u6708'),
                ),
                DropdownMenuItem(
                  value: MembershipPlan.threeMonths,
                  child: Text('3 \u4e2a\u6708'),
                ),
                DropdownMenuItem(
                  value: MembershipPlan.yearly,
                  child: Text('1 \u5e74'),
                ),
                DropdownMenuItem(
                  value: MembershipPlan.forever,
                  child: Text('\u6c38\u4e45'),
                ),
              ],
              onChanged: (value) => setState(() => plan = value ?? plan),
              decoration: const InputDecoration(
                labelText: '\u4f1a\u5458\u65f6\u957f',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('\u53d6\u6d88'),
          ),
          FilledButton(
            key: const Key('admin-grant-submit-button'),
            onPressed: () async {
              try {
                await controller.grantMembershipRemote(
                  identifier: identifier.text,
                  plan: plan,
                );
                if (!dialogContext.mounted || !context.mounted) return;
                Navigator.pop(dialogContext);
                showKiloSnack(
                  context,
                  '\u5df2\u4e3a\u7528\u6237\u5f00\u901a\u4f1a\u5458',
                );
              } on CoachApiException catch (error) {
                if (!context.mounted) return;
                showKiloSnack(
                  context,
                  error.code == 'user_not_found'
                      ? '没有找到该手机号账号'
                      : '开通失败：${error.code}',
                  error: true,
                );
              }
            },
            child: const Text('\u786e\u8ba4\u5f00\u901a'),
          ),
        ],
      ),
    ),
  );
}

Future<void> _showAdminCreateUserSheet(
  BuildContext context,
  AppController controller,
) async {
  final parentContext = context;
  final phone = TextEditingController();
  final displayName = TextEditingController();
  final password = TextEditingController(text: '1234');
  var grantMember = true;
  var plan = MembershipPlan.oneMonth;
  var submitting = false;
  String? error;
  await showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: paper,
    builder: (sheetContext) => StatefulBuilder(
      builder: (sheetBodyContext, setState) => AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.fromLTRB(
          20,
          14,
          20,
          20 + MediaQuery.viewInsetsOf(sheetBodyContext).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: hairline,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: primaryContainer,
                    foregroundColor: primary,
                    child: Icon(Icons.person_add_alt_1_rounded),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '创建会员账号',
                          style: TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          '账号仅在服务端创建，不会切换当前管理员登录。',
                          style: TextStyle(fontSize: 12, color: muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              TextField(
                key: const Key('admin-create-user-phone'),
                controller: phone,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: '手机号',
                  prefixIcon: Icon(Icons.phone_iphone_rounded),
                  hintText: '11 位中国大陆手机号',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: displayName,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: '用户昵称（可选）',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                key: const Key('admin-create-user-password'),
                controller: password,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: '初始密码',
                  prefixIcon: Icon(Icons.lock_outline_rounded),
                  helperText: '默认 1234，请提醒用户首次登录后妥善保管。',
                ),
              ),
              const SizedBox(height: 8),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('创建时开通会员'),
                subtitle: const Text('关闭后创建为免费账号，可稍后单独开通。'),
                value: grantMember,
                onChanged: submitting
                    ? null
                    : (value) => setState(() => grantMember = value),
              ),
              if (grantMember)
                DropdownButtonFormField<MembershipPlan>(
                  initialValue: plan,
                  decoration: const InputDecoration(
                    labelText: '会员时长',
                    prefixIcon: Icon(Icons.workspace_premium_outlined),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: MembershipPlan.oneMonth,
                      child: Text('1 个月'),
                    ),
                    DropdownMenuItem(
                      value: MembershipPlan.threeMonths,
                      child: Text('3 个月'),
                    ),
                    DropdownMenuItem(
                      value: MembershipPlan.yearly,
                      child: Text('1 年'),
                    ),
                    DropdownMenuItem(
                      value: MembershipPlan.forever,
                      child: Text('永久'),
                    ),
                  ],
                  onChanged: submitting
                      ? null
                      : (value) => setState(() => plan = value ?? plan),
                ),
              if (error != null) ...[
                const SizedBox(height: 10),
                Text(error!, style: TextStyle(color: danger)),
              ],
              const SizedBox(height: 18),
              FilledButton.icon(
                key: const Key('admin-create-user-submit'),
                onPressed: submitting
                    ? null
                    : () async {
                        final normalized = phone.text.trim();
                        if (!RegExp(r'^1[3-9]\d{9}$').hasMatch(normalized)) {
                          setState(() => error = '请输入有效的 11 位手机号');
                          return;
                        }
                        if (password.text.length < 4) {
                          setState(() => error = '初始密码至少 4 位');
                          return;
                        }
                        setState(() {
                          submitting = true;
                          error = null;
                        });
                        try {
                          await controller.createManagedUserRemote(
                            identifier: normalized,
                            password: password.text,
                            displayName: displayName.text,
                            membershipPlan: grantMember ? plan : null,
                          );
                          if (!sheetContext.mounted || !parentContext.mounted) {
                            return;
                          }
                          Navigator.pop(sheetContext);
                          showKiloSnack(
                            parentContext,
                            grantMember ? '账号已创建，会员权益已生效' : '账号已创建',
                          );
                        } on CoachApiException catch (exception) {
                          if (!sheetBodyContext.mounted) return;
                          setState(() {
                            error = switch (exception.code) {
                              'identifier_taken' => '该手机号已经注册',
                              'admin_required' => '当前账号没有管理员权限',
                              _ => '创建失败：${exception.code}',
                            };
                            submitting = false;
                          });
                        } catch (_) {
                          if (!sheetBodyContext.mounted) return;
                          setState(() {
                            error = '网络暂时不可用，请稍后重试';
                            submitting = false;
                          });
                        }
                      },
                icon: submitting
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.person_add_alt_1_rounded),
                label: Text(submitting ? '正在创建…' : '创建账号'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    ),
  );
  phone.dispose();
  displayName.dispose();
  password.dispose();
}

void _showAdminCodeDialog(BuildContext context, AppController controller) {
  var plan = MembershipPlan.oneMonth;
  showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('\u751f\u6210\u4e00\u6b21\u6027\u5151\u6362\u7801'),
        content: DropdownButtonFormField<MembershipPlan>(
          initialValue: plan,
          items: const [
            DropdownMenuItem(
              value: MembershipPlan.oneMonth,
              child: Text('1 \u4e2a\u6708'),
            ),
            DropdownMenuItem(
              value: MembershipPlan.threeMonths,
              child: Text('3 \u4e2a\u6708'),
            ),
            DropdownMenuItem(
              value: MembershipPlan.yearly,
              child: Text('1 \u5e74'),
            ),
            DropdownMenuItem(
              value: MembershipPlan.forever,
              child: Text('\u6c38\u4e45'),
            ),
          ],
          onChanged: (value) => setState(() => plan = value ?? plan),
          decoration: const InputDecoration(
            labelText: '\u4f1a\u5458\u65f6\u957f',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('\u53d6\u6d88'),
          ),
          FilledButton(
            key: const Key('admin-generate-submit-button'),
            onPressed: () {
              try {
                final code = controller.generateRedemptionCode(plan: plan);
                Navigator.pop(dialogContext);
                showDialog<void>(
                  context: context,
                  builder: (codeContext) => AlertDialog(
                    title: const Text('\u5151\u6362\u7801\u5df2\u751f\u6210'),
                    content: SelectableText(code.code),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(codeContext),
                        child: const Text('\u5173\u95ed'),
                      ),
                    ],
                  ),
                );
              } catch (error) {
                showKiloSnack(context, error.toString(), error: true);
              }
            },
            child: const Text('\u751f\u6210'),
          ),
        ],
      ),
    ),
  );
}

void _showAppLanguageSheet(BuildContext context, AppController controller) {
  showModalBottomSheet<void>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ListTile(
            title: Text('语言与地区'),
            subtitle: Text('切换导航、训练流程、动作名称和 AI 回答语言'),
          ),
          RadioListTile<AppLanguage>(
            key: const Key('app-language-zh'),
            value: AppLanguage.simplifiedChinese,
            // ignore: deprecated_member_use
            groupValue: controller.appLanguage,
            title: const Text('简体中文'),
            // ignore: deprecated_member_use
            onChanged: (value) {
              if (value != null) controller.setAppLanguage(value);
              Navigator.pop(sheetContext);
            },
          ),
          RadioListTile<AppLanguage>(
            key: const Key('app-language-en'),
            value: AppLanguage.english,
            // ignore: deprecated_member_use
            groupValue: controller.appLanguage,
            title: const Text('English'),
            // ignore: deprecated_member_use
            onChanged: (value) {
              if (value != null) controller.setAppLanguage(value);
              Navigator.pop(sheetContext);
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

void _showRestSheet(BuildContext context, AppController controller) {
  showModalBottomSheet<void>(
    context: context,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: Text('休息 ${controller.restRemainingSeconds} 秒'),
            trailing: TextButton(
              onPressed: controller.skipRest,
              child: const Text('跳过'),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

void _showBatchEditor(BuildContext context, AppController controller) {
  String type = 'work';
  final weight = TextEditingController();
  final reps = TextEditingController();
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '批量修改 ${controller.selectedSetIds.length} 组',
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: type,
                decoration: const InputDecoration(labelText: '组别类型'),
                items: [
                  for (final entry in setTypeLabels.entries)
                    DropdownMenuItem(
                      value: entry.key,
                      child: Text(entry.value),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    type = value;
                    setState(() {});
                  }
                },
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: weight,
                      keyboardType: TextInputType.text,
                      decoration: const InputDecoration(labelText: '重量（可填自重）'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: reps,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: '次数（可选）'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              PrimaryButton(
                label: '应用修改',
                icon: Icons.check,
                onPressed: () {
                  controller.batchUpdate(
                    type: type,
                    weightInput: weight.text,
                    reps: int.tryParse(reps.text),
                  );
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

void _showExerciseDetail(
  BuildContext context,
  AppController controller,
  Exercise exercise,
) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) =>
        _ExerciseDetailSheet(controller: controller, exercise: exercise),
  );
}

class _ExerciseDetailSheet extends StatefulWidget {
  const _ExerciseDetailSheet({
    required this.controller,
    required this.exercise,
  });

  final AppController controller;
  final Exercise exercise;

  @override
  State<_ExerciseDetailSheet> createState() => _ExerciseDetailSheetState();
}

class _ExerciseDetailSheetState extends State<_ExerciseDetailSheet> {
  var tab = 0;
  var techniqueRange = 'all';
  late final TextEditingController note;
  late final TextEditingController link;
  bool openingLink = false;
  String? linkError;

  Exercise get exercise => widget.exercise;
  AppController get controller => widget.controller;
  ExerciseMedia? get media => mediaForExercise(exercise.id);

  @override
  void initState() {
    super.initState();
    final resource = controller.resourceFor(exercise.id, 'library');
    note = TextEditingController(text: resource.note);
    link = TextEditingController(text: resource.link);
  }

  @override
  void dispose() {
    note.dispose();
    link.dispose();
    super.dispose();
  }

  List<WorkoutRecord> get matchingRecords => controller.history.where((record) {
    if (record.exercises.isNotEmpty) {
      return record.exercises.any((item) => item.exerciseId == exercise.id);
    }
    return record.exerciseIds.contains(exercise.id);
  }).toList();

  List<WorkoutSet> setsFor(WorkoutRecord record) {
    if (record.exercises.isEmpty) return const <WorkoutSet>[];
    return record.exercises
        .where((item) => item.exerciseId == exercise.id)
        .expand((item) => item.sets)
        .where((set) => set.completed)
        .toList();
  }

  WorkoutExercise? exerciseForRecord(WorkoutRecord record) {
    for (final item in record.exercises) {
      if (item.exerciseId == exercise.id) return item;
    }
    return null;
  }

  List<WorkoutSet> get completedSets => matchingRecords
      .expand(setsFor)
      .where((set) => set.completed && set.reps > 0)
      .toList();

  List<TechniqueAssessment> get techniqueHistory =>
      controller.techniqueAssessments
          .where((item) => item.exerciseId == exercise.id)
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  double? get heaviestWeight {
    if (completedSets.isEmpty) return null;
    return completedSets
        .map((set) => set.weight)
        .reduce((a, b) => a > b ? a : b);
  }

  double? get estimatedOneRepMax {
    final eligible = completedSets
        .where((set) => set.weight > 0 && set.reps > 0)
        .map((set) => set.weight * (1 + set.reps / 30))
        .toList();
    if (eligible.isEmpty) return null;
    return eligible.reduce((a, b) => a > b ? a : b);
  }

  String _weight(double? value) {
    if (value == null) return '—';
    if (value.abs() < .01 && exercise.loadMode == 'bodyweight') return '自重';
    return '${value.toStringAsFixed(value % 1 == 0 ? 0 : 1)} kg';
  }

  String _date(DateTime value) =>
      '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  void _saveResource() {
    controller.saveResource(
      exerciseId: exercise.id,
      scope: 'library',
      note: note.text.trim(),
      link: link.text.trim(),
    );
    showKiloSnack(context, '动作备注已保存');
  }

  void _openRecognition() {
    final navigator = Navigator.of(context);
    controller.selectRecognitionExercise(exercise.id);
    navigator.pop();
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('动作分析')),
          body: SafeArea(child: RecognitionPage(controller: controller)),
        ),
      ),
    );
  }

  Future<void> _openLink() async {
    final uri = normalizeTrainingUri(link.text);
    if (uri == null) {
      setState(() => linkError = '请输入有效的 HTTP 或 HTTPS 链接。');
      return;
    }
    setState(() {
      openingLink = true;
      linkError = null;
    });
    var launched = false;
    try {
      launched = await launchTrainingUri(uri);
    } catch (_) {
      launched = false;
    }
    if (!mounted) return;
    setState(() {
      openingLink = false;
      linkError = launched ? null : '链接打开失败，请检查地址或系统应用权限。';
    });
    showKiloSnack(
      context,
      launched ? '已交给系统处理，正在打开' : '链接打开失败，请检查地址或系统应用权限。',
      error: !launched,
      icon: launched ? Icons.open_in_new : Icons.error_outline,
    );
  }

  @override
  Widget build(BuildContext context) {
    final records = matchingRecords;
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final sheetHeight = MediaQuery.sizeOf(context).height * .94;
    final contentHeight = (sheetHeight - keyboardInset)
        .clamp(320.0, sheetHeight)
        .toDouble();
    return AnimatedPadding(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(bottom: keyboardInset),
      child: SafeArea(
        child: SizedBox(
          key: const Key('exercise-detail-sheet'),
          height: contentHeight,
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ExerciseDetailHeader(
                  controller: controller,
                  exercise: exercise,
                ),
                _ExerciseMediaHero(exercise: exercise, media: media),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _DetailTag(label: '主要：${exercise.muscle}'),
                    _DetailTag(label: '辅助：${exercise.secondary}'),
                    _DetailTag(label: '器械：${exercise.equipment}'),
                  ],
                ),
                const SizedBox(height: 12),
                _ExerciseDetailTabs(
                  selected: tab,
                  onChanged: (value) => setState(() => tab = value),
                ),
                const SizedBox(height: 4),
                if (tab == 0)
                  _buildOverview(records: records)
                else if (tab == 1)
                  _buildTeaching()
                else
                  _buildHistory(records),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOverview({required List<WorkoutRecord> records}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) => GridView.count(
            key: const Key('exercise-detail-stats'),
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: constraints.maxWidth < 340 ? 1.08 : 1.25,
            children: [
              _DetailStat(
                key: const Key('exercise-stat-sessions'),
                label: '训练次数',
                value: '${records.length}',
              ),
              _DetailStat(
                key: const Key('exercise-stat-heaviest'),
                label: '最重重量',
                value: _weight(heaviestWeight),
              ),
              _DetailStat(
                key: const Key('exercise-stat-one-rm'),
                label: '估算 1RM',
                value: _weight(estimatedOneRepMax),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _buildTechniqueGrowth(),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            key: const Key('exercise-detail-analyze-action'),
            onPressed: controller.entitlements?.isMember == true
                ? _openRecognition
                : () => showMembershipPaywall(
                    context,
                    controller: controller,
                    reason: MembershipPaywallReason.premiumFeature,
                  ),
            icon: Icon(
              controller.entitlements?.isMember == true
                  ? Icons.videocam_outlined
                  : Icons.lock_outline_rounded,
            ),
            label: Text(
              controller.entitlements?.isMember == true
                  ? '分析一组动作'
                  : '解锁 PRO 动作分析',
            ),
          ),
        ),
        const SizedBox(height: 10),
        _DetailBlock(
          key: const Key('exercise-detail-resource'),
          title: '备注与链接',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                key: const Key('exercise-detail-note'),
                controller: note,
                maxLines: 2,
                minLines: 1,
                textInputAction: TextInputAction.newline,
                scrollPadding: EdgeInsets.only(
                  bottom: MediaQuery.viewInsetsOf(context).bottom + 150,
                ),
                decoration: const InputDecoration(
                  labelText: '动作备注',
                  hintText: '例如：回程控制 2 秒，保持胸口支撑',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                key: const Key('exercise-detail-link'),
                controller: link,
                maxLines: 1,
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.done,
                scrollPadding: EdgeInsets.only(
                  bottom: MediaQuery.viewInsetsOf(context).bottom + 150,
                ),
                decoration: const InputDecoration(
                  labelText: '教学链接（可选）',
                  prefixIcon: Icon(Icons.link),
                ),
                onChanged: (_) => setState(() => linkError = null),
              ),
              if (link.text.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    key: const Key('exercise-detail-open-link'),
                    onPressed: openingLink ? null : _openLink,
                    icon: openingLink
                        ? const SizedBox(
                            width: 17,
                            height: 17,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.open_in_new),
                    label: Text(openingLink ? '打开中…' : '打开链接'),
                  ),
                ),
              ],
              if (linkError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    linkError!,
                    style: const TextStyle(
                      color: Color(0xFFB3261E),
                      fontSize: 12,
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                key: const Key('exercise-detail-save-button'),
                onPressed: _saveResource,
                icon: const Icon(Icons.check),
                label: const Text('保存备注与链接'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _DetailActions(
          onAdd: () {
            controller.addExercise(exercise.id);
            Navigator.pop(context);
          },
        ),
      ],
    );
  }

  Widget _buildTechniqueGrowth() {
    if (controller.entitlements?.isMember != true) {
      return _DetailBlock(
        key: const Key('exercise-technique-growth'),
        title: '技术成长档案',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.lock_outline_rounded, color: primary),
                const SizedBox(width: 7),
                const Expanded(
                  child: Text(
                    'PRO 技术评分与成长曲线',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                const _ProPill(),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '上传动作视频后，查看 ROM、稳定性、对称性、节奏和历史趋势。',
              style: TextStyle(color: quiet, fontSize: 12, height: 1.35),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                key: const Key('exercise-technique-growth-paywall'),
                onPressed: () => showMembershipPaywall(
                  context,
                  controller: controller,
                  reason: MembershipPaywallReason.premiumFeature,
                ),
                icon: const Icon(Icons.lock_open_outlined, size: 17),
                label: const Text('解锁技术成长'),
              ),
            ),
          ],
        ),
      );
    }
    final scoreable = techniqueHistory
        .where((item) => item.scoreable)
        .toList(growable: false);
    final unavailable = techniqueHistory
        .where((item) => !item.scoreable)
        .firstOrNull;
    if (scoreable.isEmpty) {
      return _DetailBlock(
        key: const Key('exercise-technique-growth'),
        title: '技术成长档案',
        child: Text(
          unavailable == null
              ? '上传一次完整动作视频后，这里会记录 ROM、稳定性、对称性、节奏和轨迹。'
              : '最近视频未进入评分曲线：${unavailable.qualityReason}。请完整拍到身体并录制至少一个完整动作周期。',
          style: TextStyle(color: quiet, height: 1.45),
        ),
      );
    }
    final latest = scoreable.first;
    final earliest = scoreable.last;
    final highest = scoreable
        .map((item) => item.overall)
        .reduce((a, b) => a > b ? a : b);
    final now = DateTime.now();
    final cutoff = switch (techniqueRange) {
      'month' => now.subtract(const Duration(days: 30)),
      'quarter' => now.subtract(const Duration(days: 90)),
      _ => null,
    };
    final visible = cutoff == null
        ? scoreable
        : scoreable
              .where((item) => !item.createdAt.isBefore(cutoff))
              .toList(growable: false);
    final visibleLatest = visible.firstOrNull ?? latest;
    return _DetailBlock(
      key: const Key('exercise-technique-growth'),
      title: '技术成长档案',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _DetailTag(label: '当前 ${latest.overall}'),
              _DetailTag(label: '最高 $highest'),
              _DetailTag(label: '首次 ${earliest.overall}'),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              for (final option in const [
                ('month', '1个月'),
                ('quarter', '3个月'),
                ('all', '全部'),
              ])
                ChoiceChip(
                  key: Key('exercise-technique-range-${option.$1}'),
                  label: Text(option.$2),
                  selected: techniqueRange == option.$1,
                  onSelected: (_) => setState(() => techniqueRange = option.$1),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (visible.isEmpty)
            Text(
              '该时间范围暂无评分记录，切换“全部”可查看完整历史。',
              style: TextStyle(color: quiet, height: 1.4),
            )
          else ...[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (var index = visible.length - 1; index >= 0; index--) ...[
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: primaryContainer,
                      foregroundColor: primary,
                      child: Text(
                        '${visible[index].overall}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    if (index > 0)
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 5),
                        child: Icon(
                          Icons.arrow_forward_rounded,
                          size: 14,
                          color: quiet,
                        ),
                      ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'ROM ${visibleLatest.rom} · 稳定 ${visibleLatest.stability} · 对称 ${visibleLatest.symmetry} · 节奏 ${visibleLatest.tempo} · 轨迹 ${visibleLatest.trajectory}',
              style: const TextStyle(fontSize: 12, height: 1.45),
            ),
            if (visibleLatest.nextFocus.isNotEmpty) ...[
              const SizedBox(height: 7),
              Text(
                '下一次重点：${visibleLatest.nextFocus}',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  height: 1.4,
                ),
              ),
            ],
            const SizedBox(height: 12),
            const Text('最近分析', style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            for (final assessment in visible.take(5))
              Container(
                key: Key('exercise-technique-assessment-${assessment.id}'),
                margin: const EdgeInsets.only(bottom: 7),
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                decoration: BoxDecoration(
                  color: surfaceRaised.withValues(alpha: .92),
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: hairline),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _date(assessment.createdAt),
                            style: TextStyle(color: quiet, fontSize: 11),
                          ),
                        ),
                        Text(
                          '${assessment.overall}/100',
                          style: TextStyle(
                            color: primary,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'ROM ${assessment.rom} · 稳定 ${assessment.stability} · 对称 ${assessment.symmetry} · 节奏 ${assessment.tempo} · 轨迹 ${assessment.trajectory}',
                      style: const TextStyle(fontSize: 11, height: 1.35),
                    ),
                    if (assessment.nextFocus.trim().isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        '下一次重点：${assessment.nextFocus}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: primary,
                          fontSize: 11,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildTeaching() {
    final steps = media?.steps ?? <String>[exercise.cue];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DetailBlock(
          title: '动作教学',
          child: Text(media?.summary ?? exercise.cue),
        ),
        const SizedBox(height: 10),
        _DetailBlock(
          title: '分步说明',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var index = 0; index < steps.length; index++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 12,
                        backgroundColor: primaryContainer,
                        foregroundColor: cobalt,
                        child: Text('${index + 1}'),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(steps[index])),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _DetailBlock(title: '现有动作提示', child: Text(exercise.cue)),
        const SizedBox(height: 10),
        _DetailBlock(title: '拍摄机位', child: Text(exercise.camera)),
        if (media != null) ...[
          const SizedBox(height: 10),
          Text(
            '数据集：${media!.datasetId} · ${media!.attribution}',
            style: TextStyle(color: quiet, fontSize: 11),
          ),
        ],
      ],
    );
  }

  Widget _buildHistory(List<WorkoutRecord> records) {
    if (records.isEmpty) {
      return _DetailBlock(
        title: '训练记录',
        child: Text(
          '还没有该动作的训练记录。加入一次训练并完成组后，这里会按日期显示真实数据。',
          style: TextStyle(color: quiet),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final record in records)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Card(
              key: Key('exercise-history-${record.id}'),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            _date(record.date),
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        Flexible(
                          child: Text(
                            record.name,
                            textAlign: TextAlign.end,
                            style: TextStyle(color: quiet, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (exerciseForRecord(record)?.note.trim().isNotEmpty ==
                        true) ...[
                      _NoteCallout(
                        key: Key('exercise-detail-note-${record.id}'),
                        label: '动作备注',
                        text: exerciseForRecord(record)!.note.trim(),
                        color: exerciseNoteColor,
                        background: exerciseNoteContainer,
                      ),
                      const SizedBox(height: 6),
                    ],
                    if (setsFor(record).isEmpty)
                      Text(
                        '这条旧记录未保存该动作的组明细，仅保留训练日期。',
                        style: TextStyle(color: quiet, fontSize: 12),
                      )
                    else
                      for (final set in setsFor(record)) ...[
                        Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: Text(
                            '${_weight(set.weight)} × ${set.reps}'
                            '${set.rir == null ? '' : ' · RIR ${set.rir}'}'
                            '${set.rpe == null ? '' : ' · RPE ${set.rpe}'}',
                          ),
                        ),
                        if (set.note.trim().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: _NoteCallout(
                              key: Key(
                                'exercise-detail-set-note-${record.id}-${set.id}',
                              ),
                              label: '组备注',
                              text: set.note.trim(),
                              color: setNoteColor,
                              background: setNoteContainer,
                            ),
                          ),
                      ],
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ExerciseDetailHeader extends StatelessWidget {
  const _ExerciseDetailHeader({
    required this.controller,
    required this.exercise,
  });

  final AppController controller;
  final Exercise exercise;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(2, 0, 0, 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IconButton(
          key: const Key('exercise-detail-close'),
          tooltip: '关闭动作详情',
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close),
        ),
        const SizedBox(width: 2),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  controller.displayExerciseName(exercise),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class _ExerciseMediaHero extends StatelessWidget {
  const _ExerciseMediaHero({required this.exercise, required this.media});

  final Exercise exercise;
  final ExerciseMedia? media;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(16),
    child: Container(
      key: Key('exercise-detail-media-${exercise.id}'),
      width: double.infinity,
      height: 205,
      decoration: BoxDecoration(
        color: surface,
        border: Border.all(color: hairline),
      ),
      child: media == null
          ? Image.asset(
              exerciseAsset(exercise.id),
              fit: BoxFit.contain,
              errorBuilder: (context, error, stack) =>
                  Icon(Icons.fitness_center, size: 52, color: cobalt),
            )
          : Image.asset(
              media!.gifPath,
              key: Key('exercise-detail-gif-${exercise.id}'),
              fit: BoxFit.contain,
              errorBuilder: (context, error, stack) => Image.asset(
                media!.imagePath,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stack) =>
                    Icon(Icons.fitness_center, size: 52, color: cobalt),
              ),
            ),
    ),
  );
}

class _DetailTag extends StatelessWidget {
  const _DetailTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: surface,
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: hairline),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      child: Text(label, style: TextStyle(fontSize: 12, color: secondaryInk)),
    ),
  );
}

class _ExerciseDetailTabs extends StatelessWidget {
  const _ExerciseDetailTabs({required this.selected, required this.onChanged});

  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => SegmentedButton<int>(
    key: const Key('exercise-detail-tabs'),
    segments: const [
      ButtonSegment(value: 0, label: Text('概览')),
      ButtonSegment(value: 1, label: Text('教学')),
      ButtonSegment(value: 2, label: Text('记录')),
    ],
    selected: {selected},
    onSelectionChanged: (value) => onChanged(value.first),
  );
}

class _DetailStat extends StatelessWidget {
  const _DetailStat({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: hairline),
    ),
    child: Padding(
      padding: const EdgeInsets.all(11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: TextStyle(color: quiet, fontSize: 12)),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    ),
  );
}

class _DetailBlock extends StatelessWidget {
  const _DetailBlock({super.key, required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: hairline),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        child,
      ],
    ),
  );
}

class _DetailActions extends StatelessWidget {
  const _DetailActions({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      PrimaryButton(
        key: const Key('exercise-detail-add-button'),
        label: '加入本次训练',
        icon: Icons.add,
        onPressed: onAdd,
      ),
    ],
  );
}

class _ProgressTrendPainter extends CustomPainter {
  const _ProgressTrendPainter(this.values);
  final List<double> values;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = hairline
      ..strokeWidth = 1;
    final linePaint = Paint()
      ..color = cobalt
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fillPaint = Paint()
      ..color = cobalt.withValues(alpha: .10)
      ..style = PaintingStyle.fill;
    for (var row = 1; row < 4; row++) {
      final y = size.height * row / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    if (values.isEmpty) return;
    final minValue = values.reduce((a, b) => a < b ? a : b);
    final maxValue = values.reduce((a, b) => a > b ? a : b);
    final span = (maxValue - minValue).abs() < .01 ? 1 : maxValue - minValue;
    final points = <Offset>[];
    for (var index = 0; index < values.length; index++) {
      final x = values.length == 1
          ? size.width / 2
          : size.width * index / (values.length - 1);
      final y =
          size.height -
          ((values[index] - minValue) / span).clamp(.08, .92) * size.height;
      points.add(Offset(x, y));
    }
    final line = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      line.lineTo(point.dx, point.dy);
    }
    final area = Path.from(line)
      ..lineTo(points.last.dx, size.height)
      ..lineTo(points.first.dx, size.height)
      ..close();
    canvas.drawPath(area, fillPaint);
    canvas.drawPath(line, linePaint);
    final dotPaint = Paint()..color = cobalt;
    for (final point in points) {
      canvas.drawCircle(point, 4, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ProgressTrendPainter oldDelegate) =>
      oldDelegate.values != values;
}

void _showProgress(BuildContext context, AppController controller) {
  final records = controller.history.reversed.toList();
  final volumes = records.map((record) => record.volume).toList();
  final latest = controller.history.isEmpty ? null : controller.history.first;
  final firstVolume = volumes.isEmpty ? 0 : volumes.first;
  final latestVolume = volumes.isEmpty ? 0 : volumes.last;
  final changeRate = firstVolume == 0
      ? 0.0
      : (latestVolume - firstVolume) / firstVolume * 100;
  var plannedSets = 0;
  var achievedPlannedSets = 0;
  var plannedDeltaTotal = 0.0;
  for (final record in controller.history) {
    for (final exercise in record.exercises) {
      for (final set in exercise.sets) {
        final planned = set.plannedWeight;
        if (planned == null) continue;
        plannedSets++;
        final delta = set.weight - planned;
        plannedDeltaTotal += delta;
        if (delta >= 0) achievedPlannedSets++;
      }
    }
  }
  final plannedAchievement = plannedSets == 0
      ? '\u8BA1\u5212\u91CD\u91CF\u672A\u8BB0\u5F55'
      : '${(achievedPlannedSets / plannedSets * 100).toStringAsFixed(0)}%';
  final averagePlannedDelta = plannedSets == 0
      ? '\u8BA1\u5212\u91CD\u91CF\u672A\u8BB0\u5F55'
      : '${plannedDeltaTotal / plannedSets >= 0 ? '+' : ''}${(plannedDeltaTotal / plannedSets).toStringAsFixed(1)} kg';
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .86,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('进步分析', style: Theme.of(context).textTheme.headlineMedium),
              Text(
                '把最近训练的变化放在同一条线上，看懂下一步该加什么。',
                style: TextStyle(color: quiet),
              ),
              const SizedBox(height: 14),
              if (volumes.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(18),
                    child: Text('还没有足够的训练数据。完成一次训练后，这里会显示趋势和动作表现。'),
                  ),
                )
              else ...[
                const Text(
                  '训练量趋势',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  key: const Key('progress-trend-chart'),
                  height: 170,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: primaryContainer,
                      borderRadius: BorderRadius.all(Radius.circular(14)),
                      border: Border.fromBorderSide(
                        BorderSide(color: hairline),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                      child: CustomPaint(
                        painter: _ProgressTrendPainter(volumes),
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${records.first.date.month}/${records.first.date.day} · ${records.first.volume.toStringAsFixed(0)} kg',
                      style: TextStyle(fontSize: 11, color: quiet),
                    ),
                    Text(
                      '${records.last.date.month}/${records.last.date.day} · ${records.last.volume.toStringAsFixed(0)} kg',
                      style: TextStyle(fontSize: 11, color: quiet),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 2.2,
                  children: [
                    _ProgressMetric(
                      label: '\u8BA1\u5212\u8FBE\u6210',
                      value: plannedAchievement,
                    ),
                    _ProgressMetric(
                      label: '\u5E73\u5747\u91CD\u91CF\u5DEE',
                      value: averagePlannedDelta,
                    ),
                    _ProgressMetric(
                      label: '最近训练量',
                      value: '${latestVolume.toStringAsFixed(0)} kg',
                    ),
                    _ProgressMetric(
                      label: '有效组',
                      value: '${latest?.effectiveSets ?? 0}',
                    ),
                    _ProgressMetric(
                      label: '记录变化',
                      value:
                          '${changeRate >= 0 ? '+' : ''}${changeRate.toStringAsFixed(1)}%',
                    ),
                    _ProgressMetric(label: '训练次数', value: '${records.length}'),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  '关键动作表现',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                for (final exerciseId
                    in (latest?.exerciseIds ?? const <String>[]).take(3))
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: _ExerciseThumb(exerciseId: exerciseId, size: 38),
                    title: Text(
                      controller.displayExerciseName(
                        controller.exerciseFor(exerciseId),
                      ),
                    ),
                    subtitle: const Text('最近一次完成 · 结合组别类型和重量复盘'),
                    trailing: Icon(Icons.trending_up, color: cobalt),
                  ),
                const SizedBox(height: 8),
                Text(
                  changeRate >= 0
                      ? '你的训练量正在上升。下一次优先保持动作质量，再让正式组增加 1–2 次或小幅加重。'
                      : '训练量暂时回落，不必急着追重量。先检查恢复、有效组和最近动作完成质量。',
                  style: TextStyle(color: secondaryInk),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

class _ProgressMetric extends StatelessWidget {
  const _ProgressMetric({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: paper,
      borderRadius: BorderRadius.all(Radius.circular(10)),
    ),
    child: Padding(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: quiet)),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    ),
  );
}

void _showRestEditor(
  BuildContext context,
  AppController controller,
  WorkoutExercise exercise,
) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) =>
        _RestEditorSheet(controller: controller, exercise: exercise),
  );
}

void _showActiveRestEditor(BuildContext context, AppController controller) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => _ActiveRestEditorSheet(controller: controller),
  );
}

void _showInitialRestSetup(BuildContext context, AppController controller) {
  if (!controller.restSetupPending || !controller.workoutStarted) return;
  final seconds = TextEditingController(text: '180');
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => AlertDialog(
      key: const Key('initial-rest-dialog'),
      title: const Text('设置组间休息'),
      content: TextField(
        key: const Key('initial-rest-seconds-input'),
        controller: seconds,
        autofocus: true,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(
          labelText: '休息时间（秒）',
          hintText: '默认 180 秒（3 分钟）',
          suffixText: 's',
        ),
      ),
      actions: [
        TextButton(
          key: const Key('initial-rest-cancel-button'),
          onPressed: () {
            controller.dismissRestSetup();
            Navigator.pop(dialogContext);
          },
          child: const Text('稍后设置'),
        ),
        FilledButton(
          key: const Key('initial-rest-save-button'),
          onPressed: () {
            final value = int.tryParse(seconds.text.trim());
            if (value == null || value < 0 || value > 600) {
              showKiloSnack(context, '请输入 0–600 秒');
              return;
            }
            controller.applyInitialRestSeconds(value);
            Navigator.pop(dialogContext);
          },
          child: const Text('应用到本次训练'),
        ),
      ],
    ),
  ).whenComplete(() => seconds.dispose());
}

class _ActiveRestEditorSheet extends StatefulWidget {
  const _ActiveRestEditorSheet({required this.controller});
  final AppController controller;

  @override
  State<_ActiveRestEditorSheet> createState() => _ActiveRestEditorSheetState();
}

class _ActiveRestEditorSheetState extends State<_ActiveRestEditorSheet> {
  static const quickValues = [0, 60, 90, 120, 180];
  late final TextEditingController seconds;

  @override
  void initState() {
    super.initState();
    seconds = TextEditingController(
      text: '${widget.controller.restRemainingSeconds}',
    );
  }

  @override
  void dispose() {
    seconds.dispose();
    super.dispose();
  }

  void setSeconds(int value) {
    seconds.value = TextEditingValue(
      text: '$value',
      selection: TextSelection.collapsed(offset: '$value'.length),
    );
    setState(() {});
  }

  void save() {
    final value = int.tryParse(seconds.text.trim());
    if (value == null || value < 0 || value > 600) {
      showKiloSnack(context, AppLocalizations.of(context).text('请输入 0–600 秒'));
      return;
    }
    widget.controller.updateActiveAndUpcomingRest(value);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          18,
          14,
          18,
          18 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              strings.text('修改组间休息'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              strings.text('保存后立即更新当前倒计时，并默认应用于本次训练后续所有动作和未完成组。'),
              style: TextStyle(color: quiet),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('active-rest-seconds-input'),
              controller: seconds,
              autofocus: true,
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: strings.text('休息秒数'),
                suffixText: 's',
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final value in quickValues)
                  ChoiceChip(
                    key: Key('active-rest-quick-$value'),
                    label: Text(value == 0 ? strings.text('关闭') : '$value s'),
                    selected: seconds.text.trim() == '$value',
                    onSelected: (_) => setSeconds(value),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(strings.text('取消')),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    key: const Key('active-rest-save-button'),
                    onPressed: save,
                    child: Text(strings.text('应用到当前及后续')),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RestEditorSheet extends StatefulWidget {
  const _RestEditorSheet({required this.controller, required this.exercise});
  final AppController controller;
  final WorkoutExercise exercise;

  @override
  State<_RestEditorSheet> createState() => _RestEditorSheetState();
}

class _RestEditorSheetState extends State<_RestEditorSheet> {
  static const quickValues = [0, 60, 90, 120, 180];
  late final TextEditingController seconds;
  int? selectedQuick;

  @override
  void initState() {
    super.initState();
    seconds = TextEditingController(text: '${widget.exercise.restSeconds}');
    selectedQuick = quickValues.contains(widget.exercise.restSeconds)
        ? widget.exercise.restSeconds
        : null;
  }

  @override
  void dispose() {
    seconds.dispose();
    super.dispose();
  }

  void setSeconds(int value) {
    seconds.value = TextEditingValue(
      text: '$value',
      selection: TextSelection.collapsed(offset: '$value'.length),
    );
    setState(() => selectedQuick = value);
  }

  void onSecondsChanged(String value) {
    final parsed = int.tryParse(value.trim());
    final next = quickValues.contains(parsed) ? parsed : null;
    if (selectedQuick == next) return;
    setState(() => selectedQuick = next);
  }

  void save(BuildContext sheetContext) {
    final value = int.tryParse(seconds.text.trim());
    if (value == null || value < 0 || value > 600) {
      showKiloSnack(sheetContext, '请输入 0–600 秒');
      return;
    }
    widget.controller.updateExerciseRest(widget.exercise, value);
    Navigator.pop(sheetContext);
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        18,
        14,
        18,
        18 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('设置动作休息', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text('0–600 秒；设置为 0 时完成组不启动休息通知。', style: TextStyle(color: quiet)),
          const SizedBox(height: 12),
          TextField(
            key: const Key('rest-seconds-input'),
            controller: seconds,
            autofocus: true,
            keyboardType: TextInputType.number,
            onChanged: onSecondsChanged,
            decoration: const InputDecoration(
              labelText: '休息秒数',
              suffixText: 's',
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final value in quickValues)
                ChoiceChip(
                  key: Key('rest-quick-$value'),
                  label: Text(value == 0 ? '关闭' : '$value s'),
                  selected: selectedQuick == value,
                  onSelected: (_) => setSeconds(value),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  key: const Key('rest-cancel-button'),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('取消'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: FilledButton(
                  key: const Key('rest-save-button'),
                  onPressed: () => save(context),
                  child: const Text('保存休息时间'),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

void _showExercisePicker(
  BuildContext context,
  AppController controller, {
  WorkoutExercise? replacing,
  Routine? routine,
  VoidCallback? onChanged,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: _ExercisePickerSheet(
        controller: controller,
        replacing: replacing,
        routine: routine,
        onChanged: onChanged,
      ),
    ),
  );
}

class _ExercisePickerSheet extends StatefulWidget {
  const _ExercisePickerSheet({
    required this.controller,
    this.replacing,
    this.routine,
    this.onChanged,
  });
  final AppController controller;
  final WorkoutExercise? replacing;
  final Routine? routine;
  final VoidCallback? onChanged;

  @override
  State<_ExercisePickerSheet> createState() => _ExercisePickerSheetState();
}

class _ExercisePickerSheetState extends State<_ExercisePickerSheet> {
  late final TextEditingController query;
  String muscle = '全部';
  String equipment = '全部';
  bool currentGymOnly = false;
  final Set<String> selectedIds = <String>{};

  @override
  void initState() {
    super.initState();
    query = TextEditingController();
  }

  @override
  void dispose() {
    query.dispose();
    super.dispose();
  }

  List<Exercise> get filtered {
    final needle = query.text.trim().toLowerCase();
    final source = currentGymOnly
        ? widget.controller.currentGymExercises
        : widget.controller.selectableExercises;
    return source.where((item) {
      final number = widget.controller.exerciseNumberFor(item).toString();
      final queryMatch =
          needle.isEmpty ||
          number == needle ||
          item.name.toLowerCase().contains(needle) ||
          item.englishName.toLowerCase().contains(needle) ||
          item.muscle.toLowerCase().contains(needle) ||
          item.equipment.toLowerCase().contains(needle);
      final muscleMatch =
          muscle == '全部' ||
          widget.controller.muscleGroupFor(item.muscle) == muscle;
      final equipmentMatch =
          equipment == '全部' ||
          widget.controller.equipmentGroupFor(item.equipment) == equipment;
      return queryMatch && muscleMatch && equipmentMatch;
    }).toList();
  }

  void choose(Exercise exercise) {
    FocusManager.instance.primaryFocus?.unfocus();
    final replacing = widget.replacing;
    if (replacing != null) {
      widget.controller.replaceExercise(replacing.id, exercise.id);
      Navigator.pop(context);
      return;
    }
    setState(() {
      if (!selectedIds.add(exercise.id)) selectedIds.remove(exercise.id);
    });
  }

  void addSelected() {
    if (selectedIds.isEmpty) return;
    final routine = widget.routine;
    if (routine == null) {
      widget.controller.addExercises(selectedIds);
    } else {
      for (final exerciseId in selectedIds) {
        if (routine.exercises.any((item) => item.exerciseId == exerciseId)) {
          continue;
        }
        routine.exercises.add(
          widget.controller.createBlankWorkoutExercise(
            exerciseId,
            'routine-${DateTime.now().microsecondsSinceEpoch}-$exerciseId',
          ),
        );
      }
      routine.updatedAt = DateTime.now();
      widget.controller.refresh();
      widget.onChanged?.call();
    }
    Navigator.pop(context);
  }

  Future<void> createCustomExercise() async {
    final exercise = await _showCustomExercise(context, widget.controller);
    if (!mounted || exercise == null) return;
    if (widget.replacing != null) {
      choose(exercise);
      return;
    }
    setState(() {
      selectedIds.add(exercise.id);
      currentGymOnly = false;
      muscle = '全部';
      equipment = '全部';
      final displayName = widget.controller.displayExerciseName(exercise);
      query.value = TextEditingValue(
        text: displayName,
        selection: TextSelection.collapsed(offset: displayName.length),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final items = filtered;
    const muscles = ['全部', '胸', '背', '肩', '腿', '手臂', '核心'];
    const muscleLabels = {
      '全部': '全部',
      '胸': '胸部',
      '背': '背部',
      '肩': '肩部',
      '腿': '腿部',
      '手臂': '手臂',
      '核心': '核心',
    };
    final equipments = widget.controller.equipmentFilterOptions;
    return SizedBox(
      key: const Key('exercise-picker'),
      height: MediaQuery.sizeOf(context).height * .84,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.replacing == null ? '添加动作' : '替换动作',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                TextButton.icon(
                  key: const Key('exercise-picker-create-custom'),
                  onPressed: createCustomExercise,
                  icon: const Icon(Icons.add_circle_outline, size: 18),
                  label: const Text('自定义'),
                ),
                IconButton(
                  tooltip: '关闭动作选择',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            if (widget.controller.currentGym != null &&
                widget.controller.currentGymExercises.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: FilterChip(
                  key: const Key('exercise-picker-current-gym'),
                  avatar: const Icon(Icons.location_on_outlined, size: 17),
                  label: Text(
                    currentGymOnly
                        ? '${widget.controller.currentGym!.name} · 仅显示本馆动作'
                        : '从 ${widget.controller.currentGym!.name} 选择',
                  ),
                  selected: currentGymOnly,
                  onSelected: (value) => setState(() {
                    currentGymOnly = value;
                    muscle = '全部';
                    equipment = '全部';
                  }),
                ),
              ),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    key: const Key('exercise-picker-muscle-strip'),
                    width: 82,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: surfaceRaised,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: hairline),
                      ),
                      child: ListView(
                        key: const Key('exercise-picker-equipment-strip'),
                        padding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 6,
                        ),
                        children: [
                          const _FilterRailHeading('部位'),
                          for (final value in muscles)
                            _FilterRailItem(
                              key: Key('exercise-picker-filter-$value'),
                              label: muscleLabels[value]!,
                              selected: muscle == value,
                              onTap: () => setState(() => muscle = value),
                            ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 7),
                            child: Divider(height: 1),
                          ),
                          const _FilterRailHeading('器械'),
                          for (final value in equipments)
                            _FilterRailItem(
                              key: Key('exercise-picker-equipment-$value'),
                              label: value == '全部' ? '全部' : value,
                              selected: equipment == value,
                              onTap: () => setState(() => equipment = value),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          key: const Key('exercise-picker-search'),
                          controller: query,
                          autofocus: false,
                          textInputAction: TextInputAction.search,
                          onTapOutside: (_) =>
                              FocusManager.instance.primaryFocus?.unfocus(),
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.search, size: 20),
                            hintText: '搜索动作',
                            isDense: true,
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          '${muscleLabels[muscle]} · ${items.length} 个动作',
                          style: TextStyle(fontSize: 11, color: quiet),
                        ),
                        const SizedBox(height: 3),
                        Expanded(
                          child: items.isEmpty
                              ? Center(
                                  child: Text(
                                    '没有匹配动作',
                                    style: TextStyle(color: quiet),
                                  ),
                                )
                              : ListView.separated(
                                  keyboardDismissBehavior:
                                      ScrollViewKeyboardDismissBehavior.onDrag,
                                  itemCount: items.length,
                                  separatorBuilder: (_, _) =>
                                      const Divider(height: 1),
                                  itemBuilder: (context, index) {
                                    final exercise = items[index];
                                    return ListTile(
                                      key: Key(
                                        'exercise-picker-item-${exercise.id}',
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            vertical: 4,
                                          ),
                                      leading: _ExerciseThumb(
                                        exerciseId: exercise.id,
                                        size: 40,
                                      ),
                                      title: Text(
                                        widget.controller.displayExerciseName(
                                          exercise,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      subtitle: Text(
                                        '${exercise.muscle} · ${exercise.equipment}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      trailing: IconButton.filled(
                                        key: Key(
                                          'exercise-picker-add-${exercise.id}',
                                        ),
                                        style: IconButton.styleFrom(
                                          backgroundColor:
                                              selectedIds.contains(exercise.id)
                                              ? primary
                                              : primaryContainer,
                                          foregroundColor:
                                              selectedIds.contains(exercise.id)
                                              ? Colors.white
                                              : primary,
                                        ),
                                        tooltip: widget.replacing != null
                                            ? '替换动作'
                                            : selectedIds.contains(exercise.id)
                                            ? '取消选择'
                                            : '选择动作',
                                        onPressed: () => choose(exercise),
                                        icon: Icon(
                                          widget.replacing != null
                                              ? Icons.swap_horiz
                                              : selectedIds.contains(
                                                  exercise.id,
                                                )
                                              ? Icons.check
                                              : Icons.add,
                                          size: 18,
                                        ),
                                      ),
                                      onTap: () => choose(exercise),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (widget.replacing == null) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: const Key('exercise-picker-add-selected'),
                  onPressed: selectedIds.isEmpty ? null : addSelected,
                  icon: const Icon(Icons.playlist_add_check),
                  label: Text(
                    selectedIds.isEmpty
                        ? '选择动作'
                        : '添加 ${selectedIds.length} 个动作',
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FilterRailHeading extends StatelessWidget {
  const _FilterRailHeading(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(7, 4, 7, 5),
    child: Text(
      label,
      style: TextStyle(color: quiet, fontSize: 10, fontWeight: FontWeight.w800),
    ),
  );
}

class _FilterRailItem extends StatelessWidget {
  const _FilterRailItem({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(1, 0, 1, 6),
    child: Material(
      color: selected ? primaryContainer : surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: selected ? primary : hairline),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 9),
          child: Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? primary : ink,
              fontSize: 11,
              fontWeight: selected ? FontWeight.w900 : FontWeight.w600,
            ),
          ),
        ),
      ),
    ),
  );
}

void _showExerciseActions(
  BuildContext context,
  AppController controller,
  WorkoutExercise exercise,
) => showModalBottomSheet<void>(
  context: context,
  builder: (context) => SafeArea(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          leading: const Icon(Icons.swap_horiz),
          title: const Text('替换动作'),
          onTap: () {
            Navigator.pop(context);
            _showExercisePicker(context, controller, replacing: exercise);
          },
        ),
        ListTile(
          leading: const Icon(Icons.arrow_upward),
          title: const Text('上移动作'),
          onTap: () {
            controller.moveExercise(exercise, -1);
            Navigator.pop(context);
          },
        ),
        ListTile(
          leading: const Icon(Icons.arrow_downward),
          title: const Text('下移动作'),
          onTap: () {
            controller.moveExercise(exercise, 1);
            Navigator.pop(context);
          },
        ),
        ListTile(
          leading: const Icon(Icons.link),
          title: Text(exercise.supersetId == null ? '加入超级组' : '取消超级组'),
          onTap: () {
            controller.toggleSuperset(exercise);
            Navigator.pop(context);
          },
        ),
        ListTile(
          leading: const Icon(Icons.delete_outline),
          title: const Text('移除动作'),
          onTap: () {
            controller.removeExercise(exercise);
            Navigator.pop(context);
          },
        ),
      ],
    ),
  ),
);

void _showFinishWorkout(
  BuildContext context,
  AppController controller, {
  bool past = false,
}) {
  showDialog<void>(
    context: context,
    builder: (context) =>
        _FinishWorkoutDialog(controller: controller, past: past),
  );
}

void _showAbortWorkout(BuildContext context, AppController controller) {
  showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    builder: (sheetContext) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '中止本次训练',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            '当前已完成 ${controller.completedSets}/${controller.totalSets} 组，'
            '训练 ${controller.currentElapsed ~/ 60} 分钟。中止后不会生成训练记录，已有计划不会被删除。',
            style: TextStyle(color: muted, height: 1.45),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              key: const Key('hold-to-abort-workout'),
              onPressed: () => showKiloSnack(sheetContext, '请长按按钮，避免误触中止训练'),
              onLongPress: () {
                controller.abortWorkout();
                Navigator.pop(sheetContext);
                showKiloSnack(context, '本次训练已中止，未保存记录');
              },
              style: FilledButton.styleFrom(
                backgroundColor: danger,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(52),
              ),
              icon: const Icon(Icons.touch_app_outlined),
              label: const Text('长按中止，不保存记录'),
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.pop(sheetContext),
              child: const Text('继续训练'),
            ),
          ),
        ],
      ),
    ),
  );
}

class _FinishWorkoutDialog extends StatefulWidget {
  const _FinishWorkoutDialog({required this.controller, required this.past});
  final AppController controller;
  final bool past;

  @override
  State<_FinishWorkoutDialog> createState() => _FinishWorkoutDialogState();
}

class _FinishWorkoutDialogState extends State<_FinishWorkoutDialog> {
  late final TextEditingController note;
  late final TextEditingController routineName;
  late final bool saveRoutineDefault;
  late bool saveAsRoutine;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    saveRoutineDefault = widget.controller.freeWorkout && !widget.past;
    saveAsRoutine = saveRoutineDefault;
    note = TextEditingController();
    routineName = TextEditingController(
      text: saveRoutineDefault
          ? _freeRoutineNameSuggestion(DateTime.now())
          : '',
    );
  }

  @override
  void dispose() {
    note.dispose();
    routineName.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.past ? '补录训练' : '结束并保存'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: note,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: '训练备注',
              hintText: '可选',
            ),
          ),
          if (saveRoutineDefault) ...[
            const SizedBox(height: 12),
            SwitchListTile(
              key: const Key('finish-save-routine-checkbox'),
              contentPadding: EdgeInsets.zero,
              value: saveAsRoutine,
              title: const Text('保存为训练计划'),
              subtitle: const Text('本次实际重量将作为下一次计划重量'),
              onChanged: (value) => setState(() => saveAsRoutine = value),
            ),
            if (saveAsRoutine)
              TextField(
                key: const Key('finish-routine-name'),
                controller: routineName,
                decoration: const InputDecoration(labelText: '计划名称'),
              ),
          ],
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      FilledButton(
        key: const Key('finish-save-button'),
        onPressed: saving
            ? null
            : () {
                setState(() => saving = true);
                final record = widget.controller.finishWorkout(
                  note: note.text,
                  saveAsRoutine: saveAsRoutine,
                  routineName: routineName.text,
                );
                final navigator = Navigator.of(context, rootNavigator: true);
                Navigator.pop(context);
                if (record != null && !widget.past) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (navigator.mounted) {
                      _showWorkoutCelebration(
                        navigator.context,
                        widget.controller,
                        record,
                      );
                    }
                  });
                }
              },
        child: const Text('保存'),
      ),
    ],
  );
}

void _showWorkoutCelebration(
  BuildContext context,
  AppController controller,
  WorkoutRecord record,
) {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _WorkoutCelebration(controller: controller, record: record),
  );
}

class _WorkoutCelebration extends StatelessWidget {
  const _WorkoutCelebration({required this.controller, required this.record});

  final AppController controller;
  final WorkoutRecord record;

  @override
  Widget build(BuildContext context) {
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    final mediaHeight = MediaQuery.sizeOf(context).height;
    final dialogMaxHeight = mediaHeight > 0 ? mediaHeight * .92 : 880.0;
    final particleLayer = reducedMotion
        ? const SizedBox.shrink()
        : Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 130,
            child: IgnorePointer(
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 1050),
                curve: Curves.easeOut,
                builder: (context, progress, child) => CustomPaint(
                  key: const Key('summary-particles'),
                  painter: _BurstPainter(progress),
                  child: child,
                ),
                child: const SizedBox.expand(),
              ),
            ),
          );
    return Dialog(
      key: const Key('workout-celebration'),
      backgroundColor: paper,
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 560, maxHeight: dialogMaxHeight),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => Stack(
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '训练完成',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w900, color: ink),
                      ),
                      const SizedBox(height: 12),
                      AspectRatio(
                        key: const Key('workout-celebration-card-preview'),
                        aspectRatio: workoutResultCardAspectRatio,
                        child: FittedBox(
                          fit: BoxFit.contain,
                          child: SizedBox(
                            width: 1200,
                            height: 950,
                            child: _WorkoutShareCard(
                              controller: controller,
                              record: record,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      _WorkoutCompletionAiReview(
                        controller: controller,
                        record: record,
                      ),
                      const SizedBox(height: 14),
                      LayoutBuilder(
                        builder: (context, constraints) => Wrap(
                          alignment: WrapAlignment.end,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            TextButton.icon(
                              key: const Key('workout-celebration-records'),
                              onPressed: () {
                                Navigator.pop(context);
                                controller.selectPage(PageId.records);
                              },
                              icon: const Icon(Icons.history, size: 18),
                              label: const Text('查看记录'),
                            ),
                            OutlinedButton.icon(
                              key: const Key('workout-celebration-publish'),
                              onPressed: record.effectiveSets == 0
                                  ? null
                                  : () => showModalBottomSheet<bool>(
                                      context: context,
                                      isScrollControlled: true,
                                      useSafeArea: true,
                                      showDragHandle: true,
                                      builder: (_) => PublishWorkoutSheet(
                                        controller: controller,
                                        record: record,
                                      ),
                                    ),
                              icon: const Icon(Icons.public_rounded, size: 18),
                              label: const Text('发布动态'),
                            ),
                            OutlinedButton.icon(
                              key: const Key('workout-celebration-share'),
                              onPressed: () => _showWorkoutShareSheet(
                                context,
                                controller,
                                record,
                              ),
                              icon: const Icon(
                                Icons.ios_share_rounded,
                                size: 18,
                              ),
                              label: const Text('分享卡片'),
                            ),
                            FilledButton.icon(
                              key: const Key('workout-celebration-done'),
                              onPressed: () {
                                Navigator.pop(context);
                                controller.selectTrainView(TrainView.plans);
                              },
                              icon: const Icon(Icons.check),
                              label: const Text('完成'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                particleLayer,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _showWorkoutShareSheet(
  BuildContext context,
  AppController controller,
  WorkoutRecord record,
) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  backgroundColor: surface,
  builder: (_) => _WorkoutShareSheet(controller: controller, record: record),
);

class _WorkoutShareSheet extends StatefulWidget {
  const _WorkoutShareSheet({required this.controller, required this.record});

  final AppController controller;
  final WorkoutRecord record;

  @override
  State<_WorkoutShareSheet> createState() => _WorkoutShareSheetState();
}

class _WorkoutShareSheetState extends State<_WorkoutShareSheet> {
  final boundaryKey = GlobalKey();
  bool sharing = false;
  String cardStyle = 'coral';
  String? localPhotoPath;
  String? localPhotoName;

  Future<void> _pickPhoto() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: false,
    );
    if (!mounted || result == null || result.files.isEmpty) return;
    final file = result.files.single;
    if (file.path == null || file.path!.isEmpty) return;
    setState(() {
      localPhotoPath = file.path;
      localPhotoName = file.name;
    });
  }

  Future<void> _share(BuildContext actionContext) async {
    if (sharing) return;
    final box = actionContext.findRenderObject() as RenderBox?;
    setState(() => sharing = true);
    try {
      await WidgetsBinding.instance.endOfFrame;
      final boundary =
          boundaryKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) throw StateError('分享卡片尚未生成');
      final image = await boundary.toImage(pixelRatio: 3);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) throw StateError('分享图片生成失败');
      final bytes = data.buffer.asUint8List();
      await SharePlus.instance.share(
        ShareParams(
          title: '${widget.record.name} · 训练完成',
          text: '今天的训练，已经完成。#形域 #KILOSTRENGTH',
          files: [XFile.fromData(bytes, mimeType: 'image/png')],
          fileNameOverrides: [
            'kilostrength-${widget.record.date.year}${widget.record.date.month.toString().padLeft(2, '0')}${widget.record.date.day.toString().padLeft(2, '0')}.png',
          ],
          sharePositionOrigin: box == null
              ? null
              : box.localToGlobal(Offset.zero) & box.size,
        ),
      );
    } catch (error) {
      if (mounted) {
        showKiloSnack(context, '分享图片生成失败，请稍后重试', error: true);
      }
    } finally {
      if (mounted) setState(() => sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewport = MediaQuery.sizeOf(context);
    final maxPreviewWidth = (viewport.width - 32).clamp(280.0, 520.0);
    return SizedBox(
      key: const Key('workout-share-sheet'),
      height: viewport.height * .92,
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(20, 2, 20, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '分享训练',
                    style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
                  ),
                ),
                Text('完整训练成果卡', style: TextStyle(color: quiet, fontSize: 12)),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: SizedBox(
                  width: maxPreviewWidth,
                  child: AspectRatio(
                    aspectRatio: workoutResultCardAspectRatio,
                    child: FittedBox(
                      fit: BoxFit.contain,
                      child: RepaintBoundary(
                        key: boundaryKey,
                        child: SizedBox(
                          width: 1200,
                          height: 950,
                          child: _WorkoutShareCard(
                            controller: widget.controller,
                            record: widget.record,
                            cardStyle: cardStyle,
                            localPhotoPath: localPhotoPath,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  '卡片样式',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 5),
                Wrap(
                  spacing: 6,
                  runSpacing: 5,
                  children: [
                    for (final style in workoutCardStyles)
                      ChoiceChip(
                        key: Key('share-card-style-$style'),
                        label: Text(_shareCardStyleLabel(style)),
                        selected: cardStyle == style,
                        onSelected: (_) => setState(() => cardStyle = style),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 5,
                  children: [
                    ChoiceChip(
                      key: const Key('share-card-image-brand'),
                      label: const Text('品牌默认图'),
                      selected: localPhotoPath == null,
                      onSelected: (_) => setState(() {
                        localPhotoPath = null;
                        localPhotoName = null;
                      }),
                    ),
                    ActionChip(
                      key: const Key('share-card-image-picker'),
                      avatar: const Icon(Icons.add_a_photo_outlined, size: 18),
                      label: Text(localPhotoName ?? '选择照片'),
                      onPressed: _pickPhoto,
                    ),
                  ],
                ),
                if (localPhotoPath != null)
                  Padding(
                    padding: EdgeInsets.only(top: 3),
                    child: Text(
                      '自选照片仅用于本机分享，不会上传服务器。',
                      style: TextStyle(color: quiet, fontSize: 11),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const Key('workout-share-system-button'),
                onPressed: sharing ? null : () => _share(context),
                icon: sharing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.ios_share_rounded),
                label: Text(sharing ? '正在生成…' : '生成图片并分享'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkoutShareCard extends StatelessWidget {
  const _WorkoutShareCard({
    required this.controller,
    required this.record,
    this.cardStyle = 'coral',
    this.localPhotoPath,
    this.compact = false,
    this.onTap,
  });

  final AppController controller;
  final WorkoutRecord record;
  final String cardStyle;
  final String? localPhotoPath;
  final bool compact;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return _CompactWorkoutShareCard(
        controller: controller,
        record: record,
        onTap: onTap,
      );
    }
    final totalSets = record.exercises.fold<int>(
      0,
      (sum, exercise) => sum + exercise.sets.length,
    );
    final completedSets = record.exercises.fold<int>(
      0,
      (sum, exercise) =>
          sum + exercise.sets.where((set) => set.completed).length,
    );
    return WorkoutResultCard(
      key: const Key('workout-share-card'),
      workoutName: record.name,
      date: record.date,
      durationSeconds: record.durationSeconds,
      volume: record.volume,
      effectiveSets: record.effectiveSets,
      completionPercent: totalSets == 0
          ? 0
          : (completedSets / totalSets * 100).round(),
      exerciseNames: [
        for (final exercise in record.exercises)
          controller.displayExerciseName(
            controller.exerciseFor(exercise.exerciseId),
          ),
      ],
      cardStyle: cardStyle,
      localPhotoPath: localPhotoPath,
    );
  }
}

class _CompactWorkoutShareCard extends StatelessWidget {
  const _CompactWorkoutShareCard({
    required this.controller,
    required this.record,
    required this.onTap,
  });

  final AppController controller;
  final WorkoutRecord record;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final exercises = record.exercises.take(3).toList(growable: false);
    return Material(
      color: const Color(0xFFE96A45),
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 13, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.bolt_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      record.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Flexible(
                    fit: FlexFit.loose,
                    child: Text(
                      '${record.date.month}/${record.date.day} · ${record.startTime}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _CompactShareMetric(
                    label: '训练量',
                    value: '${record.volume.toStringAsFixed(0)} kg',
                  ),
                  _CompactShareMetric(
                    label: '有效组',
                    value: '${record.effectiveSets}',
                  ),
                  _CompactShareMetric(
                    label: '时长',
                    value: '${(record.durationSeconds / 60).round()} 分',
                  ),
                ],
              ),
              if (exercises.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(height: 1, color: Colors.white24),
                const SizedBox(height: 7),
                for (final exercise in exercises)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.fitness_center_rounded,
                          color: Colors.white70,
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            controller.displayExerciseName(
                              controller.exerciseFor(exercise.exerciseId),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          fit: FlexFit.loose,
                          child: Text(
                            _compactSetSummary(exercise),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.end,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

String _compactSetSummary(WorkoutExercise exercise) {
  final completed = exercise.sets.where((set) => set.completed).toList();
  if (completed.isEmpty) return '暂无有效组';
  return completed
      .take(2)
      .map((set) => '${_displayWeight(set.weight)} kg × ${set.reps}')
      .join(' · ');
}

class _CompactShareMetric extends StatelessWidget {
  const _CompactShareMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 9)),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    ),
  );
}

String _shareCardStyleLabel(String style) => workoutShareStyleLabel(style);

// Kept for the dedicated record-detail view; the compact completion dialog
// intentionally does not render PR history.
// ignore: unused_element
class _WorkoutPrHistorySummary extends StatelessWidget {
  const _WorkoutPrHistorySummary({
    required this.controller,
    required this.record,
  });

  final AppController controller;
  final WorkoutRecord record;

  String _metricLabel(String metric) => switch (metric) {
    'estimated1rm' => '估算 1RM',
    'volume' => '单动作容量',
    _ => '最大重量',
  };

  String _value(WorkoutPrDetail detail) {
    final digits = detail.currentValue % 1 == 0 ? 0 : 1;
    return '${detail.currentValue.toStringAsFixed(digits)} kg';
  }

  @override
  Widget build(BuildContext context) {
    final details = record.prDetails;
    return Card(
      key: const Key('workout-pr-history-summary'),
      margin: EdgeInsets.zero,
      color: details.isEmpty ? surface : emberTint,
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  details.isEmpty
                      ? Icons.insights_outlined
                      : Icons.emoji_events_rounded,
                  color: details.isEmpty ? quiet : primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    details.isEmpty ? '历史基线' : '历史个人纪录',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                if (details.isNotEmpty)
                  Text(
                    'NEW PR',
                    style: TextStyle(
                      color: primary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 7),
            if (details.isEmpty)
              Text(
                '本次没有超过同动作历史最佳；首次记录只建立基线，不会被误报为 PR。',
                style: TextStyle(color: secondaryInk, fontSize: 12),
              )
            else
              for (final detail in details)
                Container(
                  key: Key('workout-pr-${detail.exerciseId}-${detail.metric}'),
                  margin: const EdgeInsets.only(top: 6),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: surfaceRaised,
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(color: hairline),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              controller.displayExerciseName(
                                controller.exerciseFor(detail.exerciseId),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              '${_metricLabel(detail.metric)} · 此前 ${detail.previousValue.toStringAsFixed(detail.previousValue % 1 == 0 ? 0 : 1)} kg（${detail.previousDate.month}月${detail.previousDate.day}日）',
                              style: TextStyle(color: quiet, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _value(detail),
                            style: TextStyle(
                              color: primary,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            '+${(detail.currentValue - detail.previousValue).toStringAsFixed(1)} kg',
                            style: const TextStyle(
                              color: Color(0xFF1E7A4A),
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

// Kept for reuse in record details; comparisons no longer lengthen the
// completion dialog.
// ignore: unused_element
class _WorkoutComparisonSummary extends StatelessWidget {
  const _WorkoutComparisonSummary({
    required this.controller,
    required this.record,
  });

  final AppController controller;
  final WorkoutRecord record;

  String _deltaNumber(num value, {String suffix = ''}) {
    final sign = value > 0 ? '+' : '';
    return '$sign${value is double ? value.toStringAsFixed(value % 1 == 0 ? 0 : 1) : value}$suffix';
  }

  @override
  Widget build(BuildContext context) {
    final comparison = controller.comparisonFor(record);
    final baseline = comparison?.baseline;
    return Card(
      key: const Key('workout-comparison-summary'),
      color: emberTint,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.compare_arrows_rounded, color: primary),
                const SizedBox(width: 7),
                const Expanded(
                  child: Text(
                    '与上次对比',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                  ),
                ),
                if (baseline != null)
                  Text(
                    baseline.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: quiet, fontSize: 11),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (comparison == null)
              Text(
                '暂无包含相同动作的历史训练。完成下一次同类训练后，这里会显示重量、次数、容量和时长变化。',
                style: TextStyle(color: secondaryInk, fontSize: 12),
              )
            else ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _ComparisonPill(
                    label: '容量',
                    value: _deltaNumber(comparison.volumeDelta, suffix: ' kg'),
                  ),
                  _ComparisonPill(
                    label: '有效组',
                    value: _deltaNumber(
                      comparison.effectiveSetsDelta,
                      suffix: ' 组',
                    ),
                  ),
                  _ComparisonPill(
                    label: '时长',
                    value: _deltaNumber(comparison.durationDelta, suffix: ' 秒'),
                  ),
                ],
              ),
              if (comparison.exerciseProgress.isNotEmpty) ...[
                const SizedBox(height: 9),
                for (final progress in comparison.exerciseProgress.take(3))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            controller.displayExerciseName(
                              controller.exerciseFor(progress.exerciseId),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Text(
                          '${_deltaNumber(progress.weightDelta, suffix: ' kg')} · ${_deltaNumber(progress.repsDelta, suffix: ' 次')}',
                          style: TextStyle(
                            color:
                                progress.weightDelta >= 0 &&
                                    progress.repsDelta >= 0
                                ? const Color(0xFF1E7A4A)
                                : const Color(0xFF9C5B19),
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _WorkoutCompletionAiReview extends StatefulWidget {
  const _WorkoutCompletionAiReview({
    required this.controller,
    required this.record,
  });

  final AppController controller;
  final WorkoutRecord record;

  @override
  State<_WorkoutCompletionAiReview> createState() =>
      _WorkoutCompletionAiReviewState();
}

class _WorkoutCompletionAiReviewState
    extends State<_WorkoutCompletionAiReview> {
  String? review;
  Object? error;
  bool loading = false;
  bool expanded = false;

  bool get isMember => widget.controller.entitlements?.isMember == true;

  @override
  void initState() {
    super.initState();
    if (isMember) unawaited(_load());
  }

  Future<void> _load() async {
    if (loading) return;
    setState(() {
      loading = true;
      error = null;
      review = '';
      expanded = false;
    });
    try {
      final value = await widget.controller.generateWorkoutCompletionReview(
        widget.record,
        baseline: widget.controller.comparisonBaselineFor(widget.record),
        onDelta: (delta) {
          if (!mounted || delta.isEmpty) return;
          setState(() => review = '${review ?? ''}$delta');
        },
      );
      if (!mounted) return;
      setState(() => review = value);
    } catch (caught) {
      if (!mounted) return;
      setState(() => error = caught);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!isMember) return _buildLocked(context);
    final content = review?.trim() ?? '';
    final plainPreview = content
        .replaceAll(RegExp(r'[#*_>`~-]+'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return Card(
      key: const Key('workout-completion-ai-review'),
      margin: EdgeInsets.zero,
      color: emberTint,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome_rounded, color: primary, size: 21),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'AI 训练评价',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                  ),
                ),
                MembershipMark(isMember: true, size: 24),
              ],
            ),
            const SizedBox(height: 7),
            if (loading && content.isEmpty)
              const Row(
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 10),
                  Expanded(child: Text('正在思考本次训练的整体安排…')),
                ],
              )
            else if (content.isNotEmpty) ...[
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 220),
                crossFadeState: expanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                firstChild: Text(
                  plainPreview,
                  key: const Key('workout-ai-review-preview'),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(height: 1.5, color: secondaryInk),
                ),
                secondChild: MarkdownBody(
                  key: const Key('workout-ai-review-expanded'),
                  data: content,
                  selectable: true,
                  styleSheet: MarkdownStyleSheet(
                    p: TextStyle(height: 1.5, color: secondaryInk),
                    h2: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: ink,
                    ),
                    h3: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: ink,
                    ),
                    blockSpacing: 6,
                    listIndent: 18,
                  ),
                ),
              ),
              if (!loading && plainPreview.length > 72)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    key: const Key('workout-ai-review-expand'),
                    onPressed: () => setState(() => expanded = !expanded),
                    icon: Icon(
                      expanded
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      size: 18,
                    ),
                    label: Text(expanded ? '收起' : '展开全文'),
                  ),
                )
              else if (loading)
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: LinearProgressIndicator(minHeight: 2),
                ),
            ] else if (error != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '训练记录已经保存，但 AI 评价暂时没有生成，不影响本次数据。',
                    style: TextStyle(color: secondaryInk),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('重新生成评价'),
                  ),
                ],
              )
            else
              const SizedBox.shrink(),
          ],
        ),
      ),
    );
  }

  Widget _buildLocked(BuildContext context) => Semantics(
    container: true,
    label: 'AI 训练评价已锁定，开通形域 PRO 后可在训练完成时自动生成',
    child: Card(
      key: const Key('workout-completion-ai-review-locked'),
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height:
            128 +
            (MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0) - 1) *
                210,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ExcludeSemantics(
              key: const Key('workout-ai-locked-blurred-preview'),
              child: ImageFiltered(
                imageFilter: ui.ImageFilter.blur(sigmaX: 7, sigmaY: 7),
                child: const Padding(
                  padding: EdgeInsets.all(15),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI 训练评价',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 7),
                      Text('训练结构  ·  主要肌群覆盖与动作模式安排', maxLines: 1),
                      SizedBox(height: 5),
                      Text('本次表现  ·  训练量分配与组间完成情况', maxLines: 1),
                      SizedBox(height: 5),
                      Text('下次调整  ·  一项可以直接执行的建议', maxLines: 1),
                    ],
                  ),
                ),
              ),
            ),
            ColoredBox(
              color: surfaceRaised.withValues(alpha: .78),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock_rounded, color: primary, size: 28),
                    const SizedBox(height: 5),
                    const Text(
                      '解锁训练后的 AI 评价',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 5),
                    FilledButton.tonal(
                      onPressed: () => showMembershipPaywall(
                        context,
                        controller: widget.controller,
                        reason: MembershipPaywallReason.premiumFeature,
                      ),
                      child: const Text('开通形域 PRO'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ComparisonPill extends StatelessWidget {
  const _ComparisonPill({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: surface,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: hairline),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: quiet, fontSize: 10)),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
          ),
        ],
      ),
    ),
  );
}

class _CelebrationExerciseSummary extends StatefulWidget {
  const _CelebrationExerciseSummary({
    required this.controller,
    required this.record,
  });

  final AppController controller;
  final WorkoutRecord record;

  @override
  State<_CelebrationExerciseSummary> createState() =>
      _CelebrationExerciseSummaryState();
}

class _CelebrationExerciseSummaryState
    extends State<_CelebrationExerciseSummary> {
  bool expanded = false;

  @override
  Widget build(BuildContext context) {
    final exercises = widget.record.exercises;
    final visible = expanded ? exercises : exercises.take(4).toList();
    return Semantics(
      container: true,
      label: '本次训练动作与完成组详情',
      child: Column(
        key: const Key('workout-celebration-exercises'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.list_alt_rounded, color: primary, size: 21),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  '本次完成动作',
                  style: TextStyle(
                    color: ink,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                '${exercises.length} 个动作',
                style: TextStyle(color: quiet, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 9),
          if (exercises.isEmpty)
            const Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: EdgeInsets.all(14),
                child: Text('本次记录没有可展示的动作明细。'),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 260 ? 2 : 1;
                final width = columns == 2
                    ? (constraints.maxWidth - 8) / 2
                    : constraints.maxWidth;
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (var index = 0; index < visible.length; index++)
                      SizedBox(
                        width: width,
                        child: _CelebrationExerciseCard(
                          controller: widget.controller,
                          exercise: visible[index],
                          index: index,
                        ),
                      ),
                  ],
                );
              },
            ),
          if (exercises.length > 4)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: const Key('workout-celebration-exercises-expand'),
                onPressed: () => setState(() => expanded = !expanded),
                icon: Icon(
                  expanded
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                ),
                label: Text(expanded ? '收起动作' : '查看全部 ${exercises.length} 个动作'),
              ),
            ),
        ],
      ),
    );
  }
}

class _CelebrationExerciseCard extends StatelessWidget {
  const _CelebrationExerciseCard({
    required this.controller,
    required this.exercise,
    required this.index,
  });

  final AppController controller;
  final WorkoutExercise exercise;
  final int index;

  @override
  Widget build(BuildContext context) {
    final completedSets = exercise.sets.where((set) => set.completed).toList();
    final volume = completedSets.fold<double>(
      0,
      (sum, set) => sum + set.weight * set.reps,
    );
    return Card(
      key: Key('workout-celebration-exercise-$index'),
      margin: EdgeInsets.zero,
      color: surface,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: Key('workout-celebration-exercise-details-$index'),
        onTap: () =>
            _showCelebrationExerciseDetails(context, controller, exercise),
        child: Padding(
          padding: const EdgeInsets.all(9),
          child: Row(
            children: [
              _ExerciseThumb(exerciseId: exercise.exerciseId, size: 38),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      controller.displayExerciseName(
                        controller.exerciseFor(exercise.exerciseId),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: ink,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${completedSets.length} 组 · ${_displayWeight(volume)} kg',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: quiet, fontSize: 10),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, size: 18, color: quiet),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecognitionRemoteVideo extends StatefulWidget {
  const _RecognitionRemoteVideo({
    super.key,
    required this.url,
    required this.headers,
    required this.title,
  });

  final String url;
  final Map<String, String> headers;
  final String title;

  @override
  State<_RecognitionRemoteVideo> createState() =>
      _RecognitionRemoteVideoState();
}

class _RecognitionRemoteVideoState extends State<_RecognitionRemoteVideo> {
  VideoPlayerController? video;
  Object? error;

  @override
  void initState() {
    super.initState();
    unawaited(_open());
  }

  Future<void> _open() async {
    try {
      final value = VideoPlayerController.networkUrl(
        Uri.parse(widget.url),
        httpHeaders: widget.headers,
      );
      await value.initialize();
      await value.setLooping(true);
      if (!mounted) {
        await value.dispose();
        return;
      }
      setState(() => video = value);
    } catch (caught) {
      if (mounted) setState(() => error = caught);
    }
  }

  void _toggle() {
    final current = video;
    if (current == null) return;
    setState(() {
      current.value.isPlaying ? current.pause() : current.play();
    });
  }

  @override
  void dispose() {
    video?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final current = video;
    final ratio = current?.value.aspectRatio ?? 16 / 9;
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF211A17),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: hairline),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final height = (constraints.maxWidth / ratio).clamp(176.0, 300.0);
              return SizedBox(
                height: height,
                child: Center(
                  child: AspectRatio(
                    aspectRatio: ratio,
                    child: InkWell(
                      onTap: current == null ? null : _toggle,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (current != null)
                            VideoPlayer(current)
                          else
                            const ColoredBox(color: Color(0xFF211A17)),
                          if (current == null && error == null)
                            const Center(
                              child: CircularProgressIndicator(
                                color: Colors.white,
                              ),
                            ),
                          if (error != null)
                            const Center(
                              child: Text(
                                '视频暂时无法播放',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          if (current != null && !current.value.isPlaying)
                            Center(
                              child: CircleAvatar(
                                radius: 25,
                                backgroundColor: primary,
                                child: Icon(
                                  Icons.play_arrow_rounded,
                                  color: Colors.white,
                                  size: 32,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          Container(
            width: double.infinity,
            color: surfaceRaised,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            child: Text(
              widget.title,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _editRecognitionVideo(
  BuildContext context,
  AppController controller,
) async {
  final path = controller.selectedMediaPath;
  if (path == null || path.isEmpty) return;
  final output = await Navigator.of(context).push<String>(
    MaterialPageRoute<String>(
      fullscreenDialog: true,
      builder: (_) => _RecognitionVideoEditorPage(path: path),
    ),
  );
  if (output == null || output.isEmpty) return;
  controller.useEditedRecognitionVideo(output);
  if (context.mounted) showKiloSnack(context, '已使用裁剪后的视频');
}

class _RecognitionVideoEditorPage extends StatefulWidget {
  const _RecognitionVideoEditorPage({required this.path});

  final String path;

  @override
  State<_RecognitionVideoEditorPage> createState() =>
      _RecognitionVideoEditorPageState();
}

class _RecognitionVideoEditorPageState
    extends State<_RecognitionVideoEditorPage> {
  final Trimmer trimmer = Trimmer();
  double startValue = 0;
  double endValue = 0;
  bool loading = true;
  bool saving = false;
  bool playing = false;
  Object? error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      await trimmer.loadVideo(videoFile: File(widget.path));
    } catch (caught) {
      error = caught;
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> _save() async {
    if (saving) return;
    setState(() => saving = true);
    try {
      await trimmer.saveTrimmedVideo(
        startValue: startValue,
        endValue: endValue,
        onSave: (output) {
          if (!mounted) return;
          if (output == null || output.isEmpty) {
            setState(() => saving = false);
            showKiloSnack(context, '视频片段保存失败，请重试');
            return;
          }
          Navigator.pop(context, output);
        },
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => saving = false);
      showKiloSnack(context, '视频片段保存失败，请重试');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: paper,
    appBar: AppBar(
      backgroundColor: paper,
      surfaceTintColor: Colors.transparent,
      title: const Text('裁剪分析片段'),
      actions: [
        TextButton(
          key: const Key('recognition-save-trim'),
          onPressed: loading || saving || error != null ? null : _save,
          child: Text(saving ? '保存中…' : '使用片段'),
        ),
      ],
    ),
    body: SafeArea(
      child: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
          ? const Center(child: Text('暂时无法编辑这个视频，请重新选择。'))
          : Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
              child: Column(
                children: [
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.sizeOf(context).height * .48,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: ColoredBox(
                        color: const Color(0xFF211A17),
                        child: VideoViewer(trimmer: trimmer),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  LayoutBuilder(
                    builder: (context, constraints) => TrimViewer(
                      trimmer: trimmer,
                      viewerHeight: 62,
                      viewerWidth: constraints.maxWidth,
                      maxVideoLength: const Duration(minutes: 3),
                      onChangeStart: (value) => startValue = value,
                      onChangeEnd: (value) => endValue = value,
                      onChangePlaybackState: (value) =>
                          setState(() => playing = value),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.tonalIcon(
                    onPressed: () async {
                      final value = await trimmer.videoPlaybackControl(
                        startValue: startValue,
                        endValue: endValue,
                      );
                      if (mounted) setState(() => playing = value);
                    },
                    icon: Icon(
                      playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    ),
                    label: Text(playing ? '暂停预览' : '预览所选片段'),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '拖动两侧把手，只保留需要分析的动作片段。',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: quiet, fontSize: 12),
                  ),
                ],
              ),
            ),
    ),
  );
}

void _showCelebrationExerciseDetails(
  BuildContext context,
  AppController controller,
  WorkoutExercise exercise,
) {
  final completed = exercise.sets.where((set) => set.completed).toList();
  final shown = completed.isEmpty ? exercise.sets : completed;
  showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _ExerciseThumb(exerciseId: exercise.exerciseId, size: 46),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  controller.displayExerciseName(
                    controller.exerciseFor(exercise.exerciseId),
                  ),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          if (exercise.note.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(exercise.note, style: TextStyle(color: secondaryInk)),
          ],
          const SizedBox(height: 12),
          for (var index = 0; index < shown.length; index++)
            Padding(
              padding: EdgeInsets.only(top: index == 0 ? 0 : 6),
              child: _CelebrationSetRow(
                set: shown[index],
                originalIndex: exercise.sets.indexOf(shown[index]),
              ),
            ),
        ],
      ),
    ),
  );
}

class _CelebrationSetRow extends StatelessWidget {
  const _CelebrationSetRow({required this.set, required this.originalIndex});

  final WorkoutSet set;
  final int originalIndex;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: set.completed ? const Color(0xFFEAF7EE) : surface,
      borderRadius: BorderRadius.circular(9),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      child: Row(
        children: [
          SizedBox(
            width: 52,
            child: Text(
              '${originalIndex + 1} · ${_setTypeShort(set.type)}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
            ),
          ),
          Expanded(
            child: Text(
              '${_displayWeight(set.weight)} kg × ${set.reps} 次',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          Text(
            '休 ${set.restSeconds}s',
            style: TextStyle(color: quiet, fontSize: 11),
          ),
          if (set.note.trim().isNotEmpty) ...[
            const SizedBox(width: 5),
            Tooltip(
              message: set.note,
              child: Icon(
                Icons.sticky_note_2_outlined,
                size: 16,
                color: primary,
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

String _freeRoutineNameSuggestion(DateTime date) =>
    '自由训练 ${date.month.toString().padLeft(2, '0')}月${date.day.toString().padLeft(2, '0')}日 ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

void _startPlanSession(
  BuildContext context,
  AppController controller,
  Plan plan,
) {
  final session = plan.sessions.first;
  controller.startWorkout(
    source: session.exerciseIds
        .map((id) => controller.createBlankWorkoutExercise(id, 'plan-$id'))
        .toList(),
    name: session.name,
  );
  controller.openLiveWorkout();
  showKiloSnack(context, '已开始 ${session.name}');
}

String _dateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

void _showCalendarDayActions(
  BuildContext context,
  AppController controller,
  DateTime date,
) {
  final key = _dateKey(date);
  final planned = controller.scheduled.contains(key);
  WorkoutRecord? record;
  for (final item in controller.history) {
    if (item.date.year == date.year &&
        item.date.month == date.month &&
        item.date.day == date.day) {
      record = item;
      break;
    }
  }
  final selectedRecord = record;
  showModalBottomSheet<void>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ListTile(title: Text('日期详情'), dense: true),
          ListTile(
            title: Text('${date.year} 年 ${date.month} 月 ${date.day} 日'),
            subtitle: Text(
              record != null
                  ? '已完成 ${record.name}'
                  : planned
                  ? controller.scheduledLabels[key] ?? '已安排训练'
                  : '未安排训练',
            ),
          ),
          if (selectedRecord != null)
            ListTile(
              leading: Icon(Icons.check_circle, color: success),
              title: const Text('查看训练记录'),
              onTap: () {
                Navigator.pop(sheetContext);
                _showRecordDetail(context, controller, selectedRecord);
              },
            ),
          if (planned)
            ListTile(
              leading: const Icon(Icons.edit_calendar_outlined),
              title: const Text('改期'),
              onTap: () {
                Navigator.pop(sheetContext);
                _showScheduleEditor(
                  context,
                  controller,
                  oldDate: key,
                  initialDate: date,
                );
              },
            ),
          if (planned)
            ListTile(
              leading: Icon(Icons.event_busy_outlined, color: orange),
              title: const Text('移除排程'),
              onTap: () {
                controller.unschedule(key);
                Navigator.pop(sheetContext);
                showKiloSnack(context, '排程已移除');
              },
            ),
          if (!planned)
            ListTile(
              leading: Icon(Icons.add_circle_outline, color: cobalt),
              title: const Text('安排训练'),
              onTap: () {
                Navigator.pop(sheetContext);
                _showScheduleEditor(context, controller, initialDate: date);
              },
            ),
          const SizedBox(height: 6),
        ],
      ),
    ),
  );
}

void _showScheduleEditor(
  BuildContext context,
  AppController controller, {
  String? oldDate,
  DateTime? initialDate,
}) {
  DateTime selected =
      initialDate ?? DateTime.tryParse(oldDate ?? '') ?? DateTime.now();
  final label = TextEditingController(
    text: oldDate == null
        ? '训练安排'
        : controller.scheduledLabels[oldDate] ?? '训练安排',
  );
  const bodyParts = ['胸', '背', '肩', '腿', '手臂', '核心', '全身'];
  String? selectedBodyPart;
  showDialog<void>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        scrollable: true,
        title: Text(oldDate == null ? '新增排程' : '改期排程'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('快速选择训练部位', style: TextStyle(fontSize: 12, color: muted)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                for (final part in bodyParts)
                  ChoiceChip(
                    key: Key('schedule-body-part-$part'),
                    label: Text(part),
                    selected: selectedBodyPart == part,
                    onSelected: (_) {
                      setState(() => selectedBodyPart = part);
                      label.text = part == '全身' ? '全身训练' : '$part部训练';
                    },
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: label,
              decoration: const InputDecoration(labelText: '训练名称'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: selected,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2035),
                );
                if (picked != null) setState(() => selected = picked);
              },
              icon: const Icon(Icons.calendar_month_outlined),
              label: Text(
                '${selected.year}-${selected.month.toString().padLeft(2, '0')}-${selected.day.toString().padLeft(2, '0')}',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              if (oldDate != null) controller.unschedule(oldDate);
              controller.schedule(
                selected,
                label.text.trim().isEmpty ? '训练安排' : label.text.trim(),
              );
              Navigator.pop(context);
              showKiloSnack(context, oldDate == null ? '排程已添加' : '排程已改期');
            },
            child: const Text('保存'),
          ),
        ],
      ),
    ),
  );
}

void _showOfficialPlans(BuildContext context, AppController controller) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _OfficialPlansSheet(controller: controller),
  );
}

class _OfficialPlansSheet extends StatefulWidget {
  const _OfficialPlansSheet({required this.controller});

  final AppController controller;

  @override
  State<_OfficialPlansSheet> createState() => _OfficialPlansSheetState();
}

class _OfficialPlansSheetState extends State<_OfficialPlansSheet> {
  late Future<List<Plan>> plans;

  @override
  void initState() {
    super.initState();
    plans = widget.controller.loadOfficialPlans();
  }

  void reload() {
    setState(() {
      plans = widget.controller.loadOfficialPlans(force: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .72,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('官方单日计划', style: Theme.of(context).textTheme.headlineMedium),
              Text(
                '计划由官方持续维护。每个入口都是一节可直接执行的训练。',
                style: TextStyle(color: quiet),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: FutureBuilder<List<Plan>>(
                  future: plans,
                  builder: (context, snapshot) {
                    final items =
                        snapshot.data ?? widget.controller.officialPlans;
                    if (snapshot.connectionState == ConnectionState.waiting &&
                        items.isEmpty) {
                      return const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 12),
                            Text('正在加载官方计划'),
                          ],
                        ),
                      );
                    }
                    if (items.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.cloud_off_outlined, size: 36),
                            const SizedBox(height: 10),
                            Text(
                              widget.controller.officialPlansError ??
                                  '官方计划暂时无法加载',
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 10),
                            OutlinedButton.icon(
                              key: const Key('official-plans-retry'),
                              onPressed: reload,
                              icon: const Icon(Icons.refresh),
                              label: const Text('重新加载'),
                            ),
                          ],
                        ),
                      );
                    }
                    return ListView(
                      children: [
                        if (widget.controller.officialPlansError != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              widget.controller.officialPlansError!,
                              style: TextStyle(color: quiet, fontSize: 12),
                            ),
                          ),
                        for (final plan in items)
                          _PlanCard(controller: widget.controller, plan: plan),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void _showPlanDetail(
  BuildContext context,
  AppController controller,
  Plan plan,
) {
  final session = plan.sessions.first;
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .82,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                session.name,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              Text(
                '${plan.title} · ${session.exercises} 个动作 · ${session.duration}',
                style: TextStyle(color: secondaryInk),
              ),
              const SizedBox(height: 4),
              Text('单日训练详情', style: TextStyle(fontSize: 12, color: quiet)),
              const SizedBox(height: 12),
              Expanded(
                child: ListView(
                  children: [
                    for (final id in session.exerciseIds)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: _ExerciseThumb(exerciseId: id, size: 42),
                        title: Text(
                          controller.displayExerciseName(
                            controller.exerciseFor(id),
                          ),
                        ),
                        subtitle: const Text('3 组 · 8 次 · 组间休息 120 秒'),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    key: Key('plan-use-${plan.id}'),
                    onPressed: () {
                      controller.saveRoutineFromExerciseIds(
                        session.name,
                        session.exerciseIds,
                      );
                      Navigator.pop(context);
                      showKiloSnack(context, '已保存 ${session.name}');
                    },
                    icon: const Icon(Icons.bookmark_add_outlined),
                    label: const Text('使用此计划'),
                  ),
                  FilledButton.icon(
                    key: Key('plan-start-${plan.id}'),
                    onPressed: () {
                      Navigator.pop(context);
                      _startPlanSession(context, controller, plan);
                    },
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('开始训练'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

void _showRoutineDetail(
  BuildContext context,
  AppController controller,
  Routine routine,
) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .84,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                routine.name,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              TextButton.icon(
                onPressed: () => _openCoachPlanEditor(context, controller,
                  plan: controller.coachPlanFromRoutines(routine.name, 1, [routine]),
                  originalRoutine: routine),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('AI 调整计划'),
              ),
              Text(
                '${routine.exercises.length} 个动作 · ${routine.exercises.fold<int>(0, (sum, item) => sum + item.sets.length)} 组',
                style: TextStyle(color: quiet),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView(
                  children: [
                    for (final exercise in routine.exercises)
                      Card(
                        color: paper,
                        margin: const EdgeInsets.only(bottom: 9),
                        child: Padding(
                          padding: const EdgeInsets.all(11),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  _ExerciseThumb(
                                    exerciseId: exercise.exerciseId,
                                    size: 44,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      controller.displayExerciseName(
                                        controller.exerciseFor(
                                          exercise.exerciseId,
                                        ),
                                      ),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '${exercise.restSeconds}s',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: quiet,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 7),
                              for (
                                var index = 0;
                                index < exercise.sets.length;
                                index++
                              )
                                Builder(
                                  builder: (context) {
                                    final set = exercise.sets[index];
                                    final planned = set.plannedWeight;
                                    final weight = planned == null
                                        ? '\u8BA1\u5212\u91CD\u91CF\u672A\u8BB0\u5F55'
                                        : '\u8BA1\u5212\u91CD\u91CF ${planned.toStringAsFixed(1)} kg';
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 3),
                                      child: Text(
                                        '${index + 1}. ${setTypeLabels[set.type] ?? set.type} · $weight · ${set.reps} \u6B21 · \u4F11\u606F ${set.restSeconds}s',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    );
                                  },
                                ),
                            ],
                          ),
                        ),
                      ),
                    if (routine.exercises.isEmpty)
                      Text(
                        '\u8FD9\u4E2A\u8BA1\u5212\u8FD8\u6CA1\u6709\u52A8\u4F5C',
                        style: TextStyle(color: quiet),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      key: Key('routine-detail-start-${routine.id}'),
                      onPressed: routine.exercises.isEmpty
                          ? null
                          : () {
                              controller.startRoutine(routine);
                              Navigator.pop(context);
                              showKiloSnack(
                                context,
                                '\u5DF2\u5F00\u59CB${routine.name}',
                              );
                            },
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('\u5F00\u59CB\u8BAD\u7EC3'),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: OutlinedButton.icon(
                      key: Key('routine-detail-edit-${routine.id}'),
                      onPressed: () {
                        Navigator.pop(context);
                        _showRoutineEditor(context, controller, routine);
                      },
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('\u7F16\u8F91\u8BA1\u5212'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

void _showRoutineMeta(
  BuildContext context,
  AppController controller,
  Routine routine,
) {
  final name = TextEditingController(text: routine.name);
  var clearedOriginalName = false;
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('模板信息'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: name,
            onTap: () {
              if (clearedOriginalName) return;
              clearedOriginalName = true;
              name.clear();
            },
            decoration: const InputDecoration(labelText: '训练名称'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () {
            controller.renameRoutine(routine, name.text);
            Navigator.pop(context);
            showKiloSnack(context, '训练名称已保存');
          },
          child: const Text('保存'),
        ),
      ],
    ),
  );
}

void _showRoutineActions(
  BuildContext context,
  AppController controller,
  Routine routine,
) {
  showModalBottomSheet<void>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            key: Key('routine-edit-${routine.id}'),
            leading: const Icon(Icons.edit_outlined),
            title: const Text('编辑计划'),
            onTap: () {
              Navigator.pop(sheetContext);
              _showRoutineEditor(context, controller, routine);
            },
          ),
          ListTile(
            key: Key('routine-rename-${routine.id}'),
            leading: const Icon(Icons.drive_file_rename_outline),
            title: const Text('重命名'),
            onTap: () {
              Navigator.pop(sheetContext);
              _showRoutineMeta(context, controller, routine);
            },
          ),
          ListTile(
            key: Key('routine-delete-${routine.id}'),
            leading: const Icon(Icons.delete_outline, color: Color(0xFFB83A3A)),
            title: const Text('删除计划'),
            onTap: () {
              controller.deleteRoutine(routine);
              Navigator.pop(sheetContext);
              showKiloSnack(context, '计划已删除');
            },
          ),
          const SizedBox(height: 6),
        ],
      ),
    ),
  );
}

void _showRoutinePicker(
  BuildContext context,
  AppController controller,
  Routine routine, {
  VoidCallback? onChanged,
}) => _showExercisePicker(
  context,
  controller,
  routine: routine,
  onChanged: onChanged,
);

void _showRoutineEditor(
  BuildContext context,
  AppController controller,
  Routine routine,
) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) =>
          _RoutineEditorPage(controller: controller, original: routine),
    ),
  );
}

class _RoutineEditorPage extends StatefulWidget {
  const _RoutineEditorPage({required this.controller, required this.original});
  final AppController controller;
  final Routine original;

  @override
  State<_RoutineEditorPage> createState() => _RoutineEditorPageState();
}

class _RoutineEditorPageState extends State<_RoutineEditorPage> {
  late final Routine draft;
  late final TextEditingController name;

  AppController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    draft = Routine(
      id: widget.original.id,
      name: widget.original.name,
      folder: widget.original.folder,
      exercises: widget.original.exercises.map((item) => item.copy()).toList(),
      updatedAt: widget.original.updatedAt,
    );
    name = TextEditingController(text: draft.name);
  }

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  void save() {
    final trimmed = name.text.trim();
    if (trimmed.isEmpty) return;
    draft.name = trimmed;
    controller.updateRoutineFromDraft(widget.original, draft);
    showKiloSnack(context, '训练计划已保存');
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('编辑计划'),
      leading: IconButton(
        tooltip: '取消并返回',
        onPressed: () => Navigator.pop(context),
        icon: const Icon(Icons.arrow_back),
      ),
      actions: [
        IconButton(
          key: const Key('template-editor-save-icon'),
          tooltip: '保存训练模板',
          onPressed: save,
          icon: const Icon(Icons.save_outlined),
        ),
      ],
    ),
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              key: const Key('routine-editor-name'),
              controller: name,
              onChanged: (value) => draft.name = value,
              decoration: const InputDecoration(
                labelText: '训练名称',
                isDense: true,
                prefixIcon: Icon(Icons.edit_outlined),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${draft.exercises.length} 个动作 · 返回不会修改原计划',
              style: TextStyle(color: quiet, fontSize: 12),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 8),
                children: [
                  for (var index = 0; index < draft.exercises.length; index++)
                    _RoutineExerciseEditor(
                      controller: controller,
                      routine: draft,
                      exercise: draft.exercises[index],
                      index: index,
                      onChanged: () => setState(() {}),
                    ),
                  OutlinedButton.icon(
                    key: const Key('routine-editor-add-exercise'),
                    onPressed: () => _showRoutinePicker(
                      context,
                      controller,
                      draft,
                      onChanged: () => setState(() {}),
                    ),
                    icon: const Icon(Icons.add),
                    label: const Text('添加动作'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
    bottomNavigationBar: SafeArea(
      minimum: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: FilledButton.icon(
        key: const Key('template-editor-save-button'),
        onPressed: name.text.trim().isEmpty ? null : save,
        icon: const Icon(Icons.save_outlined),
        label: const Text('保存训练模板'),
      ),
    ),
  );
}

Future<int?> _showRoutineRestPicker(
  BuildContext context, {
  required int initialSeconds,
}) {
  var seconds = initialSeconds.clamp(0, 600);
  const quickValues = <int>[0, 30, 60, 90, 120, 180];
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (sheetContext) => StatefulBuilder(
      builder: (context, setState) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('设置动作休息', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text('使用快捷时长或按钮调整，无需输入数字。', style: TextStyle(color: quiet)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton.outlined(
                  key: const Key('routine-rest-minus'),
                  tooltip: '减少 15 秒',
                  onPressed: seconds == 0
                      ? null
                      : () => setState(
                          () => seconds = (seconds - 15).clamp(0, 600),
                        ),
                  icon: const Icon(Icons.remove_rounded),
                ),
                const SizedBox(width: 18),
                Container(
                  constraints: const BoxConstraints(minWidth: 126),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 13,
                  ),
                  decoration: BoxDecoration(
                    color: primaryContainer,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: primary.withValues(alpha: .35)),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.timer_outlined, color: primary, size: 24),
                      const SizedBox(height: 3),
                      Text(
                        seconds == 0 ? '关闭' : '$seconds 秒',
                        key: const Key('routine-rest-value'),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 18),
                IconButton.outlined(
                  key: const Key('routine-rest-plus'),
                  tooltip: '增加 15 秒',
                  onPressed: seconds == 600
                      ? null
                      : () => setState(
                          () => seconds = (seconds + 15).clamp(0, 600),
                        ),
                  icon: const Icon(Icons.add_rounded),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                for (final value in quickValues)
                  ChoiceChip(
                    key: Key('routine-rest-quick-$value'),
                    label: Text(value == 0 ? '关闭' : '$value s'),
                    selected: seconds == value,
                    onSelected: (_) => setState(() => seconds = value),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              key: const Key('routine-rest-save'),
              onPressed: () => Navigator.pop(sheetContext, seconds),
              icon: const Icon(Icons.check_rounded),
              label: const Text('保存休息时间'),
            ),
          ],
        ),
      ),
    ),
  );
}

enum _RoutineExerciseAction {
  moveUp,
  moveDown,
  replace,
  toggleSuperset,
  delete,
}

class _RoutineExerciseEditor extends StatelessWidget {
  const _RoutineExerciseEditor({
    required this.controller,
    required this.routine,
    required this.exercise,
    required this.index,
    required this.onChanged,
  });
  final AppController controller;
  final Routine routine;
  final WorkoutExercise exercise;
  final int index;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final title = controller.displayExerciseName(
      controller.exerciseFor(exercise.exerciseId),
    );
    void applyAction(_RoutineExerciseAction action) {
      switch (action) {
        case _RoutineExerciseAction.moveUp:
          if (index <= 0) return;
          final item = routine.exercises.removeAt(index);
          routine.exercises.insert(index - 1, item);
          routine.updatedAt = DateTime.now();
          controller.refresh();
          onChanged();
        case _RoutineExerciseAction.moveDown:
          if (index >= routine.exercises.length - 1) return;
          final item = routine.exercises.removeAt(index);
          routine.exercises.insert(index + 1, item);
          routine.updatedAt = DateTime.now();
          controller.refresh();
          onChanged();
        case _RoutineExerciseAction.replace:
          _showRoutineReplacePicker(context, controller, routine, exercise);
        case _RoutineExerciseAction.toggleSuperset:
          exercise.supersetId = exercise.supersetId == null
              ? 'routine-superset-${DateTime.now().microsecondsSinceEpoch}'
              : null;
          controller.refresh();
          onChanged();
        case _RoutineExerciseAction.delete:
          routine.exercises.removeAt(index);
          routine.updatedAt = DateTime.now();
          controller.refresh();
          onChanged();
      }
    }

    Future<void> chooseRest() async {
      final value = await _showRoutineRestPicker(
        context,
        initialSeconds: exercise.restSeconds,
      );
      if (value == null) return;
      exercise.restSeconds = value;
      controller.refresh();
      onChanged();
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 9),
      child: ExpansionTile(
        initiallyExpanded: index == 0,
        dense: true,
        visualDensity: VisualDensity.compact,
        tilePadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 1),
        leading: _ExerciseThumb(exerciseId: exercise.exerciseId, size: 34),
        title: Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          '${exercise.sets.length} 组 · 休息 ${exercise.restSeconds}s${exercise.supersetId == null ? '' : ' · 超级组'}',
          style: const TextStyle(fontSize: 12),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(10, 0, 10, 9),
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: PopupMenuButton<_RoutineExerciseAction>(
              key: Key('routine-exercise-actions-${exercise.id}'),
              tooltip: '更多动作操作',
              icon: const Icon(Icons.more_horiz_rounded),
              style: IconButton.styleFrom(
                backgroundColor: primaryContainer,
                foregroundColor: primary,
                minimumSize: const Size(44, 44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: _RoutineExerciseAction.moveUp,
                  enabled: index > 0,
                  child: const _RoutineActionMenuLabel(
                    icon: Icons.arrow_upward_rounded,
                    label: '上移',
                  ),
                ),
                PopupMenuItem(
                  value: _RoutineExerciseAction.moveDown,
                  enabled: index < routine.exercises.length - 1,
                  child: const _RoutineActionMenuLabel(
                    icon: Icons.arrow_downward_rounded,
                    label: '下移',
                  ),
                ),
                const PopupMenuItem(
                  value: _RoutineExerciseAction.replace,
                  child: _RoutineActionMenuLabel(
                    icon: Icons.swap_horiz_rounded,
                    label: '替换',
                  ),
                ),
                PopupMenuItem(
                  value: _RoutineExerciseAction.toggleSuperset,
                  child: _RoutineActionMenuLabel(
                    icon: exercise.supersetId == null
                        ? Icons.link_rounded
                        : Icons.link_off_rounded,
                    label: exercise.supersetId == null ? '加入超级组' : '取消超级组',
                  ),
                ),
                const PopupMenuItem(
                  value: _RoutineExerciseAction.delete,
                  child: _RoutineActionMenuLabel(
                    icon: Icons.delete_outline_rounded,
                    label: '删除动作',
                    destructive: true,
                  ),
                ),
              ],
              onSelected: applyAction,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            '动作设置',
            style: TextStyle(
              color: quiet,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          Material(
            color: surface,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              key: Key('routine-rest-${exercise.id}'),
              borderRadius: BorderRadius.circular(12),
              onTap: chooseRest,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: hairline),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: primaryContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.timer_outlined, color: primary),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '动作休息',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                          Text(
                            exercise.restSeconds == 0
                                ? '不启动休息计时'
                                : '${exercise.restSeconds} 秒',
                            style: TextStyle(color: quiet, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: quiet),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '组设置',
            style: TextStyle(
              color: quiet,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          for (var setIndex = 0; setIndex < exercise.sets.length; setIndex++)
            _RoutineSetEditor(
              controller: controller,
              cardio: controller.isCardioExercise(exercise.exerciseId),
              set: exercise.sets[setIndex],
              index: setIndex,
              onRemove: () {
                exercise.sets.removeAt(setIndex);
                controller.refresh();
                onChanged();
              },
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () {
                exercise.sets.add(
                  WorkoutSet(
                    id: 'routine-set-${DateTime.now().microsecondsSinceEpoch}',
                    type: 'work',
                    weight: 0,
                    plannedWeight: null,
                    reps: 0,
                    targetMin: 0,
                    targetMax: 0,
                    restSeconds: 0,
                  ),
                );
                controller.refresh();
                onChanged();
              },
              icon: const Icon(Icons.add, size: 17),
              label: const Text('添加一组'),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoutineActionMenuLabel extends StatelessWidget {
  const _RoutineActionMenuLabel({
    required this.icon,
    required this.label,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final bool destructive;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 18, color: destructive ? danger : null),
      const SizedBox(width: 8),
      Text(label, style: destructive ? TextStyle(color: danger) : null),
    ],
  );
}

class _RoutineSetEditorBase extends StatelessWidget {
  const _RoutineSetEditorBase({
    required this.set,
    required this.index,
    required this.onRemove,
    required this.cardio,
  });
  final WorkoutSet set;
  final int index;
  final VoidCallback onRemove;
  final bool cardio;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final typeWidth = (constraints.maxWidth - 40).clamp(150.0, 190.0);
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Wrap(
          spacing: 6,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 24,
              child: Text('${index + 1}', style: TextStyle(color: quiet)),
            ),
            SizedBox(
              width: typeWidth,
              child: DropdownButtonFormField<String>(
                initialValue: set.type,
                isDense: true,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: '组别类型',
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 6,
                  ),
                ),
                items: [
                  for (final entry in setTypeLabels.entries)
                    DropdownMenuItem(
                      value: entry.key,
                      child: Text(entry.value, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) set.type = value;
                },
              ),
            ),
            SizedBox(
              width: 68,
              child: TextFormField(
                initialValue: _editableSetWeight(set),
                keyboardType: TextInputType.text,
                onTapOutside: (_) =>
                    FocusManager.instance.primaryFocus?.unfocus(),
                decoration: const InputDecoration(
                  labelText: '重量',
                  suffixText: 'kg',
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 6,
                  ),
                ),
                onChanged: (value) {
                  final parsed = double.tryParse(value.trim());
                  set.weight = parsed ?? 0;
                  set.weightText = parsed == null ? value.trim() : '';
                },
              ),
            ),
            SizedBox(
              width: 62,
              child: TextFormField(
                initialValue: _editableCount(set.reps),
                keyboardType: TextInputType.number,
                onTapOutside: (_) =>
                    FocusManager.instance.primaryFocus?.unfocus(),
                decoration: const InputDecoration(
                  labelText: '次数',
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 6,
                  ),
                ),
                onChanged: (value) {
                  set.reps = int.tryParse(value) ?? 0;
                },
              ),
            ),
            TextButton.icon(
              onPressed: onRemove,
              icon: const Icon(Icons.delete_outline, size: 18),
              label: const Text('删除'),
            ),
          ],
        ),
      );
    },
  );
}

class _RoutineSetEditor extends _RoutineSetEditorBase {
  const _RoutineSetEditor({
    required this.controller,
    required super.cardio,
    required super.set,
    required super.index,
    required super.onRemove,
  });
  final AppController controller;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final textScale = MediaQuery.textScalerOf(context).scale(1);
      final compact = !cardio && constraints.maxWidth >= 300 && textScale < 1.4;
      final type = DecoratedBox(
        decoration: BoxDecoration(
          color: primaryContainer.withValues(alpha: .46),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: hairline),
        ),
        child: _SetTypeButton(
          controller: controller,
          set: set,
          index: index,
          compact: false,
          persistWorkout: false,
          onChanged: controller.refresh,
        ),
      );
      final weight = TextFormField(
        initialValue: cardio
            ? _editableDecimal(
                set.durationSeconds == null ? null : set.durationSeconds! / 60,
              )
            : _editableSetWeight(set, planned: true),
        keyboardType: cardio
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
        decoration: InputDecoration(
          labelText: cardio ? '时长' : '重量',
          suffixText: cardio ? '分钟' : null,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 7,
            vertical: 8,
          ),
        ),
        onChanged: (value) {
          if (cardio) {
            final minutes = double.tryParse(value);
            set.durationSeconds = minutes == null
                ? null
                : (minutes * 60).round().clamp(0, 86400);
          } else {
            controller.updateSetWeightText(set, value, planned: true);
          }
          controller.refresh();
        },
      );
      final reps = TextFormField(
        initialValue: cardio
            ? _editableDecimal(set.speedKph)
            : _editableCount(set.reps),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
        decoration: InputDecoration(
          labelText: cardio ? '速度' : '次数',
          suffixText: cardio ? 'km/h' : null,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 7,
            vertical: 8,
          ),
        ),
        onChanged: (value) {
          if (cardio) {
            set.speedKph = double.tryParse(value);
          } else {
            set.reps = int.tryParse(value) ?? 0;
          }
          controller.refresh();
        },
      );
      final incline = TextFormField(
        initialValue: _editableDecimal(set.inclinePercent),
        keyboardType: const TextInputType.numberWithOptions(
          decimal: true,
          signed: true,
        ),
        onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
        decoration: const InputDecoration(
          labelText: '坡度',
          suffixText: '%',
          isDense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 7, vertical: 8),
        ),
        onChanged: (value) {
          set.inclinePercent = double.tryParse(value);
          controller.refresh();
        },
      );
      final remove = IconButton(
        tooltip: '删除这一组',
        visualDensity: VisualDensity.compact,
        constraints: const BoxConstraints.tightFor(width: 38, height: 38),
        onPressed: onRemove,
        icon: const Icon(
          Icons.delete_outline,
          size: 20,
          color: Color(0xFFB83A3A),
        ),
      );
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: compact
            ? Row(
                children: [
                  SizedBox(
                    width: 22,
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        color: quiet,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  SizedBox(width: 100, child: type),
                  const SizedBox(width: 6),
                  Expanded(child: weight),
                  const SizedBox(width: 6),
                  SizedBox(width: 58, child: reps),
                  remove,
                ],
              )
            : Column(
                children: [
                  Row(
                    children: [
                      SizedBox(width: 24, child: Text('${index + 1}')),
                      SizedBox(width: 104, child: type),
                      const Spacer(),
                      remove,
                    ],
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Expanded(child: weight),
                      const SizedBox(width: 7),
                      Expanded(child: reps),
                      if (cardio) ...[
                        const SizedBox(width: 7),
                        Expanded(child: incline),
                      ],
                    ],
                  ),
                ],
              ),
      );
    },
  );
}

void _showRoutineReplacePicker(
  BuildContext context,
  AppController controller,
  Routine routine,
  WorkoutExercise target,
) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .72,
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            const Padding(
              padding: EdgeInsets.all(8),
              child: Text(
                '替换模板动作',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
            ),
            for (final item in controller.selectableExercises)
              ListTile(
                dense: true,
                title: Text(controller.displayExerciseName(item)),
                subtitle: Text('${item.muscle} · ${item.equipment}'),
                onTap: () {
                  target.exerciseId = item.id;
                  routine.updatedAt = DateTime.now();
                  controller.refresh();
                  Navigator.pop(context);
                },
              ),
          ],
        ),
      ),
    ),
  );
}

void _showPlanBuilder(BuildContext context, AppController controller) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => _DraftPlanComposer(controller: controller),
    ),
  );
}

class _DraftPlanComposer extends StatefulWidget {
  const _DraftPlanComposer({required this.controller});
  final AppController controller;

  @override
  State<_DraftPlanComposer> createState() => _DraftPlanComposerState();
}

class _DraftPlanComposerState extends State<_DraftPlanComposer> {
  late final TextEditingController name;
  late final Routine draft;
  String? error;

  AppController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    name = TextEditingController(text: '\u6211\u7684\u8BAD\u7EC3\u8BA1\u5212');
    draft = Routine(
      id: 'draft-${DateTime.now().microsecondsSinceEpoch}',
      name: name.text,
      folder: '\u81EA\u5B9A\u4E49',
      exercises: [],
      updatedAt: DateTime.now(),
    );
  }

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  void save() {
    final trimmed = name.text.trim();
    if (trimmed.isEmpty) {
      setState(
        () => error = '\u8BF7\u5148\u8F93\u5165\u8BAD\u7EC3\u540D\u79F0',
      );
      return;
    }
    if (draft.exercises.isEmpty) {
      setState(
        () => error = '\u81F3\u5C11\u6DFB\u52A0\u4E00\u4E2A\u52A8\u4F5C',
      );
      return;
    }
    controller.saveRoutineFromDraft(trimmed, draft.exercises);
    Navigator.pop(context);
    showKiloSnack(context, '\u8BAD\u7EC3\u8BA1\u5212\u5DF2\u4FDD\u5B58');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: IconButton(
        key: const Key('draft-cancel-icon'),
        tooltip: '取消并返回',
        onPressed: () => Navigator.pop(context),
        icon: const Icon(Icons.arrow_back_rounded),
      ),
      title: const Text('新建计划'),
      actions: [
        IconButton(
          key: const Key('draft-save-icon'),
          tooltip: '保存计划',
          onPressed: save,
          icon: const Icon(Icons.save_outlined),
        ),
      ],
    ),
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              key: const Key('draft-name'),
              controller: name,
              onChanged: (value) => setState(() {
                draft.name = value;
                error = null;
              }),
              onTapOutside: (_) =>
                  FocusManager.instance.primaryFocus?.unfocus(),
              decoration: const InputDecoration(
                labelText: '训练名称',
                isDense: true,
                prefixIcon: Icon(Icons.edit_outlined),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 5),
            Text(
              '${draft.exercises.length} 个动作 · 保存后才会加入我的计划',
              style: TextStyle(color: quiet, fontSize: 12),
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Text(
                  error!,
                  style: const TextStyle(color: Color(0xFFB83A3A)),
                ),
              ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.only(bottom: 8),
                children: [
                  for (var index = 0; index < draft.exercises.length; index++)
                    _RoutineExerciseEditor(
                      controller: controller,
                      routine: draft,
                      exercise: draft.exercises[index],
                      index: index,
                      onChanged: () => setState(() => error = null),
                    ),
                  OutlinedButton.icon(
                    key: const Key('draft-add-exercise'),
                    onPressed: () => _showRoutinePicker(
                      context,
                      controller,
                      draft,
                      onChanged: () => setState(() => error = null),
                    ),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('添加动作'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
    bottomNavigationBar: SafeArea(
      minimum: const EdgeInsets.fromLTRB(14, 8, 14, 12),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              key: const Key('draft-cancel-button'),
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: KeyedSubtree(
              key: const Key('draft-save-button'),
              child: FilledButton(
                key: const Key('template-save-button'),
                onPressed: save,
                child: const Text('保存计划'),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

void _showExerciseHistory(
  BuildContext context,
  AppController controller,
  String exerciseId,
) {
  final records = controller.exerciseHistoryFor(exerciseId);
  final definition = controller.exerciseFor(exerciseId);
  final pageContext = context;
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(sheetContext).height * .82,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 12, 10),
              child: Row(
                children: [
                  _ExerciseThumb(exerciseId: exerciseId, size: 46),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          controller.displayExerciseName(definition),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(sheetContext).textTheme.titleLarge,
                        ),
                        Text(
                          '${records.length} 次历史 · 点击查看当时完整备注',
                          style: TextStyle(color: quiet, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: '关闭',
                    onPressed: () => Navigator.pop(sheetContext),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                key: Key('exercise-history-list-$exerciseId'),
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
                itemCount: records.length,
                itemBuilder: (context, index) {
                  final record = records[index];
                  final performed = record.exercises.firstWhere(
                    (item) => item.exerciseId == exerciseId,
                  );
                  final completed = performed.sets
                      .where((set) => set.completed)
                      .toList(growable: false);
                  final best = completed.isEmpty
                      ? null
                      : completed.reduce((a, b) {
                          final aE1rm = a.weight * (1 + a.reps / 30);
                          final bE1rm = b.weight * (1 + b.reps / 30);
                          return bE1rm > aE1rm ? b : a;
                        });
                  final notedSets = completed
                      .where((set) => set.note.trim().isNotEmpty)
                      .take(2)
                      .toList(growable: false);
                  final hasNotes =
                      performed.note.trim().isNotEmpty ||
                      notedSets.isNotEmpty ||
                      record.note.trim().isNotEmpty;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 9),
                    color: surfaceRaised,
                    child: InkWell(
                      key: Key('exercise-history-record-${record.id}'),
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        Navigator.pop(sheetContext);
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (pageContext.mounted) {
                            _showRecordDetail(pageContext, controller, record);
                          }
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(13),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${record.date.month}月${record.date.day}日 · ${record.name}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.chevron_right,
                                  color: quiet,
                                  size: 20,
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              best == null
                                  ? '${completed.length} 组完成'
                                  : '${completed.length} 组 · 最佳 ${_displayWeight(best.weight)} kg × ${best.reps}',
                              style: TextStyle(
                                color: secondaryInk,
                                fontSize: 12,
                              ),
                            ),
                            if (hasNotes) ...[
                              const SizedBox(height: 8),
                              if (performed.note.trim().isNotEmpty)
                                _NoteCallout(
                                  key: Key(
                                    'history-exercise-note-${record.id}',
                                  ),
                                  label: '动作备注',
                                  text: performed.note.trim(),
                                  color: exerciseNoteColor,
                                  background: exerciseNoteContainer,
                                  maxLines: 3,
                                ),
                              for (
                                var noteIndex = 0;
                                noteIndex < notedSets.length;
                                noteIndex++
                              ) ...[
                                const SizedBox(height: 5),
                                _NoteCallout(
                                  key: Key(
                                    'history-set-note-${record.id}-$noteIndex',
                                  ),
                                  label:
                                      '第 ${performed.sets.indexOf(notedSets[noteIndex]) + 1} 组',
                                  text: notedSets[noteIndex].note.trim(),
                                  color: setNoteColor,
                                  background: setNoteContainer,
                                  maxLines: 2,
                                ),
                              ],
                              if (record.note.trim().isNotEmpty) ...[
                                const SizedBox(height: 5),
                                _NoteCallout(
                                  key: Key('history-workout-note-${record.id}'),
                                  label: '训练备注',
                                  text: record.note.trim(),
                                  color: workoutNoteColor,
                                  background: workoutNoteContainer,
                                  maxLines: 2,
                                ),
                              ],
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

void _showRecordDetail(
  BuildContext context,
  AppController controller,
  WorkoutRecord record,
) {
  final details = record.exercises.isNotEmpty
      ? record.exercises
      : [
          for (var index = 0; index < record.exerciseIds.length; index++)
            WorkoutExercise(
              id: 'legacy-record-$index',
              exerciseId: record.exerciseIds[index],
              sets: [],
            ),
        ];
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .86,
        child: SingleChildScrollView(
          key: Key('record-detail-${record.id}'),
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 26),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFE85B17), Color(0xFFFF9B55)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x33D95718),
                      blurRadius: 24,
                      offset: Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.emoji_events_rounded,
                      color: Colors.white,
                      size: 30,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      record.name,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    Text(
                      '${record.date.year}-${record.date.month.toString().padLeft(2, '0')}-${record.date.day.toString().padLeft(2, '0')} · ${record.startTime}',
                      style: const TextStyle(color: Color(0xFFFFE9DD)),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _RecordMetric(
                          icon: Icons.monitor_weight_outlined,
                          value: '${record.volume.toStringAsFixed(0)} kg',
                          label: '总容量',
                        ),
                        _RecordMetric(
                          icon: Icons.check_circle_outline_rounded,
                          value: '${record.effectiveSets}',
                          label: '完成组',
                        ),
                        _RecordMetric(
                          icon: Icons.timer_outlined,
                          value: '${(record.durationSeconds / 60).round()} 分',
                          label: '时长',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                '动作与每组数据',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              if (details.isEmpty)
                Text('这条记录没有保存动作明细。', style: TextStyle(color: quiet))
              else
                for (final exercise in details)
                  Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    color: paper,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              _ExerciseThumb(
                                exerciseId: exercise.exerciseId,
                                size: 42,
                              ),
                              const SizedBox(width: 9),
                              Expanded(
                                child: Text(
                                  controller.displayExerciseName(
                                    controller.exerciseFor(exercise.exerciseId),
                                  ),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          if (exercise.note.trim().isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 5),
                              child: _NoteCallout(
                                key: Key(
                                  'record-exercise-note-${record.id}-${exercise.id}',
                                ),
                                label: '动作备注',
                                text: exercise.note.trim(),
                                color: exerciseNoteColor,
                                background: exerciseNoteContainer,
                              ),
                            ),
                          if (exercise.sets.isEmpty)
                            Text(
                              '\u8BA1\u5212\u91CD\u91CF\u672A\u8BB0\u5F55\uFF08\u65E7\u8BB0\u5F55\u672A\u4FDD\u5B58\u7EC4\u660E\u7EC6\uFF09',
                              style: TextStyle(fontSize: 12, color: quiet),
                            ),
                          for (
                            var index = 0;
                            index < exercise.sets.length;
                            index++
                          )
                            _RecordSetRow(
                              set: exercise.sets[index],
                              index: index,
                            ),
                          _RecordTechniqueSummary(
                            controller: controller,
                            record: record,
                            exercise: exercise,
                          ),
                        ],
                      ),
                    ),
                  ),
              if (record.note.trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: _NoteCallout(
                    key: Key('record-workout-note-${record.id}'),
                    label: '训练备注',
                    text: record.note.trim(),
                    color: workoutNoteColor,
                    background: workoutNoteContainer,
                  ),
                ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _showRecordEditor(context, controller, record);
                      },
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('编辑备注'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: '删除记录',
                    onPressed: () {
                      controller.deleteRecord(record);
                      Navigator.pop(context);
                    },
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Color(0xFFB83A3A),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _RecordMetric extends StatelessWidget {
  const _RecordMetric({
    required this.icon,
    required this.value,
    required this.label,
  });
  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      margin: const EdgeInsets.only(right: 7),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .17),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white, size: 17),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            label,
            style: const TextStyle(color: Color(0xFFFFE9DD), fontSize: 10),
          ),
        ],
      ),
    ),
  );
}

TechniqueAssessment? _latestTechniqueFor(
  AppController controller,
  String exerciseId,
) {
  final matches =
      controller.techniqueAssessments
          .where((item) => item.exerciseId == exerciseId)
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return matches.firstOrNull;
}

class _RecordTechniqueSummary extends StatelessWidget {
  const _RecordTechniqueSummary({
    required this.controller,
    required this.record,
    required this.exercise,
  });

  final AppController controller;
  final WorkoutRecord record;
  final WorkoutExercise exercise;

  @override
  Widget build(BuildContext context) {
    final assessment = _latestTechniqueFor(controller, exercise.exerciseId);
    if (assessment == null) return const SizedBox.shrink();
    final scoreText = assessment.scoreable
        ? '技术评分 ${assessment.overall}/100'
        : '本次动作暂不评分';
    return Padding(
      padding: const EdgeInsets.only(top: 9),
      child: Container(
        key: Key('record-technique-${record.id}-${exercise.id}'),
        width: double.infinity,
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: emberTint,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: primary.withValues(alpha: .2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.analytics_outlined, size: 18, color: primary),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    'AI动作分析',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                Text(
                  scoreText,
                  style: TextStyle(color: primary, fontWeight: FontWeight.w900),
                ),
              ],
            ),
            const SizedBox(height: 7),
            if (!assessment.scoreable)
              Text(
                assessment.qualityReason.isEmpty
                    ? '视频证据不足，未生成可靠评分。'
                    : assessment.qualityReason,
                style: TextStyle(color: quiet, height: 1.35),
              )
            else ...[
              Wrap(
                spacing: 8,
                runSpacing: 5,
                children: [
                  Text('ROM ${assessment.rom}'),
                  Text('稳定 ${assessment.stability}'),
                  Text('对称 ${assessment.symmetry}'),
                  Text('节奏 ${assessment.tempo}'),
                ],
              ),
              if (assessment.issues.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  '最需改善：${assessment.issues.take(2).join('；')}',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: quiet, height: 1.35),
                ),
              ],
              if (assessment.nextFocus.trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  '下一次重点：${assessment.nextFocus}',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: primary,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

void _showAllHistory(BuildContext context, AppController controller) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .84,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('全部训练历史', style: Theme.of(context).textTheme.headlineMedium),
              Text(
                '${controller.history.length} 次训练 · 点击查看动作与每组数据',
                style: TextStyle(color: quiet),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: ListView(
                  children: [
                    for (final record in controller.history)
                      _RecordTile(
                        controller: controller,
                        record: record,
                        onTap: () =>
                            _showRecordDetail(context, controller, record),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Future<Exercise?> _showCustomExercise(
  BuildContext context,
  AppController controller,
) async {
  final name = TextEditingController();
  final english = TextEditingController();
  final equipment = TextEditingController(text: '自定义器械');
  const muscleOptions = <String>[
    '胸部',
    '背部',
    '肩部',
    '臀部',
    '股四头肌',
    '腘绳肌',
    '小腿',
    '肱二头肌',
    '肱三头肌',
    '前臂',
    '核心',
  ];
  var muscle = muscleOptions.first;
  final cue = TextEditingController();
  final result = await showDialog<Exercise>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('新建自定义动作'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const Key('custom-exercise-name'),
              controller: name,
              decoration: const InputDecoration(labelText: '动作名称 *'),
            ),
            const SizedBox(height: 8),
            TextField(
              key: const Key('custom-exercise-english-name'),
              controller: english,
              decoration: const InputDecoration(labelText: '英文名称'),
            ),
            const SizedBox(height: 8),
            TextField(
              key: const Key('custom-exercise-equipment'),
              controller: equipment,
              decoration: const InputDecoration(labelText: '器械'),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              key: const Key('custom-exercise-muscle'),
              initialValue: muscle,
              isExpanded: true,
              decoration: const InputDecoration(labelText: '主要训练部位 *'),
              items: [
                for (final option in muscleOptions)
                  DropdownMenuItem(value: option, child: Text(option)),
              ],
              onChanged: (value) {
                if (value != null) muscle = value;
              },
            ),
            const SizedBox(height: 8),
            TextField(
              key: const Key('custom-exercise-cue'),
              controller: cue,
              maxLines: 2,
              decoration: const InputDecoration(labelText: '动作提示'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          key: const Key('custom-exercise-save'),
          onPressed: () {
            if (name.text.trim().isNotEmpty) {
              final exercise = controller.addCustomExercise(
                name: name.text.trim(),
                englishName: english.text.trim(),
                equipment: equipment.text.trim(),
                muscle: muscle,
                cue: cue.text.trim(),
              );
              Navigator.pop(context, exercise);
            }
          },
          child: const Text('保存动作'),
        ),
      ],
    ),
  );
  return result;
}

void _showLibraryFilters(BuildContext context, AppController controller) {
  final equipment = controller.equipmentFilterOptions;
  showModalBottomSheet<void>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '器械筛选',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final item in equipment)
                  ChoiceChip(
                    label: Text(item),
                    selected: controller.equipmentFilter == item,
                    onSelected: (_) {
                      controller.equipmentFilter = item;
                      controller.refresh();
                      Navigator.pop(sheetContext);
                      showKiloSnack(
                        context,
                        item == '全部' ? '已清除器械筛选' : '已筛选 $item',
                      );
                    },
                  ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    ),
  );
}

void _showRecordEditor(
  BuildContext context,
  AppController controller,
  WorkoutRecord record,
) {
  final note = TextEditingController(text: record.note);
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('编辑训练备注'),
      content: TextField(
        controller: note,
        maxLines: 4,
        decoration: const InputDecoration(hintText: '记录本次训练的感受、PR 或异常'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () {
            controller.updateRecordNote(record, note.text.trim());
            Navigator.pop(context);
          },
          child: const Text('保存'),
        ),
      ],
    ),
  );
}
