import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The local account/entitlement implementation used while the production
/// identity service is not available yet.  The public API deliberately keeps
/// the same boundaries as the service contract documented in v10 so the
/// repository can be replaced by an authenticated client later.

const bool _testAdminFlag = bool.fromEnvironment(
  'ENABLE_TEST_ADMIN',
  defaultValue: false,
);

/// `123 / 123` and `1234 / 1234` are development fixtures only. In a release
/// build they are disabled unless the developer explicitly opted in with
/// `--dart-define=ENABLE_TEST_ADMIN=true`.
bool get testAdminEnabled => kDebugMode || _testAdminFlag;

enum AuthProvider { phone, apple, google }

enum MembershipPlan { free, oneMonth, threeMonths, yearly, forever }

enum MembershipOrderStatus {
  pending,
  processing,
  paid,
  restored,
  cancelled,
  failed,
  refunded,
}

enum MembershipOrderProvider {
  appStore,
  googlePlay,
  wechatPay,
  alipay,
  redemption,
}

enum UsageKind { ai, recognition }

enum AccountError {
  none,
  emptyIdentifier,
  invalidIdentifier,
  invalidPassword,
  invalidCredentials,
  serviceNotConfigured,
  notAuthenticated,
  adminRequired,
  quotaExhausted,
  invalidCode,
  codeAlreadyUsed,
  invalidMembershipPlan,
}

class PhoneCodeChallenge {
  const PhoneCodeChallenge({
    required this.sent,
    required this.retryAfterSeconds,
    required this.expiresInSeconds,
  });

  final bool sent;
  final int retryAfterSeconds;
  final int expiresInSeconds;
}

String safeAccountName(String value) {
  final clean = value.trim();
  if (clean.isEmpty ||
      RegExp(
        r'^(apple:|phone:|google:|usr_)|^[a-f0-9_-]{20,}$',
        caseSensitive: false,
      ).hasMatch(clean)) {
    return '形域用户';
  }
  return clean;
}

String _newPublicAccountId() =>
    '${1 + Random.secure().nextInt(9)}${Random.secure().nextInt(1000000000).toString().padLeft(9, '0')}';

class AccountUser {
  const AccountUser({
    required this.id,
    required this.identifier,
    required this.displayName,
    required this.isAdmin,
    this.provider = AuthProvider.phone,
    this.avatarPath,
    this.publicId = '',
  });

  final String id;
  final String identifier;
  final String displayName;
  final bool isAdmin;
  final AuthProvider provider;
  final String? avatarPath;
  final String publicId;
  String get visibleName => safeAccountName(displayName);

  Map<String, Object?> toMap() => {
    'id': id,
    'identifier': identifier,
    'displayName': displayName,
    'isAdmin': isAdmin,
    'provider': provider.name,
    'avatarPath': avatarPath,
    'publicId': publicId,
  };

  factory AccountUser.fromMap(Map<String, dynamic> map) => AccountUser(
    id: (map['id'] ?? '').toString(),
    identifier: (map['identifier'] ?? '').toString(),
    displayName: (map['displayName'] ?? map['identifier'] ?? '').toString(),
    isAdmin: map['isAdmin'] == true,
    provider: AuthProvider.values.firstWhere(
      (item) => item.name == map['provider'],
      orElse: () => AuthProvider.phone,
    ),
    avatarPath: map['avatarPath']?.toString(),
    publicId: (map['publicId']?.toString().isNotEmpty == true)
        ? map['publicId'].toString()
        : _newPublicAccountId(),
  );
}

class AccountResult<T> {
  const AccountResult({required this.error, this.value, this.message});

  const AccountResult.success([this.value])
    : error = AccountError.none,
      message = null;

  const AccountResult.failure(this.error, {this.message, this.value});

  final AccountError error;
  final T? value;
  final String? message;

  bool get isSuccess => error == AccountError.none;
}

class AuthResult extends AccountResult<AccountUser> {
  const AuthResult.success(super.value) : super.success();

  const AuthResult.failure(super.error, {super.message}) : super.failure();

  AccountUser? get user => value;
}

class EntitlementSnapshot {
  const EntitlementSnapshot({
    required this.membership,
    required this.membershipExpiresAt,
    this.trialStartedAt,
    this.trialExpiresAt,
    this.trialWorkoutId,
    required this.aiRemaining,
    required this.aiDailyLimit,
    required this.recognitionRemaining,
    required this.recognitionWeeklyGrant,
    required this.aiPeriodKey,
    required this.recognitionWeekKey,
    this.cloudRetentionExpiresAt,
    this.cloudSyncReadable = false,
    this.cloudSyncWritable = false,
  });

  factory EntitlementSnapshot.free({
    int aiRemaining = 3,
    int recognitionRemaining = 5,
    String aiPeriodKey = '',
    String recognitionWeekKey = '',
  }) => EntitlementSnapshot(
    membership: MembershipPlan.free,
    membershipExpiresAt: null,
    aiRemaining: aiRemaining,
    aiDailyLimit: 3,
    recognitionRemaining: recognitionRemaining,
    recognitionWeeklyGrant: 1,
    aiPeriodKey: aiPeriodKey,
    recognitionWeekKey: recognitionWeekKey,
  );

