import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

enum AppLanguage { simplifiedChinese, english }

extension AppLanguageValue on AppLanguage {
  Locale get locale => switch (this) {
    AppLanguage.simplifiedChinese => const Locale('zh', 'CN'),
    AppLanguage.english => const Locale('en'),
  };

  String get storageValue => switch (this) {
    AppLanguage.simplifiedChinese => 'zh-CN',
    AppLanguage.english => 'en',
  };

  static AppLanguage fromStorage(String? value) =>
      value == 'en' ? AppLanguage.english : AppLanguage.simplifiedChinese;
}

/// Lightweight localization for the current single-file Flutter UI.
///
/// Chinese source strings remain the canonical keys so existing widget keys,
/// data models and backend contracts do not change. Unknown strings stay
/// readable instead of rendering an empty placeholder while the English
/// catalog is expanded.
class AppStrings {
  AppStrings._();

  static String tr(String source, {AppLanguage? language}) {
    if (language != AppLanguage.english) return source;
    final direct = _english[source];
    if (direct != null) return direct;
    return _translateDynamic(source);
  }

  static String _translateDynamic(String source) {
    final replacements = <MapEntry<RegExp, String>>[
      MapEntry(RegExp(r'^(\d+) 个动作$'), r'$1 exercises'),
      MapEntry(RegExp(r'^(\d+) 个已保存训练$'), r'$1 saved workouts'),
      MapEntry(RegExp(r'^(\d+) 次训练$'), r'$1 workouts'),
      MapEntry(RegExp(r'^(\d+) 秒$'), r'$1 sec'),
      MapEntry(RegExp(r'^休息 (\d+) 秒$'), r'Rest $1 sec'),
      MapEntry(RegExp(r'^完成第 (\d+) 组$'), r'Complete set $1'),
      MapEntry(RegExp(r'^第 (\d+) 组已完成$'), r'Set $1 completed'),
      MapEntry(RegExp(r'^添加 (\d+) 个动作$'), r'Add $1 exercises'),
      MapEntry(RegExp(r'^添加 (\d+) 项$'), r'Add $1 items'),
      MapEntry(RegExp(r'^已筛选 (.+) 部位$'), r'Filtered: $1'),
    ];
    for (final entry in replacements) {
      if (entry.key.hasMatch(source)) {
        return source.replaceFirstMapped(entry.key, (match) {
          var value = entry.value;
          for (var index = 1; index <= match.groupCount; index++) {
            value = value.replaceAll('\$$index', match.group(index) ?? '');
          }
          return value;
        });
      }
    }
    return source;
  }

