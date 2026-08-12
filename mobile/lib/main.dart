import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import 'account_membership.dart';
import 'controller.dart';
import 'exercise_media.dart';
import 'link_utils.dart';
import 'models.dart';
import 'recognition_api.dart';

// Warm-orange Material 3 tokens. The older names remain as compatibility
// aliases because the prototype has many focused, purpose-built widgets.
const paper = Color(0xFFFFF7F0);
const surface = Color(0xFFFFFFFF);
const primary = Color(0xFFD95718);
const primaryBright = Color(0xFFF36A1D);
const primaryContainer = Color(0xFFFFE3D2);
const ink = Color(0xFF241A15);
const muted = Color(0xFF756156);
const secondaryInk = muted;
const quiet = muted;
const cobalt = primary;
const lime = Color(0xFFB7E34A);
const orange = primaryBright;
const success = Color(0xFF21845A);
const successContainer = Color(0xFFE6F5EC);
const calendarScheduled = Color(0xFFE65A17);
const calendarScheduledContainer = Color(0xFFFFE4D2);
const calendarSelected = Color(0xFF2468C9);
const calendarSelectedContainer = Color(0xFFE7F0FF);
const hairline = Color(0xFFEAD9CD);
const emberTint = Color(0xFFFFEFE4);
const emberShadow = Color(0x1F8E3D15);
const danger = Color(0xFFB3261E);
const kiloAppVersion = '1.0.10';
const kiloAppBuild = '11';
const kiloAppVersionLabel = '$kiloAppVersion ($kiloAppBuild)';
const kiloAppNavigationLabel = '新版导航：训练/记录、AI/识别已合并';
const brandName = '形域';
const brandEnglish = 'XINGYU';
const brandLogoAsset = 'assets/branding/xingyu-mark.png';

void main() => runApp(const KiloApp());

class KiloApp extends StatefulWidget {
  const KiloApp({super.key, this.initialController});
  final AppController? initialController;
  @override
  State<KiloApp> createState() => _KiloAppState();
}

// Kept as a compatibility alias for the generated Flutter smoke test.
typedef MyApp = KiloApp;

class _KiloAppState extends State<KiloApp> {
  late final AppController controller;
  late final bool ownsController;
  late bool durableStateReady;
  late bool splashElapsed;
  @override
  void initState() {
    super.initState();
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
      await controller.hydrateWorkoutHistory().timeout(
        const Duration(seconds: 3),
      );
      await controller.hydrateActiveWorkout().timeout(
        const Duration(seconds: 3),
      );
      await controller.hydrateTrainingLibrary().timeout(
        const Duration(seconds: 3),
      );
    } catch (_) {
      // Local storage is optional in previews; the in-memory repository stays
      // usable when a platform implementation is unavailable.
    }
    if (mounted) setState(() => durableStateReady = true);
  }

  @override
  void dispose() {
    if (ownsController) controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      // Existing widget tests inject a controller to exercise a particular
      // shell route. Real app startup owns its controller and therefore
      // starts at the authentication root until a user signs in.
      final injectedTestController = widget.initialController != null;
      final showLogin =
          durableStateReady &&
          !injectedTestController &&
          !controller.isAuthenticated;
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        title: '$brandName $brandEnglish',
        theme: _theme,
        home: !durableStateReady || !splashElapsed
            ? const BrandSplashPage()
            : showLogin
            ? LoginPage(controller: controller)
            : KiloShell(controller: controller),
      );
    },
  );
}