  final MembershipPlan membership;
  final DateTime? membershipExpiresAt;
  final DateTime? trialStartedAt;
  final DateTime? trialExpiresAt;
  final String? trialWorkoutId;
  final int aiRemaining;
  final int aiDailyLimit;
  final int recognitionRemaining;
  final int recognitionWeeklyGrant;
  final String aiPeriodKey;
  final String recognitionWeekKey;
  final DateTime? cloudRetentionExpiresAt;
  final bool cloudSyncReadable;
  final bool cloudSyncWritable;

  bool isTrialActiveAt(DateTime at) => trialExpiresAt?.isAfter(at) == true;

  bool get trialActive => isTrialActiveAt(DateTime.now());

  bool get trialClaimed =>
      trialStartedAt != null ||
      trialExpiresAt != null ||
      trialWorkoutId != null;

  bool get trialEligible => !trialClaimed;

  bool get isMember => membership != MembershipPlan.free || trialActive;

  EntitlementSnapshot copyWith({
    MembershipPlan? membership,
    DateTime? membershipExpiresAt,
    bool clearMembershipExpiresAt = false,
    DateTime? trialStartedAt,
    DateTime? trialExpiresAt,
    String? trialWorkoutId,
    int? aiRemaining,
    int? aiDailyLimit,
    int? recognitionRemaining,
    int? recognitionWeeklyGrant,
    String? aiPeriodKey,
    String? recognitionWeekKey,
    DateTime? cloudRetentionExpiresAt,
    bool? cloudSyncReadable,
    bool? cloudSyncWritable,
  }) => EntitlementSnapshot(
    membership: membership ?? this.membership,
    membershipExpiresAt: clearMembershipExpiresAt
        ? null
        : membershipExpiresAt ?? this.membershipExpiresAt,
    trialStartedAt: trialStartedAt ?? this.trialStartedAt,
    trialExpiresAt: trialExpiresAt ?? this.trialExpiresAt,
    trialWorkoutId: trialWorkoutId ?? this.trialWorkoutId,
    aiRemaining: aiRemaining ?? this.aiRemaining,
    aiDailyLimit: aiDailyLimit ?? this.aiDailyLimit,
    recognitionRemaining: recognitionRemaining ?? this.recognitionRemaining,
    recognitionWeeklyGrant:
        recognitionWeeklyGrant ?? this.recognitionWeeklyGrant,
    aiPeriodKey: aiPeriodKey ?? this.aiPeriodKey,
    recognitionWeekKey: recognitionWeekKey ?? this.recognitionWeekKey,
    cloudRetentionExpiresAt:
        cloudRetentionExpiresAt ?? this.cloudRetentionExpiresAt,
    cloudSyncReadable: cloudSyncReadable ?? this.cloudSyncReadable,
    cloudSyncWritable: cloudSyncWritable ?? this.cloudSyncWritable,
  );

  Map<String, Object?> toMap() => {
    'membership': membership.name,
    'membershipExpiresAt': membershipExpiresAt?.toIso8601String(),
    'trialStartedAt': trialStartedAt?.toIso8601String(),
    'trialExpiresAt': trialExpiresAt?.toIso8601String(),
    'trialWorkoutId': trialWorkoutId,
    'aiRemaining': aiRemaining,
    'aiDailyLimit': aiDailyLimit,
    'recognitionRemaining': recognitionRemaining,
    'recognitionWeeklyGrant': recognitionWeeklyGrant,
    'aiPeriodKey': aiPeriodKey,
    'recognitionWeekKey': recognitionWeekKey,
    'cloudRetentionExpiresAt': cloudRetentionExpiresAt?.toIso8601String(),
    'cloudSyncReadable': cloudSyncReadable,
    'cloudSyncWritable': cloudSyncWritable,
  };

  factory EntitlementSnapshot.fromMap(Map<String, dynamic> map) {
    final rawMembership = (map['membership'] ?? '').toString();
    // `threeMonths` was already persisted by older builds and remains the
    // quarterly plan. `yearly` is a new explicit value; never collapse the
    // two because that would change an existing user's entitlement label.
    final membership = MembershipPlan.values.firstWhere(
      (item) => item.name == rawMembership,
      orElse: () => MembershipPlan.free,
    );
    final trialStartedAt = DateTime.tryParse(
      (map['trialStartedAt'] ?? '').toString(),
    );
    final trialExpiresAt = DateTime.tryParse(
      (map['trialExpiresAt'] ?? '').toString(),
    );
    final trialActive = trialExpiresAt?.isAfter(DateTime.now()) == true;
    final member = membership != MembershipPlan.free || trialActive;
    return EntitlementSnapshot(
      membership: membership,
      membershipExpiresAt: DateTime.tryParse(
        (map['membershipExpiresAt'] ?? '').toString(),
      ),
      trialStartedAt: trialStartedAt,
      trialExpiresAt: trialExpiresAt,
      trialWorkoutId: (map['trialWorkoutId'] ?? '').toString().trim().isEmpty
          ? null
          : (map['trialWorkoutId'] ?? '').toString(),
      aiRemaining: _asInt(map['aiRemaining'], member ? 20 : 3),
      aiDailyLimit: _asInt(map['aiDailyLimit'], member ? 20 : 3),
      recognitionRemaining: _asInt(map['recognitionRemaining'], 5),
      recognitionWeeklyGrant: _asInt(
        map['recognitionWeeklyGrant'],
        member ? 3 : 1,
      ),
      aiPeriodKey: (map['aiPeriodKey'] ?? '').toString(),
      recognitionWeekKey: (map['recognitionWeekKey'] ?? '').toString(),
      cloudRetentionExpiresAt: DateTime.tryParse(
        (map['cloudRetentionExpiresAt'] ?? '').toString(),
      ),
      cloudSyncReadable: map['cloudSyncReadable'] == true || member,
      cloudSyncWritable: map['cloudSyncWritable'] == true || member,
    );
  }
}

