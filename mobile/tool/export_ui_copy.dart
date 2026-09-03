// ignore_for_file: avoid_print

// Export a review inventory of user-visible copy embedded in the Flutter app.
//
// This dependency-free lexical scan does not change app source. Run from
// `mobile/` with `dart run tool/export_ui_copy.dart`.

import 'dart:convert';
import 'dart:io';

import 'package:kilo_strength/exercise_dataset.generated.dart'
    as exercise_dataset;
import 'package:kilo_strength/exercise_name_zh.dart' as exercise_names;

const _uiFiles = <String>{
  'main.dart',
  'product_features.dart',
  'membership_ui.dart',
  'ai_training_ui.dart',
  'muscle_selector.dart',
};

const _supportFiles = <String>{
  'account_membership.dart',
  'ai_api.dart',
  'app_localizations.dart',
  'controller.dart',
  'models.dart',
  'recognition_api.dart',
  'training_intelligence.dart',
  'exercise_growth.dart',
  'muscle_palette.dart',
};

const _interestingCalls = <String>{
  'text',
  'textspan',
  'richtext',
  'inputdecoration',
  'snackbar',
  'alertdialog',
  'simpledialog',
  'dialog',
  'showdialog',
  'showmodalbottomsheet',
  'bottomsheet',
  'tooltip',
  'elevatedbutton',
  'outlinedbutton',
  'textbutton',
  'filledbutton',
  'iconbutton',
  'floatingactionbutton',
  'buttonstylebutton',
  'navigationdestination',
  'bottomnavigationbaritem',
  'dropdownmenuentry',
  'listtile',
  'expansiontile',
  'filterchip',
  'choicechip',
  'inputchip',
  'actionchip',
  'chip',
  'buttonsegment',
  'segmentedbutton',
  'appbar',
  'tab',
  'tabbar',
};

const _buttonCalls = <String>{
  'elevatedbutton',
  'outlinedbutton',
  'textbutton',
  'filledbutton',
  'iconbutton',
  'floatingactionbutton',
  'buttonstylebutton',
  'buttonsegment',
  'dropdownmenuentry',
  'navigationdestination',
  'bottomnavigationbaritem',
};

final _classDeclaration = RegExp(r'\bclass\s+([A-Za-z_][A-Za-z0-9_]*)');
final _functionDeclaration = RegExp(
  r'^\s*(?:(?:abstract|static|late|external|const|factory)\s+)*'
  r'(?:[A-Za-z_][A-Za-z0-9_<>,.?\[\] ]*\s+)?'
  r'(_?[A-Za-z][A-Za-z0-9_]*)\s*\(',
);
final _technicalOnly = RegExp(
  r'^(?:[A-Za-z_][A-Za-z0-9_]*|[A-Z][A-Z0-9_]{2,}|'
  r'[a-z0-9_.-]+(?:_[a-z0-9_.-]+)+|v?\d+(?:\.\d+)*|'
  r'#[0-9a-fA-F]{3,8})$',
);
final _cjk = RegExp(r'[\u3400-\u4DBF\u4E00-\u9FFF\uF900-\uFAFF]');

class _StringToken {
  _StringToken({
    required this.start,
    required this.end,
    required this.line,
    required this.column,
    required this.value,
    required this.template,
    required this.literalSource,
    required this.raw,
  });

  final int start;
  final int end;
  final int line;
  final int column;
  final String value;
  final String template;
  final String literalSource;
  final bool raw;
}

class _SyntaxEvent {
  _SyntaxEvent({
    required this.start,
    required this.end,
    required this.kind,
    required this.value,
    this.stringToken,
  });

  final int start;
  final int end;
  final String kind;
  final String value;
  final _StringToken? stringToken;
}

class _CallFrame {
  _CallFrame(this.name, this.openStart);

  final String name;
  final int openStart;
}

class _StringContext {
  _StringContext({
    required this.calls,
    required this.namedArgument,
    required this.localized,
  });

  final List<String> calls;
  final String? namedArgument;
  final bool localized;
}

class _ClassRange {
  _ClassRange({required this.name, required this.start, required this.end});

  final String name;
  final int start;
  final int end;
}

class _Declaration {
  _Declaration({
    required this.name,
    required this.start,
    required this.className,
  });

  final String name;
  final int start;
  final String? className;
}

class _DeclarationIndex {
  _DeclarationIndex({
    required this.classes,
    required this.functions,
    required this.lineStarts,
  });

  final List<_ClassRange> classes;
  final List<_Declaration> functions;
  final List<int> lineStarts;

  String? classFor(int offset) {
    final matches = classes
        .where((item) => offset >= item.start && offset <= item.end)
        .toList(growable: false);
    if (matches.isEmpty) return null;
    matches.sort((a, b) => (a.end - a.start).compareTo(b.end - b.start));
    return matches.first.name;
  }

  String? functionFor(int offset, String? className) {
    _Declaration? selected;
    for (final declaration in functions) {
      if (declaration.start > offset) break;
      if (declaration.className == className) selected = declaration;
    }
    return selected?.name;
  }
}

class _Entry {
  _Entry({
    required this.id,
    required this.originalText,
    required this.literalSource,
    required this.file,
    required this.line,
    required this.column,
    required this.page,
    required this.className,
    required this.functionName,
    required this.type,
    required this.locale,
    required this.explanatoryCandidate,
    required this.explanatoryReason,
    required this.detection,
  });

  final String id;
  final String originalText;
  final String literalSource;
  final String file;
  final int line;
  final int column;
  final String page;
  final String? className;
  final String? functionName;
  final String type;
  final String locale;
  final bool explanatoryCandidate;
  final String explanatoryReason;
  final String detection;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'originalText': originalText,
    'literalSource': literalSource,
    'file': file,
    'line': line,
    'column': column,
    'page': page,
    'className': className,
    'functionName': functionName,
    'type': type,
    'locale': locale,
    'explanatoryCandidate': explanatoryCandidate,
    'explanatoryReason': explanatoryReason,
    'detection': detection,
  };
}

class _ScanResult {
  _ScanResult(this.tokens, this.contexts, this.declarations);

  final List<_StringToken> tokens;
  final Map<_StringToken, _StringContext> contexts;
  final _DeclarationIndex declarations;
}

class _Candidate {
  _Candidate({
    required this.type,
    required this.locale,
    required this.explanatoryCandidate,
    required this.explanatoryReason,
    required this.detection,
  });

  final String type;
  final String locale;
  final bool explanatoryCandidate;
  final String explanatoryReason;
  final String detection;
}

const _limitations = <String>[
  '词法扫描覆盖 Dart 普通/raw/多行字符串、注释和常见插值；不依赖 analyzer package。',
  '静态 UI 文案按 Flutter Text/表单/按钮/提示/弹窗等构造器上下文，以及本地化表和用户反馈辅助函数筛选。',
  '运行时 AI/远端回答、用户输入和服务端动作/营养结果无法穷举；动作目录名称、教学摘要和步骤另列为动作库·目录附录。',
  '资源路径、API 字段/地址、日志与 AI 系统指令排除在清单外。',
  'AI 系统指令、API 地址/字段、密钥/令牌、资源路径和纯数据/序列化字符串排除在清单外。',
  '稳定 ID 基于相对文件、类/函数、类型、locale、原文模板和同上下文出现序号；同一文案多个使用点会分别列出。',
];