  static const _english = <String, String>{
    '主页': 'Home',
    '训练': 'Train',
    '动作': 'Exercises',
    '我的': 'Profile',
    '动作库': 'Exercise Library',
    '记录': 'History',
    '动作识别': 'Form Check',
    'AI': 'AI',
    'AI 对话': 'AI Chat',
    'AI 问答': 'AI Q&A',
    '训练、记录和计划概览': 'Training, history and plan overview',
    '保持专注，完成下一组': 'Stay focused and complete the next set',
    '选择计划并开始训练': 'Choose a plan and start training',
    '训练日历、完成情况和历史记录': 'Calendar, completion and training history',
    '动作、机位与识别能力': 'Exercises, camera angles and form checks',
    '上传训练视频并查看动作建议': 'Upload a training video for movement feedback',
    '有来源的训练问答': 'Evidence-based training answers',
    '训练偏好、设备连接和隐私设置': 'Training preferences, devices and privacy',
    '记录每一组，把坚持变成看得见的成长。': 'Log every set. Make consistency visible.',
    '登录账号': 'Sign in',
    '手机号登录': 'Sign in with phone',
    '手机号': 'Phone number',
    '手机号或账号': 'Phone or account',
    '密码': 'Password',
    '登录': 'Sign in',
    '登录中…': 'Signing in…',
    '使用 Apple 登录': 'Sign in with Apple',
    '使用 Google 登录': 'Sign in with Google',
    '其他登录方式': 'Other sign-in options',
    '普通体验 123': 'Member demo 123',
    '管理测试 1234': 'Admin demo 1234',
    '测试入口仅在测试构建中显示': 'Demo access is shown in test builds only',
    '请输入手机号或账号。': 'Enter a phone number or account.',
    '账号或密码不正确。': 'Incorrect account or password.',
    '登录暂时不可用，请稍后重试。': 'Sign-in is temporarily unavailable. Try again later.',
    'Apple 登录尚未配置。': 'Sign in with Apple is not configured yet.',
    'Apple 登录已取消。': 'Sign in with Apple was canceled.',
    '当前设备不支持 Apple 登录。': 'Sign in with Apple is not available on this device.',
    'Apple 登录凭据无效，请重试。': 'The Apple sign-in credential is invalid. Try again.',
    'Apple 登录失败，请稍后重试。': 'Sign in with Apple failed. Try again later.',
    'Apple 登录服务尚未完成服务器配置。':
        'Sign in with Apple is not configured on the server yet.',
    'Apple 登录暂时不可用，请稍后重试。':
        'Sign in with Apple is temporarily unavailable. Try again later.',
    'Google 登录尚未配置。': 'Sign in with Google is not configured yet.',
    '今日训练': "Today's workout",
    '今天只做最重要的下一步': 'Focus on the next important action',
    '开始训练': 'Start workout',
    '继续训练': 'Resume workout',
    '浏览计划': 'Browse plans',
    '开始下一次训练': 'Start your next workout',
    '训练周': 'Training week',
    '完整月历': 'Full calendar',
    '训练进步': 'Progress',
    '进步分析': 'Progress analysis',
    '最近进步': 'Recent progress',
    '最近训练': 'Recent workouts',
    '最近记录': 'Recent history',
    '我的训练计划': 'My workout plans',
    '我的计划': 'My plans',
    '新建计划': 'New plan',
    '自由训练 · 立即开始': 'Free workout · Start',
    '自由训练': 'Free workout',
    '使用官方计划': 'Use official plans',
    '官方单日计划': 'Official single-day plans',
    '还没有保存的计划，先新建一个训练。': 'No saved plans yet. Create your first workout.',
    '计划': 'Plan',
    '安排训练': 'Schedule workout',
    '已安排': 'Scheduled',
    '已完成': 'Completed',
    '未安排': 'Unscheduled',
    '查看全部': 'View all',
    '训练记录': 'Workout history',
    '训练量': 'Volume',
    '有效组': 'Effective sets',
    '训练日': 'Training days',
    '训练次数': 'Workouts',
    '时长': 'Duration',
    '搜索动作、肌群或器械': 'Search exercises, muscles or equipment',
    '搜索动作、器械': 'Search exercises or equipment',
    '搜索动作': 'Search exercises',
    '全部': 'All',
    '胸': 'Chest',
    '胸部': 'Chest',
    '背': 'Back',
    '背部': 'Back',
    '肩': 'Shoulders',
    '肩部': 'Shoulders',
    '腿': 'Legs',
    '腿部': 'Legs',
    '手臂': 'Arms',
    '核心': 'Core',
    '器械': 'Equipment',
    '部位': 'Body part',
    '没有匹配动作': 'No matching exercises',
    '没有匹配动作，试试清空搜索或筛选。': 'Try clearing the search or filters.',
    '添加动作': 'Add exercises',
    '替换动作': 'Replace exercise',
    '选择动作': 'Choose exercises',
    '关闭动作选择': 'Close exercise picker',
    '显示全部动作': 'Show all exercises',
    '动作名称 *': 'Exercise name *',
    '英文名称': 'English name',
    '自定义器械': 'Custom equipment',
    '保存动作': 'Save exercise',
    '动作教学': 'Exercise guide',
    '概览': 'Overview',
    '教学': 'Guide',
    '讲解': 'Guide',
    '参考文献': 'References',
    '复制全部': 'Copy all',
    '动作备注': 'Exercise note',
    '保存备注': 'Save note',
    '保存备注与链接': 'Save note and link',
    '教学链接（可选）': 'Instruction link (optional)',
    '打开链接': 'Open link',
    '训练概览': 'Workout overview',
    '实时训练': 'Live workout',
    '准备开始': 'Ready',
    '开始本次训练计时': 'Start workout timer',
    '开始计时': 'Start timer',
    '暂停计时': 'Pause timer',
    '恢复计时': 'Resume timer',
    '结束并保存': 'Finish & save',
    '结束并保存训练': 'Finish & save workout',
    '添加一组': 'Add set',
    '添加动作备注': 'Add exercise note',
    '添加本组备注': 'Add set note',
    '组': 'Set',
    '上次': 'Previous',
    '重量': 'Weight',
    '次数': 'Reps',
    '完成': 'Done',
    '组别类型': 'Set type',
    '热身': 'Warm-up',
    '力量': 'Strength',
    '超级组': 'Superset',
    '力竭': 'Failure',
    '递减': 'Drop set',
    '组间休息': 'Rest timer',
    '跳过': 'Skip',
    '跳过休息': 'Skip rest',
    '增加 15 秒休息': 'Add 15 seconds to rest',
    '休息已增加 15 秒': 'Rest extended by 15 seconds',
    '修改当前及后续休息时间': 'Edit current and upcoming rest',
    '修改休息': 'Edit rest',
    '修改组间休息': 'Edit rest timer',
    '保存后立即更新当前倒计时，并默认应用于本次训练后续所有动作和未完成组。':
        'Updates the current countdown and applies to all upcoming exercises and unfinished sets in this workout.',
    '休息秒数': 'Rest seconds',
    '请输入 0–600 秒': 'Enter a value from 0 to 600 seconds',
    '应用到当前及后续': 'Apply now and onward',
    '增加 15 秒': 'Add 15 sec',
    '设置': 'Settings',
    '批量': 'Batch',
    '杠片': 'Plates',
    '保存为训练计划': 'Save as workout plan',
    '本次完成动作': 'Completed exercises',
    '总容量': 'Total volume',
    '本次 PR': 'PRs',
    '完成组': 'Completed sets',
    '训练时长': 'Duration',
    '主要肌群': 'Primary muscles',
    '训练完成': 'Workout complete',
    '训练已保存': 'Workout saved',
    '问答': 'Chat',
    '发送': 'Send',
    '新建对话': 'New chat',
    '对话列表': 'Conversations',
    '询问训练、恢复或计划安排': 'Ask about training, recovery or planning',
    '添加训练上下文': 'Attach training context',
    '不添加上下文': 'No context',
    '本周频率、容量、肌群和备注': 'Weekly frequency, volume, muscles and notes',
    '本月趋势、PR、容量和完成情况': 'Monthly trends, PRs, volume and completion',
    '正在思考中': 'Thinking…',
    '服务与训练授权': 'Service and training permission',
    '允许使用训练摘要': 'Allow training summary',
    '只随下一条消息发送': 'Only for the next message',
    '选择视频': 'Choose video',
    '选择一个视频开始': 'Choose a video to begin',
    '开始分析': 'Start analysis',
    '重新分析': 'Analyze again',
    '正在上传视频': 'Uploading video',
    '正在创建识别任务': 'Creating analysis task',
    '正在分析动作轨迹': 'Analyzing movement',
    '分析完成': 'Analysis complete',
    '识别失败 · 可以重试': 'Analysis failed · Retry',
    '原始视频': 'Original video',
    '动作分析视频': 'Movement analysis video',
    '生成分析视频': 'Generate analysis video',
    '拍摄机位': 'Camera angle',
    '选择识别动作': 'Choose exercise',
    '这里只显示服务端当前已支持的动作': 'Only server-supported exercises are shown',
    '动作结果、分析视频与训练建议': 'Results, analysis video and training advice',
    '个性化': 'Personalization',
    '默认休息': 'Default rest',
    '趋势、肌群与记录': 'Trends, muscles and history',
    '应用语言': 'App language',
    '简体中文': 'Simplified Chinese',
    '语言与地区': 'Language & region',
    '通知反馈': 'Notifications',
    '训练提醒已开启': 'Workout reminders on',
    '训练提醒已关闭': 'Workout reminders off',
    '服务与安全': 'Service & security',
    '锁屏实时活动': 'Lock Screen Live Activity',
    '训练总时长与组间休息': 'Workout duration and rest timer',
    '尚未开启设备同步': 'Device sync is off',
    '隐私与 AI 授权': 'Privacy & AI permission',
    '训练摘要默认不上传': 'Training summaries stay private by default',
    '训练摘要已授权，可随时撤销': 'Training summary permission granted; revoke anytime',
    '会员与兑换': 'Membership & redemption',
    '基础权益 · 可随时升级': 'Basic access · Upgrade anytime',
    '取消': 'Cancel',
    '保存': 'Save',
    '关闭': 'Close',
    '清除': 'Clear',
    '清空': 'Clear all',
    '删除': 'Delete',
    '重试': 'Retry',
    '完成率': 'Completion',
    '查看详情': 'View details',
  };
}

class AppLocalizations {
  const AppLocalizations(this.locale);

  final Locale locale;

  static AppLocalizations of(BuildContext context) =>
      Localizations.of<AppLocalizations>(context, AppLocalizations) ??
      const AppLocalizations(Locale('zh', 'CN'));

  String text(String source) => AppStrings.tr(
    source,
    language: locale.languageCode == 'en'
        ? AppLanguage.english
        : AppLanguage.simplifiedChinese,
  );

  static const delegate = _AppLocalizationsDelegate();
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => {'zh', 'en'}.contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) =>
      SynchronousFuture<AppLocalizations>(AppLocalizations(locale));

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