int _asInt(Object? value, int fallback) =>
    value is num ? value.toInt() : int.tryParse('$value') ?? fallback;

class RedemptionCode {
  const RedemptionCode({
    required this.code,
    required this.plan,
    required this.createdAt,
    this.usedAt,
    this.usedBy,
  });

  final String code;
  final MembershipPlan plan;
  final DateTime createdAt;
  final DateTime? usedAt;
  final String? usedBy;

  bool get isUsed => usedAt != null || usedBy != null;

  RedemptionCode markUsed({required String userId, DateTime? at}) =>
      RedemptionCode(
        code: code,
        plan: plan,
        createdAt: createdAt,
        usedAt: at ?? DateTime.now(),
        usedBy: userId,
      );

  Map<String, Object?> toMap() => {
    'code': code,
    'plan': plan.name,
    'createdAt': createdAt.toIso8601String(),
    'usedAt': usedAt?.toIso8601String(),
    'usedBy': usedBy,
  };

  factory RedemptionCode.fromMap(Map<String, dynamic> map) => RedemptionCode(
    code: (map['code'] ?? '').toString(),
    plan: MembershipPlan.values.firstWhere(
      (item) => item.name == map['plan'],
      orElse: () => MembershipPlan.free,
    ),
    createdAt:
        DateTime.tryParse((map['createdAt'] ?? '').toString()) ??
        DateTime.fromMillisecondsSinceEpoch(0),
    usedAt: DateTime.tryParse((map['usedAt'] ?? '').toString()),
    usedBy: map['usedBy']?.toString(),
  );
}

class MembershipOrder {
  const MembershipOrder({
    required this.id,
    required this.userId,
    required this.plan,
    required this.productId,
    required this.provider,
    required this.status,
    required this.displayPrice,
    required this.createdAt,
    required this.updatedAt,
    this.transactionId,
    this.failureReason,
  });

  final String id;
  final String userId;
  final MembershipPlan plan;
  final String productId;
  final MembershipOrderProvider provider;
  final MembershipOrderStatus status;
  final String displayPrice;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? transactionId;
  final String? failureReason;

  MembershipOrder copyWith({
    MembershipOrderStatus? status,
    DateTime? updatedAt,
    String? transactionId,
    String? failureReason,
    bool clearFailureReason = false,
  }) => MembershipOrder(
    id: id,
    userId: userId,
    plan: plan,
    productId: productId,
    provider: provider,
    status: status ?? this.status,
    displayPrice: displayPrice,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    transactionId: transactionId ?? this.transactionId,
    failureReason: clearFailureReason
        ? null
        : failureReason ?? this.failureReason,
  );

  Map<String, Object?> toMap() => {
    'id': id,
    'userId': userId,
    'plan': plan.name,
    'productId': productId,
    'provider': provider.name,
    'status': status.name,
    'displayPrice': displayPrice,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'transactionId': transactionId,
    'failureReason': failureReason,
  };

  factory MembershipOrder.fromMap(Map<String, dynamic> map) {
    final createdAt =
        DateTime.tryParse((map['createdAt'] ?? '').toString()) ??
        DateTime.fromMillisecondsSinceEpoch(0);
    final amount = map['amountMinor'];
    final fallbackPrice = amount is num
        ? '${map['currency'] ?? 'CNY'} ${(amount.toDouble() / 100).toStringAsFixed(2)}'
        : '';
    return MembershipOrder(
      id: (map['id'] ?? '').toString(),
      userId: (map['userId'] ?? '').toString(),
      plan: MembershipPlan.values.firstWhere(
        (item) => item.name == map['plan'],
        orElse: () => MembershipPlan.free,
      ),
      productId: (map['productId'] ?? '').toString(),
      provider: switch ((map['provider'] ?? '').toString()) {
        'google_play' || 'googlePlay' => MembershipOrderProvider.googlePlay,
        'wechat_pay' || 'wechatPay' => MembershipOrderProvider.wechatPay,
        'alipay' => MembershipOrderProvider.alipay,
        'redemption' => MembershipOrderProvider.redemption,
        _ => MembershipOrderProvider.appStore,
      },
      status: MembershipOrderStatus.values.firstWhere(
        (item) => item.name == map['status'],
        orElse: () => MembershipOrderStatus.pending,
      ),
      displayPrice: (map['displayPrice'] ?? fallbackPrice).toString(),
      createdAt: createdAt,
      updatedAt:
          DateTime.tryParse((map['updatedAt'] ?? '').toString()) ?? createdAt,
      transactionId: map['transactionId']?.toString(),
      failureReason: map['failureReason']?.toString(),
    );
  }
}