final _theme = ThemeData(
  useMaterial3: true,
  scaffoldBackgroundColor: paper,
  colorScheme:
      ColorScheme.fromSeed(
        seedColor: primary,
        brightness: Brightness.light,
      ).copyWith(
        primary: primary,
        onPrimary: Colors.white,
        primaryContainer: primaryContainer,
        onPrimaryContainer: ink,
        secondary: primaryBright,
        onSecondary: Colors.white,
        secondaryContainer: primaryContainer,
        onSecondaryContainer: ink,
        surface: surface,
        onSurface: ink,
        outline: hairline,
        outlineVariant: hairline,
      ),
  textTheme: const TextTheme(
    headlineLarge: TextStyle(
      fontSize: 30,
      fontWeight: FontWeight.w800,
      color: ink,
      letterSpacing: -1,
    ),
    headlineMedium: TextStyle(
      fontSize: 23,
      fontWeight: FontWeight.w800,
      color: ink,
    ),
    titleLarge: TextStyle(
      fontSize: 19,
      fontWeight: FontWeight.w800,
      color: ink,
    ),
    titleMedium: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w700,
      color: ink,
    ),
    bodyLarge: TextStyle(fontSize: 16, color: secondaryInk, height: 1.35),
    bodyMedium: TextStyle(fontSize: 14, color: secondaryInk, height: 1.35),
    labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
  ),
  inputDecorationTheme: const InputDecorationTheme(
    border: OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(12)),
      borderSide: BorderSide(color: hairline),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(12)),
      borderSide: BorderSide(color: hairline),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(12)),
      borderSide: BorderSide(color: primary, width: 2),
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
    fillColor: surface,
    labelStyle: TextStyle(color: muted),
    floatingLabelStyle: TextStyle(color: primary),
  ),
  cardTheme: const CardThemeData(
    color: surface,
    elevation: 0,
    margin: EdgeInsets.zero,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(18)),
      side: BorderSide(color: hairline),
    ),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: ButtonStyle(
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
      minimumSize: WidgetStatePropertyAll(Size(48, 44)),
      side: WidgetStatePropertyAll(BorderSide(color: hairline)),
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
  dividerTheme: const DividerThemeData(color: hairline, thickness: 1),
  navigationBarTheme: const NavigationBarThemeData(
    backgroundColor: surface,
    indicatorColor: primaryContainer,
    labelTextStyle: WidgetStatePropertyAll(
      TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: ink),
    ),
    height: 66,
  ),
);

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
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(size * .22),
    child: Image.asset(
      brandLogoAsset,
      width: size,
      height: size,
      fit: BoxFit.cover,
      semanticLabel: '$brandName $brandEnglish 标志',
    ),
  );
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
                const Text(
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

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.controller});

  final AppController controller;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  late final TextEditingController identifier;
  late final TextEditingController password;
  String? error;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    identifier = TextEditingController();
    password = TextEditingController();
  }

  @override
  void dispose() {
    identifier.dispose();
    password.dispose();
    super.dispose();
  }

  void submit() {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    final result = widget.controller.loginWithPhone(
      identifier.text,
      password: password.text,
    );
    if (!result.isSuccess) {
      setState(() {
        busy = false;
        error =
            result.message ??
            switch (result.error) {
              AccountError.emptyIdentifier => '请输入手机号或账号。',
              AccountError.invalidCredentials => '账号或密码不正确。',
              _ => '登录暂时不可用，请稍后重试。',
            };
      });
      return;
    }
    setState(() => busy = false);
  }

  void fillTestAccount(String value) {
    setState(() {
      identifier.text = value;
      password.text = value;
      error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isIos = defaultTargetPlatform == TargetPlatform.iOS;
    final testAccountEnabled =
        widget.controller.accountService.isTestAccountEnabled;
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
                    const Row(
                      children: [
                        BrandLogo(size: 66),
                        SizedBox(width: 12),
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
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '记录每一组，把坚持变成看得见的成长。',
                      style: TextStyle(color: muted),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              '登录账号',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              key: const Key('login-identifier'),
                              controller: identifier,
                              keyboardType: TextInputType.phone,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.username],
                              decoration: const InputDecoration(
                                labelText: '手机号或账号',
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              key: const Key('login-password'),
                              controller: password,
                              obscureText: true,
                              textInputAction: TextInputAction.done,
                              autofillHints: const [AutofillHints.password],
                              onSubmitted: (_) => submit(),
                              decoration: const InputDecoration(
                                labelText: '密码',
                              ),
                            ),
                            if (error != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                error!,
                                style: const TextStyle(
                                  color: danger,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                            const SizedBox(height: 12),
                            FilledButton(
                              key: const Key('login-button'),
                              onPressed: busy ? null : submit,
                              child: Text(busy ? '登录中…' : '登录'),
                            ),
                            if (testAccountEnabled) ...[
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      key: const Key(
                                        'login-member-account-fill-button',
                                      ),
                                      onPressed: busy
                                          ? null
                                          : () => fillTestAccount('123'),
                                      child: const Text('普通体验 123'),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: OutlinedButton(
                                      key: const Key(
                                        'login-test-account-fill-button',
                                      ),
                                      onPressed: busy
                                          ? null
                                          : () => fillTestAccount('1234'),
                                      child: const Text('管理测试 1234'),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                '测试入口仅在测试构建中显示',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 11, color: muted),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    if (isIos) ...[
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        key: const Key('apple-login-button'),
                        onPressed: () {
                          final result = widget.controller.loginWithApple();
                          setState(
                            () => error = result.message ?? 'Apple 登录尚未配置。',
                          );
                        },
                        icon: const Icon(Icons.apple),
                        label: const Text('使用 Apple 登录'),
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
    PageId.ai || PageId.recognition => 3,
    PageId.profile => 4,
  };
  String get pageTitle => switch (controller.page) {
    PageId.today => '主页',
    PageId.train => '训练',
    PageId.records => '记录',
    PageId.exercises => '动作库',
    PageId.recognition => '动作识别',
    PageId.ai => '知识库 AI',
    PageId.profile => '我的',
  };
  String get pageSubtitle => switch (controller.page) {
    PageId.today => '训练、记录和计划概览',
    PageId.train => controller.workoutStarted ? '保持专注，完成下一组' : '选择计划并开始训练',
    PageId.records => '训练日历、完成情况和历史记录',
    PageId.exercises => '动作、机位与识别能力',
    PageId.recognition => '上传视频并查看可解释报告',
    PageId.ai => '有来源的训练问答',
    PageId.profile => '训练偏好、设备连接和隐私设置',
  };

  @override
  Widget build(BuildContext context) {
    final body = switch (controller.page) {
      PageId.today => HomePage(controller: controller),
      PageId.train => TrainPage(controller: controller),
      PageId.records => TrainPage(controller: controller),
      PageId.exercises => ExerciseLibraryPage(controller: controller),
      PageId.recognition => RecognitionPage(controller: controller),
      PageId.ai => AiPage(controller: controller),
      PageId.profile => ProfilePage(controller: controller),
    };
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(58),
        child: SafeArea(
          child: _TopBar(controller: controller, title: pageTitle),
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
            GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
              child: body,
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: navIndex,
        onDestinationSelected: (index) => controller.selectPage(pages[index]),
        destinations: [
          for (var i = 0; i < pages.length; i++)
            NavigationDestination(
              icon: Icon(icons[i]),
              selectedIcon: Icon(icons[i], color: cobalt),
              label: labels[i],
            ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.controller, required this.title});
  final AppController controller;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      padding: const EdgeInsets.fromLTRB(16, 0, 10, 0),
      decoration: const BoxDecoration(
        color: paper,
        border: Border(bottom: BorderSide(color: hairline)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Row(
              children: [
                const BrandLogo(size: 35),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 21,
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
              tooltip: '新建自定义动作',
              onPressed: () => _showCustomExercise(context, controller),
              icon: const Icon(Icons.add),
            ),
          if (controller.page == PageId.ai &&
              controller.aiView == AiView.recognition)
            IconButton(
              tooltip: '选择视频',
              onPressed: controller.mediaPicking ? null : controller.pickVideo,
              icon: const Icon(Icons.video_camera_back_outlined),
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
            const Icon(Icons.timer_outlined, size: 16, color: ink),
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
    this.padding = const EdgeInsets.fromLTRB(16, 18, 16, 100),
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
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: const TextStyle(fontSize: 12, color: quiet),
                ),
            ],
          ),
        ),
        if (action != null)
          TextButton(onPressed: onAction, child: Text(action!)),
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
      label: Text(label, overflow: TextOverflow.ellipsis),
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
              message,
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
  const _StatusChip(
    this.label, {
    this.color = cobalt,
    this.icon = Icons.circle,
  });
  final String label;
  final Color color;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .1),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: color.withValues(alpha: .25)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class _ExerciseThumb extends StatelessWidget {
  const _ExerciseThumb({super.key, required this.exerciseId, this.size = 42});
  final String exerciseId;
  final double size;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(10),
    child: Container(
      width: size,
      height: size,
      color: paper,
      child: Image.asset(
        exerciseAsset(exerciseId),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stack) =>
            const Icon(Icons.fitness_center, color: cobalt),
      ),
    ),
  );
}

class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final hasHistory = controller.history.isNotEmpty;
    final latest = hasHistory ? controller.history.first : null;
    final totalVolume = controller.history.fold<double>(
      0,
      (sum, record) => sum + record.volume,
    );
    final totalEffectiveSets = controller.history.fold<int>(
      0,
      (sum, record) => sum + record.effectiveSets,
    );
    return PageFrame(
      children: [
        SectionTitle('训练概览', subtitle: '今天只做最重要的下一步'),
        _HomeWorkoutHero(controller: controller, latest: latest),
        const SizedBox(height: 18),
        SectionTitle(
          '训练周',
          subtitle: '点击日期查看或调整安排',
          action: '完整月历',
          onAction: () => controller.selectPage(PageId.records),
        ),
        _WeekStrip(controller: controller),
        if (controller.scheduled.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('暂无排程，可在记录日历中安排训练。', style: TextStyle(color: quiet)),
          ),
        const SizedBox(height: 18),
        SectionTitle(
          '进步摘要',
          subtitle: '只展示真实训练记录',
          action: '全部趋势',
          onAction: () => _showProgress(context, controller),
        ),
        _HomeProgressPanel(
          controller: controller,
          totalVolume: totalVolume,
          totalEffectiveSets: totalEffectiveSets,
          onTap: () => _showProgress(context, controller),
        ),
        const SizedBox(height: 18),
        SectionTitle(
          '最近记录',
          subtitle: hasHistory ? '已保存的真实训练记录' : '完成训练后会出现在这里',
          action: hasHistory ? '全部记录' : null,
          onAction: hasHistory
              ? () => controller.selectPage(PageId.records)
              : null,
        ),
        if (!hasHistory)
          const Card(
            key: Key('home-recent-empty'),
            child: Padding(
              padding: EdgeInsets.all(14),
              child: Text('暂无训练记录。', style: TextStyle(color: quiet)),
            ),
          )
        else
          for (final record in controller.history.take(3))
            _RecordTile(
              controller: controller,
              record: record,
              onTap: () => _showRecordDetail(context, controller, record),
            ),
      ],
    );
  }
}

class _HomeWorkoutHero extends StatelessWidget {
  const _HomeWorkoutHero({required this.controller, required this.latest});
  final AppController controller;
  final WorkoutRecord? latest;

  @override
  Widget build(BuildContext context) {
    final active = controller.workoutStarted;
    final title = active ? controller.workoutName : latest?.name ?? '自由训练';
    final exerciseId = active && controller.workout.isNotEmpty
        ? controller.workout.first.exerciseId
        : latest != null && latest!.exerciseIds.isNotEmpty
        ? latest!.exerciseIds.first
        : null;
    final meta = active
        ? '${controller.workout.length} 个动作 · ${controller.currentElapsed ~/ 60} 分钟'
        : latest == null
        ? '不需要计划，也可以边练边记录'
        : '${latest!.exerciseIds.length} 个动作 · ${(latest!.durationSeconds / 60).round()} 分钟';
    return Container(
      key: const Key('home-overview-section'),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: hairline),
        boxShadow: const [
          BoxShadow(color: emberShadow, blurRadius: 28, offset: Offset(0, 12)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            right: -45,
            top: -55,
            child: Container(
              width: 190,
              height: 190,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: emberTint,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            active
                                ? '实时训练'
                                : latest == null
                                ? '今日训练'
                                : '最近训练',
                            style: const TextStyle(
                              color: primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 7),
                          Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          const SizedBox(height: 5),
                          Text(
                            meta,
                            style: const TextStyle(color: secondaryInk),
                          ),
                        ],
                      ),
                    ),
                    if (exerciseId != null) ...[
                      const SizedBox(width: 12),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .76),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: _ExerciseThumb(
                            exerciseId: exerciseId,
                            size: 86,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (active) ...[
                  const SizedBox(height: 14),
                  LinearProgressIndicator(
                    value: controller.completion,
                    minHeight: 7,
                    borderRadius: BorderRadius.circular(7),
                    color: primary,
                    backgroundColor: primaryContainer,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${controller.completedSets} / ${controller.totalSets} 组已完成',
                    style: const TextStyle(fontSize: 12, color: quiet),
                  ),
                ],
                const SizedBox(height: 16),
                if (active)
                  FilledButton.icon(
                    key: const Key('home-continue'),
                    onPressed: () {
                      controller.openLiveWorkout();
                      showKiloSnack(context, '已返回实时训练');
                    },
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('继续训练'),
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          key: const Key('home-free-workout'),
                          onPressed: () {
                            controller.startWorkout(
                              name: '自由训练',
                              autoStartTimer: false,
                            );
                            controller.openLiveWorkout();
                          },
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: const Text('开始训练'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.outlined(
                        key: const Key('home-browse-plans'),
                        tooltip: '浏览计划',
                        onPressed: () {
                          controller.selectPage(PageId.train);
                          controller.selectTrainView(TrainView.plans);
                        },
                        icon: const Icon(Icons.menu_book_outlined),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeProgressPanel extends StatelessWidget {
  const _HomeProgressPanel({
    required this.controller,
    required this.totalVolume,
    required this.totalEffectiveSets,
    required this.onTap,
  });
  final AppController controller;
  final double totalVolume;
  final int totalEffectiveSets;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    key: const Key('home-progress-section'),
    child: InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: controller.history.isEmpty
            ? const Row(
                children: [
                  Icon(Icons.query_stats_rounded, color: primary),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '完成一次训练后，这里会显示训练量和有效组变化。',
                      style: TextStyle(color: quiet),
                    ),
                  ),
                ],
              )
            : Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('累计训练量', style: TextStyle(color: quiet)),
                        Text(
                          '${totalVolume.toStringAsFixed(0)} kg',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          '$totalEffectiveSets 个有效组',
                          style: const TextStyle(
                            color: primary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 108,
                    height: 64,
                    child: CustomPaint(
                      painter: _MiniVolumePainter(
                        controller.history
                            .take(6)
                            .map((record) => record.volume)
                            .toList()
                            .reversed
                            .toList(),
                      ),
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: quiet),
                ],
              ),
      ),
    ),
  );
}

class _MiniVolumePainter extends CustomPainter {
  const _MiniVolumePainter(this.values);
  final List<double> values;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final maxValue = values.reduce((a, b) => a > b ? a : b);
    final step = size.width / values.length;
    final line = Path();
    for (var i = 0; i < values.length; i++) {
      final ratio = maxValue == 0
          ? 0.08
          : (values[i] / maxValue).clamp(.08, 1.0);
      final point = Offset(
        step * i + step / 2,
        size.height - size.height * ratio,
      );
      if (i == 0) {
        line.moveTo(point.dx, point.dy);
      } else {
        line.lineTo(point.dx, point.dy);
      }
    }
    canvas.drawPath(
      line,
      Paint()
        ..color = primary
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );
    for (var i = 0; i < values.length; i++) {
      final ratio = maxValue == 0
          ? 0.08
          : (values[i] / maxValue).clamp(.08, 1.0);
      canvas.drawCircle(
        Offset(step * i + step / 2, size.height - size.height * ratio),
        3,
        Paint()..color = primaryBright,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MiniVolumePainter oldDelegate) =>
      oldDelegate.values != values;
}

class _WeekStrip extends StatelessWidget {
  const _WeekStrip({required this.controller});
  final AppController controller;
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
    return SizedBox(
      height: 78 * scale,
      child: Row(
        children: [
          for (var i = 0; i < 7; i++)
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: i == 6 ? 0 : 5),
                child: Container(
                  decoration: BoxDecoration(
                    color: _isSameDay(dates[i], today) ? cobalt : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _isSameDay(dates[i], today) ? cobalt : hairline,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        days[i],
                        style: TextStyle(
                          fontSize: 11,
                          color: _isSameDay(dates[i], today)
                              ? Colors.white
                              : quiet,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${dates[i].day}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: _isSameDay(dates[i], today)
                              ? Colors.white
                              : ink,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Icon(
                        controller.history.any(
                              (record) => _isSameDay(record.date, dates[i]),
                            )
                            ? Icons.check_circle
                            : controller.scheduled.contains(_dateKey(dates[i]))
                            ? Icons.fitness_center
                            : Icons.remove,
                        size: 12,
                        color: _isSameDay(dates[i], today)
                            ? lime
                            : controller.history.any(
                                (record) => _isSameDay(record.date, dates[i]),
                              )
                            ? cobalt
                            : hairline,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

bool _isSameDay(DateTime left, DateTime right) =>
    left.year == right.year &&
    left.month == right.month &&
    left.day == right.day;

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
                    SectionTitle('我的训练计划', subtitle: '选择一节训练后进入独立实时记录界面'),
                    _PlansView(controller: controller),
                  ],
                ),
        ),
      ],
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
    decoration: const BoxDecoration(
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

  @override
  Widget build(BuildContext context) {
    final elapsed = controller.currentElapsed;
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final compact = MediaQuery.sizeOf(context).width < 340 || textScale > 1.35;
    final title = Text(
      controller.workoutName,
      maxLines: compact ? 2 : 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.titleLarge,
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
          style: const TextStyle(fontSize: 12, color: secondaryInk),
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
                    const Icon(Icons.timer_outlined, color: cobalt, size: 19),
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
                            style: const TextStyle(
                              fontSize: 11,
                              color: secondaryInk,
                            ),
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
                      message: '增加 15 秒休息',
                      child: TextButton.icon(
                        key: const Key('rest-add-15-button'),
                        onPressed: () {
                          controller.addRestSeconds();
                          showKiloSnack(context, '休息已增加 15 秒');
                        },
                        icon: const Icon(Icons.add_circle_outline, size: 17),
                        label: const Text('+15 秒'),
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
              style: const TextStyle(fontSize: 12, color: secondaryInk),
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
              message: controller.batchMode ? '退出批量' : '批量修改',
              child: OutlinedButton.icon(
                key: const Key('workout-batch-button'),
                onPressed: controller.toggleBatchMode,
                icon: Icon(
                  controller.batchMode ? Icons.check_circle : Icons.checklist,
                ),
                label: Text(controller.batchMode ? '退出批量' : '批量'),
              ),
            ),
            Tooltip(
              message: '杠片计算器',
              child: OutlinedButton.icon(
                key: const Key('plate-calculator-button'),
                onPressed: () => _showPlateCalculator(context),
                icon: const Icon(Icons.calculate_outlined),
                label: const Text('杠片'),
              ),
            ),
            Tooltip(
              message: '训练设置',
              child: OutlinedButton.icon(
                key: const Key('workout-settings-button'),
                onPressed: () => _showWorkoutSettings(context, controller),
                icon: const Icon(Icons.tune),
                label: const Text('设置'),
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
                gradient: const LinearGradient(
                  colors: [primary, primaryBright],
                ),
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
              const Icon(Icons.check_circle, color: cobalt, size: 48),
              const SizedBox(height: 10),
              Text('训练已保存', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 5),
              Text(
                '${controller.history.first.name} · ${controller.history.first.effectiveSets} 个有效组',
                style: const TextStyle(color: secondaryInk),
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
                  const Icon(Icons.playlist_add, size: 44, color: quiet),
                  const SizedBox(height: 8),
                  const Text(
                    '还没有动作',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '可以先添加动作，也可以直接开始计时。',
                    style: TextStyle(color: quiet),
                  ),
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
                backgroundColor: ink,
                foregroundColor: Colors.white,
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
      color: Colors.white,
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
              key: const Key('workout-batch-button'),
              tooltip: controller.batchMode ? '退出批量' : '批量修改',
              onPressed: controller.toggleBatchMode,
              icon: Icon(
                controller.batchMode ? Icons.check_circle : Icons.checklist,
              ),
            ),
            IconButton(
              key: const Key('plate-calculator-button'),
              tooltip: '杠片计算器',
              onPressed: () => _showPlateCalculator(context),
              icon: const Icon(Icons.calculate_outlined),
            ),
            IconButton(
              key: const Key('workout-settings-button'),
              tooltip: '训练设置',
              onPressed: () => _showWorkoutSettings(context, controller),
              icon: const Icon(Icons.tune),
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
                const Icon(Icons.timer_outlined, color: cobalt),
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
                        style: const TextStyle(
                          fontSize: 12,
                          color: secondaryInk,
                        ),
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
    final definition = findExercise(exercise.exerciseId);
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
                  _ExerciseThumb(exerciseId: exercise.exerciseId, size: 38),
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
                              const Padding(
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
                          style: const TextStyle(fontSize: 11, color: quiet),
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
                            backgroundColor: emberTint,
                            foregroundColor: primary,
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
                        color: emberTint,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: primary.withValues(alpha: .18),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.sticky_note_2_outlined,
                            size: 17,
                            color: primary,
                          ),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text(
                              exercise.note.trim().isEmpty
                                  ? '动作备注 · 点击记录握距、档位或动作提示'
                                  : '动作备注 · ${exercise.note.trim()}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: secondaryInk,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.edit_outlined,
                            size: 15,
                            color: primary,
                          ),
                        ],
                      ),
                    ),
                  ),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final columns = _SetColumns.fromWidth(
                        constraints.maxWidth,
                      );
                      return Column(
                        children: [
                          _SetTableHeader(columns: columns),
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
                  Row(
                    children: [
                      TextButton.icon(
                        key: Key('reuse-previous-${exercise.id}'),
                        onPressed: () {
                          final reused = controller.reusePreviousValues(
                            exercise,
                          );
                          showKiloSnack(
                            context,
                            reused ? '已带入上次完成数据' : '暂无可带入的历史数据',
                          );
                        },
                        icon: const Icon(Icons.history, size: 17),
                        label: const Text('带入上次'),
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
                      const Spacer(),
                    ],
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
    return _SetColumns(
      compact: compact,
      group: compact ? 52 : 64,
      last: compact ? 44 : 58,
      weight: compact ? 50 : 58,
      reps: compact ? 34 : 42,
      note: compact ? 34 : 40,
      complete: compact ? 36 : 40,
      gap: compact ? 2 : 4,
    );
  }
}

class _SetTableHeader extends StatelessWidget {
  const _SetTableHeader({required this.columns});
  final _SetColumns columns;

  Widget _label(String text, double width) => SizedBox(
    width: width,
    child: Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontSize: 11, color: quiet),
    ),
  );

  @override
  Widget build(BuildContext context) => Row(
    children: [
      _label('组', columns.group),
      SizedBox(width: columns.gap),
      _label('上次', columns.last),
      SizedBox(width: columns.gap),
      _label('kg', columns.weight),
      SizedBox(width: columns.gap),
      _label('次数', columns.reps),
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
            const Text(
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
            const Text(
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
  int index,
) {
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
                    controller.refresh(persistWorkout: true);
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
  });
  final AppController controller;
  final WorkoutSet set;
  final int index;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final label = _setTypeShort(set.type);
    final color = _setTypeColor(set.type);
    return Semantics(
      button: true,
      enabled: true,
      label: '第 ${index + 1} 组类型：${setTypeLabels[set.type] ?? set.type}',
      child: InkWell(
        key: Key('set-type-${set.id}'),
        borderRadius: BorderRadius.circular(8),
        onTap: () => _showSetTypeSheet(context, controller, set, index),
        child: Container(
          constraints: BoxConstraints(
            minWidth: compact ? 31 : 43,
            minHeight: 44,
          ),
          padding: EdgeInsets.symmetric(horizontal: compact ? 1 : 3),
          child: Row(
            mainAxisSize: MainAxisSize.min,
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
        fillColor: completed ? const Color(0xFFE8F6EC) : Colors.white,
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
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    children: [
      AnimatedContainer(
        key: Key('set-row-${set.id}'),
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 3),
        decoration: BoxDecoration(
          color: set.completed ? successContainer : Colors.white,
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
                              value: controller.selectedSetIds.contains(set.id),
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
                          : '${_displayWeight(previous.weight)}×${previous.reps}';
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
                    key: ValueKey('weight-${set.id}-${set.weight}'),
                    initialValue: _editableWeight(set.weight),
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
                      set.weight = double.tryParse(value) ?? 0;
                      controller.persistActiveWorkout();
                    },
                  ),
                ),
                _cellGap(),
                SizedBox(
                  width: columns.reps,
                  child: TextFormField(
                    key: ValueKey('reps-${set.id}-${set.reps}'),
                    initialValue: _editableCount(set.reps),
                    enabled: true,
                    keyboardType: TextInputType.number,
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
                      set.reps = int.tryParse(value) ?? 0;
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
                      color: set.note.isEmpty
                          ? (set.completed ? const Color(0xFF1E6B45) : quiet)
                          : (set.completed ? const Color(0xFF1E6B45) : primary),
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
                              if (autoStarted) {
                                showKiloSnack(
                                  context,
                                  controller.restRunning
                                      ? '训练已开始，本组完成，休息计时已启动'
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
            const SizedBox(height: 4),
            Row(
              children: [
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
                          color: set.completed
                              ? const Color(0xFFDDF1E4)
                              : emberTint,
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.sticky_note_2_outlined,
                              size: 15,
                              color: set.completed
                                  ? const Color(0xFF1E6B45)
                                  : primary,
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

class _PlansView extends StatelessWidget {
  const _PlansView({required this.controller});
  final AppController controller;
  static const plans = <Plan>[
    Plan(
      id: 'upper-lower-4',
      title: '上下肢力量',
      subtitle: '力量与增肌并重，围绕主项双重渐进',
      days: 4,
      weeks: 12,
      level: '中级',
      focus: '力量 + 增肌',
      sessions: [
        PlanSession(
          day: '周一',
          name: '上肢力量',
          exercises: 6,
          duration: '65 分钟',
          exerciseIds: ['bench_press', 'chest_supported_row', 'shoulder_press'],
        ),
        PlanSession(
          day: '周二',
          name: '下肢力量',
          exercises: 5,
          duration: '70 分钟',
          exerciseIds: ['barbell_squat', 'romanian_deadlift', 'leg_curl'],
        ),
        PlanSession(
          day: '周四',
          name: '上肢容量',
          exercises: 7,
          duration: '60 分钟',
          exerciseIds: ['dumbbell_press', 'lat_pulldown', 'lateral_raise'],
        ),
      ],
    ),
    Plan(
      id: 'ppl-6',
      title: '推拉腿进阶',
      subtitle: '高频分化，适合恢复能力较好的训练者',
      days: 6,
      weeks: 8,
      level: '中高级',
      focus: '肌肥大',
      sessions: [
        PlanSession(
          day: '周一',
          name: '推 A',
          exercises: 6,
          duration: '58 分钟',
          exerciseIds: ['bench_press', 'shoulder_press', 'triceps_extension'],
        ),
        PlanSession(
          day: '周二',
          name: '拉 A',
          exercises: 6,
          duration: '60 分钟',
          exerciseIds: ['pull_up', 'row', 'biceps_curl'],
        ),
      ],
    ),
    Plan(
      id: 'full-body-3',
      title: '全身三日',
      subtitle: '低频率限制下保持每周肌群刺激',
      days: 3,
      weeks: 10,
      level: '中级',
      focus: '均衡增肌',
      sessions: [
        PlanSession(
          day: '周一',
          name: '全身 A',
          exercises: 6,
          duration: '62 分钟',
          exerciseIds: ['barbell_squat', 'bench_press', 'row'],
        ),
        PlanSession(
          day: '周三',
          name: '全身 B',
          exercises: 6,
          duration: '60 分钟',
          exerciseIds: ['deadlift', 'shoulder_press', 'lat_pulldown'],
        ),
      ],
    ),
  ];
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            key: const Key('free-workout-button'),
            onPressed: () {
              controller.startWorkout(name: '自由训练', autoStartTimer: false);
              controller.openLiveWorkout();
            },
            icon: const Icon(Icons.play_arrow),
            label: const Text('自由训练 · 立即开始'),
          ),
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
          (exercise) =>
              controller.displayExerciseName(findExercise(exercise.exerciseId)),
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
                  const Padding(
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
                  style: const TextStyle(fontSize: 12, color: quiet),
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
      style: const TextStyle(fontSize: 11, color: secondaryInk),
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
              const Icon(Icons.auto_awesome_outlined, color: cobalt),
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
                      style: const TextStyle(fontSize: 12, color: quiet),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: quiet),
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
        .map((id) => controller.displayExerciseName(findExercise(id)))
        .join(' · ');
    return Card(
      key: Key('record-tile-${record.id}'),
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: paper,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.event_available, color: cobalt),
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
                          style: const TextStyle(fontSize: 12, color: quiet),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: quiet),
                ],
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
                  style: const TextStyle(fontSize: 12, color: secondaryInk),
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
        color: set.completed ? const Color(0xFFE5F5EB) : Colors.white,
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
                  const SizedBox(height: 3),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.sticky_note_2_outlined,
                        size: 14,
                        color: statusColor,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          set.note.trim(),
                          style: TextStyle(fontSize: 11, color: statusColor),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
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
  AppController get controller => widget.controller;
  @override
  Widget build(BuildContext context) {
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
              const Row(
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
                              style: const TextStyle(
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
              const Wrap(
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
      Text(label, style: const TextStyle(fontSize: 11, color: quiet)),
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

  AppController get controller => widget.controller;

  @override
  Widget build(BuildContext context) {
    const groups = ['全部', '胸', '背', '肩', '腿', '手臂', '核心'];
    final items = controller.visibleExercises;
    final displayedItems = items.take(shownCount).toList(growable: false);
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final cardAspectRatio = textScale >= 1.5 ? .46 : .68;
    return PageFrame(
      children: [
        SectionTitle('动作库', subtitle: '${controller.allExercises.length} 个动作'),
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
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search),
                          hintText: '搜索动作、肌群或器械',
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
                              ? '器械'
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
                        tooltip: '新建自定义动作',
                        onPressed: () =>
                            _showCustomExercise(context, controller),
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
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(22),
                        child: Center(child: Text('没有匹配动作，试试清空搜索或筛选。')),
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
                                  aspectRatio: 1.18,
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      ColoredBox(
                                        color: paper,
                                        child: Image.asset(
                                          exerciseAsset(exercise.id),
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (context, error, stack) =>
                                                  const Icon(
                                                    Icons.fitness_center,
                                                    color: cobalt,
                                                    size: 34,
                                                  ),
                                        ),
                                      ),
                                      const Positioned(
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
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 7,
                                              vertical: 4,
                                            ),
                                            child: Text(
                                              '讲解',
                                              style: TextStyle(
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
                                        '${exercise.muscle} · ${exercise.equipment}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
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
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(13),
                border: Border.all(
                  color: controller.muscleFilter == group
                      ? const Color(0xFFF0A278)
                      : Colors.transparent,
                  width: controller.muscleFilter == group ? 1.5 : 1,
                ),
                boxShadow: controller.muscleFilter == group
                    ? const [
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
                        ? const BoxDecoration(
                            border: Border(
                              left: BorderSide(color: primary, width: 3),
                            ),
                          )
                        : null,
                    child: Text(
                      group,
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
      const SectionTitle('动作识别', subtitle: '上传视频并查看可解释报告'),
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
                        : const Icon(
                            Icons.document_scanner_outlined,
                            color: cobalt,
                          ),
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
                          style: const TextStyle(fontSize: 12, color: quiet),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (controller.selectedMediaPath != null) ...[
                const SizedBox(height: 14),
                _SelectedRecognitionVideo(
                  path: controller.selectedMediaPath!,
                  name: controller.selectedMediaName ?? '已选择视频',
                  sizeLabel: _formatBytes(controller.selectedMediaBytes),
                  enabled:
                      controller.recognitionStatus !=
                      RecognitionStatus.processing,
                  onClear: controller.resetRecognition,
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
                  color: const Color(0xFFF8EEE7),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.tips_and_updates_outlined,
                      size: 18,
                      color: primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        controller.selectedRecognitionCamera.hint,
                        style: const TextStyle(
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
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: hairline),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.accessibility_new_rounded,
                      size: 20,
                      color: primary,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '返回骨骼标注视频',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            '关闭后仅返回数据、文字和预览图',
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
                      const Icon(Icons.info_outline, size: 16, color: danger),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          controller.mediaError!,
                          style: const TextStyle(fontSize: 12, color: danger),
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
              const Icon(Icons.info_outline, color: quiet),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  '仅在点击开始分析后上传视频，用于生成骨骼识别报告。',
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
      style: const TextStyle(
        color: secondaryInk,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _SelectedRecognitionVideo extends StatefulWidget {
  const _SelectedRecognitionVideo({
    required this.path,
    required this.name,
    required this.sizeLabel,
    required this.enabled,
    required this.onClear,
  });

  final String path;
  final String name;
  final String sizeLabel;
  final bool enabled;
  final VoidCallback onClear;

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
          AspectRatio(
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
                      child: CircularProgressIndicator(color: Colors.white),
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
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(12, 8, 5, 8),
            child: Row(
              children: [
                const Icon(Icons.movie_outlined, size: 18, color: primary),
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
                        style: const TextStyle(fontSize: 10, color: quiet),
                      ),
                    ],
                  ),
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
        color: const Color(0xFFFFEEE3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF4C4A7)),
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
                      const CircularProgressIndicator(
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
                      style: const TextStyle(fontSize: 11, color: secondaryInk),
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
            style: const TextStyle(
              fontSize: 11,
              height: 1.45,
              color: secondaryInk,
            ),
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
            ? Colors.white
            : const Color(0xFFF3E8E1),
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
  RecognitionStage.preparing => '正在创建识别任务',
  RecognitionStage.uploading => '正在上传视频',
  RecognitionStage.queued => '视频已上传，等待服务器处理',
  RecognitionStage.analyzing => '正在分析动作轨迹',
  RecognitionStage.idle => '正在准备',
};

String _recognitionStageDetail(RecognitionStage stage) => switch (stage) {
  RecognitionStage.preparing => '正在检查登录状态和识别额度。',
  RecognitionStage.uploading => '请保持网络连接，上传完成后会自动进入处理队列。',
  RecognitionStage.queued => 'CPU Worker 正在领取任务，请勿重复提交。',
  RecognitionStage.analyzing => '正在逐帧提取骨骼关键点，短视频通常需要约 1 分钟。',
  RecognitionStage.idle => '正在连接识别服务。',
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
    final exercise = findExercise(capability.exerciseId);
    final selected = controller.recognitionExerciseId == capability.exerciseId;
    return Material(
      color: selected ? primaryContainer : Colors.white,
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
                      style: const TextStyle(fontSize: 10, color: quiet),
                    ),
                  ],
                ),
              ),
              if (selected)
                const Icon(Icons.check_circle, size: 18, color: primary),
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
    final exercise = findExercise(capability.exerciseId);
    return Material(
      color: primaryContainer.withValues(alpha: .55),
      borderRadius: BorderRadius.circular(18),
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
                      style: const TextStyle(fontSize: 11, color: quiet),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.swap_horiz_rounded, color: primary),
              const SizedBox(width: 4),
              const Text(
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
      final exercise = findExercise(item.exerciseId);
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
                const Expanded(
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
                      decoration: const BoxDecoration(
                        color: Color(0xFFFFF2E8),
                        borderRadius: BorderRadius.all(Radius.circular(14)),
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
                          style: const TextStyle(color: quiet, fontSize: 11),
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
      color: selected ? primaryContainer : Colors.white,
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
          title: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('动作分析报告'),
              Text(
                '视频、骨骼标注与 AI 评价',
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
              if (controller.selectedMediaPath != null)
                _SelectedRecognitionVideo(
                  path: controller.selectedMediaPath!,
                  name: controller.selectedMediaName ?? '原始视频',
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
                  onPressed: controller.startRecognition,
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
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: result.status == RecognitionStatus.complete
          ? const Color(0xFFEFF8DE)
          : paper,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              result.status == RecognitionStatus.complete
                  ? '分析完成'
                  : result.status == RecognitionStatus.lowConfidence
                  ? '低置信度'
                  : result.status == RecognitionStatus.offline
                  ? '离线'
                  : '识别错误',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const Spacer(),
            if (result.confidence > 0)
              Text(
                '${(result.confidence * 100).round()}%',
                style: const TextStyle(
                  color: cobalt,
                  fontWeight: FontWeight.w800,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(result.summary, style: const TextStyle(fontSize: 13)),
        if (result.repetitions > 0)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              '检测到 ${result.repetitions} 次重复 · ${controller.displayExerciseName(findExercise(controller.recognitionExerciseId))}',
              style: const TextStyle(fontSize: 12, color: secondaryInk),
            ),
          ),
        if (result.overlayUrl != null) ...[
          const SizedBox(height: 14),
          const Text(
            '骨骼标注视频',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
          ),
          const SizedBox(height: 7),
          _NetworkRecognitionVideo(
            url: result.overlayUrl!,
            headers: result.mediaHeaders,
          ),
        ],
        if (result.metrics.isNotEmpty) ...[
          const SizedBox(height: 14),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              if (result.metrics['durationSeconds'] != null)
                _RecognitionMetricChip(
                  icon: Icons.timer_outlined,
                  label: '${result.metrics['durationSeconds']} 秒',
                ),
              if (result.metrics['detectionRate'] is num)
                _RecognitionMetricChip(
                  icon: Icons.accessibility_new_rounded,
                  label:
                      '骨骼捕获 ${((result.metrics['detectionRate'] as num) * 100).round()}%',
                ),
              if (result.repetitions > 0)
                _RecognitionMetricChip(
                  icon: Icons.repeat_rounded,
                  label: '${result.repetitions} 次',
                ),
            ],
          ),
        ],
        const SizedBox(height: 15),
        _RecognitionAiReviewCard(result: result),
        if (result.status == RecognitionStatus.complete ||
            result.status == RecognitionStatus.lowConfidence)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: controller.saveRecognitionCue,
              icon: Icon(
                controller.savedCue ? Icons.bookmark : Icons.bookmark_border,
              ),
              label: Text(controller.savedCue ? '已保存提示' : '保存到下一组'),
            ),
          ),
      ],
    ),
  );
}

class _RecognitionMetricChip extends StatelessWidget {
  const _RecognitionMetricChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: hairline),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: primary),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    ),
  );
}

class _RecognitionAiReviewCard extends StatelessWidget {
  const _RecognitionAiReviewCard({required this.result});
  final RecognitionResult result;

  @override
  Widget build(BuildContext context) {
    final review = result.aiReview;
    return Container(
      key: const Key('recognition-ai-review'),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF1C8AB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.auto_awesome_rounded, color: primary, size: 19),
              SizedBox(width: 7),
              Text(
                'AI 动作评价',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (review == null)
            Text(
              result.aiReviewError == 'deepseek_not_configured'
                  ? 'AI 服务尚未配置，本次骨骼识别数据已保留。'
                  : 'AI 评价暂时不可用，骨骼识别结果不受影响。',
              style: const TextStyle(color: secondaryInk),
            )
          else ...[
            Text(
              review.headline,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            if (review.strengths.isNotEmpty) ...[
              const SizedBox(height: 9),
              const Text(
                '做得好的地方',
                style: TextStyle(color: success, fontWeight: FontWeight.w800),
              ),
              for (final item in review.strengths)
                _RecognitionReviewBullet(text: item, positive: true),
            ],
            if (review.risks.isNotEmpty) ...[
              const SizedBox(height: 7),
              const Text(
                '下一步需要关注',
                style: TextStyle(color: primary, fontWeight: FontWeight.w800),
              ),
              for (final item in review.risks)
                _RecognitionReviewBullet(text: item, positive: false),
            ],
            if (review.nextSet.trim().isNotEmpty) ...[
              const SizedBox(height: 9),
              Text(
                '下一组建议：${review.nextSet}',
                style: const TextStyle(height: 1.45),
              ),
            ],
            if (review.basis.trim().isNotEmpty) ...[
              const SizedBox(height: 7),
              Text(
                '判断依据：${review.basis}',
                style: const TextStyle(color: quiet, fontSize: 11),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _RecognitionReviewBullet extends StatelessWidget {
  const _RecognitionReviewBullet({required this.text, required this.positive});
  final String text;
  final bool positive;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          positive ? Icons.check_circle_outline : Icons.adjust_rounded,
          size: 15,
          color: positive ? success : primary,
        ),
        const SizedBox(width: 6),
        Expanded(child: Text(text, style: const TextStyle(height: 1.35))),
      ],
    ),
  );
}

class _NetworkRecognitionVideo extends StatefulWidget {
  const _NetworkRecognitionVideo({required this.url, required this.headers});
  final String url;
  final Map<String, String> headers;

  @override
  State<_NetworkRecognitionVideo> createState() =>
      _NetworkRecognitionVideoState();
}

class _NetworkRecognitionVideoState extends State<_NetworkRecognitionVideo> {
  VideoPlayerController? _video;
  File? _localFile;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      final client = HttpClient();
      final request = await client.getUrl(Uri.parse(widget.url));
      widget.headers.forEach(request.headers.set);
      final response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        client.close(force: true);
        throw HttpException('media_http_${response.statusCode}');
      }
      final safeId = widget.url.hashCode.toUnsigned(32).toRadixString(16);
      final file = File(
        '${Directory.systemTemp.path}${Platform.pathSeparator}kilo-overlay-$safeId.mp4',
      );
      final sink = file.openWrite();
      await response.pipe(sink);
      client.close();
      _localFile = file;
      final video = VideoPlayerController.file(file);
      await video.initialize();
      await video.setLooping(true);
      if (!mounted) {
        await video.dispose();
        return;
      }
      setState(() => _video = video);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  @override
  void dispose() {
    _video?.dispose();
    final localFile = _localFile;
    if (localFile != null) {
      localFile.delete().catchError((_) => localFile);
    }
    super.dispose();
  }

  Future<void> _retry() async {
    await _video?.dispose();
    setState(() {
      _video = null;
      _error = null;
    });
    await _initialize();
  }

  @override
  Widget build(BuildContext context) {
    final video = _video;
    return Container(
      key: const Key('recognition-overlay-video'),
      decoration: BoxDecoration(
        color: const Color(0xFF211A17),
        borderRadius: BorderRadius.circular(13),
      ),
      clipBehavior: Clip.antiAlias,
      child: AspectRatio(
        aspectRatio:
            video?.value.isInitialized == true && video!.value.aspectRatio > 0
            ? video.value.aspectRatio
            : 16 / 9,
        child: InkWell(
          onTap: video?.value.isInitialized == true
              ? () => setState(() {
                  video!.value.isPlaying ? video.pause() : video.play();
                })
              : null,
          child: Stack(
            fit: StackFit.expand,
            alignment: Alignment.center,
            children: [
              if (video?.value.isInitialized == true)
                VideoPlayer(video!)
              else
                const ColoredBox(color: Color(0xFF211A17)),
              if (video == null && _error == null)
                const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              if (_error != null)
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        '标注视频加载失败',
                        style: TextStyle(color: Colors.white),
                      ),
                      const SizedBox(height: 7),
                      OutlinedButton.icon(
                        onPressed: _retry,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white70),
                        ),
                        icon: const Icon(Icons.refresh_rounded, size: 17),
                        label: const Text('重新加载'),
                      ),
                    ],
                  ),
                ),
              if (video?.value.isInitialized == true &&
                  video?.value.isPlaying != true)
                const Center(
                  child: CircleAvatar(
                    radius: 25,
                    backgroundColor: Color(0xE6D95718),
                    child: Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ),
              const Positioned(
                left: 9,
                bottom: 8,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Color(0xB3000000),
                    borderRadius: BorderRadius.all(Radius.circular(8)),
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    child: Text(
                      '骨骼标注结果 · 点击播放',
                      style: TextStyle(color: Colors.white, fontSize: 10),
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
}

String _recognitionLabel(RecognitionStatus status) => switch (status) {
  RecognitionStatus.idle => '选择一个视频开始',
  RecognitionStatus.ready => '视频已就绪',
  RecognitionStatus.processing => '正在分析动作轨迹',
  RecognitionStatus.complete => '分析完成 · 置信度良好',
  RecognitionStatus.lowConfidence => '分析完成 · 置信度较低',
  RecognitionStatus.offline => '离线 · 已保留本地任务',
  RecognitionStatus.error => '识别失败 · 可以重试',
};
String _recognitionDetail(AppController controller) =>
    controller.recognitionStatus == RecognitionStatus.idle
    ? '选择动作、机位和本地视频后开始请求识别服务。'
    : controller.recognitionStatus == RecognitionStatus.processing
    ? '逐帧提取姿态关键点，请保持应用打开。'
    : controller.recognitionResult?.error == 'service_not_configured'
    ? '识别服务未配置，请在设置中配置服务后重试。'
    : '识别服务已返回状态，可在报告中查看结果。';
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
    final text = input.text;
    if (text.trim().isEmpty) return;
    input.clear();
    FocusManager.instance.primaryFocus?.unfocus();
    followLatest = true;
    final contexts = selectedContexts.toList(growable: false);
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
    final recognition = controller.aiView == AiView.recognition;
    if (controller.chat.length != lastMessageCount) {
      lastMessageCount = controller.chat.length;
      if (followLatest) _scrollToLatest();
    }
    return Scaffold(
      key: const Key('ai-page'),
      drawer: recognition ? null : _AiDrawer(controller: controller),
      body: SafeArea(
        child: Column(
          children: [
            _AiTopTabs(controller: controller),
            if (recognition)
              Expanded(child: RecognitionPage(controller: controller))
            else ...[
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
                      const Expanded(
                        child: Text(
                          'AI 问答',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
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
                    if (controller.chat.isEmpty && !controller.aiTyping)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 10),
                        child: Text(
                          '尚无对话。发送一个问题开始。',
                          style: TextStyle(color: quiet, fontSize: 12),
                        ),
                      ),
                    for (final message in controller.chat)
                      _ChatBubble(message: message, controller: controller),
                    if (controller.aiTyping) const _ThinkingIndicator(),
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
                      if (selectedContexts.isNotEmpty)
                        SizedBox(
                          height: 34,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: selectedContexts.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(width: 6),
                            itemBuilder: (context, index) {
                              final item = selectedContexts.elementAt(index);
                              return InputChip(
                                label: Text(item.label),
                                onDeleted: () => setState(
                                  () => selectedContexts.remove(item),
                                ),
                                visualDensity: VisualDensity.compact,
                              );
                            },
                          ),
                        ),
                      if (selectedContexts.isNotEmpty)
                        const SizedBox(height: 5),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          IconButton.filledTonal(
                            key: const Key('ai-add-context'),
                            tooltip: '添加训练上下文',
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
                            onPressed: controller.aiTyping
                                ? null
                                : _sendMessage,
                            icon: const Icon(Icons.arrow_upward),
                          ),
                        ],
                      ),
                    ],
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

class _AiContextPicker extends StatefulWidget {
  const _AiContextPicker({required this.controller, required this.initial});
  final AppController controller;
  final Set<AiContextSelection> initial;

  @override
  State<_AiContextPicker> createState() => _AiContextPickerState();
}

class _AiContextPickerState extends State<_AiContextPicker> {
  late final Set<AiContextSelection> selected = {...widget.initial};

  IconData _icon(AiContextType type) => switch (type) {
    AiContextType.activeWorkout => Icons.fitness_center,
    AiContextType.workoutRecord => Icons.history,
    AiContextType.routine => Icons.menu_book_outlined,
    AiContextType.week => Icons.view_week_outlined,
    AiContextType.month => Icons.calendar_month_outlined,
  };

  String _subtitle(AiContextType type) => switch (type) {
    AiContextType.activeWorkout => '动作、完成组、重量与当前备注',
    AiContextType.workoutRecord => '一次已完成训练的完整明细',
    AiContextType.routine => '计划动作、目标重量、次数与休息',
    AiContextType.week => '本周频率、容量、肌群和备注',
    AiContextType.month => '本月趋势、PR、容量和完成情况',
  };

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
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '添加训练上下文',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text('只随下一条消息发送', style: TextStyle(color: quiet)),
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
                      return Card(
                        margin: const EdgeInsets.only(bottom: 7),
                        child: CheckboxListTile(
                          value: checked,
                          onChanged: (value) => setState(() {
                            if (value == true) {
                              selected.add(item);
                            } else {
                              selected.remove(item);
                            }
                          }),
                          secondary: CircleAvatar(
                            backgroundColor: emberTint,
                            foregroundColor: primary,
                            child: Icon(_icon(item.type), size: 20),
                          ),
                          title: Text(
                            item.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          subtitle: Text(_subtitle(item.type)),
                          controlAffinity: ListTileControlAffinity.trailing,
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
                icon: const Icon(Icons.add_comment_outlined),
                label: Text(
                  selected.isEmpty ? '不添加上下文' : '添加 ${selected.length} 项',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AiTopTabs extends StatelessWidget {
  const _AiTopTabs({required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    if (controller.aiView.index >= 0) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: _UnderlineTabs(
          key: const Key('ai-top-tabs'),
          labels: const ['\u95EE\u7B54', '\u52A8\u4F5C\u8BC6\u522B'],
          items: [
            _UnderlineTab(
              label: 'ai-chat',
              selected: controller.aiView == AiView.chat,
              onTap: () => controller.selectAiView(AiView.chat),
            ),
            _UnderlineTab(
              label: 'ai-recognition',
              selected: controller.aiView == AiView.recognition,
              onTap: () => controller.selectAiView(AiView.recognition),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
      child: SegmentedButton<AiView>(
        key: const Key('ai-top-tabs'),
        segments: const [
          ButtonSegment(value: AiView.chat, label: Text('问答')),
          ButtonSegment(value: AiView.recognition, label: Text('动作识别')),
        ],
        selected: {controller.aiView},
        onSelectionChanged: (value) => controller.selectAiView(value.first),
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
            leading: const Icon(Icons.tune, color: cobalt),
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
              const Text(
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
                title: const Text('允许使用训练摘要'),
                subtitle: const Text('仅在授权后将训练记录作为上下文。'),
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
            Text(
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
                p: const TextStyle(color: ink, height: 1.45, fontSize: 14),
                h1: const TextStyle(
                  color: ink,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
                h2: const TextStyle(
                  color: ink,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
                h3: const TextStyle(
                  color: ink,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
                strong: const TextStyle(
                  color: ink,
                  fontWeight: FontWeight.w900,
                ),
                listBullet: const TextStyle(color: primary, fontSize: 15),
                a: const TextStyle(
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
                      const Expanded(
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
                              style: const TextStyle(
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
  const _ThinkingIndicator();

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
          const Text(
            '正在思考中',
            style: TextStyle(
              color: muted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
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
            const Icon(Icons.calendar_month_outlined, size: 18, color: primary),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                plan.title,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            Text(
              '${plan.weeks} 周',
              style: const TextStyle(fontSize: 11, color: muted),
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
                        style: const TextStyle(
                          fontSize: 12,
                          color: secondaryInk,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const Icon(Icons.chevron_right, size: 17, color: muted),
                  ],
                ),
              ),
            ),
          ),
        Text(
          totalSets > 0
              ? '$totalExercises 个动作 · $totalSets 组 · 已含重量/次数/休息'
              : '$totalExercises 个动作 · 旧计划未包含组次处方',
          style: const TextStyle(fontSize: 11, color: muted),
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
          style: const TextStyle(color: muted),
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
                      style: const TextStyle(color: muted, fontSize: 12),
                    ),
                  ],
                  const SizedBox(height: 10),
                  if (session.exercises.isEmpty)
                    const Text(
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
                        title: Text(findExercise(exerciseId).name),
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
                    style: const TextStyle(color: muted, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
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
                    style: const TextStyle(fontSize: 11, color: muted),
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
                  style: const TextStyle(fontSize: 12, color: primary),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _AccountMembershipCard extends StatelessWidget {
  const _AccountMembershipCard({required this.controller});

  final AppController controller;

  String _membershipLabel(MembershipPlan plan) => switch (plan) {
    MembershipPlan.free => '\u514d\u8d39\u8d26\u53f7',
    MembershipPlan.oneMonth => '1 \u4e2a\u6708\u4f1a\u5458',
    MembershipPlan.threeMonths => '3 \u4e2a\u6708\u4f1a\u5458',
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
            '\u767b\u5f55\u540e\u540c\u6b65\u4f1a\u5458\u4e0e AI \u989d\u5ea6',
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
                    Container(
                      width: 56,
                      height: 56,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: ink,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Text(
                        user.displayName.isEmpty
                            ? 'K'
                            : user.displayName.substring(0, 1),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
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
                            style: const TextStyle(
                              color: primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
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
                      const SizedBox(height: 12),
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
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 330 || textScale > 1.5;
                final ai = _QuotaMetric(
                  icon: Icons.auto_awesome_outlined,
                  label: 'AI 问答',
                  value: '${quota.aiRemaining} / ${quota.aiDailyLimit}',
                  caption: '今日剩余',
                );
                final recognition = _QuotaMetric(
                  icon: Icons.center_focus_strong_outlined,
                  label: '动作识别',
                  value: '${quota.recognitionRemaining}',
                  caption: '当前可用',
                );
                return compact
                    ? Column(
                        children: [ai, const Divider(height: 20), recognition],
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: ai),
                          const SizedBox(
                            height: 64,
                            child: VerticalDivider(width: 24),
                          ),
                          Expanded(child: recognition),
                        ],
                      );
              },
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    key: const Key('redeem-membership-button'),
                    onPressed: () => _showRedeemDialog(context, controller),
                    icon: const Icon(Icons.confirmation_number_outlined),
                    label: const Text('会员与兑换'),
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
              const Divider(height: 24),
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
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton(
                    key: const Key('admin-grant-membership-button'),
                    onPressed: () => _showAdminGrantDialog(context, controller),
                    child: const Text('\u5f00\u901a\u4f1a\u5458'),
                  ),
                  OutlinedButton(
                    key: const Key('admin-generate-code-button'),
                    onPressed: () => _showAdminCodeDialog(context, controller),
                    child: const Text('\u751f\u6210\u5151\u6362\u7801'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _QuotaMetric extends StatelessWidget {
  const _QuotaMetric({
    required this.icon,
    required this.label,
    required this.value,
    required this.caption,
  });

  final IconData icon;
  final String label;
  final String value;
  final String caption;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: primaryContainer,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Icon(icon, color: primary, size: 18),
      ),
      const SizedBox(width: 9),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 20,
                color: ink,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(caption, style: const TextStyle(fontSize: 11, color: quiet)),
          ],
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
        const SizedBox(height: 18),
        const _ProfileSectionLabel(
          title: '训练资产',
          icon: Icons.bar_chart_rounded,
        ),
        const SizedBox(height: 9),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
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
        const SizedBox(height: 18),
        const _ProfileSectionLabel(title: '个性化', icon: Icons.tune_rounded),
        const SizedBox(height: 9),
        LayoutBuilder(
          builder: (context, constraints) {
            final textScale = MediaQuery.textScalerOf(context).scale(1);
            final singleColumn = constraints.maxWidth < 330 || textScale > 1.45;
            return GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: singleColumn ? 1 : 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              mainAxisExtent: singleColumn
                  ? (textScale > 1.45 ? 124 : 96)
                  : (textScale > 1.2 ? 132 : 116),
              children: [
                _ProfileQuickAction(
                  icon: Icons.insights_rounded,
                  title: '训练进步',
                  caption: '趋势、肌群与记录',
                  onTap: () => _showProgress(context, controller),
                ),
                _ProfileQuickAction(
                  icon: Icons.timer_outlined,
                  title: '默认休息',
                  caption: '${controller.defaultRestSeconds} 秒',
                  onTap: () => _showWorkoutSettings(context, controller),
                ),
                _ProfileQuickAction(
                  key: const Key('exercise-name-language-setting'),
                  icon: Icons.translate_rounded,
                  title: '动作语言',
                  caption:
                      controller.exerciseNameLanguage ==
                          ExerciseNameLanguage.english
                      ? 'English'
                      : '简体中文',
                  onTap: () =>
                      _showExerciseNameLanguageSheet(context, controller),
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
        const SizedBox(height: 18),
        const _ProfileSectionLabel(title: '服务与安全', icon: Icons.shield_outlined),
        const SizedBox(height: 9),
        Card(
          child: Column(
            children: [
              _ProfileSettingRow(
                icon: Icons.lock_clock_outlined,
                title: '锁屏实时活动',
                caption: '训练总时长与组间休息',
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
                caption: controller.appleWatch ? '训练状态同步已开启' : '尚未开启设备同步',
                trailing: Switch(
                  value: controller.appleWatch,
                  onChanged: (value) {
                    controller.appleWatch = value;
                    controller.refresh();
                  },
                ),
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
              const _ProfileSettingRow(
                key: Key('app-version-row'),
                icon: Icons.info_outline,
                title: '关于形域',
                caption: '版本 $kiloAppVersionLabel · $kiloAppNavigationLabel',
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
      Icon(icon, size: 18, color: primary),
      const SizedBox(width: 7),
      Text(title, style: Theme.of(context).textTheme.titleLarge),
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
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
        ),
      ),
      Text(label, style: const TextStyle(fontSize: 11, color: quiet)),
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
      side: const BorderSide(color: hairline),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: primaryContainer,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, size: 18, color: primary),
            ),
            const SizedBox(width: 10),
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
                    caption,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: quiet),
                  ),
                ],
              ),
            ),
            trailing ?? const Icon(Icons.chevron_right, size: 18, color: quiet),
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
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
    leading: Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: primaryContainer,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Icon(icon, size: 18, color: primary),
    ),
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
    subtitle: Text(caption, maxLines: 3, overflow: TextOverflow.ellipsis),
    trailing:
        trailing ?? (onTap == null ? null : const Icon(Icons.chevron_right)),
    onTap: onTap,
  );
}

void _showRedeemDialog(BuildContext context, AppController controller) {
  final code = TextEditingController();
  showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('\u5151\u6362\u4f1a\u5458'),
      content: TextField(
        controller: code,
        autofocus: true,
        textCapitalization: TextCapitalization.characters,
        decoration: const InputDecoration(
          labelText: '\u4e00\u6b21\u6027\u5151\u6362\u7801',
          hintText: 'KILO1-…',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('\u53d6\u6d88'),
        ),
        FilledButton(
          key: const Key('redeem-submit-button'),
          onPressed: () {
            final result = controller.redeemCode(code.text);
            if (result.isSuccess) {
              Navigator.pop(dialogContext);
              showKiloSnack(context, '\u5151\u6362\u6210\u529f');
            } else {
              showKiloSnack(
                context,
                _accountErrorMessage(result.error),
                error: true,
              );
            }
          },
          child: const Text('\u5151\u6362'),
        ),
      ],
    ),
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
            onPressed: () {
              final result = controller.grantMembership(
                identifier: identifier.text,
                plan: plan,
              );
              if (result.isSuccess) {
                Navigator.pop(dialogContext);
                showKiloSnack(
                  context,
                  '\u5df2\u4e3a\u7528\u6237\u5f00\u901a\u4f1a\u5458',
                );
              } else {
                showKiloSnack(
                  context,
                  _accountErrorMessage(result.error),
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

String _accountErrorMessage(AccountError error) => switch (error) {
  AccountError.emptyIdentifier => '\u8bf7\u8f93\u5165\u7528\u6237\u6807\u8bc6',
  AccountError.invalidCode => '\u5151\u6362\u7801\u65e0\u6548',
  AccountError.codeAlreadyUsed => '\u5151\u6362\u7801\u5df2\u4f7f\u7528',
  AccountError.quotaExhausted => '\u989d\u5ea6\u4e0d\u8db3',
  AccountError.adminRequired => '\u4ec5\u7ba1\u7406\u5458\u53ef\u64cd\u4f5c',
  AccountError.notAuthenticated => '\u8bf7\u5148\u767b\u5f55',
  _ => '\u64cd\u4f5c\u5931\u8d25',
};

void _showExerciseNameLanguageSheet(
  BuildContext context,
  AppController controller,
) {
  showModalBottomSheet<void>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ListTile(
            title: Text('动作名称语言'),
            subtitle: Text('仅控制动作名称显示，其他界面保持中文'),
          ),
          RadioListTile<ExerciseNameLanguage>(
            key: const Key('exercise-name-language-zh'),
            value: ExerciseNameLanguage.chinese,
            // ignore: deprecated_member_use
            groupValue: controller.exerciseNameLanguage,
            title: const Text('简体中文'),
            // ignore: deprecated_member_use
            onChanged: (value) {
              if (value != null) controller.setExerciseNameLanguage(value);
              Navigator.pop(sheetContext);
            },
          ),
          RadioListTile<ExerciseNameLanguage>(
            key: const Key('exercise-name-language-en'),
            value: ExerciseNameLanguage.english,
            // ignore: deprecated_member_use
            groupValue: controller.exerciseNameLanguage,
            title: const Text('English'),
            // ignore: deprecated_member_use
            onChanged: (value) {
              if (value != null) controller.setExerciseNameLanguage(value);
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

void _showPlateCalculator(BuildContext context) {
  final weight = TextEditingController(text: '80');
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        final total = double.tryParse(weight.text) ?? 0;
        final perSide = ((total - 20) / 2).clamp(0, double.infinity);
        final plates = <double>[20, 10, 5, 2.5, 1.25];
        var remaining = perSide;
        final counts = <double, int>{};
        for (final plate in plates) {
          counts[plate] = (remaining / plate).floor();
          remaining -= counts[plate]! * plate;
        }
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '杠片计算器',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                const Text(
                  '按 20 kg 杠铃计算每侧配置，结果仅作装片提示。',
                  style: TextStyle(color: quiet),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: weight,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: '目标总重量（kg）'),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                Text(
                  '每侧约 ${perSide.toStringAsFixed(2)} kg',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: cobalt,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final plate in plates)
                      if ((counts[plate] ?? 0) > 0)
                        Chip(
                          label: Text(
                            '${counts[plate]} × ${plate.toStringAsFixed(2)} kg',
                          ),
                        ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
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
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: '重量（kg，可选）',
                        suffixText: 'kg',
                      ),
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
                    weight: double.tryParse(weight.text),
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

  List<WorkoutSet> get completedSets => matchingRecords
      .expand(setsFor)
      .where((set) => set.completed && set.reps > 0)
      .toList();

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
            style: const TextStyle(color: quiet, fontSize: 11),
          ),
        ],
      ],
    );
  }

  Widget _buildHistory(List<WorkoutRecord> records) {
    if (records.isEmpty) {
      return const _DetailBlock(
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
                            style: const TextStyle(color: quiet, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (setsFor(record).isEmpty)
                      const Text(
                        '这条旧记录未保存该动作的组明细，仅保留训练日期。',
                        style: TextStyle(color: quiet, fontSize: 12),
                      )
                    else
                      for (final set in setsFor(record))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: Text(
                            '${_weight(set.weight)} × ${set.reps}'
                            '${set.note.trim().isEmpty ? '' : '\n备注：${set.note.trim()}'}',
                          ),
                        ),
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
        color: Colors.white,
        border: Border.all(color: hairline),
      ),
      child: media == null
          ? Image.asset(
              exerciseAsset(exercise.id),
              fit: BoxFit.contain,
              errorBuilder: (context, error, stack) =>
                  const Icon(Icons.fitness_center, size: 52, color: cobalt),
            )
          : Image.asset(
              media!.gifPath,
              key: Key('exercise-detail-gif-${exercise.id}'),
              fit: BoxFit.contain,
              errorBuilder: (context, error, stack) => Image.asset(
                media!.imagePath,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stack) =>
                    const Icon(Icons.fitness_center, size: 52, color: cobalt),
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
      color: Colors.white,
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: hairline),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      child: Text(
        label,
        style: const TextStyle(fontSize: 12, color: secondaryInk),
      ),
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
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: hairline),
    ),
    child: Padding(
      padding: const EdgeInsets.all(11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: const TextStyle(color: quiet, fontSize: 12)),
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
      color: Colors.white,
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
              const Text(
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
                      style: const TextStyle(fontSize: 11, color: quiet),
                    ),
                    Text(
                      '${records.last.date.month}/${records.last.date.day} · ${records.last.volume.toStringAsFixed(0)} kg',
                      style: const TextStyle(fontSize: 11, color: quiet),
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
                      controller.displayExerciseName(findExercise(exerciseId)),
                    ),
                    subtitle: const Text('最近一次完成 · 结合组别类型和重量复盘'),
                    trailing: const Icon(Icons.trending_up, color: cobalt),
                  ),
                const SizedBox(height: 8),
                Text(
                  changeRate >= 0
                      ? '你的训练量正在上升。下一次优先保持动作质量，再让正式组增加 1–2 次或小幅加重。'
                      : '训练量暂时回落，不必急着追重量。先检查恢复、有效组和最近动作完成质量。',
                  style: const TextStyle(color: secondaryInk),
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
    decoration: const BoxDecoration(
      color: paper,
      borderRadius: BorderRadius.all(Radius.circular(10)),
    ),
    child: Padding(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: quiet)),
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
          const Text(
            '0–600 秒；设置为 0 时完成组不启动休息通知。',
            style: TextStyle(color: quiet),
          ),
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
    return widget.controller.allExercises.where((item) {
      final queryMatch =
          needle.isEmpty ||
          item.name.toLowerCase().contains(needle) ||
          item.englishName.toLowerCase().contains(needle) ||
          item.equipment.toLowerCase().contains(needle);
      final muscleMatch =
          muscle == '全部' ||
          widget.controller.muscleGroupFor(item.muscle) == muscle;
      final equipmentMatch = equipment == '全部' || item.equipment == equipment;
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
    final equipments =
        <String>{
          '全部',
          for (final item in widget.controller.allExercises) item.equipment,
        }.toList()..sort(
          (a, b) => a == '全部'
              ? -1
              : b == '全部'
              ? 1
              : a.compareTo(b),
        );
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
                IconButton(
                  tooltip: '关闭动作选择',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    key: const Key('exercise-picker-muscle-strip'),
                    width: 82,
                    child: DecoratedBox(
                      decoration: const BoxDecoration(
                        color: Color(0xFFFFF2E8),
                        borderRadius: BorderRadius.all(Radius.circular(14)),
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
                          style: const TextStyle(fontSize: 11, color: quiet),
                        ),
                        const SizedBox(height: 3),
                        Expanded(
                          child: items.isEmpty
                              ? const Center(
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
      style: const TextStyle(
        color: quiet,
        fontSize: 10,
        fontWeight: FontWeight.w800,
      ),
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
    padding: const EdgeInsets.only(bottom: 4),
    child: Material(
      color: selected ? primary : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
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
              color: selected ? Colors.white : secondaryInk,
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
          leading: const Icon(Icons.calculate_outlined),
          title: const Text('杠片计算器'),
          onTap: () {
            Navigator.pop(context);
            _showPlateCalculator(context);
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

void _showWorkoutSettings(BuildContext context, AppController controller) {
  showModalBottomSheet<void>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setSheetState) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '训练设置',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 14),
              Text('默认组间休息：${controller.defaultRestSeconds} 秒'),
              Slider(
                value: controller.defaultRestSeconds.toDouble(),
                min: 30,
                max: 300,
                divisions: 9,
                onChanged: (value) {
                  controller.defaultRestSeconds = value.round();
                  setSheetState(() {});
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    ),
  );
}

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

  String _duration() {
    final minutes = record.durationSeconds ~/ 60;
    final seconds = record.durationSeconds % 60;
    if (minutes == 0) return '$seconds 秒';
    return seconds == 0 ? '$minutes 分钟' : '$minutes 分 $seconds 秒';
  }

  String _volume() =>
      '${record.volume.toStringAsFixed(record.volume % 1 == 0 ? 0 : 1)} kg';

  String _completionRate() {
    final total = record.exercises.expand((exercise) => exercise.sets).length;
    if (total == 0) return '—';
    final completed = record.exercises
        .expand((exercise) => exercise.sets)
        .where((set) => set.completed)
        .length;
    return '${(completed * 100 / total).round()}%';
  }

  String _primaryMuscles() {
    final counts = <String, int>{};
    for (final exerciseId in record.exerciseIds) {
      final group = controller.muscleGroupFor(findExercise(exerciseId).muscle);
      counts[group] = (counts[group] ?? 0) + 1;
    }
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.isEmpty
        ? '—'
        : sorted.take(2).map((item) => item.key).join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    final metrics = <(String, String, IconData)>[
      ('训练时长', _duration(), Icons.timer_outlined),
      ('训练容量', _volume(), Icons.fitness_center_outlined),
      ('有效组数', '${record.effectiveSets}', Icons.check_circle_outline),
      ('主要肌群', _primaryMuscles(), Icons.accessibility_new),
      ('本次 PR', '${record.prs.length}', Icons.emoji_events_outlined),
      ('完成率', _completionRate(), Icons.task_alt_outlined),
    ];
    final hero = reducedMotion
        ? Container(
            key: const Key('workout-celebration-burst'),
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: const Color(0xFFE5F5EB),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF6DB787), width: 2),
            ),
            child: const Icon(
              Icons.check_circle,
              color: Color(0xFF1E6B45),
              size: 48,
            ),
          )
        : TweenAnimationBuilder<double>(
            key: const Key('workout-celebration-burst'),
            tween: Tween(begin: .72, end: 1),
            duration: const Duration(milliseconds: 950),
            curve: Curves.easeOutBack,
            builder: (context, progress, _) => Transform.scale(
              scale: progress,
              child: Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5F5EB),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1E6B45).withValues(alpha: .24),
                      blurRadius: 22 * progress,
                      spreadRadius: 4 * progress,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: Color(0xFF1E6B45),
                  size: 48,
                ),
              ),
            ),
          );
    final particleLayer = reducedMotion
        ? const SizedBox.shrink()
        : Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 180,
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
    return Dialog.fullscreen(
      key: const Key('workout-celebration'),
      backgroundColor: paper,
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 28, 18, 22),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - 50,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(child: hero),
                      const SizedBox(height: 18),
                      Text(
                        '训练完成',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w900, color: ink),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        record.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: secondaryInk),
                      ),
                      const SizedBox(height: 20),
                      LayoutBuilder(
                        builder: (context, metricConstraints) {
                          final width = (metricConstraints.maxWidth - 10) / 2;
                          return Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              for (
                                var index = 0;
                                index < metrics.length;
                                index++
                              )
                                _CelebrationMetricReveal(
                                  index: index,
                                  reducedMotion: reducedMotion,
                                  child: SizedBox(
                                    width: width,
                                    child: Card(
                                      margin: EdgeInsets.zero,
                                      child: Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Icon(
                                              metrics[index].$3,
                                              color: cobalt,
                                              size: 20,
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              metrics[index].$1,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: quiet,
                                                fontSize: 12,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              metrics[index].$2,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: ink,
                                                fontSize: 19,
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 18),
                      _CelebrationExerciseSummary(
                        controller: controller,
                        record: record,
                      ),
                      const SizedBox(height: 22),
                      if (constraints.maxWidth < 380)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            OutlinedButton.icon(
                              key: const Key('workout-celebration-records'),
                              onPressed: () {
                                Navigator.pop(context);
                                controller.selectPage(PageId.records);
                              },
                              icon: const Icon(Icons.history),
                              label: const Text('查看记录'),
                            ),
                            const SizedBox(height: 8),
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
                        )
                      else
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                key: const Key('workout-celebration-records'),
                                onPressed: () {
                                  Navigator.pop(context);
                                  controller.selectPage(PageId.records);
                                },
                                icon: const Icon(Icons.history),
                                label: const Text('查看记录'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: FilledButton.icon(
                                key: const Key('workout-celebration-done'),
                                onPressed: () {
                                  Navigator.pop(context);
                                  controller.selectTrainView(TrainView.plans);
                                },
                                icon: const Icon(Icons.check),
                                label: const Text('完成'),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
              particleLayer,
            ],
          ),
        ),
      ),
    );
  }
}

class _CelebrationExerciseSummary extends StatelessWidget {
  const _CelebrationExerciseSummary({
    required this.controller,
    required this.record,
  });

  final AppController controller;
  final WorkoutRecord record;

  @override
  Widget build(BuildContext context) {
    final exercises = record.exercises;
    return Semantics(
      container: true,
      label: '本次训练动作与完成组详情',
      child: Column(
        key: const Key('workout-celebration-exercises'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.list_alt_rounded, color: primary, size: 21),
              const SizedBox(width: 7),
              const Expanded(
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
                style: const TextStyle(color: quiet, fontSize: 12),
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
            for (
              var exerciseIndex = 0;
              exerciseIndex < exercises.length;
              exerciseIndex++
            )
              _CelebrationExerciseCard(
                controller: controller,
                exercise: exercises[exerciseIndex],
                index: exerciseIndex,
              ),
          if (record.note.trim().isNotEmpty) ...[
            const SizedBox(height: 2),
            DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFF4D1B4)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.notes_rounded, color: primary, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(record.note)),
                  ],
                ),
              ),
            ),
          ],
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
    final shownSets = completedSets.isEmpty ? exercise.sets : completedSets;
    final volume = completedSets.fold<double>(
      0,
      (sum, set) => sum + set.weight * set.reps,
    );
    return Card(
      key: Key('workout-celebration-exercise-$index'),
      margin: const EdgeInsets.only(bottom: 9),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                _ExerciseThumb(exerciseId: exercise.exerciseId, size: 42),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        controller.displayExerciseName(
                          findExercise(exercise.exerciseId),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: ink,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        '${completedSets.length}/${exercise.sets.length} 组完成 · ${_displayWeight(volume)} kg 容量',
                        style: const TextStyle(color: quiet, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Icon(
                  completedSets.isNotEmpty
                      ? Icons.check_circle_rounded
                      : Icons.pending_outlined,
                  color: completedSets.isNotEmpty
                      ? const Color(0xFF1E7A4A)
                      : quiet,
                ),
              ],
            ),
            if (exercise.note.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                '动作备注：${exercise.note}',
                style: const TextStyle(color: secondaryInk, fontSize: 12),
              ),
            ],
            const SizedBox(height: 9),
            for (var setIndex = 0; setIndex < shownSets.length; setIndex++)
              Padding(
                padding: EdgeInsets.only(top: setIndex == 0 ? 0 : 6),
                child: _CelebrationSetRow(
                  set: shownSets[setIndex],
                  originalIndex: exercise.sets.indexOf(shownSets[setIndex]),
                ),
              ),
          ],
        ),
      ),
    );
  }
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
            style: const TextStyle(color: quiet, fontSize: 11),
          ),
          if (set.note.trim().isNotEmpty) ...[
            const SizedBox(width: 5),
            Tooltip(
              message: set.note,
              child: const Icon(
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

class _CelebrationMetricReveal extends StatelessWidget {
  const _CelebrationMetricReveal({
    required this.index,
    required this.reducedMotion,
    required this.child,
  });

  final int index;
  final bool reducedMotion;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (reducedMotion) return child;
    return TweenAnimationBuilder<double>(
      key: ValueKey('summary-card-$index'),
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 360 + index * 70),
      curve: Curves.easeOutCubic,
      builder: (context, progress, child) => Opacity(
        opacity: progress,
        child: Transform.translate(
          offset: Offset(0, 10 * (1 - progress)),
          child: child,
        ),
      ),
      child: child,
    );
  }
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
              leading: const Icon(Icons.check_circle, color: success),
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
              leading: const Icon(Icons.event_busy_outlined, color: orange),
              title: const Text('移除排程'),
              onTap: () {
                controller.unschedule(key);
                Navigator.pop(sheetContext);
                showKiloSnack(context, '排程已移除');
              },
            ),
          if (!planned)
            ListTile(
              leading: const Icon(Icons.add_circle_outline, color: cobalt),
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
            const Text(
              '快速选择训练部位',
              style: TextStyle(fontSize: 12, color: muted),
            ),
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
    builder: (context) => SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .72,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('官方单日计划', style: Theme.of(context).textTheme.headlineMedium),
              const Text(
                '每个入口都是一节可直接执行的训练。先看详情，再决定使用。',
                style: TextStyle(color: quiet),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView(
                  children: [
                    for (final plan in _PlansView.plans)
                      _PlanCard(controller: controller, plan: plan),
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
                style: const TextStyle(color: secondaryInk),
              ),
              const SizedBox(height: 4),
              const Text(
                '单日训练详情',
                style: TextStyle(fontSize: 12, color: quiet),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView(
                  children: [
                    for (final id in session.exerciseIds)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: _ExerciseThumb(exerciseId: id, size: 42),
                        title: Text(
                          controller.displayExerciseName(findExercise(id)),
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
              Text(
                '${routine.exercises.length} 个动作 · ${routine.exercises.fold<int>(0, (sum, item) => sum + item.sets.length)} 组',
                style: const TextStyle(color: quiet),
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
                                        findExercise(exercise.exerciseId),
                                      ),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '${exercise.restSeconds}s',
                                    style: const TextStyle(
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
                      const Text(
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
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('模板信息'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: name,
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
              style: const TextStyle(color: quiet, fontSize: 12),
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
      findExercise(exercise.exerciseId),
    );
    return Card(
      margin: const EdgeInsets.only(bottom: 9),
      child: ExpansionTile(
        initiallyExpanded: index == 0,
        leading: _ExerciseThumb(exerciseId: exercise.exerciseId, size: 38),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(
          '${exercise.sets.length} 组 · 休息 ${exercise.restSeconds}s${exercise.supersetId == null ? '' : ' · 超级组'}',
        ),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        children: [
          Wrap(
            spacing: 4,
            children: [
              IconButton(
                tooltip: '上移',
                onPressed: index == 0
                    ? null
                    : () {
                        final item = routine.exercises.removeAt(index);
                        routine.exercises.insert(index - 1, item);
                        routine.updatedAt = DateTime.now();
                        controller.refresh();
                        onChanged();
                      },
                icon: const Icon(Icons.arrow_upward),
              ),
              IconButton(
                tooltip: '下移',
                onPressed: index == routine.exercises.length - 1
                    ? null
                    : () {
                        final item = routine.exercises.removeAt(index);
                        routine.exercises.insert(index + 1, item);
                        routine.updatedAt = DateTime.now();
                        controller.refresh();
                        onChanged();
                      },
                icon: const Icon(Icons.arrow_downward),
              ),
              IconButton(
                tooltip: '替换',
                onPressed: () => _showRoutineReplacePicker(
                  context,
                  controller,
                  routine,
                  exercise,
                ),
                icon: const Icon(Icons.swap_horiz),
              ),
              IconButton(
                tooltip: exercise.supersetId == null ? '加入超级组' : '取消超级组',
                onPressed: () {
                  exercise.supersetId = exercise.supersetId == null
                      ? 'routine-superset-${DateTime.now().microsecondsSinceEpoch}'
                      : null;
                  controller.refresh();
                  onChanged();
                },
                icon: Icon(
                  exercise.supersetId == null ? Icons.link : Icons.link_off,
                ),
              ),
              IconButton(
                tooltip: '删除',
                onPressed: () {
                  routine.exercises.removeAt(index);
                  routine.updatedAt = DateTime.now();
                  controller.refresh();
                  onChanged();
                },
                icon: const Icon(
                  Icons.delete_outline,
                  color: Color(0xFFB83A3A),
                ),
              ),
            ],
          ),
          TextFormField(
            initialValue: _editableCount(exercise.restSeconds),
            keyboardType: TextInputType.number,
            onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
            decoration: const InputDecoration(labelText: '动作休息（秒）'),
            onChanged: (value) {
              exercise.restSeconds = int.tryParse(value) ?? 0;
            },
          ),
          const SizedBox(height: 6),
          for (var setIndex = 0; setIndex < exercise.sets.length; setIndex++)
            _RoutineSetEditor(
              controller: controller,
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

class _RoutineSetEditorBase extends StatelessWidget {
  const _RoutineSetEditorBase({
    required this.set,
    required this.index,
    required this.onRemove,
  });
  final WorkoutSet set;
  final int index;
  final VoidCallback onRemove;

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
              child: Text('${index + 1}', style: const TextStyle(color: quiet)),
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
                initialValue: _editableWeight(set.weight),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
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
                  set.weight = double.tryParse(value) ?? 0;
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
    required super.set,
    required super.index,
    required super.onRemove,
  });
  final AppController controller;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Column(
      children: [
        Row(
          children: [
            SizedBox(
              width: 28,
              child: Text(
                '${index + 1}',
                style: const TextStyle(
                  color: quiet,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: set.type,
                isDense: true,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: '\u7EC4\u522B\u7C7B\u578B',
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 8,
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
                  if (value == null) return;
                  set.type = value;
                  controller.refresh();
                },
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              tooltip: '\u5220\u9664\u8FD9\u4E00\u7EC4',
              onPressed: onRemove,
              icon: const Icon(Icons.delete_outline, color: Color(0xFFB83A3A)),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(left: 28, top: 6),
          child: Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: set.plannedWeight == null
                      ? _editableWeight(set.weight)
                      : _editableWeight(set.plannedWeight!),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onTapOutside: (_) =>
                      FocusManager.instance.primaryFocus?.unfocus(),
                  decoration: const InputDecoration(
                    labelText: '\u8BA1\u5212\u91CD\u91CF',
                    suffixText: 'kg',
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 8,
                    ),
                  ),
                  onChanged: (value) {
                    final weight = double.tryParse(value);
                    if (weight == null) {
                      set.plannedWeight = null;
                      set.weight = 0;
                      controller.refresh();
                    } else {
                      controller.updatePlannedWeight(set, weight);
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 84,
                child: TextFormField(
                  initialValue: _editableCount(set.reps),
                  keyboardType: TextInputType.number,
                  onTapOutside: (_) =>
                      FocusManager.instance.primaryFocus?.unfocus(),
                  decoration: const InputDecoration(
                    labelText: '\u6B21\u6570',
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 8,
                    ),
                  ),
                  onChanged: (value) {
                    set.reps = int.tryParse(value) ?? 0;
                    controller.refresh();
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    ),
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
            for (final item in controller.allExercises)
              ListTile(
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
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _DraftPlanComposer(controller: controller),
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
  Widget build(BuildContext context) => SafeArea(
    child: SizedBox(
      height: MediaQuery.sizeOf(context).height * .92,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('draft-name'),
                    controller: name,
                    onChanged: (value) => draft.name = value,
                    decoration: const InputDecoration(
                      labelText: '\u8BAD\u7EC3\u540D\u79F0',
                      border: InputBorder.none,
                      filled: false,
                    ),
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ),
                IconButton(
                  tooltip: '\u5173\u95ED',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            Text(
              '${draft.exercises.length} \u4E2A\u52A8\u4F5C',
              style: const TextStyle(color: quiet),
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
                    icon: const Icon(Icons.add),
                    label: const Text('\u6DFB\u52A0\u52A8\u4F5C'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    key: const Key('draft-cancel-button'),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('\u53D6\u6D88'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: KeyedSubtree(
                    key: const Key('draft-save-button'),
                    child: FilledButton(
                      key: const Key('template-save-button'),
                      onPressed: draft.exercises.isEmpty ? null : save,
                      child: const Text('\u4FDD\u5B58\u8BAD\u7EC3\u8BA1\u5212'),
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
                const Text('这条记录没有保存动作明细。', style: TextStyle(color: quiet))
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
                                    findExercise(exercise.exerciseId),
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
                            Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(bottom: 5),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: emberTint,
                                borderRadius: BorderRadius.circular(9),
                              ),
                              child: Text(
                                '动作备注 · ${exercise.note.trim()}',
                                style: const TextStyle(
                                  color: secondaryInk,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          if (exercise.sets.isEmpty)
                            const Text(
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
                        ],
                      ),
                    ),
                  ),
              if (record.note.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(record.note),
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
                style: const TextStyle(color: quiet),
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

void _showCustomExercise(BuildContext context, AppController controller) {
  final name = TextEditingController();
  final english = TextEditingController();
  final equipment = TextEditingController(text: '自定义器械');
  final muscle = TextEditingController(text: '未分类');
  final cue = TextEditingController();
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('新建自定义动作'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: '动作名称 *'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: english,
              decoration: const InputDecoration(labelText: '英文名称'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: equipment,
              decoration: const InputDecoration(labelText: '器械'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: muscle,
              decoration: const InputDecoration(labelText: '主要肌群'),
            ),
            const SizedBox(height: 8),
            TextField(
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
          onPressed: () {
            if (name.text.trim().isNotEmpty) {
              controller.addCustomExercise(
                name: name.text.trim(),
                englishName: english.text.trim(),
                equipment: equipment.text.trim(),
                muscle: muscle.text.trim(),
                cue: cue.text.trim(),
              );
            }
            Navigator.pop(context);
          },
          child: const Text('保存动作'),
        ),
      ],
    ),
  );
}

void _showLibraryFilters(BuildContext context, AppController controller) {
  final equipment = [
    '全部',
    ...{for (final item in controller.allExercises) item.equipment},
  ];
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