void main(List<String> args) {
  final mobileRoot = _resolveMobileRoot(args);
  final noHtml = args.contains('--no-html');
  final repoRoot = Directory(mobileRoot.parent.path);
  final outDir = Directory(_join(repoRoot.path, 'docs', 'ui-copy-review'));
  outDir.createSync(recursive: true);
  final libDir = Directory(_join(mobileRoot.path, 'lib'));
  final files =
      libDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.toLowerCase().endsWith('.dart'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  final entries = <_Entry>[];
  final occurrenceByKey = <String, int>{};
  var scannedFiles = 0;
  for (final file in files) {
    final relative = _relativePath(mobileRoot.path, file.path);
    final base = _basename(relative);
    if (!_supportFiles.contains(base) && !_uiFiles.contains(base)) continue;
    scannedFiles++;
    final source = file.readAsStringSync();
    final scan = _scanSource(source);
    for (final token in scan.tokens) {
      final context = scan.contexts[token]!;
      final className = scan.declarations.classFor(token.start);
      final functionName = scan.declarations.functionFor(
        token.start,
        className,
      );
      final mapRole = base == 'app_localizations.dart'
          ? _localizationMapRole(source, token.start)
          : null;
      final candidate = _classify(
        base: base,
        token: token,
        context: context,
        functionName: functionName,
        mapRole: mapRole,
      );
      if (candidate == null) continue;
      final page = _pageFor(base, className, functionName);
      final key = [
        relative,
        className ?? '',
        functionName ?? '',
        candidate.type,
        candidate.locale,
        token.template,
      ].join('|');
      final occurrence = occurrenceByKey.update(
        key,
        (value) => value + 1,
        ifAbsent: () => 1,
      );
      entries.add(
        _Entry(
          id: 'copy-${_fnv1a('$key|$occurrence')}',
          originalText: token.template,
          literalSource: token.literalSource,
          file: relative,
          line: token.line,
          column: token.column,
          page: page,
          className: className,
          functionName: functionName,
          type: candidate.type,
          locale: candidate.locale,
          explanatoryCandidate: candidate.explanatoryCandidate,
          explanatoryReason: candidate.explanatoryReason,
          detection: candidate.detection,
        ),
      );
    }
  }
  final catalog = _exerciseCatalogEntries(mobileRoot);
  entries.addAll(catalog);
  if (catalog.isNotEmpty) scannedFiles++;
  entries.sort((a, b) {
    final page = a.page.compareTo(b.page);
    if (page != 0) return page;
    final file = a.file.compareTo(b.file);
    if (file != 0) return file;
    final line = a.line.compareTo(b.line);
    if (line != 0) return line;
    return a.column.compareTo(b.column);
  });

  final payload = <String, Object?>{
    'schemaVersion': 1,
    'generatedBy': 'mobile/tool/export_ui_copy.dart',
    'sourceRoot': 'mobile/lib',
    'scannedFileCount': scannedFiles,
    'catalogExerciseCount': exercise_dataset.datasetExerciseEntries.length,
    'catalogEntryCount': catalog.length,
    'entryCount': entries.length,
    'limitations': _limitations,
    'entries': entries.map((entry) => entry.toJson()).toList(growable: false),
  };
  final jsonText = const JsonEncoder.withIndent('  ').convert(payload);
  File(
    _join(outDir.path, 'ui-copy-review.json'),
  ).writeAsStringSync('$jsonText\n');
  File(
    _join(outDir.path, 'ui-copy-review.md'),
  ).writeAsStringSync(_markdown(entries, scannedFiles));
  if (!noHtml) {
    File(
      _join(outDir.path, 'ui-copy-review.html'),
    ).writeAsStringSync(_html(payload));
  }

  final explanatory = entries.where((item) => item.explanatoryCandidate).length;
  final locales = <String, int>{};
  for (final entry in entries) {
    locales.update(entry.locale, (value) => value + 1, ifAbsent: () => 1);
  }
  print('Scanned $scannedFiles Dart files under mobile/lib.');
  print(
    'Exported ${entries.length} UI-copy occurrences '
    '($explanatory explanatory candidates).',
  );
  print(
    'Locales: ${locales.entries.map((e) => '${e.key}=${e.value}').join(', ')}',
  );
  print(
    noHtml
        ? 'HTML: skipped (--no-html): ${_join(outDir.path, 'ui-copy-review.html')}'
        : 'HTML: ${_join(outDir.path, 'ui-copy-review.html')}',
  );
  print('Markdown: ${_join(outDir.path, 'ui-copy-review.md')}');
  print('JSON: ${_join(outDir.path, 'ui-copy-review.json')}');
}

_Candidate? _classify({
  required String base,
  required _StringToken token,
  required _StringContext context,
  required String? functionName,
  required String? mapRole,
}) {
  final text = token.template.trim();
  if (text.isEmpty || _isTechnicalLiteral(text)) return null;
  final isLocalizationMap = mapRole != null;
  final calls = context.calls.map((item) => item.toLowerCase()).toList();
  final callMatch = calls.firstWhere(
    _interestingCalls.contains,
    orElse: () => '',
  );
  final named = context.namedArgument?.toLowerCase();
  final localizedCall = context.localized;
  final helperFunction =
      functionName != null && _looksLikeCopyFunction(functionName);
  final supportFile = _supportFiles.contains(base);
  final cjkText = _cjk.hasMatch(text);

  if (base == 'app_localizations.dart' && !isLocalizationMap) return null;
  // This range contains AI tool schemas and system prompts, not copy rendered
  // by Flutter widgets. Keep it out even when a Chinese description looks
  // like ordinary user-facing text.
  if (base == 'controller.dart' && token.line >= 4600 && token.line <= 5585) {
    return null;
  }
  if (isLocalizationMap) {
    final locale = mapRole == 'key' ? 'zh-CN' : 'en';
    final type = mapRole == 'key' ? '本地化源键' : '本地化英文值';
    final explanatory = _longOrExplanatory(text);
    return _Candidate(
      type: type,
      locale: locale,
      explanatoryCandidate: explanatory,
      explanatoryReason: explanatory ? '本地化句子/说明候选' : '',
      detection: 'AppStrings._english $mapRole',
    );
  }

  final relevantCall = callMatch.isNotEmpty;
  final supportHumanText =
      supportFile &&
      cjkText &&
      !_looksLikeAiPrompt(text, functionName) &&
      !_looksLikeDataOnlyText(text, context, functionName);
  if (!relevantCall && !localizedCall && !helperFunction && !supportHumanText) {
    return null;
  }
  if (supportFile && _looksLikeAiPrompt(text, functionName)) return null;

  final type = _typeFor(
    namedArgument: named,
    calls: calls,
    functionName: functionName,
    helperFunction: helperFunction,
    supportHumanText: supportHumanText,
  );
  final reason = _explanatoryReason(
    namedArgument: named,
    calls: calls,
    functionName: functionName,
  );
  final locale = localizedCall
      ? 'zh-CN + en'
      : cjkText
      ? 'zh-CN'
      : 'en';
  final detection = localizedCall
      ? 'AppStrings/localized call'
      : relevantCall
      ? 'Flutter ${callMatch.isEmpty ? 'UI' : callMatch} context'
      : 'user-facing helper/support text';
  return _Candidate(
    type: type,
    locale: locale,
    explanatoryCandidate: reason.isNotEmpty || _longOrExplanatory(text),
    explanatoryReason: reason.isNotEmpty
        ? reason
        : (_longOrExplanatory(text) ? '较长句子候选' : ''),
    detection: detection,
  );
}

String _typeFor({
  required String? namedArgument,
  required List<String> calls,
  required String? functionName,
  required bool helperFunction,
  required bool supportHumanText,
}) {
  final named = namedArgument ?? '';
  if (named == 'labeltext') return '输入框标签';
  if (named == 'hinttext') return '输入提示';
  if (named == 'helpertext' || named == 'supportingtext') return '辅助说明';
  if (named == 'tooltip') return '工具提示';
  if (named == 'semanticlabel') return '无障碍标签';
  if (named == 'subtitle') return '副标题';
  if (named == 'title') return '标题';
  if (named == 'description') return '描述';
  if (named == 'reason') return '解释/原因';
  if (named == 'caption') return '说明文字';
  if (named == 'message') return '消息';
  if (named == 'content') {
    if (calls.contains('snackbar')) return '轻提示正文';
    if (calls.contains('alertdialog') ||
        calls.contains('simpledialog') ||
        calls.contains('dialog')) {
      return '弹窗正文';
    }
    return '正文';
  }
  if (named == 'label') {
    if (calls.contains('navigationdestination') ||
        calls.contains('bottomnavigationbaritem')) {
      return '导航标签';
    }
    return '按钮/选项标签';
  }
  if (calls.contains('snackbar')) return '轻提示正文';
  if (calls.contains('alertdialog') ||
      calls.contains('simpledialog') ||
      calls.contains('dialog')) {
    return '弹窗文本';
  }
  if (calls.contains('tooltip')) return '工具提示';
  if (calls.any(_buttonCalls.contains)) return '按钮/选项文本';
  if (calls.contains('inputdecoration')) return '表单文案';
  if (calls.contains('navigationdestination') ||
      calls.contains('bottomnavigationbaritem')) {
    return '导航标签';
  }
  final function = functionName?.toLowerCase() ?? '';
  if (function.contains('error')) return '错误提示';
  if (function.contains('empty')) return '空状态提示';
  if (helperFunction) return '文案辅助函数';
  if (supportHumanText) return '用户反馈/默认文案';
  return '文本';
}

String _explanatoryReason({
  required String? namedArgument,
  required List<String> calls,
  required String? functionName,
}) {
  final named = namedArgument?.toLowerCase();
  if (named == 'helpertext' || named == 'supportingtext') return '表单辅助说明';
  if (named == 'subtitle') return '列表/卡片副说明';
  if (named == 'description' || named == 'reason' || named == 'caption') {
    return '解释或说明性质';
  }
  if (named == 'content' &&
      (calls.contains('alertdialog') ||
          calls.contains('simpledialog') ||
          calls.contains('dialog'))) {
    return '弹窗解释正文';
  }
  if (calls.contains('snackbar')) return '状态反馈（轻提示）';
  final function = functionName?.toLowerCase() ?? '';
  if (function.contains('error')) return '错误反馈';
  if (function.contains('empty')) return '空状态反馈';
  return '';
}

bool _longOrExplanatory(String text) {
  final compact = text.replaceAll(RegExp(r'\s+'), '');
  return compact.length >= 18 ||
      text.contains('。') ||
      text.contains('？') ||
      text.contains('?');
}

bool _looksLikeCopyFunction(String name) {
  final value = name.toLowerCase();
  return value.contains('label') ||
      value.contains('caption') ||
      value.contains('title') ||
      value.contains('subtitle') ||
      value.contains('description') ||
      value.contains('message') ||
      value.contains('reason') ||
      value.contains('error') ||
      value.contains('empty') ||
      value.contains('status') ||
      value.contains('advice') ||
      value.contains('validity') ||
      value.contains('weekday') ||
      value.contains('meal') ||
      value.contains('theme') ||
      value.contains('time') ||
      value.contains('weight') ||
      value.contains('date');
}

bool _looksLikeAiPrompt(String text, String? functionName) {
  final function = functionName?.toLowerCase() ?? '';
  if (function.contains('prompt') ||
      function.contains('requestai') ||
      function.contains('aicustom')) {
    return true;
  }
  if (text.length < 45) return false;
  return text.contains('请') &&
      (text.contains('不要') ||
          text.contains('生成') ||
          text.contains('根据') ||
          text.contains('训练计划'));
}

bool _looksLikeDataOnlyText(
  String text,
  _StringContext context,
  String? functionName,
) {
  final function = functionName?.toLowerCase() ?? '';
  if (function.contains('json') ||
      function.contains('serialize') ||
      function.contains('deserialize')) {
    return true;
  }
  final named = context.namedArgument?.toLowerCase() ?? '';
  if (named == 'id' || named == 'name' || named == 'value' || named == 'key') {
    return !_longOrExplanatory(text) && !_cjk.hasMatch(text);
  }
  return false;
}

bool _isTechnicalLiteral(String text) {
  final value = text.trim();
  if (value.isEmpty) return true;
  if (value.contains('://') ||
      value.startsWith('package:') ||
      value.startsWith('assets/') ||
      value.startsWith('file://') ||
      value.contains('api.kilostrength') ||
      value.contains('/v1/')) {
    return true;
  }
  if (value.contains('=>') ||
      value.contains('jsonDecode') ||
      value.contains('DateTime.')) {
    return true;
  }
  // Widget test keys and accessibility-independent DOM-ish identifiers are
  // not product copy, even when they happen to sit inside a widget call.
  if (RegExp(
    r'^[a-z0-9][a-z0-9_.-]*-\{\{[^}]+\}\}(?:-[^ ]+)?$',
  ).hasMatch(value)) {
    return true;
  }
  if (_technicalOnly.hasMatch(value) && !_cjk.hasMatch(value)) return true;
  if (RegExp(r'^[0-9_+\-./:]+$').hasMatch(value)) return true;
  if (RegExp(r'^[a-z][A-Za-z0-9_.-]*-[A-Za-z0-9_.-]+$').hasMatch(value)) {
    return true;
  }
  return false;
}

String? _localizationMapRole(String source, int offset) {
  final begin = source.indexOf('static const _english');
  if (begin < 0 || offset < begin) return null;
  final end = source.indexOf('};', begin);
  if (end < 0 || offset > end) return null;
  final before = source.substring(begin, offset);
  final recentColon = before.lastIndexOf(':');
  final recentComma = before.lastIndexOf(',');
  final recentBrace = before.lastIndexOf('{');
  if (recentColon > recentComma && recentColon > recentBrace) return 'value';
  return 'key';
}

String _pageFor(String file, String? className, String? functionName) {
  final tokens = _nameTokens('${className ?? ''} ${functionName ?? ''}');
  bool hasAny(Set<String> values) => tokens.any(values.contains);
  if (file == 'app_localizations.dart') return '全局本地化';
  if (file == 'exercise_growth.dart') return '动作趋势';
  if (file == 'muscle_palette.dart') return '训练统计/肌群图例';
  if (file == 'models.dart') return '动作识别/能力目录';
  if (file == 'recognition_api.dart') return '动作识别';
  if (file == 'ai_api.dart') return 'AI';
  if (file == 'training_intelligence.dart') return '训练';
  if (file == 'membership_ui.dart') return '会员与订单';
  if (hasAny({'login', 'onboarding', 'auth', 'account', 'profile'})) {
    return '登录与资料';
  }
  if (hasAny({'membership', 'paywall', 'order', 'redeem', 'purchase'})) {
    return '会员与订单';
  }
  if (hasAny({'nutrition', 'food', 'meal', 'water'})) return '饮食';
  if (hasAny({'weight'})) return '体重记录';
  if (hasAny({'calendar'})) return '训练与饮食日历';
  if (hasAny({'guide'})) return '使用指南';
  if (hasAny({'theme'})) return '主题设置';
  if (hasAny({'gym', 'location'})) return '训练地点';
  if (hasAny({'friend', 'activity', 'publish', 'share'})) return '训练动态';
  if (hasAny({'recognition', 'pose', 'form'})) return '动作识别';
  if (tokens.any((token) => token == 'ai' || token.startsWith('ai'))) {
    return 'AI';
  }
  if (hasAny({'exercise', 'muscle', 'picker', 'library'})) return '动作库';
  if (hasAny({'workout', 'training', 'train', 'routine', 'set', 'plan'})) {
    return '训练';
  }
  if (hasAny({'home', 'dashboard'})) return '主页';
  if (file == 'main.dart') return '主应用/未归类';
  if (file == 'product_features.dart') return '产品功能/未归类';
  if (file == 'controller.dart') return '控制器用户反馈';
  return '${_basenameWithoutExtension(file)}${className == null ? '' : ' · $className'}';
}

List<String> _nameTokens(String value) {
  final separated = value.replaceAllMapped(
    RegExp(r'([a-z0-9])([A-Z])'),
    (match) => '${match.group(1)} ${match.group(2)}',
  );
  return separated
      .toLowerCase()
      .split(RegExp(r'[^a-z0-9]+'))
      .where((token) => token.isNotEmpty)
      .toList(growable: false);
}

List<_Entry> _exerciseCatalogEntries(Directory mobileRoot) {
  final file = File(
    _join(mobileRoot.path, 'lib', 'exercise_dataset.generated.dart'),
  );
  if (!file.existsSync()) return const <_Entry>[];
  final source = file.readAsStringSync();
  final scan = _scanSource(source);
  final lineStarts = scan.declarations.lineStarts;
  final entries = <_Entry>[];
  var ordinal = 0;
  for (final item in exercise_dataset.datasetExerciseEntries.entries) {
    final key = item.key;
    final value = item.value;
    final entryStart = source.indexOf("'$key':", 0);
    if (entryStart < 0) continue;
    final nextKey = source.indexOf("'dataset_", entryStart + key.length + 2);
    final entryEnd = nextKey < 0 ? source.length : nextKey;
    final nameToken = _fieldToken(
      scan.tokens,
      source,
      'name:',
      entryStart,
      entryEnd,
    );
    final summaryToken = _fieldToken(
      scan.tokens,
      source,
      'summary:',
      entryStart,
      entryEnd,
    );
    final stepsStart = source.indexOf('steps:', entryStart);
    final stepsEnd = stepsStart < 0
        ? entryEnd
        : source.indexOf('],', stepsStart);
    final stepTokens = stepsStart < 0
        ? const <_StringToken>[]
        : scan.tokens
              .where(
                (token) =>
                    token.start > stepsStart &&
                    token.start < (stepsEnd < 0 ? entryEnd : stepsEnd),
              )
              .toList(growable: false);
    final displayName = exercise_names.chineseExerciseName(
      value.name,
      equipment: value.equipment,
      muscle: value.muscle,
    );
    final nameLine = nameToken == null
        ? _lineFor(lineStarts, entryStart)
        : nameToken.line;
    entries.add(
      _catalogEntry(
        id: key,
        text: value.name,
        locale: 'en',
        type: '目录·动作名称',
        line: nameLine,
        ordinal: ordinal++,
      ),
    );
    entries.add(
      _catalogEntry(
        id: '$key-zh',
        text: displayName,
        locale: 'zh-CN',
        type: '目录·动作名称',
        line: nameLine,
        ordinal: ordinal++,
      ),
    );
    if (summaryToken != null && summaryToken.template.trim().isNotEmpty) {
      entries.add(
        _catalogEntry(
          id: '$key-summary',
          text: summaryToken.template,
          locale: 'zh-CN',
          type: '目录·教学摘要',
          line: summaryToken.line,
          ordinal: ordinal++,
          explanatory: true,
        ),
      );
    }
    for (var stepIndex = 0; stepIndex < stepTokens.length; stepIndex++) {
      final token = stepTokens[stepIndex];
      if (token.template.trim().isEmpty) continue;
      entries.add(
        _catalogEntry(
          id: '$key-step-$stepIndex',
          text: token.template,
          locale: 'zh-CN',
          type: '目录·教学步骤',
          line: token.line,
          ordinal: ordinal++,
          explanatory: true,
        ),
      );
    }
  }
  return entries;
}

_StringToken? _fieldToken(
  List<_StringToken> tokens,
  String source,
  String field,
  int start,
  int end,
) {
  final fieldStart = source.indexOf(field, start);
  if (fieldStart < 0 || fieldStart >= end) return null;
  final fields = <String>[
    'datasetId:',
    'name:',
    'family:',
    'muscle:',
    'secondary:',
    'equipment:',
    'summary:',
    'steps:',
    'imageAsset:',
    'gifAsset:',
    'attribution:',
    'loadMode:',
  ];
  var limit = end;
  for (final candidate in fields) {
    if (candidate == field) continue;
    final next = source.indexOf('\n    $candidate', fieldStart + field.length);
    if (next >= 0 && next < limit) limit = next;
  }
  for (final token in tokens) {
    if (token.start > fieldStart + field.length && token.start < limit) {
      return token;
    }
  }
  return null;
}

_Entry _catalogEntry({
  required String id,
  required String text,
  required String locale,
  required String type,
  required int line,
  required int ordinal,
  bool explanatory = false,
}) {
  final key = 'catalog|$id|$locale|$type|$ordinal';
  return _Entry(
    id: 'copy-${_fnv1a(key)}',
    originalText: text,
    literalSource: text,
    file: 'lib/exercise_dataset.generated.dart',
    line: line,
    column: 1,
    page: '动作库·目录附录',
    className: 'DatasetExerciseEntry',
    functionName: 'datasetExerciseEntries',
    type: type,
    locale: locale,
    explanatoryCandidate: explanatory,
    explanatoryReason: explanatory ? '动作教学说明候选' : '',
    detection: 'generated exercise catalog appendix',
  );
}

String _markdown(List<_Entry> entries, int scannedFiles) {
  final buffer = StringBuffer()
    ..writeln('# Flutter UI 文案盘点（可审阅删除候选）')
    ..writeln()
    ..writeln(
      '> 本表由 `mobile/tool/export_ui_copy.dart` 生成。仅盘点，不会自动删除或修改 app 文案。',
    )
    ..writeln()
    ..writeln('扫描范围：`mobile/lib` 中与 UI 相关的 Dart 文件（本次扫描文件数：$scannedFiles）。')
    ..writeln(
      '总条目：`${entries.length}`（按源码出现位置保留重复使用点）；每条都有稳定 ID、原文模板、locale、类型与源码行号。',
    )
    ..writeln()
    ..writeln('## 使用与边界')
    ..writeln()
    ..writeln(
      '- 重新生成：`cd "E:/fitness app/strength-pro/mobile"; dart run tool/export_ui_copy.dart`。',
    )
    ..writeln(
      '- 在同目录的 `ui-copy-review.html` 中搜索、按页面筛选、勾选条目，并导出“ID + 原文模板” JSON；导出不会回写源码。',
    )
    ..writeln(
      '- `zh-CN + en` 表示调用了 `AppStrings` 的中文源键/英文目录；直接中文字符串标记为 `zh-CN`，直接英文字符串标记为 `en`。',
    )
    ..writeln(
      '- 解释候选只是审阅提示，不代表应删除；重点包含 helper/subtitle/description、弹窗正文、空状态和错误/轻提示。',
    )
    ..writeln(
      '- 运行时 AI/远端回答、用户输入和服务端下发的动作/营养内容无法由静态扫描穷举；生成动作目录中的名称、教学摘要和步骤另列为“动作库·目录附录”（资源路径、API 字段/地址、日志与 AI 系统指令排除）。',
    )
    ..writeln()
    ..writeln('## 统计')
    ..writeln()
    ..writeln('| 页面/分组 | 条目数 |')
    ..writeln('| --- | ---: |');
  final byPage = <String, int>{};
  for (final entry in entries) {
    byPage.update(entry.page, (value) => value + 1, ifAbsent: () => 1);
  }
  for (final item in byPage.entries) {
    buffer.writeln('| ${_md(item.key)} | ${item.value} |');
  }
  buffer
    ..writeln()
    ..writeln('## 完整清单')
    ..writeln()
    ..writeln('| 选择 | 稳定 ID | 页面 | locale | 类型 | 原文模板 | 源码 | 解释候选 |')
    ..writeln('| --- | --- | --- | --- | --- | --- | --- | --- |');
  for (final entry in entries) {
    final source = '${entry.file}:${entry.line}:${entry.column}';
    final explanatory = entry.explanatoryCandidate
        ? '是（${entry.explanatoryReason}）'
        : '否';
    buffer.writeln(
      '| [ ] | `$entry.id` | ${_md(entry.page)} | ${_md(entry.locale)} | ${_md(entry.type)} | ${_md(entry.originalText)} | `$source` | ${_md(explanatory)} |',
    );
  }
  return buffer.toString();
}

String _html(Map<String, Object?> payload) {
  final data = jsonEncode(payload).replaceAll('</', '<\\/');
  final template = r'''<!doctype html>
<html lang="zh-CN">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Flutter UI 文案盘点</title>
<style>
:root { color-scheme: light; --ink:#162033; --muted:#5a6475; --line:#d9deea; --paper:#fff; --soft:#f4f6fa; --accent:#1258d6; --warn:#fff7df; }
* { box-sizing:border-box; }
body { margin:0; background:var(--soft); color:var(--ink); font:15px/1.55 system-ui,-apple-system,"Segoe UI","Microsoft YaHei",sans-serif; }
main { width:min(1500px,100%); margin:0 auto; padding:24px clamp(14px,3vw,36px) 48px; }
h1 { margin:0 0 8px; font-size:clamp(22px,3vw,34px); line-height:1.2; }
p { margin:6px 0; }
.muted { color:var(--muted); }
.notice { margin:16px 0; padding:12px 14px; border:1px solid #edd99b; border-radius:12px; background:var(--warn); }
.toolbar { position:sticky; top:0; z-index:2; display:grid; grid-template-columns:minmax(220px,2fr) minmax(140px,1fr) minmax(130px,1fr) auto auto auto; gap:10px; align-items:end; padding:12px 0; background:rgba(244,246,250,.94); backdrop-filter:blur(8px); }
label { display:grid; gap:4px; color:var(--muted); font-size:12px; font-weight:650; }
input,select,button { min-height:42px; border:1px solid var(--line); border-radius:9px; background:var(--paper); color:var(--ink); font:inherit; padding:8px 11px; }
input:focus,select:focus,button:focus-visible { outline:3px solid rgba(18,88,214,.25); outline-offset:1px; border-color:var(--accent); }
button { cursor:pointer; font-weight:650; }
button.primary { border-color:var(--accent); background:var(--accent); color:#fff; }
button:disabled { cursor:not-allowed; opacity:.55; }
.stats { display:flex; gap:14px; flex-wrap:wrap; color:var(--muted); margin:4px 0 10px; }
.table-wrap { overflow-x:auto; border:1px solid var(--line); border-radius:12px; background:var(--paper); }
table { width:100%; border-collapse:collapse; table-layout:fixed; }
th,td { padding:10px 9px; border-bottom:1px solid var(--line); vertical-align:top; overflow-wrap:anywhere; word-break:break-word; text-align:left; }
th { position:sticky; top:76px; z-index:1; background:#eef2f9; color:#38445a; font-size:12px; }
tr:last-child td { border-bottom:0; }
tbody tr:hover { background:#f8faff; }
th:nth-child(1),td:nth-child(1) { width:48px; text-align:center; }
th:nth-child(2),td:nth-child(2) { width:145px; font-family:ui-monospace,SFMono-Regular,Consolas,monospace; font-size:12px; }
th:nth-child(3),td:nth-child(3) { width:115px; }
th:nth-child(4),td:nth-child(4) { width:86px; }
th:nth-child(5),td:nth-child(5) { width:110px; }
th:nth-child(7),td:nth-child(7) { width:190px; font-size:12px; color:var(--muted); }
th:nth-child(8),td:nth-child(8) { width:125px; }
.copy { white-space:pre-wrap; }
.explain { color:#8a5a00; }
.empty { padding:28px; text-align:center; color:var(--muted); }
.pager { display:flex; justify-content:center; align-items:center; gap:12px; padding:14px 0 0; }
.pager span { min-width:120px; text-align:center; color:var(--muted); }
@media (max-width:760px) {
  main { padding:18px 10px 34px; }
  .toolbar { position:static; grid-template-columns:1fr 1fr; }
  .toolbar label:first-child { grid-column:1/-1; }
  .toolbar button { width:100%; }
  .table-wrap { border:0; background:transparent; overflow:visible; }
  table,thead,tbody,tr,th,td { display:block; width:100%; }
  thead { position:absolute; width:1px; height:1px; overflow:hidden; clip:rect(0 0 0 0); }
  tbody { display:grid; gap:10px; }
  tbody tr { border:1px solid var(--line); border-radius:12px; background:var(--paper); padding:8px 10px; }
  tbody td { display:grid; grid-template-columns:92px minmax(0,1fr); gap:8px; padding:6px 0; border:0; }
  tbody td::before { content:attr(data-label); color:var(--muted); font-size:12px; font-weight:650; }
  tbody td:first-child { display:block; padding-bottom:8px; border-bottom:1px solid var(--line); }
  tbody td:first-child::before { content:none; }
}
@media (prefers-reduced-motion:reduce) { *,*::before,*::after { scroll-behavior:auto !important; transition:none !important; } }
</style>
</head>
<body>
<main>
  <h1>Flutter UI 文案盘点</h1>
  <p class="muted">静态源码审阅清单：可搜索、按页面筛选、勾选候选，并导出 ID + 原文模板 JSON。导出不会修改 app。</p>
  <div class="notice" role="note">边界：运行时 AI/远端内容、用户输入与服务端下发数据无法静态穷举；动作目录名称、教学摘要和步骤收在独立附录，默认隐藏以便先审阅界面文案。删除前请人工确认每个稳定 ID 的所有使用点。</div>
  <section class="toolbar" aria-label="清单筛选与导出">
    <label>搜索原文/源码/ID<input id="search" type="search" placeholder="例如：休息、tooltip、main.dart" autocomplete="off"></label>
    <label>范围<select id="scope"><option value="ui" selected>界面文案（默认）</option><option value="catalog">仅动作目录附录</option><option value="all">界面 + 目录</option></select></label>
    <label>页面筛选<select id="page"><option value="">全部页面</option></select></label>
    <label>解释候选<select id="explain"><option value="">全部</option><option value="yes">仅解释候选</option><option value="no">普通文案</option></select></label>
    <button id="selectVisible" type="button">勾选筛选结果</button>
    <button id="clear" type="button">清除勾选</button>
    <button id="export" class="primary" type="button" disabled>导出所选 JSON</button>
  </section>
  <div class="stats" id="stats" aria-live="polite"></div>
  <div class="table-wrap">
    <table>
      <thead><tr><th scope="col">选</th><th scope="col">稳定 ID</th><th scope="col">页面</th><th scope="col">locale</th><th scope="col">类型</th><th scope="col">原文模板</th><th scope="col">源码</th><th scope="col">解释候选</th></tr></thead>
      <tbody id="rows"></tbody>
    </table>
    <div id="empty" class="empty" hidden>没有匹配条目。</div>
  </div>
  <nav class="pager" aria-label="清单分页"><button id="prev" type="button" disabled>上一页</button><span id="pageInfo" aria-live="polite"></span><button id="next" type="button" disabled>下一页</button></nav>
</main>
<script>
const INVENTORY = __INVENTORY__;
const entries = INVENTORY.entries || [];
const selected = new Set();
const search = document.querySelector('#search');
const scope = document.querySelector('#scope');
const page = document.querySelector('#page');
const explain = document.querySelector('#explain');
const rows = document.querySelector('#rows');
const empty = document.querySelector('#empty');
const stats = document.querySelector('#stats');
const exportButton = document.querySelector('#export');
const prev = document.querySelector('#prev');
const next = document.querySelector('#next');
const pageInfo = document.querySelector('#pageInfo');
const PAGE_SIZE = 80;
let pageIndex = 0;
const esc = (value) => String(value ?? '').replace(/[&<>"']/g, (ch) => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[ch]));
const normalized = (value) => String(value ?? '').toLocaleLowerCase();
const pages = [...new Set(entries.map((entry) => entry.page).filter(Boolean))].sort((a,b) => a.localeCompare(b,'zh-CN'));
for (const value of pages) { const option = document.createElement('option'); option.value = value; option.textContent = value; page.append(option); }
function visibleEntries() {
  const query = normalized(search.value.trim());
  const scopeValue = scope.value;
  const pageValue = page.value;
  const explainValue = explain.value;
  return entries.filter((entry) => {
    const isCatalog = entry.page === '动作库·目录附录';
    if (scopeValue === 'ui' && isCatalog) return false;
    if (scopeValue === 'catalog' && !isCatalog) return false;
    if (pageValue && entry.page !== pageValue) return false;
    if (explainValue === 'yes' && !entry.explanatoryCandidate) return false;
    if (explainValue === 'no' && entry.explanatoryCandidate) return false;
    if (!query) return true;
    return [entry.id,entry.originalText,entry.literalSource,entry.file,entry.type,entry.className,entry.functionName].some((value) => normalized(value).includes(query));
  });
}
function update() {
  const allVisible = visibleEntries();
  const pageCount = Math.max(1, Math.ceil(allVisible.length / PAGE_SIZE));
  pageIndex = Math.min(pageIndex, pageCount - 1);
  const visible = allVisible.slice(pageIndex * PAGE_SIZE, (pageIndex + 1) * PAGE_SIZE);
  rows.innerHTML = visible.map((entry) => {
    const checked = selected.has(entry.id) ? ' checked' : '';
    const source = `${entry.file}:${entry.line}:${entry.column}`;
    const explanatory = entry.explanatoryCandidate ? `是：${entry.explanatoryReason}` : '否';
    return `<tr><td data-label="选择"><input class="pick" type="checkbox" data-id="${esc(entry.id)}"${checked} aria-label="选择 ${esc(entry.id)}"></td><td data-label="稳定 ID"><code>${esc(entry.id)}</code></td><td data-label="页面">${esc(entry.page)}<br><span class="muted">${esc(entry.className || '')}${entry.functionName ? ` · ${esc(entry.functionName)}` : ''}</span></td><td data-label="locale">${esc(entry.locale)}</td><td data-label="类型">${esc(entry.type)}</td><td data-label="原文模板" class="copy">${esc(entry.originalText)}</td><td data-label="源码"><code>${esc(source)}</code></td><td data-label="解释候选" class="${entry.explanatoryCandidate ? 'explain' : ''}">${esc(explanatory)}</td></tr>`;
  }).join('');
  empty.hidden = visible.length !== 0;
  stats.textContent = `共 ${entries.length} 条 · 当前筛选 ${allVisible.length} 条 · 本页 ${visible.length} 条 · 已选 ${selected.size} 条`;
  pageInfo.textContent = `${pageIndex + 1} / ${pageCount}`;
  prev.disabled = pageIndex <= 0;
  next.disabled = pageIndex >= pageCount - 1;
  exportButton.disabled = selected.size === 0;
  rows.querySelectorAll('.pick').forEach((box) => box.addEventListener('change', () => { box.checked ? selected.add(box.dataset.id) : selected.delete(box.dataset.id); update(); }));
}
search.addEventListener('input', () => { pageIndex = 0; update(); });
scope.addEventListener('change', () => { pageIndex = 0; update(); });
page.addEventListener('change', () => { pageIndex = 0; update(); });
explain.addEventListener('change', () => { pageIndex = 0; update(); });
document.querySelector('#selectVisible').addEventListener('click', () => { visibleEntries().forEach((entry) => selected.add(entry.id)); update(); });
document.querySelector('#clear').addEventListener('click', () => { selected.clear(); update(); });
prev.addEventListener('click', () => { pageIndex = Math.max(0, pageIndex - 1); update(); });
next.addEventListener('click', () => { pageIndex += 1; update(); });
exportButton.addEventListener('click', () => {
  const output = entries.filter((entry) => selected.has(entry.id)).map((entry) => ({id:entry.id, originalText:entry.originalText}));
  const blob = new Blob([JSON.stringify(output,null,2) + '\n'], {type:'application/json;charset=utf-8'});
  const url = URL.createObjectURL(blob); const link = document.createElement('a'); link.href = url; link.download = 'selected-ui-copy.json'; link.click(); URL.revokeObjectURL(url);
});
update();
</script>
</body>
</html>
''';
  return template.replaceFirst('__INVENTORY__', data);
}

_ScanResult _scanSource(String source) {
  final lineStarts = <int>[0];
  for (var i = 0; i < source.length; i++) {
    if (source.codeUnitAt(i) == 10) lineStarts.add(i + 1);
  }
  final events = <_SyntaxEvent>[];
  final strings = <_StringToken>[];
  var i = 0;
  while (i < source.length) {
    final code = source.codeUnitAt(i);
    if (_isWhitespace(code)) {
      i++;
      continue;
    }
    if (source.startsWith('//', i)) {
      i = _skipLine(source, i + 2);
      continue;
    }
    if (source.startsWith('/*', i)) {
      i = _skipBlockComment(source, i + 2);
      continue;
    }
    final quote = _quoteAt(source, i);
    if (quote != null) {
      final token = _readString(source, i, lineStarts, quote);
      strings.add(token);
      events.add(
        _SyntaxEvent(
          start: token.start,
          end: token.end,
          kind: 'string',
          value: token.template,
          stringToken: token,
        ),
      );
      i = token.end;
      continue;
    }
    if (_isIdentifierStart(code)) {
      var end = i + 1;
      while (end < source.length && _isIdentifierPart(source.codeUnitAt(end))) {
        end++;
      }
      events.add(
        _SyntaxEvent(
          start: i,
          end: end,
          kind: 'ident',
          value: source.substring(i, end),
        ),
      );
      i = end;
      continue;
    }
    final punctuation = String.fromCharCode(code);
    if ('(){}[]:,.;'.contains(punctuation)) {
      events.add(
        _SyntaxEvent(start: i, end: i + 1, kind: 'punct', value: punctuation),
      );
    }
    i++;
  }

  final contexts = <_StringToken, _StringContext>{};
  final frames = <_CallFrame>[];
  for (var eventIndex = 0; eventIndex < events.length; eventIndex++) {
    final event = events[eventIndex];
    if (event.kind == 'string') {
      final named = _namedArgument(
        source,
        event.start,
        frames.isEmpty ? 0 : frames.last.openStart,
      );
      contexts[event.stringToken!] = _StringContext(
        calls: frames
            .map((frame) => frame.name)
            .where((name) => name.isNotEmpty)
            .toList(growable: false),
        namedArgument: named,
        localized: _isLocalizedContext(frames),
      );
      continue;
    }
    if (event.kind != 'punct') continue;
    if (event.value == '(') {
      var name = '';
      if (eventIndex > 0 && events[eventIndex - 1].kind == 'ident') {
        name = events[eventIndex - 1].value;
      }
      frames.add(_CallFrame(name, event.start));
    } else if (event.value == ')' && frames.isNotEmpty) {
      frames.removeLast();
    }
  }
  return _ScanResult(
    strings,
    contexts,
    _buildDeclarations(source, events, lineStarts),
  );
}

bool _isLocalizedContext(List<_CallFrame> frames) {
  return frames.any((frame) {
    final name = frame.name.toLowerCase();
    return name == 'text' ||
        name == 'tr' ||
        name == 'textfor' ||
        name == 'translate';
  });
}

String? _namedArgument(String source, int stringStart, int openStart) {
  final from = openStart > 0
      ? openStart + 1
      : (stringStart - 220).clamp(0, stringStart);
  final snippet = source.substring(from.clamp(0, stringStart), stringStart);
  final match = RegExp(
    r'([A-Za-z_][A-Za-z0-9_]*)\s*:\s*(?:const\s+)?$',
  ).firstMatch(snippet);
  return match?.group(1);
}

_DeclarationIndex _buildDeclarations(
  String source,
  List<_SyntaxEvent> events,
  List<int> lineStarts,
) {
  final bracePairs = <int, int>{};
  final braces = <_SyntaxEvent>[];
  for (final event in events) {
    if (event.kind != 'punct') continue;
    if (event.value == '{') {
      braces.add(event);
    } else if (event.value == '}' && braces.isNotEmpty) {
      final open = braces.removeLast();
      bracePairs[open.start] = event.end;
    }
  }
  final classes = <_ClassRange>[];
  final functions = <_Declaration>[];
  final lines = source.split('\n');
  var offset = 0;
  for (final line in lines) {
    final classMatch = _classDeclaration.firstMatch(line);
    if (classMatch != null) {
      final declarationStart = offset + classMatch.start;
      final open = events.firstWhere(
        (event) =>
            event.kind == 'punct' &&
            event.value == '{' &&
            event.start >= declarationStart,
        orElse: () => _SyntaxEvent(
          start: declarationStart,
          end: declarationStart,
          kind: 'none',
          value: '',
        ),
      );
      if (open.kind == 'punct') {
        classes.add(
          _ClassRange(
            name: classMatch.group(1)!,
            start: declarationStart,
            end: bracePairs[open.start] ?? source.length,
          ),
        );
      }
    }
    final functionMatch = _functionDeclaration.firstMatch(line);
    if (functionMatch != null &&
        !line.trimLeft().startsWith('class ') &&
        _isLikelyFunctionDeclaration(line, functionMatch)) {
      final start = offset + functionMatch.start;
      final matches = classes
          .where((item) => start >= item.start && start <= item.end)
          .toList();
      final className = matches.isEmpty ? null : matches.last.name;
      functions.add(
        _Declaration(
          name: functionMatch.group(1)!,
          start: start,
          className: className,
        ),
      );
    }
    offset += line.length + 1;
  }
  classes.sort((a, b) => a.start.compareTo(b.start));
  functions.sort((a, b) => a.start.compareTo(b.start));
  return _DeclarationIndex(
    classes: classes,
    functions: functions,
    lineStarts: lineStarts,
  );
}

bool _isLikelyFunctionDeclaration(String line, RegExpMatch match) {
  final name = match.group(1) ?? '';
  if (name.isEmpty || name[0].toUpperCase() == name[0]) return false;
  final trimmed = line.trimLeft();
  if (RegExp(
    r'^(?:if|for|while|switch|catch|return|throw|assert|setState)\b',
  ).hasMatch(trimmed)) {
    return false;
  }
  final prefix = line.substring(0, match.start).trim();
  if (prefix.contains('.')) return false;
  // A typed signature is the usual form for top-level functions and methods.
  // Allow a line ending in `{`/`=>` for inferred return types, but reject
  // ordinary widget/collection calls that happen to start with an identifier.
  final typed =
      prefix.isNotEmpty &&
      !RegExp(r'^(?:final|const|var|late)\b').hasMatch(trimmed);
  if (typed) return true;
  final suffix = line.substring(match.end);
  return suffix.contains('{') || suffix.contains('=>');
}

String? _quoteAt(String source, int index) {
  if (index >= source.length) return null;
  final value = source[index];
  if (value == "'" || value == '"') return value;
  if ((value == 'r' || value == 'R') && index + 1 < source.length) {
    final next = source[index + 1];
    if (next == "'" || next == '"') return next;
  }
  return null;
}

_StringToken _readString(
  String source,
  int start,
  List<int> lineStarts,
  String quote,
) {
  final raw = source[start] == 'r' || source[start] == 'R';
  final quoteStart = raw ? start + 1 : start;
  final triple = source.startsWith('$quote$quote$quote', quoteStart);
  final delimiterLength = triple ? 3 : 1;
  final contentStart = quoteStart + delimiterLength;
  final closing = _findStringEnd(source, contentStart, quote, triple, raw);
  final contentEnd = closing >= 0 ? closing : source.length;
  final content = source.substring(contentStart, contentEnd);
  final value = raw ? content : _decodeDartEscapes(content);
  final template = _interpolationTemplate(value, raw);
  final line = _lineFor(lineStarts, start);
  final column = start - lineStarts[line - 1] + 1;
  final end = closing < 0 ? source.length : closing + delimiterLength;
  return _StringToken(
    start: start,
    end: end,
    line: line,
    column: column,
    value: value,
    template: template,
    literalSource: source.substring(start, end),
    raw: raw,
  );
}

int _findStringEnd(
  String source,
  int start,
  String quote,
  bool triple,
  bool raw,
) {
  var index = start;
  while (index < source.length) {
    if (!raw && source[index] == '\\') {
      index = (index + 2).clamp(0, source.length);
      continue;
    }
    if (!raw &&
        source[index] == '\$' &&
        index + 1 < source.length &&
        source[index + 1] == '{') {
      index = _skipInterpolation(source, index + 2);
      continue;
    }
    if (triple && source.startsWith('$quote$quote$quote', index)) return index;
    if (!triple && source[index] == quote) return index;
    index++;
  }
  return -1;
}

int _skipInterpolation(String source, int start) {
  var depth = 1;
  var index = start;
  while (index < source.length) {
    if (source.startsWith('//', index)) {
      index = _skipLine(source, index + 2);
      continue;
    }
    if (source.startsWith('/*', index)) {
      index = _skipBlockComment(source, index + 2);
      continue;
    }
    final quote = _quoteAt(source, index);
    if (quote != null) {
      final raw = source[index] == 'r' || source[index] == 'R';
      final quoteStart = raw ? index + 1 : index;
      final triple = source.startsWith('$quote$quote$quote', quoteStart);
      final delimiterLength = triple ? 3 : 1;
      final contentStart = quoteStart + delimiterLength;
      final end = _findStringEnd(source, contentStart, quote, triple, raw);
      index = end < 0 ? source.length : end + delimiterLength;
      continue;
    }
    if (source[index] == '{') {
      depth++;
    } else if (source[index] == '}') {
      depth--;
      if (depth == 0) return index + 1;
    }
    index++;
  }
  return source.length;
}

String _decodeDartEscapes(String value) {
  final buffer = StringBuffer();
  for (var index = 0; index < value.length; index++) {
    if (value[index] != '\\' || index + 1 >= value.length) {
      buffer.write(value[index]);
      continue;
    }
    final next = value[++index];
    switch (next) {
      case 'n':
        buffer.write('\n');
      case 'r':
        buffer.write('\r');
      case 't':
        buffer.write('\t');
      case 'b':
        buffer.write('\b');
      case 'f':
        buffer.write('\f');
      case 'v':
        buffer.write('\v');
      case '0':
        buffer.write('\u0000');
      case '\\':
        buffer.write('\\');
      case "'":
        buffer.write("'");
      case '"':
        buffer.write('"');
      case '\$':
        buffer.write('\$');
      case 'x':
        if (index + 2 <= value.length - 1) {
          final hex = value.substring(index + 1, index + 3);
          final code = int.tryParse(hex, radix: 16);
          if (code != null) {
            buffer.write(String.fromCharCode(code));
            index += 2;
            break;
          }
        }
        buffer.write('\\x');
      case 'u':
        if (index + 1 < value.length && value[index + 1] == '{') {
          final close = value.indexOf('}', index + 2);
          if (close > index) {
            final code = int.tryParse(
              value.substring(index + 2, close),
              radix: 16,
            );
            if (code != null) {
              buffer.write(String.fromCharCode(code));
              index = close;
              break;
            }
          }
        } else if (index + 4 <= value.length - 1) {
          final hex = value.substring(index + 1, index + 5);
          final code = int.tryParse(hex, radix: 16);
          if (code != null) {
            buffer.write(String.fromCharCode(code));
            index += 4;
            break;
          }
        }
        buffer.write('\\u');
      default:
        buffer.write('\\$next');
    }
  }
  return buffer.toString();
}

String _interpolationTemplate(String value, bool raw) {
  if (raw) return value;
  final buffer = StringBuffer();
  var index = 0;
  while (index < value.length) {
    final current = value[index];
    if (current == '\\' &&
        index + 1 < value.length &&
        value[index + 1] == '\$') {
      buffer.write('\$');
      index += 2;
      continue;
    }
    if (current != '\$') {
      buffer.write(current);
      index++;
      continue;
    }
    if (index + 1 < value.length && value[index + 1] == '{') {
      final close = _balancedInterpolationEnd(value, index + 2);
      if (close >= 0) {
        final expression = value.substring(index + 2, close).trim();
        buffer.write('{{${_templateExpression(expression)}}}');
        index = close + 1;
        continue;
      }
    }
    if (index + 1 < value.length &&
        _isIdentifierStart(value.codeUnitAt(index + 1))) {
      var end = index + 2;
      while (end < value.length && _isIdentifierPart(value.codeUnitAt(end))) {
        end++;
      }
      buffer.write('{{${value.substring(index + 1, end)}}}');
      index = end;
      continue;
    }
    buffer.write('\$');
    index++;
  }
  return buffer.toString();
}

int _balancedInterpolationEnd(String value, int start) {
  var depth = 1;
  var index = start;
  while (index < value.length) {
    if (value[index] == '\\') {
      index += 2;
      continue;
    }
    if (value[index] == '{') depth++;
    if (value[index] == '}') {
      depth--;
      if (depth == 0) return index;
    }
    index++;
  }
  return -1;
}

String _templateExpression(String expression) {
  if (expression.isEmpty) return 'value';
  final normalized = expression.replaceAll(RegExp(r'\s+'), ' ').trim();
  return normalized.length > 80
      ? '${normalized.substring(0, 77)}…'
      : normalized;
}

int _lineFor(List<int> lineStarts, int offset) {
  var low = 0;
  var high = lineStarts.length - 1;
  while (low <= high) {
    final mid = (low + high) >> 1;
    if (lineStarts[mid] <= offset) {
      low = mid + 1;
    } else {
      high = mid - 1;
    }
  }
  return high + 1;
}

int _skipLine(String source, int index) {
  final newline = source.indexOf('\n', index);
  return newline < 0 ? source.length : newline + 1;
}

int _skipBlockComment(String source, int index) {
  final end = source.indexOf('*/', index);
  return end < 0 ? source.length : end + 2;
}

bool _isWhitespace(int code) =>
    code == 9 || code == 10 || code == 13 || code == 32;

bool _isIdentifierStart(int code) =>
    (code >= 65 && code <= 90) ||
    (code >= 97 && code <= 122) ||
    code == 95 ||
    code == 36;

bool _isIdentifierPart(int code) =>
    _isIdentifierStart(code) || (code >= 48 && code <= 57);

String _fnv1a(String value) {
  var hash = 0xcbf29ce484222325;
  for (final code in value.codeUnits) {
    hash ^= code;
    // Keep a positive 63-bit digest so IDs are convenient to copy and use as
    // HTML data attributes on every Dart VM platform.
    hash = (hash * 0x100000001b3) & 0x7fffffffffffffff;
  }
  return hash.toRadixString(16).padLeft(16, '0');
}

String _md(String value) => value
    .replaceAll('\\', '\\\\')
    .replaceAll('|', '\\|')
    .replaceAll('\r', '')
    .replaceAll('\n', '<br>');

String _join(String a, String b, [String? c, String? d]) {
  final parts = <String>[a, b];
  if (c != null) parts.add(c);
  if (d != null) parts.add(d);
  return parts.join(Platform.pathSeparator);
}

String _basename(String path) => path.split(RegExp(r'[/\\]')).last;

String _basenameWithoutExtension(String path) {
  final value = _basename(path);
  final dot = value.lastIndexOf('.');
  return dot > 0 ? value.substring(0, dot) : value;
}

String _relativePath(String root, String path) {
  var value = path;
  if (value.startsWith(root)) value = value.substring(root.length);
  return value.replaceFirst(RegExp(r'^[/\\]'), '').replaceAll('\\', '/');
}

Directory _resolveMobileRoot(List<String> args) {
  String? supplied;
  for (var index = 0; index < args.length; index++) {
    if (args[index] == '--project-root' && index + 1 < args.length) {
      supplied = args[++index];
    }
  }
  final current = Directory.current;
  final candidates = <Directory>[
    if (supplied != null) Directory(supplied),
    current,
    Directory(_join(current.path, 'mobile')),
  ];
  for (final candidate in candidates) {
    if (Directory(_join(candidate.path, 'lib')).existsSync()) {
      return candidate.absolute;
    }
  }
  throw StateError(
    'Cannot find mobile root. Run from strength-pro/mobile or pass --project-root.',
  );
}