/// Small synchronous persistence boundary.  The production adapter can map
/// this shape to a database transaction without changing entitlement logic.
abstract interface class AccountPersistence {
  Map<String, dynamic>? read();
  void write(Map<String, dynamic> value);
}

class InMemoryAccountPersistence implements AccountPersistence {
  InMemoryAccountPersistence([Map<String, dynamic>? initial])
    : _value = initial == null ? null : _clone(initial);

  Map<String, dynamic>? _value;

  @override
  Map<String, dynamic>? read() => _value == null ? null : _clone(_value!);

  @override
  void write(Map<String, dynamic> value) => _value = _clone(value);

  static Map<String, dynamic> _clone(Map<String, dynamic> input) =>
      jsonDecode(jsonEncode(input)) as Map<String, dynamic>;
}

/// SharedPreferences is intentionally injected after `getInstance()` so
/// tests never need a platform channel.  Use [fromPreferences] in the app
/// bootstrap when durable local storage is wanted.
class SharedPreferencesAccountPersistence implements AccountPersistence {
  SharedPreferencesAccountPersistence(this.preferences);

  final SharedPreferences preferences;
  static const key = 'kilo.account_membership.v1';

  static Future<SharedPreferencesAccountPersistence> fromPreferences() async =>
      SharedPreferencesAccountPersistence(
        await SharedPreferences.getInstance(),
      );

  @override
  Map<String, dynamic>? read() {
    final raw = preferences.getString(key);
    if (raw == null || raw.isEmpty) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  @override
  void write(Map<String, dynamic> value) {
    // SharedPreferences writes asynchronously; callers do not block a user
    // action on disk I/O, and the in-memory state remains authoritative.
    preferences.setString(key, jsonEncode(value));
  }
}

class QuotaReservation {
  QuotaReservation._(
    this._service,
    this.kind,
    this._userId, {
    this.quotaExempt = false,
  });

  final AccountService _service;
  final UsageKind kind;
  final String _userId;
  final bool quotaExempt;
  bool _closed = false;

  bool get isClosed => _closed;

  void commit() {
    if (_closed) return;
    _closed = true;
    _service._persist();
  }

  void rollback() {
    if (_closed) return;
    _closed = true;
    if (!quotaExempt) _service._restoreReservation(kind, _userId);
  }
}

class AccountService extends ChangeNotifier {
  AccountService({
    AccountPersistence? persistence,
    DateTime Function()? clock,
    bool? allowTestAdmin,
  }) : persistence = persistence ?? InMemoryAccountPersistence(),
       _clock = clock ?? DateTime.now,
       allowTestAdmin =
           (allowTestAdmin ?? testAdminEnabled) && testAdminEnabled {
    _restore(persistence?.read());
    _refreshEntitlements();
    if (_users.isNotEmpty) _persist();
  }

  AccountPersistence persistence;
  final DateTime Function() _clock;
  final bool allowTestAdmin;
  final Map<String, AccountUser> _users = <String, AccountUser>{};
  final Map<String, EntitlementSnapshot> _entitlements =
      <String, EntitlementSnapshot>{};
  final Map<String, Set<String>> _rewardedWorkouts = <String, Set<String>>{};
  final Map<String, RedemptionCode> _codes = <String, RedemptionCode>{};
  final Map<String, MembershipOrder> _orders = <String, MembershipOrder>{};
  String? _currentUserId;

  /// Whether the development-only test administrator is available for this
  /// service instance.  The constructor still enforces the compile-time
  /// release gate even when callers request [allowTestAdmin].
  bool get isTestAdminEnabled => allowTestAdmin;

  /// Both the free-member and administrator fixtures share the same explicit
  /// build gate so production releases cannot expose either account by
  /// accident.
  bool get isTestAccountEnabled => allowTestAdmin;

  AccountUser? get currentUser =>
      _currentUserId == null ? null : _users[_currentUserId];
  bool get isAuthenticated => currentUser != null;
  bool get isAdmin => currentUser?.isAdmin == true;
  EntitlementSnapshot? get entitlements {
    final user = currentUser;
    if (user == null) return null;
    _refreshEntitlements();
    return _entitlements[user.id];
  }

  List<RedemptionCode> get redemptionCodes =>
      _codes.values.toList(growable: false);

  List<MembershipOrder> get membershipOrders {
    final userId = currentUser?.id;
    if (userId == null) return const [];
    final rows = _orders.values.where((item) => item.userId == userId).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return rows;
  }

  MembershipOrder? createMembershipOrder({
    required MembershipPlan plan,
    required String productId,
    required String displayPrice,
    required MembershipOrderProvider provider,
  }) {
    final user = currentUser;
    // Quarterly subscriptions are retained only for historical orders and
    // entitlements. They must not be created by a current client.
    if (user == null ||
        plan == MembershipPlan.free ||
        plan == MembershipPlan.threeMonths ||
        productId == 'com.kilostrength.pro.quarterly') {
      return null;
    }
    final now = _clock();
    final order = MembershipOrder(
      id: 'order-${now.microsecondsSinceEpoch.toRadixString(36)}',
      userId: user.id,
      plan: plan,
      productId: productId,
      provider: provider,
      status: MembershipOrderStatus.pending,
      displayPrice: displayPrice,
      createdAt: now,
      updatedAt: now,
    );
    _orders[order.id] = order;
    _persist();
    notifyListeners();
    return order;
  }

  MembershipOrder? updateMembershipOrder(
    String orderId, {
    required MembershipOrderStatus status,
    String? transactionId,
    String? failureReason,
  }) {
    final existing = _orders[orderId];
    if (existing == null || existing.userId != currentUser?.id) return null;
    final updated = existing.copyWith(
      status: status,
      updatedAt: _clock(),
      transactionId: transactionId,
      failureReason: failureReason,
      clearFailureReason: failureReason == null,
    );
    _orders[orderId] = updated;
    _persist();
    notifyListeners();
    return updated;
  }

  void upsertMembershipOrder(MembershipOrder order) {
    final user = currentUser;
    if (user == null || order.userId != user.id) return;
    _orders[order.id] = order;
    _persist();
    notifyListeners();
  }

  void replaceMembershipOrders(List<MembershipOrder> orders) {
    final user = currentUser;
    if (user == null) return;
    _orders.removeWhere((_, value) => value.userId == user.id);
    for (final order in orders.where((item) => item.userId == user.id)) {
      _orders[order.id] = order;
    }
    _persist();
    notifyListeners();
  }

  void replaceCurrentEntitlement(EntitlementSnapshot entitlement) {
    final user = currentUser;
    if (user == null) return;
    _entitlements[user.id] = entitlement;
    _persist();
    notifyListeners();
  }

  String get currentUserId => currentUser?.id ?? '';

  /// Loads the persisted local prototype state. The app calls this during its
  /// startup gate; tests can instead inject [InMemoryAccountPersistence] and
  /// stay entirely synchronous.
  Future<void> hydrateFromSharedPreferences() async {
    final adapter = await SharedPreferencesAccountPersistence.fromPreferences();
    final saved = adapter.read();
    if (saved != null) {
      _users.clear();
      _entitlements.clear();
      _rewardedWorkouts.clear();
      _codes.clear();
      _orders.clear();
      _restore(saved);
    }
    persistence = adapter;
    _refreshEntitlements();
    notifyListeners();
  }

  AuthResult loginWithPhone(String identifier, {String? password}) {
    final normalized = identifier.trim();
    if (normalized.isEmpty) {
      return const AuthResult.failure(AccountError.emptyIdentifier);
    }
    if (normalized == '1234') {
      if (password != '1234' || !allowTestAdmin) {
        return const AuthResult.failure(AccountError.invalidCredentials);
      }
      return _login(
        identifier: normalized,
        displayName: '测试管理员',
        provider: AuthProvider.phone,
        isAdmin: true,
      );
    }
    if (normalized == '123') {
      if (password != '123' || !allowTestAdmin) {
        return const AuthResult.failure(AccountError.invalidCredentials);
      }
      return _login(
        identifier: normalized,
        displayName: '普通体验用户',
        provider: AuthProvider.phone,
        isAdmin: false,
      );
    }
    return _login(
      identifier: normalized,
      displayName: normalized,
      provider: AuthProvider.phone,
      isAdmin: false,
    );
  }

  AuthResult loginWithTestAdmin(String identifier, String password) =>
      loginWithPhone(identifier, password: password);

  /// Completes a login that has already been authenticated by the backend.
  /// Role and display name come from the signed-in server user rather than a
  /// debug-only identifier convention.
  AuthResult loginAuthenticatedRemote({
    required String identifier,
    required String displayName,
    required bool isAdmin,
    AuthProvider provider = AuthProvider.phone,
    String? publicId,
  }) => _login(
    identifier: identifier.trim(),
    displayName: displayName.trim().isEmpty ? identifier.trim() : displayName,
    provider: provider,
    isAdmin: isAdmin,
    publicId: publicId,
  );

  AuthResult loginWithApple() => const AuthResult.failure(
    AccountError.serviceNotConfigured,
    message: 'Apple 登录尚未配置，请先完成服务端凭据配置。',
  );

  AuthResult loginWithGoogle() => const AuthResult.failure(
    AccountError.serviceNotConfigured,
    message: 'Google 登录尚未配置，请先完成 OAuth 客户端配置。',
  );

  void logout() {
    _currentUserId = null;
    _persist();
    notifyListeners();
  }

  AccountUser? updateCurrentProfile({
    String? displayName,
    String? avatarPath,
    String? publicId,
  }) {
    final current = currentUser;
    if (current == null) return null;
    final cleanName = displayName?.trim();
    final updated = AccountUser(
      id: current.id,
      identifier: current.identifier,
      displayName: cleanName == null || cleanName.isEmpty
          ? current.displayName
          : cleanName,
      isAdmin: current.isAdmin,
      provider: current.provider,
      avatarPath: avatarPath ?? current.avatarPath,
      publicId: publicId ?? current.publicId,
    );
    _users[current.id] = updated;
    _persist();
    notifyListeners();
    return updated;
  }

  AuthResult _login({
    required String identifier,
    required String displayName,
    required AuthProvider provider,
    required bool isAdmin,
    String? publicId,
  }) {
    final normalizedIdentifier = identifier.toLowerCase();
    final id = normalizedIdentifier.startsWith('${provider.name}:')
        ? normalizedIdentifier
        : '${provider.name}:$normalizedIdentifier';
    // A successful backend login is authoritative. Rebuild the cached user
    // instead of keeping a stale locally-persisted role or display name.
    final previous = _users[id];
    final user = AccountUser(
      id: id,
      identifier: identifier,
      displayName: displayName,
      isAdmin: isAdmin,
      provider: provider,
      avatarPath: previous?.avatarPath,
      publicId:
          publicId ??
          (previous?.publicId.isNotEmpty == true
              ? previous!.publicId
              : _newPublicAccountId()),
    );
    _users[id] = user;
    _currentUserId = id;
    final existing = _entitlements[id] ?? _newEntitlements();
    final permanentTestAccount =
        allowTestAdmin && (identifier == '123' || identifier == '1234');
    _entitlements[id] = permanentTestAccount
        ? existing.copyWith(
            membership: MembershipPlan.forever,
            clearMembershipExpiresAt: true,
            aiRemaining: existing.aiRemaining < 20 ? 20 : existing.aiRemaining,
            aiDailyLimit: 20,
            recognitionWeeklyGrant: 3,
          )
        : existing;
    _refreshEntitlements();
    _persist();
    notifyListeners();
    return AuthResult.success(user);
  }

  EntitlementSnapshot _newEntitlements() {
    final now = _clock();
    return EntitlementSnapshot.free(
      aiRemaining: 3,
      recognitionRemaining: 5,
      aiPeriodKey: _dayKey(now),
      recognitionWeekKey: _weekKey(now),
    );
  }

  AccountResult<EntitlementSnapshot> grantMembership({
    required String identifier,
    required MembershipPlan plan,
  }) {
    if (!isAdmin) {
      return const AccountResult.failure(AccountError.adminRequired);
    }
    if (identifier.trim().isEmpty) {
      return const AccountResult.failure(AccountError.emptyIdentifier);
    }
    if (plan == MembershipPlan.free) {
      return const AccountResult.failure(AccountError.invalidMembershipPlan);
    }
    final normalized = identifier.trim();
    final target = _users.values
        .where((item) => item.identifier == normalized)
        .firstOrNull;
    final adminId = _currentUserId;
    if (target == null) {
      _login(
        identifier: normalized,
        displayName: normalized,
        provider: AuthProvider.phone,
        isAdmin: false,
      );
      // Keep the administrator logged in after provisioning a new user.
      _currentUserId = adminId;
    }
    final user = _users.values
        .where((item) => item.identifier == normalized)
        .first;
    _applyMembership(user.id, plan);
    return AccountResult.success(_entitlements[user.id]);
  }

  /// Synchronous admin-only code generation keeps local prototype actions
  /// deterministic and makes the server replacement boundary explicit.
  RedemptionCode generateRedemptionCode({required MembershipPlan plan}) {
    if (!isAdmin) throw StateError(AccountError.adminRequired.name);
    if (plan == MembershipPlan.free) {
      throw StateError(AccountError.invalidMembershipPlan.name);
    }
    final now = _clock();
    final prefix = switch (plan) {
      MembershipPlan.oneMonth => 'KILO1',
      MembershipPlan.threeMonths => 'KILO3',
      MembershipPlan.yearly => 'KILO12',
      MembershipPlan.forever => 'KILOP',
      MembershipPlan.free => 'KILOF',
    };
    final code =
        '$prefix-${now.microsecondsSinceEpoch.toRadixString(36).toUpperCase()}';
    final redemption = RedemptionCode(code: code, plan: plan, createdAt: now);
    _codes[code] = redemption;
    _persist();
    notifyListeners();
    return redemption;
  }

  AccountResult<EntitlementSnapshot> redeemCode(String rawCode) {
    final user = currentUser;
    if (user == null) {
      return const AccountResult.failure(AccountError.notAuthenticated);
    }
    final code = rawCode.trim().toUpperCase();
    final redemption = _codes[code];
    if (redemption == null) {
      return const AccountResult.failure(AccountError.invalidCode);
    }
    if (redemption.isUsed) {
      return const AccountResult.failure(AccountError.codeAlreadyUsed);
    }
    _codes[code] = redemption.markUsed(userId: user.id, at: _clock());
    _applyMembership(user.id, redemption.plan);
    _persist();
    notifyListeners();
    return AccountResult.success(_entitlements[user.id]);
  }

  /// Reserves one unit before a remote request.  Call [QuotaReservation.commit]
  /// only after the remote operation succeeds; call rollback on all failures.
  QuotaReservation? reserve(UsageKind kind) {
    final user = currentUser;
    if (user == null) return null;
    _refreshEntitlements();
    if (user.isAdmin) {
      return QuotaReservation._(this, kind, user.id, quotaExempt: true);
    }
    final current = _entitlements[user.id]!;
    final remaining = kind == UsageKind.ai
        ? current.aiRemaining
        : current.recognitionRemaining;
    if (remaining <= 0) return null;
    _entitlements[user.id] = kind == UsageKind.ai
        ? current.copyWith(aiRemaining: remaining - 1)
        : current.copyWith(recognitionRemaining: remaining - 1);
    _persist();
    notifyListeners();
    return QuotaReservation._(this, kind, user.id);
  }

  bool consume(UsageKind kind) {
    final reservation = reserve(kind);
    if (reservation == null) return false;
    reservation.commit();
    return true;
  }

  bool consumeAi() => consume(UsageKind.ai);

  bool consumeRecognition() => consume(UsageKind.recognition);

  QuotaReservation? reserveAi() => reserve(UsageKind.ai);

  QuotaReservation? reserveRecognition() => reserve(UsageKind.recognition);

  int get aiRemaining => entitlements?.aiRemaining ?? 0;

  int get recognitionRemaining => entitlements?.recognitionRemaining ?? 0;

  Future<T?> runWithQuota<T>(
    UsageKind kind,
    Future<T> Function() operation,
  ) async {
    final reservation = reserve(kind);
    if (reservation == null) return null;
    try {
      final value = await operation();
      reservation.commit();
      return value;
    } catch (_) {
      reservation.rollback();
      rethrow;
    }
  }

  bool rewardWorkoutCompleted(String workoutId, {bool valid = true}) {
    final user = currentUser;
    if (user == null || !valid || workoutId.trim().isEmpty) return false;
    final rewarded = _rewardedWorkouts.putIfAbsent(user.id, () => <String>{});
    if (!rewarded.add(workoutId)) return false;
    _refreshEntitlements();
    final current = _entitlements[user.id]!;
    _entitlements[user.id] = current.copyWith(
      recognitionRemaining: current.recognitionRemaining + 1,
    );
    _persist();
    notifyListeners();
    return true;
  }

  void _restoreReservation(UsageKind kind, String userId) {
    if (!_users.containsKey(userId)) return;
    _refreshEntitlements();
    final current = _entitlements[userId];
    if (current == null) return;
    _entitlements[userId] = kind == UsageKind.ai
        ? current.copyWith(aiRemaining: current.aiRemaining + 1)
        : current.copyWith(
            recognitionRemaining: current.recognitionRemaining + 1,
          );
    _persist();
    notifyListeners();
  }

  void _applyMembership(String userId, MembershipPlan plan) {
    _refreshEntitlements();
    final now = _clock();
    final current = _entitlements[userId] ?? _newEntitlements();
    final currentActive =
        current.membership != MembershipPlan.free &&
        (current.membership == MembershipPlan.forever ||
            current.membershipExpiresAt?.isAfter(now) == true);
    final effectivePlan = current.membership == MembershipPlan.forever
        ? MembershipPlan.forever
        : plan == MembershipPlan.forever
        ? MembershipPlan.forever
        : _membershipRank(current.membership) > _membershipRank(plan)
        ? current.membership
        : plan;
    final expires = effectivePlan == MembershipPlan.forever
        ? null
        : plan == MembershipPlan.free
        ? current.membershipExpiresAt
        : _addMonths(
            currentActive && current.membershipExpiresAt != null
                ? current.membershipExpiresAt!
                : now,
            _membershipMonths(plan),
          );
    _entitlements[userId] = current.copyWith(
      membership: effectivePlan,
      membershipExpiresAt: expires,
      clearMembershipExpiresAt: effectivePlan == MembershipPlan.forever,
      aiRemaining: effectivePlan == MembershipPlan.free
          ? current.aiRemaining.clamp(0, 3).toInt()
          : current.aiRemaining < 20
          ? 20
          : current.aiRemaining,
      aiDailyLimit: effectivePlan == MembershipPlan.free ? 3 : 20,
      recognitionWeeklyGrant: effectivePlan == MembershipPlan.free ? 1 : 3,
    );
    _refreshEntitlements();
    _persist();
    notifyListeners();
  }

  static int _membershipRank(MembershipPlan plan) => switch (plan) {
    MembershipPlan.free => 0,
    MembershipPlan.oneMonth => 1,
    MembershipPlan.threeMonths => 2,
    MembershipPlan.yearly => 3,
    MembershipPlan.forever => 4,
  };

  static int _membershipMonths(MembershipPlan plan) => switch (plan) {
    MembershipPlan.oneMonth => 1,
    MembershipPlan.threeMonths => 3,
    MembershipPlan.yearly => 12,
    MembershipPlan.free || MembershipPlan.forever => 0,
  };

  void _refreshEntitlements() {
    final now = _clock();
    final day = _dayKey(now);
    final week = _weekKey(now);
    for (final userId in _users.keys) {
      var current = _entitlements[userId] ?? _newEntitlements();
      final wasMember =
          current.membership != MembershipPlan.free &&
              (current.membership == MembershipPlan.forever ||
                  current.membershipExpiresAt?.isAfter(now) == true) ||
          current.isTrialActiveAt(now);
      if (current.membership != MembershipPlan.free &&
          current.membershipExpiresAt != null &&
          !current.membershipExpiresAt!.isAfter(now)) {
        current = current.copyWith(
          membership: MembershipPlan.free,
          clearMembershipExpiresAt: true,
          aiRemaining: current.aiRemaining.clamp(0, 3).toInt(),
          aiDailyLimit: 3,
          recognitionWeeklyGrant: 1,
        );
      }
      final member =
          current.membership != MembershipPlan.free &&
              (current.membership == MembershipPlan.forever ||
                  current.membershipExpiresAt?.isAfter(now) == true) ||
          current.isTrialActiveAt(now);
      if (member && !wasMember) {
        current = current.copyWith(
          aiRemaining: current.aiRemaining < 20 ? 20 : current.aiRemaining,
          aiDailyLimit: 20,
          recognitionWeeklyGrant: 3,
        );
      } else if (!member && current.aiDailyLimit > 3) {
        current = current.copyWith(
          aiRemaining: current.aiRemaining.clamp(0, 3).toInt(),
          aiDailyLimit: 3,
          recognitionWeeklyGrant: 1,
        );
      }
      if (current.aiPeriodKey != day) {
        current = current.copyWith(
          aiRemaining: member ? 20 : current.aiDailyLimit,
          aiPeriodKey: day,
        );
      }
      if (current.recognitionWeekKey.isEmpty) {
        current = current.copyWith(recognitionWeekKey: week);
      } else if (current.recognitionWeekKey != week) {
        final elapsedWeeks = _weekDistance(current.recognitionWeekKey, week);
        current = current.copyWith(
          recognitionRemaining:
              current.recognitionRemaining +
              elapsedWeeks * current.recognitionWeeklyGrant,
          recognitionWeekKey: week,
        );
      }
      _entitlements[userId] = current;
    }
  }

  void _persist() {
    persistence.write({
      'currentUserId': _currentUserId,
      'users': _users.map((key, value) => MapEntry(key, value.toMap())),
      'entitlements': _entitlements.map(
        (key, value) => MapEntry(key, value.toMap()),
      ),
      'rewardedWorkouts': _rewardedWorkouts.map(
        (key, value) => MapEntry(key, value.toList()),
      ),
      'codes': _codes.map((key, value) => MapEntry(key, value.toMap())),
      'orders': _orders.map((key, value) => MapEntry(key, value.toMap())),
    });
  }

  void _restore(Map<String, dynamic>? map) {
    if (map == null) return;
    _currentUserId = map['currentUserId']?.toString();
    final users = map['users'];
    if (users is Map) {
      for (final entry in users.entries) {
        if (entry.value is Map) {
          _users[entry.key.toString()] = AccountUser.fromMap(
            Map<String, dynamic>.from(entry.value as Map),
          );
        }
      }
    }
    if (!allowTestAdmin) {
      final disabledAdminIds = _users.values
          .where(
            (item) =>
                (item.identifier == '1234' && item.isAdmin) ||
                (item.identifier == '123' && !item.isAdmin),
          )
          .map((item) => item.id)
          .toList();
      for (final id in disabledAdminIds) {
        _users.remove(id);
        _entitlements.remove(id);
        _rewardedWorkouts.remove(id);
        if (_currentUserId == id) _currentUserId = null;
      }
    }
    final entitlements = map['entitlements'];
    if (entitlements is Map) {
      for (final entry in entitlements.entries) {
        if (entry.value is Map) {
          _entitlements[entry.key.toString()] = EntitlementSnapshot.fromMap(
            Map<String, dynamic>.from(entry.value as Map),
          );
        }
      }
    }
    final rewards = map['rewardedWorkouts'];
    if (rewards is Map) {
      for (final entry in rewards.entries) {
        final list = entry.value is List ? entry.value as List : const [];
        _rewardedWorkouts[entry.key.toString()] = list
            .map((item) => '$item')
            .toSet();
      }
    }
    final codes = map['codes'];
    if (codes is Map) {
      for (final entry in codes.entries) {
        if (entry.value is Map) {
          final code = RedemptionCode.fromMap(
            Map<String, dynamic>.from(entry.value as Map),
          );
          if (code.code.isNotEmpty) _codes[entry.key.toString()] = code;
        }
      }
    }
    final orders = map['orders'];
    if (orders is Map) {
      for (final entry in orders.entries) {
        if (entry.value is Map) {
          final order = MembershipOrder.fromMap(
            Map<String, dynamic>.from(entry.value as Map),
          );
          if (order.id.isNotEmpty) _orders[entry.key.toString()] = order;
        }
      }
    }
  }

  static String _dayKey(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  static String _weekKey(DateTime value) {
    final monday = DateTime(
      value.year,
      value.month,
      value.day,
    ).subtract(Duration(days: value.weekday - DateTime.monday));
    return _dayKey(monday);
  }

  static int _weekDistance(String from, String to) {
    final start = DateTime.tryParse(from);
    final end = DateTime.tryParse(to);
    if (start == null || end == null || !end.isAfter(start)) return 0;
    return end.difference(start).inDays ~/ 7;
  }

  static DateTime _addMonths(DateTime value, int months) {
    final target = DateTime(
      value.year,
      value.month + months,
      1,
      value.hour,
      value.minute,
      value.second,
      value.millisecond,
      value.microsecond,
    );
    final lastDay = DateTime(target.year, target.month + 1, 0).day;
    return DateTime(
      target.year,
      target.month,
      value.day.clamp(1, lastDay),
      value.hour,
      value.minute,
      value.second,
      value.millisecond,
      value.microsecond,
    );
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
