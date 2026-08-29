import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_compress/video_compress.dart';

import 'account_membership.dart';
import 'app_localizations.dart';
import 'ai_api.dart';
import 'natural_workout_parser.dart';
import 'models.dart';
import 'recognition_api.dart';
import 'secure_session_store.dart';
import 'workout_history_persistence.dart';

const String defaultCoachApiBaseUrl = String.fromEnvironment(
  'KILO_API_BASE_URL',
  defaultValue: 'https://api.kilostrength.cn',
);

class PlatformTimerBridge {
  static const _channel = MethodChannel('kilo.platform.timer');

  static void setSystemActionHandlers({
    VoidCallback? onRestSkipped,
    VoidCallback? onOpenWorkout,
    ValueChanged<int>? onCompletedSetsChanged,
    ValueChanged<bool>? onPauseChanged,
  }) {
    _channel.setMethodCallHandler(
      onRestSkipped == null &&
              onOpenWorkout == null &&
              onCompletedSetsChanged == null &&
              onPauseChanged == null
          ? null
          : (call) async {
              if (call.method == 'restSkippedFromNotification') {
                onRestSkipped?.call();
              } else if (call.method == 'openWorkoutFromSystem') {
                onOpenWorkout?.call();
              } else if (call.method == 'completeSetFromNotification') {
                final value = call.arguments;
                final target = value is Map
                    ? value['completedSets'] as int?
                    : null;
                if (target != null) onCompletedSetsChanged?.call(target);
              } else if (call.method == 'pauseChangedFromNotification') {
                onPauseChanged?.call(call.arguments == true);
              }
            },
    );
    if (onOpenWorkout != null) {
      unawaited(
        _consumePendingWorkoutOpen().then((pending) {
          if (pending) onOpenWorkout();
        }),
      );
    }
    if (onCompletedSetsChanged != null || onPauseChanged != null) {
      unawaited(
        _consumePendingTimerActions().then((pending) {
          final completed = pending['completedSets'];
          if (completed is int) onCompletedSetsChanged?.call(completed);
          final paused = pending['paused'];
          if (paused is bool) onPauseChanged?.call(paused);
        }),
      );
    }
  }

  static Future<Map<dynamic, dynamic>> _consumePendingTimerActions() async {
    try {
      final result = await _channel.invokeMethod<dynamic>(
        'consumePendingTimerActions',
      );
      return result is Map ? result : const {};
    } on MissingPluginException {
      return const {};
    } on PlatformException catch (_) {
      return const {};
    }
  }

  static Future<bool> _consumePendingWorkoutOpen() async {
    try {
      return await _channel.invokeMethod<bool>('consumePendingWorkoutOpen') ??
          false;
    } on MissingPluginException {
      return false;
    } on PlatformException catch (_) {
      return false;
    }
  }

  static Future<void> start({
    required String exercise,
    required int seconds,
    DateTime? endsAt,
  }) async {
    try {
      await _channel.invokeMethod<void>('startTimer', {
        'exercise': exercise,
        'seconds': seconds,
        if (endsAt != null) 'endsAtEpochMs': endsAt.millisecondsSinceEpoch,
      });
    } on MissingPluginException {
      // The Android/iOS bridge is optional in widget tests and desktop previews.
    } on PlatformException catch (_) {
      // UI state remains authoritative when a system capability is unavailable.
    }
  }

  static Future<void> startWorkout({
    required int elapsedSeconds,
    required String workoutName,
    required String exercise,
    required int completedSets,
    required int totalSets,
  }) async {
    try {
      await _channel.invokeMethod<void>('startWorkout', {
        'elapsedSeconds': elapsedSeconds,
        'workoutName': workoutName,
        'exercise': exercise,
        'completedSets': completedSets,
        'totalSets': totalSets,
      });
    } on MissingPluginException {
      // The native foreground service is optional in widget tests and previews.
    } on PlatformException catch (_) {
      // UI state remains authoritative when the system capability is unavailable.
    }
  }

  static Future<void> updateWorkoutState({
    required String exercise,
    required int completedSets,
    required int totalSets,
  }) async {
    try {
      await _channel.invokeMethod<void>('updateWorkoutState', {
        'exercise': exercise,
        'completedSets': completedSets,
        'totalSets': totalSets,
      });
    } on MissingPluginException {
      // Optional capability.
    } on PlatformException catch (_) {
      // Optional capability.
    }
  }

  static Future<void> pause() async {
    try {
      await _channel.invokeMethod<void>('pauseTimer');
    } on MissingPluginException {
      // Optional capability.
    } on PlatformException catch (_) {
      // Optional capability.
    }
  }

  static Future<void> update({
    required String exercise,
    required int seconds,
    DateTime? endsAt,
  }) async {
    try {
      await _channel.invokeMethod<void>('updateTimer', {
        'exercise': exercise,
        'seconds': seconds,
        if (endsAt != null) 'endsAtEpochMs': endsAt.millisecondsSinceEpoch,
      });
    } on MissingPluginException {
      // Optional capability.
    } on PlatformException catch (_) {
      // Optional capability.
    }
  }

  static Future<void> finish() async {
    try {
      await _channel.invokeMethod<void>('finishTimer');
    } on MissingPluginException {
      // Optional capability.
    } on PlatformException catch (_) {
      // Optional capability.
    }
  }

  static Future<void> clearRest() async {
    try {
      await _channel.invokeMethod<void>('clearRest');
    } on MissingPluginException {
      // Optional capability.
    } on PlatformException catch (_) {
      // Optional capability.
    }
  }

  static Future<void> completeRest() async {
    try {
      await _channel.invokeMethod<void>('completeRest');
    } on MissingPluginException {
      // The native completion notification is optional in tests and previews.
    } on PlatformException catch (_) {
      // UI state remains authoritative when the system capability is unavailable.
    }
  }
}

class AppController extends ChangeNotifier {
  AppController({
    AccountService? accountService,
    this.recognitionApi,
    this.coachApi,
    WorkoutHistoryPersistence? workoutHistoryPersistence,
    ActiveWorkoutPersistence? activeWorkoutPersistence,
    TrainingLibraryPersistence? trainingLibraryPersistence,
    SecureSessionStore? secureSessionStore,
  }) : accountService = accountService ?? AccountService(),
       workoutHistoryPersistence =
           workoutHistoryPersistence ??
           SharedPreferencesWorkoutHistoryPersistence(),
       activeWorkoutPersistence =
           activeWorkoutPersistence ??
           SharedPreferencesActiveWorkoutPersistence(),
       trainingLibraryPersistence =
           trainingLibraryPersistence ??
           SharedPreferencesTrainingLibraryPersistence(),
       secureSessionStore = secureSessionStore ?? FlutterSecureSessionStore() {
    _seed();
    PlatformTimerBridge.setSystemActionHandlers(
      onRestSkipped: skipRest,
      onOpenWorkout: _openWorkoutFromSystem,
      onCompletedSetsChanged: syncCompletedSetsFromSystem,
      onPauseChanged: setWorkoutPausedFromSystem,
    );
    this.accountService.addListener(_handleAccountChanged);
    _observedAccountUserId = currentUser?.id;
    unawaited(loadRecognitionCapabilities());
  }

  final AccountService accountService;
  final RecognitionApi? recognitionApi;
  final CoachApi? coachApi;
  final WorkoutHistoryPersistence workoutHistoryPersistence;
  final ActiveWorkoutPersistence activeWorkoutPersistence;
  final TrainingLibraryPersistence trainingLibraryPersistence;
  final SecureSessionStore secureSessionStore;
  Future<void> _historyWriteChain = Future<void>.value();
  Future<void> _activeWorkoutWriteChain = Future<void>.value();
  Future<void> _trainingLibraryWriteChain = Future<void>.value();
  Future<void> _customExerciseWriteChain = Future<void>.value();
  Future<void> _aiConversationWriteChain = Future<void>.value();
  int _aiConversationRevision = 0;
  String? _loadedHistoryUserId;
  String? _loadedTrainingLibraryUserId;
  String? _loadedCustomExercisesUserId;
  String? _loadedAiConversationsUserId;
  String? _observedAccountUserId;
  bool _pendingSystemWorkoutOpen = false;
  HttpCoachApi? _defaultCoachApi;
  String? _defaultCoachApiBaseUrl;
  HttpRecognitionApi? _defaultRecognitionApi;
  String? _defaultRecognitionApiBaseUrl;
  String? _remoteIdentifier;
  String? _remotePassword;
  RemoteSession? _storedRemoteSession;
  bool _secureSessionLoaded = false;
  String? _sessionExpiredMessage;
  bool _disposed = false;

  AccountUser? get currentUser => accountService.currentUser;
  bool get isAuthenticated => accountService.isAuthenticated;
  bool get isAdmin => accountService.isAdmin;
  String? get sessionExpiredMessage => _sessionExpiredMessage;
  EntitlementSnapshot? get entitlements => accountService.entitlements;
  int get aiRemaining => accountService.aiRemaining;
  int get recognitionRemaining => accountService.recognitionRemaining;
  List<MembershipOrder> get membershipOrders => accountService.membershipOrders;
  CheckinSnapshot get checkinStatus => accountService.checkinStatus;

  MembershipOrder? createMembershipOrder({
    required MembershipPlan plan,
    required String productId,
    required String displayPrice,
    required MembershipOrderProvider provider,
  }) => accountService.createMembershipOrder(
    plan: plan,
    productId: productId,
    displayPrice: displayPrice,
    provider: provider,
  );

  MembershipOrder? updateMembershipOrder(
    String orderId, {
    required MembershipOrderStatus status,
    String? transactionId,
    String? failureReason,
  }) => accountService.updateMembershipOrder(
    orderId,
    status: status,
    transactionId: transactionId,
    failureReason: failureReason,
  );

  MembershipOrder _remoteMembershipOrder(Map<String, dynamic> raw) {
    final value = Map<String, dynamic>.from(raw);
    value['userId'] = accountService.currentUserId;
    return MembershipOrder.fromMap(value);
  }

  Future<MembershipOrder?> createMembershipOrderRemote({
    required MembershipPlan plan,
    required String productId,
    required String displayPrice,
    required MembershipOrderProvider provider,
  }) async {
    final api = await _activeCoachApi();
    if (api is! HttpCoachApi) {
      throw const CoachApiException('membership_order_unavailable');
    }
    final payload = await api.createMembershipOrder(
      productId: productId,
      plan: productId.endsWith('.yearly') ? 'yearly' : 'oneMonth',
      provider: provider == MembershipOrderProvider.googlePlay
          ? 'google_play'
          : provider == MembershipOrderProvider.wechatPay
          ? 'wechat_pay'
          : provider == MembershipOrderProvider.alipay
          ? 'alipay'
          : 'app_store',
      amountMinor: _priceToMinor(displayPrice),
    );
    final raw = payload['order'];
    if (raw is! Map) throw const CoachApiException('membership_order_missing');
    final order = _remoteMembershipOrder(Map<String, dynamic>.from(raw));
    accountService.upsertMembershipOrder(order);
    return order;
  }

  Future<MembershipOrder?> cancelMembershipOrderRemote(String orderId) async {
    final api = await _activeCoachApi();
    if (api is! HttpCoachApi) {
      throw const CoachApiException('membership_order_unavailable');
    }
    final payload = await api.cancelMembershipOrder(orderId);
    final raw = payload['order'];
    if (raw is! Map) throw const CoachApiException('membership_order_missing');
    final order = _remoteMembershipOrder(Map<String, dynamic>.from(raw));
    accountService.upsertMembershipOrder(order);
    return order;
  }

  Future<void> hydrateMembershipOrders() async {
    try {
      final api = await _activeCoachApi();
      if (api is! HttpCoachApi) return;
      final rows = await api.fetchMembershipOrders();
      accountService.replaceMembershipOrders(
        rows.map(_remoteMembershipOrder).toList(),
      );
    } catch (_) {
      // Local orders remain available while a tunnel/network is offline.
    }
  }

  Future<void> hydrateCheckinStatus() async {
    try {
      final api = await _activeCoachApi();
      if (api is! HttpCoachApi) return;
      final payload = await api.fetchCheckinStatus();
      final raw = payload['entitlement'];
      if (raw is Map) {
        accountService.replaceCurrentEntitlement(
          EntitlementSnapshot.fromMap(Map<String, dynamic>.from(raw)),
        );
      }
      accountService.replaceCheckinStatus(_checkinFromRemote(payload));
    } catch (_) {
      // Sign-in should not be blocked by an unavailable reward endpoint.
    }
  }

  Future<CheckinSnapshot> checkIn() async {
    final api = await _activeCoachApi();
    if (api is! HttpCoachApi) {
      throw const CoachApiException('checkin_unavailable');
    }
    final payload = await api.checkIn();
    final raw = payload['entitlement'];
    if (raw is Map) {
      accountService.replaceCurrentEntitlement(
        EntitlementSnapshot.fromMap(Map<String, dynamic>.from(raw)),
      );
    }
    final snapshot = _checkinFromRemote(payload);
    accountService.replaceCheckinStatus(snapshot);
    return snapshot;
  }

  CheckinSnapshot _checkinFromRemote(Map<String, dynamic> payload) =>
      CheckinSnapshot(
        todayCheckedIn: payload['todayCheckedIn'] == true,
        roundDays: (payload['roundDays'] as num?)?.toInt() ?? 0,
        totalDays: (payload['totalDays'] as num?)?.toInt() ?? 0,
        rewardRound: (payload['rewardRound'] as num?)?.toInt() ?? 0,
        lastRewardAt: DateTime.tryParse(
          (payload['lastRewardAt'] ?? '').toString(),
        ),
        rewarded: payload['awarded'] == true,
        rewardDays: (payload['rewardDays'] as num?)?.toInt() ?? 0,
      );

  static int? _priceToMinor(String value) {
    final match = RegExp(r'([0-9]+(?:\.[0-9]+)?)').firstMatch(value);
    final parsed = double.tryParse(match?.group(1) ?? '');
    return parsed == null ? null : (parsed * 100).round();
  }

  Future<void> verifyAppleMembershipPurchase({
    required String productId,
    required String verificationData,
    String? transactionId,
    String? localOrderId,
  }) async {
    final api = await _activeCoachApi();
    if (api is! HttpCoachApi) {
      throw const CoachApiException('membership_verification_unavailable');
    }
    final payload = await api.verifyApplePurchase(
      productId: productId,
      verificationData: verificationData,
      transactionId: transactionId,
      localOrderId: localOrderId,
    );
    final raw = payload['entitlement'];
    if (raw is! Map) {
      throw const CoachApiException('membership_entitlement_missing');
    }
    accountService.replaceCurrentEntitlement(
      EntitlementSnapshot.fromMap(Map<String, dynamic>.from(raw)),
    );
  }

  void _handleAccountChanged() {
    final userId = currentUser?.id;
    if (_observedAccountUserId != userId) {
      _observedAccountUserId = userId;
      _remoteIdentifier = currentUser?.identifier;
      _remotePassword = null;
      if (userId == null || userId.isEmpty) {
        unawaited(secureSessionStore.clear());
      }
      _loadedAiConversationsUserId = null;
      conversations.clear();
      chat.clear();
      trainingProfile = const TrainingProfile();
      nutritionEntries.clear();
      profileOnboardingCompleted = false;
      personalAgentDataReady = false;
      activeConversationId = 'conversation-main';
      if (userId != null && userId.isNotEmpty) {
        unawaited(hydrateAiConversations(force: true));
        unawaited(hydrateMembershipOrders());
        unawaited(hydrateCheckinStatus());
      }
    }
    notifyListeners();
  }

  AuthResult loginWithPhone(String identifier, {String? password}) {
    _defaultCoachApi?.clearSession();
    _defaultRecognitionApi?.clearSession();
    _storedRemoteSession = null;
    _secureSessionLoaded = true;
    unawaited(secureSessionStore.clear());
    final result = accountService.loginWithPhone(
      identifier,
      password: password,
    );
    if (result.isSuccess) {
      _remoteIdentifier = identifier.trim();
      _remotePassword = password;
      _sessionExpiredMessage = null;
      aiSkills.clear();
      unawaited(hydrateWorkoutHistory(force: true));
      unawaited(hydrateActiveWorkout());
      unawaited(hydrateTrainingLibrary(force: true));
      unawaited(hydrateCustomExercises(force: true));
      unawaited(hydrateAiSkills());
      unawaited(hydrateAiConversations(force: true));
      unawaited(hydratePersonalAgentData());
    }
    return result;
  }

  Future<Map<String, bool>> androidPaymentCapabilities() async {
    final api = coachApi is HttpCoachApi
        ? coachApi! as HttpCoachApi
        : (_defaultCoachApi ??= HttpCoachApi(
            baseUrl: defaultCoachApiBaseUrl,
            onSessionInvalidated: _handleRemoteSessionInvalidated,
          ));
    final payload = await api.fetchAndroidPaymentCapabilities();
    return {
      'wechatPay': payload['wechatPay'] == true,
      'alipay': payload['alipay'] == true,
    };
  }

  Future<Uri> createAndroidMembershipCheckout({
    required MembershipPlan plan,
    required MembershipOrderProvider provider,
  }) async {
    final api = await _activeCoachApi();
    if (api is! HttpCoachApi) {
      throw const CoachApiException('android_payment_unavailable');
    }
    final productId = membershipProductIdForPlan(plan);
    final payload = await api.createAndroidMembershipCheckout(
      productId: productId,
      provider: provider == MembershipOrderProvider.wechatPay
          ? 'wechat_pay'
          : 'alipay',
      amountMinor: plan == MembershipPlan.threeMonths ? 16800 : 1800,
    );
    final raw = payload['order'];
    if (raw is Map) {
      accountService.upsertMembershipOrder(
        _remoteMembershipOrder(Map<String, dynamic>.from(raw)),
      );
    }
    final uri = Uri.tryParse((payload['paymentUrl'] ?? '').toString());
    if (uri == null || !uri.hasScheme) {
      throw const CoachApiException('payment_url_missing');
    }
    return uri;
  }

  static String membershipProductIdForPlan(MembershipPlan plan) =>
      plan == MembershipPlan.threeMonths
      ? 'com.kilostrength.pro.yearly'
      : 'com.kilostrength.pro.monthly';

  Future<AuthResult> loginWithPhoneRemote(
    String identifier, {
    required String password,
  }) async {
    final normalized = identifier.trim();
    if (normalized.isEmpty) {
      return const AuthResult.failure(AccountError.emptyIdentifier);
    }
    // A new remote login starts a fresh session. This prevents the previous
    // account's token from being reused while the local account is replaced.
    _defaultCoachApi?.clearSession();
    _defaultRecognitionApi?.clearSession();
    if (coachApi is HttpCoachApi) {
      (coachApi as HttpCoachApi).clearSession();
    }
    if (recognitionApi is HttpRecognitionApi) {
      (recognitionApi as HttpRecognitionApi).clearSession();
    }
    _storedRemoteSession = null;
    _secureSessionLoaded = true;
    final api = coachApi is HttpCoachApi
        ? coachApi! as HttpCoachApi
        : (_defaultCoachApi ??= HttpCoachApi(
            baseUrl: defaultCoachApiBaseUrl,
            onSessionInvalidated: _handleRemoteSessionInvalidated,
          ));
    _defaultCoachApiBaseUrl = defaultCoachApiBaseUrl;
    try {
      final payload = await api.signIn(
        identifier: normalized,
        password: password,
      );
      final rawUser = payload['user'];
      if (rawUser is! Map) {
        return const AuthResult.failure(AccountError.invalidCredentials);
      }
      final user = Map<String, dynamic>.from(rawUser);
      final result = accountService.loginAuthenticatedRemote(
        identifier: (user['identifier'] ?? normalized).toString(),
        displayName: (user['displayName'] ?? normalized).toString(),
        isAdmin: user['role'] == 'admin',
      );
      if (result.isSuccess) {
        _remoteIdentifier = normalized;
        _remotePassword = password;
        _sessionExpiredMessage = null;
        _storedRemoteSession = api.session;
        _secureSessionLoaded = true;
        final session = api.session;
        if (session != null) await secureSessionStore.write(session);
        aiSkills.clear();
        unawaited(_hydrateUserDataAfterLogin());
      }
      return result;
    } on CoachApiException catch (error) {
      if (error.code == 'invalid_credentials' || error.code == 'coach_auth') {
        return const AuthResult.failure(AccountError.invalidCredentials);
      }
      return AuthResult.failure(
        AccountError.serviceNotConfigured,
        message: error.code,
      );
    } catch (_) {
      return const AuthResult.failure(
        AccountError.serviceNotConfigured,
        message: 'network_unavailable',
      );
    }
  }

  Future<Map<String, dynamic>> createManagedUserRemote({
    required String identifier,
    String password = '1234',
    String? displayName,
    MembershipPlan? membershipPlan,
  }) async {
    final api = await _activeCoachApi();
    if (api is! HttpCoachApi) {
      throw const CoachApiException('admin_user_create_unavailable');
    }
    return api.createManagedUser(
      identifier: identifier,
      password: password,
      displayName: displayName,
      membershipPlan: membershipPlan == null
          ? null
          : switch (membershipPlan) {
              MembershipPlan.oneMonth => 'oneMonth',
              MembershipPlan.threeMonths => 'yearly',
              MembershipPlan.forever => 'forever',
              MembershipPlan.free => 'free',
            },
    );
  }

  Future<Map<String, dynamic>> grantMembershipRemote({
    required String identifier,
    required MembershipPlan plan,
  }) async {
    final api = await _activeCoachApi();
    if (api is! HttpCoachApi) {
      throw const CoachApiException('admin_membership_grant_unavailable');
    }
    return api.grantMembershipRemote(
      identifier: identifier,
      plan: switch (plan) {
        MembershipPlan.oneMonth => 'oneMonth',
        MembershipPlan.threeMonths => 'yearly',
        MembershipPlan.forever => 'forever',
        MembershipPlan.free => 'free',
      },
    );
  }

  Future<Map<String, dynamic>> fetchFriendsRemote() async {
    final api = await _activeCoachApi();
    if (api is! HttpCoachApi) {
      throw const CoachApiException('friends_unavailable');
    }
    return api.fetchFriends();
  }

  Future<Map<String, dynamic>> fetchFriendPlanFeedRemote() async {
    final api = await _activeCoachApi();
    if (api is! HttpCoachApi) {
      throw const CoachApiException('friends_unavailable');
    }
    return api.fetchFriendPlanFeed();
  }

  Future<void> sendFriendRequestRemote(String identifier) async {
    final api = await _activeCoachApi();
    if (api is! HttpCoachApi) {
      throw const CoachApiException('friends_unavailable');
    }
    await api.sendFriendRequest(identifier.trim());
  }

  Future<void> acceptFriendRequestRemote(String requestId) async {
    final api = await _activeCoachApi();
    if (api is! HttpCoachApi) {
      throw const CoachApiException('friends_unavailable');
    }
    await api.acceptFriendRequest(requestId);
  }

  Future<void> shareRoutineWithFriends(Routine routine) async {
    final api = await _activeCoachApi();
    if (api is! HttpCoachApi) {
      throw const CoachApiException('friends_unavailable');
    }
    await api.shareFriendPlan(
      sourcePlanId: routine.id,
      name: routine.name,
      plan: {
        'exercises': [
          for (final exercise in routine.exercises)
            {
              'exerciseId': exercise.exerciseId,
              'restSeconds': exercise.restSeconds,
              'sets': [
                for (final set in exercise.sets)
                  {
                    'type': set.type,
                    'weight': set.plannedWeight ?? set.weight,
                    'reps': set.reps,
                    'restSeconds': set.restSeconds,
                  },
              ],
            },
        ],
      },
    );
  }

  Future<void> reactToFriendPlanRemote(String shareId, String emoji) async {
    final api = await _activeCoachApi();
    if (api is! HttpCoachApi) {
      throw const CoachApiException('friends_unavailable');
    }
    await api.reactToFriendPlan(shareId, emoji);
  }

  void saveFriendPlan(Map<String, dynamic> share) {
    final rawPlan = share['plan'];
    if (rawPlan is! Map) return;
    final exercises = <WorkoutExercise>[];
    final rawExercises = rawPlan['exercises'];
    if (rawExercises is! List) return;
    for (
      var exerciseIndex = 0;
      exerciseIndex < rawExercises.length;
      exerciseIndex++
    ) {
      final rawExercise = rawExercises[exerciseIndex];
      if (rawExercise is! Map) continue;
      final exerciseId = (rawExercise['exerciseId'] ?? '').toString();
      if (exerciseId.isEmpty) continue;
      final sets = <WorkoutSet>[];
      final rawSets = rawExercise['sets'];
      if (rawSets is List) {
        for (var setIndex = 0; setIndex < rawSets.length; setIndex++) {
          final rawSet = rawSets[setIndex];
          if (rawSet is! Map) continue;
          final weight = (rawSet['weight'] as num?)?.toDouble() ?? 0;
          sets.add(
            WorkoutSet(
              id: 'friend-set-${DateTime.now().microsecondsSinceEpoch}-$setIndex',
              type: (rawSet['type'] ?? 'work').toString(),
              weight: weight,
              plannedWeight: weight,
              reps: (rawSet['reps'] as num?)?.toInt() ?? 0,
              restSeconds: (rawSet['restSeconds'] as num?)?.toInt() ?? 0,
            ),
          );
        }
      }
      exercises.add(
        WorkoutExercise(
          id: 'friend-exercise-${DateTime.now().microsecondsSinceEpoch}-$exerciseIndex',
          exerciseId: exerciseId,
          sets: sets,
          restSeconds: (rawExercise['restSeconds'] as num?)?.toInt() ?? 0,
        ),
      );
    }
    final name = (share['name'] ?? '好友训练计划').toString();
    saveRoutineFromDraft('$name · 好友分享', exercises, folder: '好友分享');
  }

  AuthResult loginWithApple() => accountService.loginWithApple();

  AuthResult loginWithGoogle() => accountService.loginWithGoogle();

  void logout() {
    _remoteIdentifier = null;
    _remotePassword = null;
    _defaultCoachApi?.clearSession();
    _defaultRecognitionApi?.clearSession();
    _storedRemoteSession = null;
    _secureSessionLoaded = true;
    unawaited(secureSessionStore.clear());
    _sessionExpiredMessage = null;
    accountService.logout();
    _loadedHistoryUserId = null;
    _loadedTrainingLibraryUserId = null;
    _loadedCustomExercisesUserId = null;
    _loadedAiConversationsUserId = null;
    history.clear();
    routines.clear();
    routineFolders.clear();
    scheduled.clear();
    scheduledLabels.clear();
    customExercises.clear();
    aiSkills.clear();
    conversations.clear();
    chat.clear();
    activeConversationId = 'conversation-main';
    notifyListeners();
  }

  Future<void> hydrateWorkoutHistory({bool force = false}) async {
    final userId = currentUser?.id;
    if (userId == null || userId.isEmpty) {
      history.clear();
      _loadedHistoryUserId = null;
      notifyListeners();
      return;
    }
    if (!force && _loadedHistoryUserId == userId) return;
    await _historyWriteChain;
    final records = await workoutHistoryPersistence.read(userId);
    if (currentUser?.id != userId) return;
    history
      ..clear()
      ..addAll(records);
    _loadedHistoryUserId = userId;
    if (_disposed) return;
    notifyListeners();
  }

  Future<void> flushWorkoutHistoryPersistence() => _historyWriteChain;

  Future<void> flushActiveWorkoutPersistence() => _activeWorkoutWriteChain;

  Future<void> flushTrainingLibraryPersistence() => _trainingLibraryWriteChain;

  Future<void> flushCustomExercisePersistence() => _customExerciseWriteChain;

  Future<void> flushAiConversationPersistence() => _aiConversationWriteChain;

  static const _cloudBackupEntityId = 'mobile_backup_v1';

  void _scheduleCloudBackup() {
    if (!isAuthenticated) return;
    unawaited(backupUserData());
  }

  Future<void> _hydrateUserDataAfterLogin() async {
    await restoreCloudBackup();
    await Future.wait([
      hydrateWorkoutHistory(force: true),
      hydrateActiveWorkout(),
      hydrateTrainingLibrary(force: true),
      hydrateCustomExercises(force: true),
      hydrateAiSkills(),
      hydrateAiConversations(force: true),
      hydratePersonalAgentData(),
    ]);
  }

  Future<void> restoreCloudBackup() async {
    final userId = currentUser?.id;
    if (userId == null || userId.isEmpty) return;
    try {
      final api = await _activeCoachApi();
      if (api is! HttpCoachApi) return;
      final entities = await api.fetchSyncEntities('settings');
      Map<String, dynamic>? backup;
      for (final entity in entities) {
        if (entity['entityId'] == _cloudBackupEntityId &&
            entity['deleted'] != true &&
            entity['payload'] is Map) {
          backup = Map<String, dynamic>.from(entity['payload'] as Map);
          break;
        }
      }
      if (backup == null || currentUser?.id != userId) return;
      final localHistory = await workoutHistoryPersistence.read(userId);
      if (localHistory.isEmpty) {
        final restored = decodeWorkoutRecords(backup['workoutHistory']);
        if (restored.isNotEmpty) {
          await workoutHistoryPersistence.write(userId, restored);
        }
      }
      final preferences = await SharedPreferences.getInstance();
      final aiKey = 'xingyu.ai-conversations.v1.$userId';
      if ((preferences.getString(aiKey) ?? '').isEmpty) {
        final aiPayload = backup['aiConversations'];
        if (aiPayload is Map) {
          await preferences.setString(aiKey, jsonEncode(aiPayload));
        }
      }
      for (final item in const [
        ['trainingProfile', 'kilo.training-profile.v1.'],
        ['nutrition', 'kilo.nutrition.v1.'],
      ]) {
        final key = '${item[1]}$userId';
        if ((preferences.getString(key) ?? '').isNotEmpty) continue;
        final value = backup[item[0]];
        if (value != null) await preferences.setString(key, jsonEncode(value));
      }
    } catch (_) {
      // Cloud recovery is best effort; existing on-device data always wins.
    }
  }

  Future<void> backupUserData() async {
    final userId = currentUser?.id;
    if (userId == null || userId.isEmpty) return;
    try {
      await Future.wait([_historyWriteChain, _aiConversationWriteChain]);
      final api = await _activeCoachApi();
      if (api is! HttpCoachApi || currentUser?.id != userId) return;
      final preferences = await SharedPreferences.getInstance();
      final rawAi = preferences.getString('xingyu.ai-conversations.v1.$userId');
      final rawProfile = preferences.getString(
        'kilo.training-profile.v1.$userId',
      );
      final rawNutrition = preferences.getString('kilo.nutrition.v1.$userId');
      final entities = await api.fetchSyncEntities('settings');
      var revision = 0;
      for (final entity in entities) {
        if (entity['entityId'] == _cloudBackupEntityId) {
          revision = (entity['revision'] as num?)?.toInt() ?? 0;
          break;
        }
      }
      await api.upsertSyncEntity(
        entityType: 'settings',
        entityId: _cloudBackupEntityId,
        baseRevision: revision,
        payload: {
          'schemaVersion': 1,
          'updatedAt': DateTime.now().toUtc().toIso8601String(),
          'workoutHistory': encodeWorkoutRecords(history),
          if (rawAi?.isNotEmpty == true) 'aiConversations': jsonDecode(rawAi!),
          if (rawProfile?.isNotEmpty == true)
            'trainingProfile': jsonDecode(rawProfile!),
          if (rawNutrition?.isNotEmpty == true)
            'nutrition': jsonDecode(rawNutrition!),
        },
      );
    } catch (_) {
      // Sync must never interrupt training or chat. A later write retries it.
    }
  }

  String get _aiConversationsStorageKey =>
      'xingyu.ai-conversations.v1.${currentUser?.id ?? 'local'}';

  Future<void> hydrateAiConversations({bool force = false}) async {
    final userId = currentUser?.id;
    if (userId == null || userId.isEmpty) return;
    if (!force && _loadedAiConversationsUserId == userId) return;
    final revisionAtStart = _aiConversationRevision;
    try {
      await _aiConversationWriteChain;
      final preferences = await SharedPreferences.getInstance();
      final raw = preferences.getString('xingyu.ai-conversations.v1.$userId');
      if (currentUser?.id != userId) return;
      if (_aiConversationRevision != revisionAtStart) {
        _loadedAiConversationsUserId = userId;
        return;
      }
      final restored = <AiConversation>[];
      var restoredActiveId = 'conversation-main';
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          restoredActiveId =
              decoded['activeConversationId']?.toString() ?? restoredActiveId;
          final items = decoded['conversations'];
          if (items is List<dynamic>) {
            for (final value in items.whereType<Map>()) {
              final json = Map<String, dynamic>.from(value);
              final id = json['id']?.toString() ?? '';
              if (id.isEmpty) continue;
              final messages = (json['messages'] as List<dynamic>? ?? const [])
                  .whereType<Map>()
                  .map(
                    (item) =>
                        _chatMessageFromJson(Map<String, dynamic>.from(item)),
                  )
                  .whereType<ChatMessage>()
                  .toList(growable: false);
              restored.add(
                AiConversation(
                  id: id,
                  title: json['title']?.toString() ?? '新对话',
                  messages: messages,
                  serverConversationId: json['serverConversationId']
                      ?.toString(),
                ),
              );
            }
          }
        }
      }
      conversations
        ..clear()
        ..addAll(restored);
      if (conversations.isEmpty) {
        activeConversationId = 'conversation-main';
        chat.clear();
      } else {
        final selected = conversations.firstWhere(
          (item) => item.id == restoredActiveId,
          orElse: () => conversations.first,
        );
        activeConversationId = selected.id;
        chat
          ..clear()
          ..addAll(selected.messages);
      }
      _loadedAiConversationsUserId = userId;
      notifyListeners();
    } catch (_) {
      // Invalid or unavailable local chat storage must not block AI startup.
    }
  }

  void _persistAiConversations() {
    final userId = currentUser?.id;
    if (userId == null || userId.isEmpty) return;
    _aiConversationRevision++;
    _loadedAiConversationsUserId = userId;
    final payload = <String, dynamic>{
      'activeConversationId': activeConversationId,
      'conversations': conversations
          .map(
            (conversation) => <String, dynamic>{
              'id': conversation.id,
              'title': conversation.title,
              if (conversation.serverConversationId?.isNotEmpty == true)
                'serverConversationId': conversation.serverConversationId,
              'messages': conversation.messages
                  .map(_chatMessageToJson)
                  .toList(growable: false),
            },
          )
          .toList(growable: false),
    };
    final key = _aiConversationsStorageKey;
    _aiConversationWriteChain = _aiConversationWriteChain
        .then((_) async {
          final preferences = await SharedPreferences.getInstance();
          await preferences.setString(key, jsonEncode(payload));
        })
        .catchError((Object _) {
          // The current conversation remains usable in memory.
        });
    _scheduleCloudBackup();
  }

  Map<String, dynamic> _chatMessageToJson(ChatMessage message) => {
    'id': message.id,
    'role': message.role,
    'body': message.body,
    'citations': message.citations,
    if (message.plan != null) 'plan': _aiPlanToJson(message.plan!),
  };

  ChatMessage? _chatMessageFromJson(Map<String, dynamic> json) {
    final id = json['id']?.toString() ?? '';
    final role = json['role']?.toString() ?? '';
    if (id.isEmpty || !const {'user', 'assistant'}.contains(role)) return null;
    return ChatMessage(
      id: id,
      role: role,
      body: json['body']?.toString() ?? '',
      citations: (json['citations'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .where((item) => item.isNotEmpty)
          .toList(growable: false),
      plan: _aiPlanFromJson(json['plan']),
    );
  }

  Map<String, dynamic> _aiPlanToJson(AiPlanDraft plan) => {
    'title': plan.title,
    'weeks': plan.weeks,
    'sessions': plan.sessions
        .map(
          (session) => <String, dynamic>{
            'dayOffset': session.dayOffset,
            'name': session.name,
            'exerciseIds': session.exerciseIds,
            'exercises': session.exercises
                .map(
                  (exercise) => <String, dynamic>{
                    'exerciseId': exercise.exerciseId,
                    if (exercise.note.trim().isNotEmpty)
                      'note': exercise.note.trim(),
                    'sets': exercise.sets
                        .map(
                          (set) => <String, dynamic>{
                            'type': set.type,
                            'weight': set.weight,
                            'reps': set.reps,
                            'restSeconds': set.restSeconds,
                          },
                        )
                        .toList(growable: false),
                  },
                )
                .toList(growable: false),
          },
        )
        .toList(growable: false),
  };

  AiPlanDraft? _aiPlanFromJson(Object? value) {
    if (value is! Map) return null;
    final json = Map<String, dynamic>.from(value);
    final sessions = <AiPlanSession>[];
    for (final rawSession
        in (json['sessions'] as List<dynamic>? ?? const []).whereType<Map>()) {
      final session = Map<String, dynamic>.from(rawSession);
      final exercises = <AiPlanExerciseDraft>[];
      for (final rawExercise
          in (session['exercises'] as List<dynamic>? ?? const [])
              .whereType<Map>()) {
        final exercise = Map<String, dynamic>.from(rawExercise);
        final exerciseId = exercise['exerciseId']?.toString() ?? '';
        if (exerciseId.isEmpty) continue;
        final sets = <AiPlanSetDraft>[];
        for (final rawSet
            in (exercise['sets'] as List<dynamic>? ?? const [])
                .whereType<Map>()) {
          final set = Map<String, dynamic>.from(rawSet);
          sets.add(
            AiPlanSetDraft(
              type: set['type']?.toString() ?? 'work',
              weight: (set['weight'] as num?)?.toDouble() ?? 0,
              reps: (set['reps'] as num?)?.toInt() ?? 0,
              restSeconds: (set['restSeconds'] as num?)?.toInt() ?? 0,
            ),
          );
        }
        exercises.add(
          AiPlanExerciseDraft(
            exerciseId: exerciseId,
            sets: sets,
            note: exercise['note']?.toString().trim() ?? '',
          ),
        );
      }
      sessions.add(
        AiPlanSession(
          dayOffset: (session['dayOffset'] as num?)?.toInt() ?? 0,
          name: session['name']?.toString() ?? '训练',
          exerciseIds: (session['exerciseIds'] as List<dynamic>? ?? const [])
              .map((item) => item.toString())
              .where((item) => item.isNotEmpty)
              .toList(growable: false),
          exercises: exercises,
        ),
      );
    }
    return AiPlanDraft(
      title: json['title']?.toString() ?? '训练计划',
      weeks: (json['weeks'] as num?)?.toInt() ?? 1,
      sessions: sessions,
    );
  }

  Future<void> hydrateCustomExercises({bool force = false}) async {
    final userId = currentUser?.id;
    if (userId == null || userId.isEmpty) return;
    if (!force && _loadedCustomExercisesUserId == userId) return;
    try {
      await _customExerciseWriteChain;
      final preferences = await SharedPreferences.getInstance();
      final raw = preferences.getString('custom_exercises_v1_$userId');
      if (currentUser?.id != userId) return;
      customExercises.clear();
      if (raw != null && raw.isNotEmpty) {
        final values = jsonDecode(raw) as List<dynamic>;
        customExercises.addAll(
          values.whereType<Map>().map((value) {
            final json = Map<String, dynamic>.from(value);
            return Exercise(
              id: json['id'] as String,
              name: json['name'] as String,
              englishName: json['englishName'] as String,
              family: json['family'] as String? ?? '自定义',
              muscle: json['muscle'] as String? ?? '未分类',
              secondary: json['secondary'] as String? ?? '无',
              equipment: json['equipment'] as String? ?? '自定义器械',
              camera: json['camera'] as String? ?? '待设置',
              cue: json['cue'] as String? ?? '',
              loadMode: json['loadMode'] as String? ?? 'total',
            );
          }),
        );
      }
      _loadedCustomExercisesUserId = userId;
      notifyListeners();
    } catch (_) {
      // A malformed or unavailable local store must not block training.
    }
  }

  void _persistCustomExercises() {
    final userId = currentUser?.id;
    if (userId == null || userId.isEmpty) return;
    _loadedCustomExercisesUserId = userId;
    final values = customExercises
        .map(
          (item) => <String, dynamic>{
            'id': item.id,
            'name': item.name,
            'englishName': item.englishName,
            'family': item.family,
            'muscle': item.muscle,
            'secondary': item.secondary,
            'equipment': item.equipment,
            'camera': item.camera,
            'cue': item.cue,
            'loadMode': item.loadMode,
          },
        )
        .toList(growable: false);
    _customExerciseWriteChain = _customExerciseWriteChain
        .then((_) async {
          final preferences = await SharedPreferences.getInstance();
          await preferences.setString(
            'custom_exercises_v1_$userId',
            jsonEncode(values),
          );
        })
        .catchError((Object _) {
          // The newly created exercise remains usable in memory.
        });
  }

  Future<void> hydrateTrainingLibrary({bool force = false}) async {
    final userId = currentUser?.id;
    if (userId == null || userId.isEmpty) return;
    if (!force && _loadedTrainingLibraryUserId == userId) return;
    await _trainingLibraryWriteChain;
    final snapshot = await trainingLibraryPersistence.read(userId);
    if (currentUser?.id != userId) return;
    routines
      ..clear()
      ..addAll(snapshot.routines);
    routineFolders
      ..clear()
      ..addAll(snapshot.routineFolders);
    scheduledLabels
      ..clear()
      ..addAll(snapshot.scheduledLabels);
    scheduled
      ..clear()
      ..addAll(snapshot.scheduledLabels.keys);
    _loadedTrainingLibraryUserId = userId;
    notifyListeners();
  }

  void _persistTrainingLibrary() {
    final userId = currentUser?.id;
    if (userId == null || userId.isEmpty) return;
    _loadedTrainingLibraryUserId = userId;
    final snapshot = TrainingLibrarySnapshot(
      routines: routines
          .map(
            (routine) => Routine(
              id: routine.id,
              name: routine.name,
              folder: routine.folder,
              exercises: routine.exercises
                  .map((exercise) => exercise.copyForPlan())
                  .toList(),
              updatedAt: routine.updatedAt,
            ),
          )
          .toList(growable: false),
      routineFolders: List<String>.from(routineFolders),
      scheduledLabels: Map<String, String>.from(scheduledLabels),
    );
    _trainingLibraryWriteChain = _trainingLibraryWriteChain
        .then((_) => trainingLibraryPersistence.write(userId, snapshot))
        .catchError((Object _) {
          // Training remains available even if platform storage is absent.
        });
  }

  Future<void> hydrateActiveWorkout() async {
    final userId = currentUser?.id;
    if (userId == null || userId.isEmpty || workoutStarted) return;
    final snapshot = await activeWorkoutPersistence.read(userId);
    if (snapshot == null || _disposed) return;
    workout
      ..clear()
      ..addAll(snapshot.exercises.map((item) => item.copy()));
    workoutName = snapshot.name;
    workoutNote = snapshot.note;
    freeWorkout = snapshot.freeWorkout;
    workoutDraft = snapshot.draft;
    workoutStarted = true;
    workoutCompleted = false;
    workoutTimerStarted = snapshot.timerStarted;
    workoutPaused = snapshot.paused;
    workoutElapsedSeconds = snapshot.elapsedSeconds;
    workoutStartedAt = snapshot.timerStarted && !snapshot.paused
        ? snapshot.startedAt ?? DateTime.now()
        : null;
    defaultRestSeconds = snapshot.defaultRestSeconds;
    restSetupPending = snapshot.restSetupPending;
    pendingRestSetId = snapshot.pendingRestSetId;
    restRunning = snapshot.restRunning;
    restRemainingSeconds = snapshot.restRemainingSeconds;
    restExerciseName = snapshot.restExerciseName;
    _restEndsAt = snapshot.restEndsAt;
    if (restRunning) {
      if (workoutPaused) _restEndsAt = null;
      reconcileRestClock();
      if (restRunning && !workoutPaused) _scheduleRestTicker();
    }
    if (workoutTimerStarted && !workoutPaused) {
      _workoutTicker?.cancel();
      _workoutTicker = Timer.periodic(
        const Duration(seconds: 1),
        (_) => notifyListeners(),
      );
    }
    if (_pendingSystemWorkoutOpen) {
      _pendingSystemWorkoutOpen = false;
      trainView = TrainView.workout;
      liveWorkoutVisible = true;
      page = PageId.train;
    }
    notifyListeners();
  }

  void persistActiveWorkout() {
    final userId = currentUser?.id;
    if (userId == null || userId.isEmpty) return;
    final snapshot = workoutStarted
        ? ActiveWorkoutSnapshot(
            name: workoutName,
            note: workoutNote,
            freeWorkout: freeWorkout,
            draft: workoutDraft,
            timerStarted: workoutTimerStarted,
            paused: workoutPaused,
            elapsedSeconds: currentElapsed,
            // The elapsed snapshot already includes the current foreground
            // segment. Restart that segment at persistence time so process
            // restoration never counts the same seconds twice.
            startedAt: workoutTimerStarted && !workoutPaused
                ? DateTime.now()
                : null,
            exercises: workout.map((item) => item.copy()).toList(),
            defaultRestSeconds: defaultRestSeconds,
            restRunning: restRunning,
            restRemainingSeconds: _currentRestRemaining(),
            restEndsAt: _restEndsAt,
            restExerciseName: restExerciseName,
            restSetupPending: restSetupPending,
            pendingRestSetId: pendingRestSetId,
          )
        : null;
    _activeWorkoutWriteChain = _activeWorkoutWriteChain
        .then((_) => activeWorkoutPersistence.write(userId, snapshot))
        .catchError((Object _) {
          // A storage failure must never interrupt a live workout.
        });
  }

  void _persistWorkoutHistory() {
    final userId = currentUser?.id;
    if (userId == null || userId.isEmpty) return;
    _loadedHistoryUserId = userId;
    final snapshot = history.map((record) => record).toList(growable: false);
    _historyWriteChain = _historyWriteChain
        .then((_) => workoutHistoryPersistence.write(userId, snapshot))
        .catchError((Object _) {
          // Training stays usable when platform storage is temporarily absent.
        });
    _scheduleCloudBackup();
  }

  AccountResult<EntitlementSnapshot> grantMembership({
    required String identifier,
    required MembershipPlan plan,
  }) => accountService.grantMembership(identifier: identifier, plan: plan);

  RedemptionCode generateRedemptionCode({required MembershipPlan plan}) =>
      accountService.generateRedemptionCode(plan: plan);

  AccountResult<EntitlementSnapshot> redeemCode(String code) =>
      accountService.redeemCode(code);

  PageId page = PageId.today;
  TrainView trainView = TrainView.workout;
  AiView aiView = AiView.chat;
  bool workoutStarted = false;
  bool workoutTimerStarted = false;
  bool workoutPaused = false;
  DateTime? workoutStartedAt;
  int workoutElapsedSeconds = 0;
  bool workoutDraft = false;
  bool workoutCompleted = false;
  bool liveWorkoutVisible = false;
  bool completionBurstActive = false;
  int completionBurstId = 0;
  String? completionBurstSetId;
  bool restSetupPending = false;
  String? pendingRestSetId;

  /// Whether the current session was started without a prescribed plan.
  /// Free-training sets intentionally keep [WorkoutSet.plannedWeight] null.
  bool freeWorkout = false;
  String workoutName = '自由训练';
  String workoutNote = '';
  final List<WorkoutExercise> workout = [];
  final List<Routine> routines = [];
  final List<String> routineFolders = [];
  final List<WorkoutRecord> history = [];
  final List<NutritionEntry> nutritionEntries = [];
  TrainingProfile trainingProfile = const TrainingProfile();
  bool profileOnboardingCompleted = false;
  bool personalAgentDataReady = false;
  final List<Exercise> customExercises = [];
  final Map<String, Map<String, ExerciseResource>> exerciseResources = {};
  String aiBaseUrl = defaultCoachApiBaseUrl;
  String? selectedMediaPath;
  String? selectedMediaName;
  int? selectedMediaBytes;
  String? mediaError;
  bool mediaPicking = false;
  RecognitionResult? recognitionResult;
  final List<String> scheduled = [];

  /// Session-wide rest chosen by the user. Zero means unset; free training
  /// must ask on the first completed set instead of inventing a duration.
  int defaultRestSeconds = 0;
  bool livePrEnabled = true;
  String selectedExerciseId = 'bench_press';
  AppLanguage appLanguage = AppLanguage.simplifiedChinese;
  String search = '';
  String muscleFilter = '全部';
  String equipmentFilter = '全部';
  RecognitionStatus recognitionStatus = RecognitionStatus.idle;
  RecognitionStage recognitionStage = RecognitionStage.idle;
  double recognitionProgress = 0;
  int recognitionElapsedSeconds = 0;
  bool recognitionIncludeOverlay = false;
  List<RecognitionCapability> recognitionCapabilities =
      fallbackRecognitionCapabilities;
  bool recognitionCapabilitiesLoading = false;
  String recognitionExerciseId =
      fallbackRecognitionCapabilities.first.exerciseId;
  String recognitionCamera =
      fallbackRecognitionCapabilities.first.cameras.first.id;
  bool savedCue = false;
  bool analysisAttached = false;
  // The AI agent is useful without a manual attachment step. It remains
  // read-only and can be disabled at any time from AI settings.
  bool aiUseTrainingData = true;
  bool aiConsentSeen = false;
  bool aiToolReading = false;
  List<CoachToolUse> aiToolUses = const [];
  String? aiToolError;
  bool aiTyping = false;
  int aiWaitingSeconds = 0;
  final List<ChatMessage> chat = [];
  final List<AiSkill> aiSkills = [];
  final List<AiConversation> conversations = [];
  String activeConversationId = 'conversation-main';
  String scenario = 'normal';
  bool appleWatch = false;
  bool liveActivity = true;
  bool androidNotifications = true;
  bool batchMode = false;
  final Set<String> selectedSetIds = <String>{};
  String? selectedPlanFolder;
  final Map<String, String> scheduledLabels = {};
  double aiScrollOffset = 0;
  int restRemainingSeconds = 0;
  bool restRunning = false;
  String? restExerciseName;
  Timer? _workoutTicker;
  Timer? _restTicker;
  DateTime? _restEndsAt;
  Timer? _recognitionTicker;
  Timer? _completionBurstTimer;
  Timer? _aiWaitingTimer;
  StreamSubscription<CoachStreamEvent>? _aiStreamSubscription;
  Completer<CoachAnswer>? _activeAiCompleter;
  bool _aiCancelled = false;
  DateTime? _activeSetStartedAt;
  int _activeSetElapsedSeconds = 0;
  QuotaReservation? _recognitionReservation;

  List<Exercise> get allExercises => [...catalog, ...customExercises];

  String get _profileStorageKey =>
      'kilo.training-profile.v1.${currentUser?.id ?? 'local'}';
  String get _nutritionStorageKey =>
      'kilo.nutrition.v1.${currentUser?.id ?? 'local'}';

  Future<void> hydratePersonalAgentData() async {
    final preferences = await SharedPreferences.getInstance();
    try {
      final rawProfile = preferences.getString(_profileStorageKey);
      if (rawProfile != null && rawProfile.isNotEmpty) {
        final value = jsonDecode(rawProfile);
        if (value is Map) {
          final map = Map<String, dynamic>.from(value);
          profileOnboardingCompleted = map['completed'] == true;
          if (map['profile'] is Map) {
            trainingProfile = TrainingProfile.fromJson(
              Map<String, dynamic>.from(map['profile'] as Map),
            );
          }
        }
      }
      final rawNutrition = preferences.getString(_nutritionStorageKey);
      nutritionEntries.clear();
      if (rawNutrition != null && rawNutrition.isNotEmpty) {
        final values = jsonDecode(rawNutrition);
        if (values is List) {
          nutritionEntries.addAll(
            values
                .whereType<Map>()
                .map(
                  (item) =>
                      NutritionEntry.fromJson(Map<String, dynamic>.from(item)),
                )
                .where(
                  (item) => item.id.isNotEmpty && item.foodName.isNotEmpty,
                ),
          );
        }
      }
      nutritionEntries.sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
      personalAgentDataReady = true;
      notifyListeners();
    } catch (_) {
      // Damaged optional profile data must not block the app.
      personalAgentDataReady = true;
      notifyListeners();
    }
  }

  Future<void> saveTrainingProfile(
    TrainingProfile profile, {
    bool completed = true,
  }) async {
    trainingProfile = profile;
    profileOnboardingCompleted = completed;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _profileStorageKey,
      jsonEncode({'completed': completed, 'profile': profile.toJson()}),
    );
    _scheduleCloudBackup();
    notifyListeners();
  }

  Future<void> skipTrainingProfile() =>
      saveTrainingProfile(trainingProfile, completed: true);

  Future<void> addNutritionEntry(NutritionEntry entry) async {
    nutritionEntries.insert(0, entry);
    await _persistNutrition();
    notifyListeners();
  }

  Future<void> deleteNutritionEntry(String id) async {
    nutritionEntries.removeWhere((item) => item.id == id);
    await _persistNutrition();
    notifyListeners();
  }

  Future<void> _persistNutrition() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _nutritionStorageKey,
      jsonEncode(nutritionEntries.map((item) => item.toJson()).toList()),
    );
    _scheduleCloudBackup();
  }

  List<NutritionEntry> nutritionForDay(DateTime day) => nutritionEntries
      .where(
        (item) =>
            item.recordedAt.year == day.year &&
            item.recordedAt.month == day.month &&
            item.recordedAt.day == day.day,
      )
      .toList(growable: false);

  double get todayCalories => nutritionForDay(
    DateTime.now(),
  ).fold(0, (sum, item) => sum + item.calories);

  double get todayProtein => nutritionForDay(
    DateTime.now(),
  ).fold(0, (sum, item) => sum + item.proteinGrams);

  double? get estimatedDailyCalories {
    final profile = trainingProfile;
    if (profile.weightKg == null ||
        profile.heightCm == null ||
        profile.age == null ||
        !const {'male', 'female'}.contains(profile.gender)) {
      return null;
    }
    final sexOffset = profile.gender == 'male' ? 5 : -161;
    final bmr =
        10 * profile.weightKg! +
        6.25 * profile.heightCm! -
        5 * profile.age! +
        sexOffset;
    final activity = switch (profile.activityLevel) {
      'low' => 1.2,
      'high' => 1.725,
      _ => 1.55,
    };
    final goalOffset = switch (profile.goal) {
      'fat_loss' => -300,
      'muscle_gain' => 250,
      _ => 0,
    };
    return bmr * activity + goalOffset;
  }

  /// Curated picker data plus user-created exercises. The generated dataset
  /// remains in [allExercises] for history/import compatibility only.
  List<Exercise> get selectableExercises => [
    ...selectableCatalog,
    ...customExercises,
  ];

  Exercise exerciseFor(String id) => allExercises.firstWhere(
    (item) => item.id == id,
    orElse: () => findExercise(id),
  );

  List<AiSkill> get enabledAiSkills =>
      aiSkills.where((skill) => skill.enabled).toList(growable: false);

  Future<void> hydrateAiSkills() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final raw = preferences.getString(_aiSkillsStorageKey);
      aiSkills.clear();
      if (raw == null || raw.isEmpty) {
        notifyListeners();
        return;
      }
      final values = jsonDecode(raw) as List<dynamic>;
      aiSkills
        ..clear()
        ..addAll(
          values
              .whereType<Map<String, dynamic>>()
              .map(AiSkill.fromJson)
              .where(
                (skill) => skill.id.isNotEmpty && skill.name.trim().isNotEmpty,
              )
              .take(3),
        );
      notifyListeners();
    } catch (_) {
      // Invalid local data must not block AI chat startup.
    }
  }

  Future<void> _persistAiSkills() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(
        _aiSkillsStorageKey,
        jsonEncode(aiSkills.map((skill) => skill.toJson()).toList()),
      );
    } catch (_) {
      // In-memory skill editing remains available in previews.
    }
  }

  bool saveAiSkill({
    String? id,
    required String name,
    required String instructions,
  }) {
    final cleanName = name.trim();
    final cleanInstructions = instructions.trim();
    if (cleanName.isEmpty || cleanInstructions.isEmpty) return false;
    final index = id == null
        ? -1
        : aiSkills.indexWhere((item) => item.id == id);
    if (index >= 0) {
      aiSkills[index] = aiSkills[index].copyWith(
        name: cleanName,
        instructions: cleanInstructions,
      );
    } else {
      if (aiSkills.length >= 3) return false;
      aiSkills.add(
        AiSkill(
          id: 'skill-${DateTime.now().microsecondsSinceEpoch}-${aiSkills.length}',
          name: cleanName,
          instructions: cleanInstructions,
        ),
      );
    }
    unawaited(_persistAiSkills());
    notifyListeners();
    return true;
  }

  String get _aiSkillsStorageKey =>
      'xingyu.ai-skills.v1.${currentUser?.id ?? 'local'}';

  bool setAiSkillEnabled(String id, bool enabled) {
    final index = aiSkills.indexWhere((item) => item.id == id);
    if (index < 0) return false;
    if (enabled && enabledAiSkills.length >= 3 && !aiSkills[index].enabled) {
      return false;
    }
    aiSkills[index] = aiSkills[index].copyWith(enabled: enabled);
    unawaited(_persistAiSkills());
    notifyListeners();
    return true;
  }

  void deleteAiSkill(String id) {
    aiSkills.removeWhere((item) => item.id == id);
    unawaited(_persistAiSkills());
    notifyListeners();
  }

  List<Exercise> get recognitionExercises => [
    for (final capability in recognitionCapabilities)
      allExercises.firstWhere(
        (exercise) => exercise.id == capability.exerciseId,
        orElse: () => recognitionExerciseDefinition(
          capability.exerciseId,
          capability.group,
        ),
      ),
  ];

  RecognitionCapability get selectedRecognitionCapability =>
      recognitionCapabilities.firstWhere(
        (item) => item.exerciseId == recognitionExerciseId,
        orElse: () => recognitionCapabilities.first,
      );

  RecognitionCameraOption get selectedRecognitionCamera =>
      selectedRecognitionCapability.cameras.firstWhere(
        (item) => item.id == recognitionCamera,
        orElse: () => selectedRecognitionCapability.cameras.first,
      );

  void selectRecognitionExercise(String exerciseId) {
    final capability = recognitionCapabilities.firstWhere(
      (item) => item.exerciseId == exerciseId,
      orElse: () => recognitionCapabilities.first,
    );
    if (recognitionExerciseId == capability.exerciseId) return;
    recognitionExerciseId = capability.exerciseId;
    recognitionCamera = capability.cameras.first.id;
    _invalidateRecognitionAnalysis();
    notifyListeners();
  }

  void selectRecognitionCamera(String cameraId) {
    if (!selectedRecognitionCapability.cameras.any(
      (item) => item.id == cameraId,
    )) {
      return;
    }
    if (recognitionCamera == cameraId) return;
    recognitionCamera = cameraId;
    _invalidateRecognitionAnalysis();
    notifyListeners();
  }

  Future<void> loadRecognitionCapabilities() async {
    if (recognitionCapabilitiesLoading) return;
    recognitionCapabilitiesLoading = true;
    notifyListeners();
    try {
      final api =
          _defaultRecognitionApi ??
          HttpRecognitionApi(
            baseUrl: aiBaseUrl.trim().isEmpty
                ? defaultCoachApiBaseUrl
                : aiBaseUrl.trim(),
          );
      final loaded = await api.capabilities();
      if (_disposed) return;
      if (loaded.isNotEmpty) recognitionCapabilities = loaded;
      if (!recognitionCapabilities.any(
        (item) => item.exerciseId == recognitionExerciseId,
      )) {
        recognitionExerciseId = recognitionCapabilities.first.exerciseId;
      }
      final capability = selectedRecognitionCapability;
      if (!capability.cameras.any((item) => item.id == recognitionCamera)) {
        recognitionCamera = capability.cameras.first.id;
      }
    } catch (_) {
      // The bundled capability list is intentionally kept usable when the
      // remote configuration endpoint is temporarily unreachable. Uploading a
      // local video and starting an analysis must not look disabled merely
      // because this optional refresh failed.
    } finally {
      if (!_disposed) {
        recognitionCapabilitiesLoading = false;
        notifyListeners();
      }
    }
  }

  List<Exercise> get visibleExercises {
    final query = search.trim().toLowerCase();
    return selectableExercises.where((item) {
      final queryMatch =
          query.isEmpty ||
          item.name.toLowerCase().contains(query) ||
          item.englishName.toLowerCase().contains(query) ||
          item.muscle.toLowerCase().contains(query) ||
          item.equipment.toLowerCase().contains(query);
      final muscleMatch =
          muscleFilter == '全部' || muscleGroupFor(item.muscle) == muscleFilter;
      final equipmentMatch =
          equipmentFilter == '全部' ||
          equipmentGroupFor(item.equipment) == equipmentFilter;
      return queryMatch && muscleMatch && equipmentMatch;
    }).toList();
  }

  String muscleGroupFor(String muscle) => muscleGroupForLabel(muscle);

  String equipmentGroupFor(String equipment) =>
      equipmentGroupForLabel(equipment);

  List<String> get equipmentFilterOptions {
    const preferred = <String>[
      '固定器械',
      '哑铃',
      '杠铃',
      '有氧',
      '史密斯机',
      '绳索',
      '自重',
      '壶铃',
      '弹力带',
      '阻力带',
    ];
    final available = <String>{
      for (final item in selectableExercises) equipmentGroupFor(item.equipment),
    }..removeWhere((item) => item.trim().isEmpty || item == '全部');
    final result = <String>['全部'];
    for (final item in preferred) {
      if (available.remove(item)) result.add(item);
    }
    result.addAll(available.toList()..sort());
    return result;
  }

  Exercise get selectedExercise => exerciseFor(selectedExerciseId);

  String displayExerciseName(Exercise exercise) =>
      appLanguage == AppLanguage.english ? exercise.englishName : exercise.name;

  WorkoutRecord? workoutRecordForAiContext(AiContextSelection context) {
    if (context.type != AiContextType.workoutRecord) return null;
    for (final record in history) {
      if (record.id == context.id) return record;
    }
    return null;
  }

  Routine? routineForAiContext(AiContextSelection context) {
    if (context.type != AiContextType.routine) return null;
    for (final routine in routines) {
      if (routine.id == context.id) return routine;
    }
    return null;
  }

  Future<void> hydrateAppLanguage() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final stored = AppLanguageValue.fromStorage(
        preferences.getString('app_language'),
      );
      if (_disposed) return;
      appLanguage = stored;
      notifyListeners();
    } catch (_) {
      // Localization remains usable with the default language in previews.
    }
  }

  Future<void> setAppLanguage(AppLanguage value) async {
    if (appLanguage == value) return;
    appLanguage = value;
    notifyListeners();
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString('app_language', value.storageValue);
    } catch (_) {
      // The in-memory language still changes if platform storage is absent.
    }
  }

  int get completedSets =>
      workout.expand((item) => item.sets).where((set) => set.completed).length;
  int get totalSets => workout.expand((item) => item.sets).length;
  double get completion => totalSets == 0 ? 0 : completedSets / totalSets;

  ({WorkoutRecord record, WorkoutExercise exercise})? _latestExerciseHistory(
    String exerciseId,
  ) {
    final records = [...history]..sort((a, b) => b.date.compareTo(a.date));
    for (final record in records) {
      for (final exercise in record.exercises) {
        if (exercise.exerciseId == exerciseId &&
            exercise.sets.any((set) => set.completed)) {
          return (record: record, exercise: exercise);
        }
      }
    }
    return null;
  }

  /// Returns a set from the most recent completed session of this exact
  /// exercise ID. Workout name, plan and list position never participate in
  /// the lookup, so similarly named movements cannot leak values into one
  /// another.
  WorkoutSet? previousSetFor(String exerciseId, int setIndex) {
    final latest = _latestExerciseHistory(exerciseId)?.exercise;
    if (latest == null) return null;
    if (setIndex < latest.sets.length && latest.sets[setIndex].completed) {
      return latest.sets[setIndex];
    }
    final completed = latest.sets.where((set) => set.completed).toList();
    return completed.isEmpty ? null : completed.last;
  }

  List<WorkoutRecord> exerciseHistoryFor(String exerciseId) {
    final records = history
        .where(
          (record) => record.exercises.any(
            (exercise) =>
                exercise.exerciseId == exerciseId &&
                exercise.sets.any((set) => set.completed),
          ),
        )
        .toList(growable: false);
    records.sort((a, b) => b.date.compareTo(a.date));
    return records;
  }

  /// Picks the most useful previous session for the completion summary: an
  /// exact plan/session name first, then the most recent record sharing the
  /// largest number of exercises.
  WorkoutRecord? comparisonBaselineFor(WorkoutRecord record) {
    final candidates = history
        .where((item) => item.id != record.id)
        .toList(growable: false);
    if (candidates.isEmpty) return null;
    final sameName = candidates.where((item) => item.name == record.name);
    if (sameName.isNotEmpty) return sameName.first;
    final currentIds = record.exerciseIds.toSet();
    WorkoutRecord? best;
    var bestOverlap = 0;
    for (final candidate in candidates) {
      final overlap = candidate.exerciseIds
          .toSet()
          .intersection(currentIds)
          .length;
      if (overlap > bestOverlap ||
          (overlap == bestOverlap &&
              best != null &&
              candidate.date.isAfter(best.date))) {
        best = candidate;
        bestOverlap = overlap;
      }
    }
    return bestOverlap > 0 ? best : null;
  }

  WorkoutComparison? comparisonFor(WorkoutRecord record) {
    final baseline = comparisonBaselineFor(record);
    if (baseline == null) return null;
    final currentById = <String, List<WorkoutSet>>{};
    final previousById = <String, List<WorkoutSet>>{};
    for (final exercise in record.exercises) {
      currentById[exercise.exerciseId] = exercise.sets
          .where((set) => set.completed)
          .toList(growable: false);
    }
    for (final exercise in baseline.exercises) {
      previousById[exercise.exerciseId] = exercise.sets
          .where((set) => set.completed)
          .toList(growable: false);
    }
    final progress = <WorkoutExerciseProgress>[];
    for (final id in currentById.keys) {
      final current = currentById[id];
      final previous = previousById[id];
      if (current == null ||
          previous == null ||
          current.isEmpty ||
          previous.isEmpty) {
        continue;
      }
      final currentWeight = current
          .map((set) => set.weight)
          .reduce((a, b) => a > b ? a : b);
      final previousWeight = previous
          .map((set) => set.weight)
          .reduce((a, b) => a > b ? a : b);
      final currentReps = current.fold<int>(0, (sum, set) => sum + set.reps);
      final previousReps = previous.fold<int>(0, (sum, set) => sum + set.reps);
      progress.add(
        WorkoutExerciseProgress(
          exerciseId: id,
          weightDelta: currentWeight - previousWeight,
          repsDelta: currentReps - previousReps,
          currentWeight: currentWeight,
          previousWeight: previousWeight,
          currentReps: currentReps,
          previousReps: previousReps,
        ),
      );
    }
    return WorkoutComparison(
      baseline: baseline,
      volumeDelta: record.volume - baseline.volume,
      effectiveSetsDelta: record.effectiveSets - baseline.effectiveSets,
      durationDelta: record.durationSeconds - baseline.durationSeconds,
      exerciseProgress: progress,
    );
  }

  double get workoutVolume => workout
      .expand((item) => item.sets)
      .where((set) => set.completed)
      .fold(0, (sum, set) => sum + set.weight * set.reps);
  int get currentElapsed {
    if (!workoutStarted || workoutStartedAt == null || workoutPaused) {
      return workoutElapsedSeconds;
    }
    return workoutElapsedSeconds +
        DateTime.now().difference(workoutStartedAt!).inSeconds;
  }

  /// The product starts with a clean local workspace. Catalog exercises and
  /// official static plans remain available, while user workouts, routines,
  /// history, schedules and conversations are created only through actions.
  void _seed() {}

  WorkoutExercise _makeWorkout(String exerciseId, String id) => WorkoutExercise(
    id: id,
    exerciseId: exerciseId,
    // This helper creates a persisted plan/template, not a free-training
    // action. Keep its explicit plan rest so starting an existing plan does
    // not lose the rest configured by that plan.
    restSeconds: 120,
    sets: List.generate(3, (index) {
      final weight = index == 0 ? 20.0 : 30.0;
      return WorkoutSet(
        id: '$id-set-$index',
        weight: weight,
        plannedWeight: weight,
        restSeconds: 120,
      );
    }),
  );

  WorkoutExercise createWorkoutExercise(String exerciseId, String id) =>
      _makeWorkout(exerciseId, id);

  WorkoutExercise createBlankWorkoutExercise(String exerciseId, String id) =>
      WorkoutExercise(
        id: id,
        exerciseId: exerciseId,
        restSeconds: 0,
        sets: [
          WorkoutSet(
            id: '$id-set-0',
            weight: 0,
            plannedWeight: null,
            reps: 0,
            targetMin: 0,
            targetMax: 0,
            restSeconds: 0,
          ),
        ],
      );

  void selectPage(PageId next) {
    switch (next) {
      case PageId.records:
        page = PageId.train;
        trainView = TrainView.history;
      case PageId.recognition:
        page = PageId.ai;
        aiView = AiView.recognition;
      case PageId.today:
      case PageId.train:
      case PageId.exercises:
      case PageId.ai:
      case PageId.profile:
        page = next;
    }
    notifyListeners();
  }

  /// Notifies Flutter after a field is edited by a form or a platform control.
  void refresh({bool persistWorkout = false}) {
    if (persistWorkout) persistActiveWorkout();
    notifyListeners();
  }

  void selectTrainView(TrainView next) {
    trainView = next;
    if (next != TrainView.workout) {
      page = PageId.train;
      liveWorkoutVisible = false;
    }
    notifyListeners();
  }

  void selectAiView(AiView next) {
    aiView = next;
    page = PageId.ai;
    notifyListeners();
  }

  void startWorkout({
    List<WorkoutExercise>? source,
    String? name,
    bool autoStartTimer = true,
  }) {
    freeWorkout = source == null;
    // A new free-training session always starts with an unset rest. A plan's
    // explicit per-exercise/per-set values are copied below and remain intact.
    defaultRestSeconds = freeWorkout ? 0 : _positivePlanRest(source);
    restSetupPending = false;
    pendingRestSetId = null;
    restRunning = false;
    restRemainingSeconds = 0;
    restExerciseName = null;
    _restEndsAt = null;
    _restTicker?.cancel();
    if (source == null && workoutCompleted) {
      workout.clear();
    }
    if (source != null) {
      workout
        ..clear()
        ..addAll(
          source.map(
            (item) => item.copyForWorkout(newId: 'session-${item.id}'),
          ),
        );
      for (final exercise in workout) {
        for (final set in exercise.sets) {
          set.completed = false;
        }
      }
    }
    workoutName = name ?? (freeWorkout ? '自由训练' : workoutName);
    workoutDraft = workout.isEmpty;
    workoutCompleted = false;
    workoutStarted = true;
    workoutTimerStarted = false;
    workoutPaused = false;
    workoutElapsedSeconds = 0;
    workoutStartedAt = null;
    _workoutTicker?.cancel();
    _workoutTicker = null;
    if (autoStartTimer) {
      beginWorkoutTimer();
    } else {
      persistActiveWorkout();
      notifyListeners();
    }
  }

  void beginWorkoutTimer() {
    if (!workoutStarted || workoutTimerStarted) return;
    workoutTimerStarted = true;
    workoutPaused = false;
    workoutStartedAt = DateTime.now();
    _activeSetStartedAt ??= DateTime.now();
    _workoutTicker?.cancel();
    _workoutTicker = Timer.periodic(
      const Duration(seconds: 1),
      (_) => notifyListeners(),
    );
    PlatformTimerBridge.startWorkout(
      elapsedSeconds: 0,
      workoutName: workoutName,
      exercise: _platformExerciseName(),
      completedSets: completedSets,
      totalSets: totalSets,
    );
    persistActiveWorkout();
    notifyListeners();
  }

  void openLiveWorkout() {
    liveWorkoutVisible = true;
    page = PageId.train;
    notifyListeners();
  }

  void _openWorkoutFromSystem() {
    if (!workoutStarted) {
      _pendingSystemWorkoutOpen = true;
      unawaited(hydrateActiveWorkout());
      return;
    }
    trainView = TrainView.workout;
    openLiveWorkout();
  }

  void closeLiveWorkout() {
    liveWorkoutVisible = false;
    notifyListeners();
  }

  void pauseWorkout() {
    if (!workoutStarted || !workoutTimerStarted) return;
    final pausing = !workoutPaused;
    if (pausing) _freezeRestClock();
    workoutElapsedSeconds = currentElapsed;
    if (!workoutPaused && _activeSetStartedAt != null) {
      _activeSetElapsedSeconds += DateTime.now()
          .difference(_activeSetStartedAt!)
          .inSeconds;
      _activeSetStartedAt = null;
    }
    workoutPaused = !workoutPaused;
    workoutStartedAt = workoutPaused ? null : DateTime.now();
    if (!workoutPaused) _resumeRestClock();
    if (workoutPaused) {
      PlatformTimerBridge.pause();
    } else {
      _activeSetStartedAt ??= DateTime.now();
      PlatformTimerBridge.startWorkout(
        elapsedSeconds: workoutElapsedSeconds,
        workoutName: workoutName,
        exercise: _platformExerciseName(),
        completedSets: completedSets,
        totalSets: totalSets,
      );
    }
    if (restRunning) {
      if (workoutPaused) {
        PlatformTimerBridge.pause();
      } else {
        PlatformTimerBridge.update(
          exercise: restExerciseName ?? '休息计时',
          seconds: restRemainingSeconds,
          endsAt: _restEndsAt,
        );
      }
    }
    persistActiveWorkout();
    notifyListeners();
  }

  void setWorkoutPausedFromSystem(bool paused) {
    if (!workoutStarted || workoutPaused == paused) return;
    if (paused) _freezeRestClock();
    workoutElapsedSeconds = currentElapsed;
    if (paused && _activeSetStartedAt != null) {
      _activeSetElapsedSeconds += DateTime.now()
          .difference(_activeSetStartedAt!)
          .inSeconds;
      _activeSetStartedAt = null;
    } else if (!paused) {
      _activeSetStartedAt ??= DateTime.now();
    }
    workoutPaused = paused;
    workoutStartedAt = paused ? null : DateTime.now();
    if (!paused) _resumeRestClock();
    persistActiveWorkout();
    notifyListeners();
  }

  /// Reconciles wall-clock timers after iOS/Android resumes the Flutter
  /// isolate. A backgrounded isolate may not receive periodic timer callbacks,
  /// so elapsed time is always derived from the persisted absolute deadline.
  @visibleForTesting
  void reconcileRestClock([DateTime? now]) {
    if (!restRunning || workoutPaused || _restEndsAt == null) return;
    final next = _secondsUntil(_restEndsAt!, now ?? DateTime.now());
    restRemainingSeconds = next;
    if (next <= 0) _completeRestCountdown();
  }

  void handleAppResumed() {
    reconcileRestClock();
    if (restRunning && !workoutPaused) {
      _scheduleRestTicker();
      PlatformTimerBridge.update(
        exercise: restExerciseName ?? '休息计时',
        seconds: restRemainingSeconds,
        endsAt: _restEndsAt,
      );
    }
    persistActiveWorkout();
    notifyListeners();
  }

  void completeNextSetFromSystem() {
    for (final exercise in workout) {
      for (final set in exercise.sets) {
        if (!set.completed) {
          completeSet(set, exercise);
          return;
        }
      }
    }

    if (workout.isEmpty) return;
    final exercise = workout.reversed.firstWhere(
      (item) => item.sets.any((set) => set.completed),
      orElse: () => workout.first,
    );
    final previous = exercise.sets.reversed
        .where((set) => set.completed)
        .firstOrNull;
    final extraSet = WorkoutSet(
      id: 'set-${exercise.id}-${exercise.sets.length}-${DateTime.now().microsecondsSinceEpoch}',
      type: previous?.type ?? 'work',
      weight: previous?.weight ?? 0,
      plannedWeight: null,
      reps: previous?.reps ?? 0,
      targetMin: previous?.targetMin ?? 0,
      targetMax: previous?.targetMax ?? 0,
      restSeconds: previous?.restSeconds ?? exercise.restSeconds,
    );
    exercise.sets.add(extraSet);
    completeSet(extraSet, exercise);
  }

  void syncCompletedSetsFromSystem(int target) {
    // A lock-screen completion may intentionally exceed the originally
    // planned set count. Cap only pathological input, not the current plan.
    final safeTarget = target.clamp(0, completedSets + 20);
    while (completedSets < safeTarget) {
      final before = completedSets;
      completeNextSetFromSystem();
      if (completedSets == before) break;
    }
  }

  void completeSet(WorkoutSet set, WorkoutExercise parent) {
    if (!workoutStarted) return;
    if (!workoutTimerStarted) beginWorkoutTimer();
    set.completed = !set.completed;
    if (set.completed) {
      final started = _activeSetStartedAt;
      final currentSegment = started == null
          ? 0
          : DateTime.now().difference(started).inSeconds;
      final duration = _activeSetElapsedSeconds + currentSegment;
      if (duration > 0) {
        set.durationSeconds = duration.clamp(1, 3600);
      }
      _activeSetStartedAt = null;
      _activeSetElapsedSeconds = 0;
      triggerCompletionBurst(set.id);
      restRemainingSeconds = effectiveRestSeconds(set, parent);
      if (restRemainingSeconds > 0) {
        restSetupPending = false;
        pendingRestSetId = null;
        startRest(
          exercise: displayExerciseName(exerciseFor(parent.exerciseId)),
          seconds: restRemainingSeconds,
        );
      } else {
        restSetupPending = true;
        pendingRestSetId = set.id;
        restRemainingSeconds = 0;
        restRunning = false;
        restExerciseName = null;
        _restEndsAt = null;
        _restTicker?.cancel();
        PlatformTimerBridge.clearRest();
      }
    } else {
      if (pendingRestSetId == set.id) {
        restSetupPending = false;
        pendingRestSetId = null;
      }
      set.durationSeconds = null;
      _activeSetElapsedSeconds = 0;
      _activeSetStartedAt = workoutPaused ? null : DateTime.now();
      restRemainingSeconds = 0;
      restRunning = false;
      restExerciseName = null;
      _restEndsAt = null;
      _restTicker?.cancel();
      PlatformTimerBridge.clearRest();
    }
    persistActiveWorkout();
    _syncPlatformWorkoutState(parent);
    notifyListeners();
  }

  void startCurrentSetTimer() {
    if (!workoutStarted) return;
    if (!workoutTimerStarted) beginWorkoutTimer();
    _activeSetStartedAt = DateTime.now();
    _activeSetElapsedSeconds = 0;
    notifyListeners();
  }

  int get currentSetElapsedSeconds => _activeSetStartedAt == null
      ? 0
      : DateTime.now().difference(_activeSetStartedAt!).inSeconds;

  ParsedWorkoutNote parseNaturalWorkout(String text) =>
      NaturalWorkoutParser.parse(text, allExercises);

  void applyNaturalWorkout(ParsedWorkoutNote parsed) {
    if (parsed.exercises.isEmpty) return;
    if (!workoutStarted) startWorkout(name: '自由训练', autoStartTimer: false);
    workout.addAll(parsed.exercises.map((item) => item.copyForWorkout()));
    if (parsed.note.isNotEmpty) workoutNote = parsed.note;
    persistActiveWorkout();
    notifyListeners();
  }

  int effectiveRestSeconds(WorkoutSet set, WorkoutExercise parent) {
    if (set.restSeconds > 0) return set.restSeconds;
    if (parent.restSeconds > 0) return parent.restSeconds;
    return defaultRestSeconds;
  }

  void applyInitialRestSeconds(int seconds) {
    final value = seconds.clamp(0, 600).toInt();
    if (value <= 0) {
      dismissRestSetup();
      return;
    }
    defaultRestSeconds = value;
    WorkoutSet? pendingSet;
    WorkoutExercise? pendingExercise;
    for (final exercise in workout) {
      exercise.restSeconds = value;
      for (final set in exercise.sets) {
        if (!set.completed) set.restSeconds = value;
        if (set.id == pendingRestSetId) {
          pendingSet = set;
          pendingExercise = exercise;
        }
      }
    }
    restSetupPending = false;
    pendingRestSetId = null;
    persistActiveWorkout();
    if (pendingSet != null && pendingExercise != null && pendingSet.completed) {
      startRest(
        exercise: displayExerciseName(exerciseFor(pendingExercise.exerciseId)),
        seconds: value,
      );
    }
    notifyListeners();
  }

  void dismissRestSetup() {
    restSetupPending = false;
    pendingRestSetId = null;
    notifyListeners();
  }

  String _platformExerciseName([WorkoutExercise? preferred]) {
    final exercise = preferred ?? (workout.isEmpty ? null : workout.first);
    if (exercise == null) return '准备训练';
    return displayExerciseName(exerciseFor(exercise.exerciseId));
  }

  void _syncPlatformWorkoutState([WorkoutExercise? preferred]) {
    if (!workoutStarted || !workoutTimerStarted) return;
    PlatformTimerBridge.updateWorkoutState(
      exercise: _platformExerciseName(preferred),
      completedSets: completedSets,
      totalSets: totalSets,
    );
  }

  void triggerCompletionBurst([String? setId]) {
    completionBurstId++;
    completionBurstActive = true;
    completionBurstSetId = setId;
    _completionBurstTimer?.cancel();
    _completionBurstTimer = Timer(const Duration(milliseconds: 800), () {
      completionBurstActive = false;
      completionBurstSetId = null;
      notifyListeners();
    });
    notifyListeners();
  }

  void addRestSeconds([int seconds = 15]) {
    if (!restRunning) return;
    reconcileRestClock();
    restRemainingSeconds = (restRemainingSeconds + seconds)
        .clamp(0, 600)
        .toInt();
    if (!workoutPaused) {
      _restEndsAt = DateTime.now().add(Duration(seconds: restRemainingSeconds));
    }
    PlatformTimerBridge.update(
      exercise: restExerciseName ?? '休息计时',
      seconds: restRemainingSeconds,
      endsAt: _restEndsAt,
    );
    persistActiveWorkout();
    notifyListeners();
  }

  void startRest({required String exercise, required int seconds}) {
    if (seconds <= 0) {
      restRemainingSeconds = 0;
      restRunning = false;
      restExerciseName = null;
      _restEndsAt = null;
      _restTicker?.cancel();
      PlatformTimerBridge.clearRest();
      notifyListeners();
      return;
    }
    restRemainingSeconds = seconds;
    restRunning = true;
    restExerciseName = exercise;
    _restEndsAt = DateTime.now().add(Duration(seconds: seconds));
    PlatformTimerBridge.start(
      exercise: exercise,
      seconds: seconds,
      endsAt: _restEndsAt,
    );
    _scheduleRestTicker();
    persistActiveWorkout();
    notifyListeners();
  }

  int _secondsUntil(DateTime deadline, DateTime now) {
    final milliseconds = deadline.difference(now).inMilliseconds;
    if (milliseconds <= 0) return 0;
    return (milliseconds / 1000).ceil();
  }

  int _currentRestRemaining() {
    if (!restRunning || workoutPaused || _restEndsAt == null) {
      return restRemainingSeconds;
    }
    return _secondsUntil(_restEndsAt!, DateTime.now());
  }

  void _scheduleRestTicker() {
    _restTicker?.cancel();
    if (!restRunning || workoutPaused) return;
    _restTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      reconcileRestClock();
      notifyListeners();
    });
  }

  void _freezeRestClock() {
    if (!restRunning) return;
    reconcileRestClock();
    _restEndsAt = null;
    _restTicker?.cancel();
  }

  void _resumeRestClock() {
    if (!restRunning || restRemainingSeconds <= 0) return;
    _restEndsAt = DateTime.now().add(Duration(seconds: restRemainingSeconds));
    _scheduleRestTicker();
  }

  void _completeRestCountdown() {
    if (!restRunning) return;
    restRemainingSeconds = 0;
    restRunning = false;
    restExerciseName = null;
    _restEndsAt = null;
    _restTicker?.cancel();
    PlatformTimerBridge.completeRest();
    SystemSound.play(SystemSoundType.alert);
    HapticFeedback.heavyImpact();
    _activeSetStartedAt = DateTime.now();
    _activeSetElapsedSeconds = 0;
    persistActiveWorkout();
  }

  void updateExerciseRest(WorkoutExercise exercise, int seconds) {
    final value = seconds.clamp(0, 600).toInt();
    if (freeWorkout) {
      updateActiveAndUpcomingRest(value);
      return;
    }
    exercise.restSeconds = value;
    persistActiveWorkout();
    notifyListeners();
  }

  void updateSetNote(WorkoutSet set, String note) {
    set.note = note.trim();
    persistActiveWorkout();
    notifyListeners();
  }

  void updateExerciseNote(WorkoutExercise exercise, String note) {
    exercise.note = note.trim();
    persistActiveWorkout();
    notifyListeners();
  }

  void skipRest() {
    restRemainingSeconds = 0;
    restRunning = false;
    restExerciseName = null;
    _restEndsAt = null;
    _restTicker?.cancel();
    PlatformTimerBridge.clearRest();
    _activeSetStartedAt = workoutPaused ? null : DateTime.now();
    _activeSetElapsedSeconds = 0;
    persistActiveWorkout();
    notifyListeners();
  }

  /// Stops the current session without creating history or changing plans.
  /// The UI exposes this behind an explicit hold gesture so an accidental tap
  /// cannot destroy a complete in-progress workout.
  void abortWorkout() {
    if (!workoutStarted && !workoutDraft) return;
    workout.clear();
    workoutName = '自由训练';
    workoutNote = '';
    workoutStarted = false;
    workoutTimerStarted = false;
    workoutPaused = false;
    workoutDraft = false;
    workoutCompleted = false;
    liveWorkoutVisible = false;
    workoutElapsedSeconds = 0;
    workoutStartedAt = null;
    freeWorkout = false;
    defaultRestSeconds = 0;
    restSetupPending = false;
    pendingRestSetId = null;
    restRunning = false;
    restRemainingSeconds = 0;
    restExerciseName = null;
    _restEndsAt = null;
    _activeSetStartedAt = null;
    _activeSetElapsedSeconds = 0;
    selectedSetIds.clear();
    batchMode = false;
    trainView = TrainView.plans;
    _workoutTicker?.cancel();
    _restTicker?.cancel();
    PlatformTimerBridge.clearRest();
    PlatformTimerBridge.finish();
    persistActiveWorkout();
    notifyListeners();
  }

  WorkoutRecord? finishWorkout({
    String note = '',
    bool saveAsRoutine = false,
    String? routineName,
  }) {
    if (!workoutStarted && !workoutDraft) return null;
    final now = DateTime.now();
    final wasFreeWorkout = freeWorkout;
    final historySnapshot = workout.map((item) => item.copy()).toList();
    final prDetails = _calculateWorkoutPrs(historySnapshot);
    final prs = prDetails
        .map((detail) => displayExerciseName(exerciseFor(detail.exerciseId)))
        .toSet()
        .toList(growable: false);
    final record = WorkoutRecord(
      id: 'history-${now.microsecondsSinceEpoch}',
      name: workoutName,
      date: now,
      startTime:
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
      durationSeconds: currentElapsed,
      volume: workoutVolume,
      effectiveSets: workout
          .expand((item) => item.sets)
          .where((set) => set.completed && set.type != 'technique')
          .length,
      note: note,
      exerciseIds: workout.map((item) => item.exerciseId).toList(),
      prs: prs,
      prDetails: prDetails,
      exercises: historySnapshot,
    );
    history.insert(0, record);
    _persistWorkoutHistory();
    // A valid completed session grants one recognition credit. The service
    // tracks record IDs, so opening/saving the same summary cannot reward it
    // twice. Empty sessions do not count as valid training.
    if (record.effectiveSets > 0) {
      accountService.rewardWorkoutCompleted(record.id, valid: true);
    }
    if (wasFreeWorkout && saveAsRoutine && workout.isNotEmpty) {
      final baseName = routineName?.trim().isNotEmpty == true
          ? routineName!.trim()
          : _defaultFreeRoutineName(now);
      var finalName = baseName;
      var suffix = 2;
      while (routines.any((routine) => routine.name == finalName)) {
        finalName = '$baseName ($suffix)';
        suffix++;
      }
      final exercises = historySnapshot.map((item) {
        final planExercise = item.copyForPlan(
          newId: 'routine-${DateTime.now().microsecondsSinceEpoch}-${item.id}',
        );
        for (final set in planExercise.sets) {
          set.plannedWeight = set.weight;
          set.completed = false;
          set.failed = false;
        }
        return planExercise;
      }).toList();
      if (!routineFolders.contains('自定义')) routineFolders.add('自定义');
      routines.insert(
        0,
        Routine(
          id: 'routine-${DateTime.now().microsecondsSinceEpoch}',
          name: finalName,
          folder: '自定义',
          exercises: exercises,
          updatedAt: now,
        ),
      );
      _persistTrainingLibrary();
    }
    workoutStarted = false;
    workoutTimerStarted = false;
    workoutPaused = false;
    workoutDraft = false;
    workoutCompleted = true;
    liveWorkoutVisible = false;
    workoutElapsedSeconds = 0;
    workoutStartedAt = null;
    freeWorkout = false;
    restSetupPending = false;
    pendingRestSetId = null;
    restRunning = false;
    restRemainingSeconds = 0;
    restExerciseName = null;
    _restEndsAt = null;
    _workoutTicker?.cancel();
    _restTicker?.cancel();
    PlatformTimerBridge.finish();
    persistActiveWorkout();
    notifyListeners();
    return record;
  }

  List<WorkoutPrDetail> _calculateWorkoutPrs(
    List<WorkoutExercise> currentExercises,
  ) {
    final details = <WorkoutPrDetail>[];
    for (final exercise in currentExercises) {
      final current = exercise.sets
          .where((set) => set.completed && set.weight > 0 && set.reps > 0)
          .toList(growable: false);
      if (current.isEmpty) continue;

      final previousSessions = <(WorkoutRecord, List<WorkoutSet>)>[];
      for (final record in history) {
        final sets = record.exercises
            .where((item) => item.exerciseId == exercise.exerciseId)
            .expand((item) => item.sets)
            .where((set) => set.completed && set.weight > 0 && set.reps > 0)
            .toList(growable: false);
        if (sets.isNotEmpty) previousSessions.add((record, sets));
      }
      // A first entry is a baseline, not a fabricated personal record.
      if (previousSessions.isEmpty) continue;

      final currentWeight = current.fold<double>(
        0,
        (best, set) => set.weight > best ? set.weight : best,
      );
      final currentE1rm = current.fold<double>(0, (best, set) {
        final value = _estimatedOneRepMax(set);
        return value > best ? value : best;
      });
      final currentVolume = current.fold<double>(
        0,
        (sum, set) => sum + set.weight * set.reps,
      );

      void addIfRecord({
        required String metric,
        required double currentValue,
        required double Function(List<WorkoutSet>) previousValueFor,
      }) {
        WorkoutRecord? baseline;
        var previousValue = 0.0;
        for (final session in previousSessions) {
          final value = previousValueFor(session.$2);
          if (value > previousValue) {
            previousValue = value;
            baseline = session.$1;
          }
        }
        if (baseline == null || currentValue <= previousValue + .001) return;
        details.add(
          WorkoutPrDetail(
            exerciseId: exercise.exerciseId,
            metric: metric,
            currentValue: currentValue,
            previousValue: previousValue,
            previousRecordId: baseline.id,
            previousDate: baseline.date,
          ),
        );
      }

      addIfRecord(
        metric: 'estimated1rm',
        currentValue: currentE1rm,
        previousValueFor: (sets) => sets.fold<double>(0, (best, set) {
          final value = _estimatedOneRepMax(set);
          return value > best ? value : best;
        }),
      );
      addIfRecord(
        metric: 'weight',
        currentValue: currentWeight,
        previousValueFor: (sets) => sets.fold<double>(
          0,
          (best, set) => set.weight > best ? set.weight : best,
        ),
      );
      addIfRecord(
        metric: 'volume',
        currentValue: currentVolume,
        previousValueFor: (sets) =>
            sets.fold<double>(0, (sum, set) => sum + set.weight * set.reps),
      );
    }
    return details;
  }

  double _estimatedOneRepMax(WorkoutSet set) =>
      set.weight * (1 + set.reps / 30);

  String _defaultFreeRoutineName(DateTime date) =>
      '自由训练 ${date.month.toString().padLeft(2, '0')}月${date.day.toString().padLeft(2, '0')}日 ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

  void addSet(WorkoutExercise exercise) {
    final nextIndex = exercise.sets.length;
    exercise.sets.add(
      WorkoutSet(
        id: 'set-${exercise.id}-$nextIndex-${DateTime.now().microsecondsSinceEpoch}',
        type: 'work',
        weight: 0,
        plannedWeight: null,
        reps: 0,
        targetMin: 0,
        targetMax: 0,
        restSeconds: exercise.restSeconds,
      ),
    );
    _syncPlatformWorkoutState(exercise);
    persistActiveWorkout();
    notifyListeners();
  }

  bool removeSet(WorkoutExercise exercise, WorkoutSet set) {
    final removed = exercise.sets.remove(set);
    if (!removed) return false;
    selectedSetIds.remove(set.id);
    if (completionBurstSetId == set.id) {
      completionBurstActive = false;
      completionBurstSetId = null;
      _completionBurstTimer?.cancel();
    }
    _syncPlatformWorkoutState(exercise);
    persistActiveWorkout();
    notifyListeners();
    return true;
  }

  bool reusePreviousValues(WorkoutExercise exercise) {
    var reused = false;
    for (var index = 0; index < exercise.sets.length; index++) {
      final previous = previousSetFor(exercise.exerciseId, index);
      if (previous == null) continue;
      exercise.sets[index].weight = previous.weight;
      exercise.sets[index].reps = previous.reps;
      reused = true;
    }
    if (reused) notifyListeners();
    return reused;
  }

  bool hasPreviousValues(WorkoutExercise exercise) {
    for (var index = 0; index < exercise.sets.length; index++) {
      if (previousSetFor(exercise.exerciseId, index) != null) return true;
    }
    return false;
  }

  /// Changes the active rest countdown and uses the same value as the default
  /// for every upcoming exercise and unfinished set in this workout.
  void updateActiveAndUpcomingRest(int seconds) {
    final value = seconds.clamp(0, 600).toInt();
    defaultRestSeconds = value;
    for (final exercise in workout) {
      exercise.restSeconds = value;
      for (final set in exercise.sets) {
        if (!set.completed) set.restSeconds = value;
      }
    }
    if (restRunning) {
      final activeName = restExerciseName ?? '休息计时';
      startRest(exercise: activeName, seconds: value);
    }
    if (value > 0) {
      restSetupPending = false;
      pendingRestSetId = null;
    }
    persistActiveWorkout();
    notifyListeners();
  }

  void clearExerciseValues(WorkoutExercise exercise) {
    for (final set in exercise.sets) {
      set.weight = 0;
      set.reps = 0;
      if (freeWorkout) set.plannedWeight = null;
    }
    notifyListeners();
  }

  void toggleBatchMode() {
    batchMode = !batchMode;
    if (!batchMode) selectedSetIds.clear();
    notifyListeners();
  }

  void toggleSetSelection(WorkoutSet set) {
    if (set.completed) return;
    if (!selectedSetIds.add(set.id)) selectedSetIds.remove(set.id);
    notifyListeners();
  }

  void batchUpdate({String? type, double? weight, int? reps}) {
    for (final item in workout.expand((item) => item.sets)) {
      if (!selectedSetIds.contains(item.id) || item.completed) continue;
      if (type != null) item.type = type;
      if (weight != null) item.weight = weight;
      if (reps != null) item.reps = reps;
    }
    selectedSetIds.clear();
    batchMode = false;
    notifyListeners();
  }

  void toggleSuperset(WorkoutExercise exercise) {
    final current = exercise.supersetId;
    exercise.supersetId = current == null
        ? 'superset-${DateTime.now().microsecondsSinceEpoch}'
        : null;
    notifyListeners();
  }

  void moveExercise(WorkoutExercise exercise, int direction) {
    final index = workout.indexOf(exercise);
    final target = index + direction;
    if (index < 0 || target < 0 || target >= workout.length) return;
    final item = workout.removeAt(index);
    workout.insert(target, item);
    notifyListeners();
  }

  void addExercise(String id) {
    if (workout.any((item) => item.exerciseId == id)) return;
    final inheritedRestSeconds = _restSecondsForNewExercise();
    final item = freeWorkout
        ? WorkoutExercise(
            id: 'we-${DateTime.now().microsecondsSinceEpoch}',
            exerciseId: id,
            sets: <WorkoutSet>[],
            restSeconds: inheritedRestSeconds,
          )
        : createBlankWorkoutExercise(
            id,
            'we-${DateTime.now().microsecondsSinceEpoch}',
          );
    item.restSeconds = inheritedRestSeconds;
    for (final set in item.sets) {
      set.restSeconds = inheritedRestSeconds;
    }
    workout.add(item);
    workoutDraft = true;
    _syncPlatformWorkoutState(item);
    persistActiveWorkout();
    notifyListeners();
  }

  Exercise addCustomExercise({
    required String name,
    required String englishName,
    required String equipment,
    required String muscle,
    required String cue,
  }) {
    final id = 'custom-${DateTime.now().microsecondsSinceEpoch}';
    final exercise = Exercise(
      id: id,
      name: name,
      englishName: englishName.isEmpty ? name : englishName,
      family: '自定义',
      muscle: muscle.isEmpty ? '未分类' : muscle,
      secondary: '无',
      equipment: equipment.isEmpty ? '自定义器械' : equipment,
      camera: '待设置',
      cue: cue.isEmpty ? '根据你的动作目标设置提示' : cue,
    );
    customExercises.add(exercise);
    _persistCustomExercises();
    notifyListeners();
    return exercise;
  }

  void saveResource({
    required String exerciseId,
    required String scope,
    required String note,
    required String link,
  }) {
    exerciseResources.putIfAbsent(exerciseId, () => {});
    exerciseResources[exerciseId]![scope] = ExerciseResource(
      note: note,
      link: link,
    );
    notifyListeners();
  }

  ExerciseResource resourceFor(String exerciseId, String scope) =>
      exerciseResources[exerciseId]?[scope] ??
      const ExerciseResource(note: '', link: '');

  void deleteRecord(WorkoutRecord record) {
    history.remove(record);
    _persistWorkoutHistory();
    notifyListeners();
  }

  void updateRecordNote(WorkoutRecord record, String note) {
    final index = history.indexOf(record);
    if (index < 0) return;
    history[index] = WorkoutRecord(
      id: record.id,
      name: record.name,
      date: record.date,
      startTime: record.startTime,
      durationSeconds: record.durationSeconds,
      volume: record.volume,
      effectiveSets: record.effectiveSets,
      note: note,
      exerciseIds: record.exerciseIds,
      prs: record.prs,
      prDetails: record.prDetails,
      exercises: record.exercises.map((item) => item.copy()).toList(),
    );
    _persistWorkoutHistory();
    notifyListeners();
  }

  void replaceExercise(String oldId, String nextId) {
    final target = workout.firstWhere((item) => item.id == oldId);
    target.exerciseId = nextId;
    notifyListeners();
  }

  void removeExercise(WorkoutExercise exercise) {
    workout.remove(exercise);
    persistActiveWorkout();
    notifyListeners();
  }

  void saveRoutine(String name, String folder) {
    if (!routineFolders.contains(folder)) routineFolders.add(folder);
    routines.insert(
      0,
      Routine(
        id: 'routine-${DateTime.now().microsecondsSinceEpoch}',
        name: name,
        folder: folder,
        exercises: workout
            .map((item) => item.copyForPlan(newId: 'routine-${item.id}'))
            .toList(),
        updatedAt: DateTime.now(),
      ),
    );
    _persistTrainingLibrary();
    notifyListeners();
  }

  /// Persists a draft composer in one transaction. The draft itself remains
  /// outside [routines] until this method is called, so cancelling a composer
  /// cannot leave an empty routine behind.
  void saveRoutineFromDraft(
    String name,
    List<WorkoutExercise> exercises, {
    String folder = '自定义',
  }) {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty || exercises.isEmpty) return;
    if (!routineFolders.contains(folder)) routineFolders.add(folder);
    routines.insert(
      0,
      Routine(
        id: 'routine-${DateTime.now().microsecondsSinceEpoch}',
        name: trimmedName,
        folder: folder,
        exercises: exercises
            .map((item) => item.copyForPlan(newId: 'routine-${item.id}'))
            .toList(),
        updatedAt: DateTime.now(),
      ),
    );
    _persistTrainingLibrary();
    notifyListeners();
  }

  /// Commits a full-page editor draft only after the user taps save. The
  /// original routine is never mutated while the draft route is open.
  void updateRoutineFromDraft(Routine original, Routine draft) {
    final index = routines.indexOf(original);
    if (index < 0) return;
    final target = routines[index];
    target.name = draft.name.trim().isEmpty ? target.name : draft.name.trim();
    target.folder = draft.folder;
    target.exercises = draft.exercises
        .map((item) => item.copyForPlan(newId: 'routine-${item.id}'))
        .toList();
    target.updatedAt = DateTime.now();
    _persistTrainingLibrary();
    notifyListeners();
  }

  /// Updates the prescribed weight in a plan and keeps its initial live
  /// workout value in sync. Live workout edits only touch [WorkoutSet.weight].
  void updatePlannedWeight(WorkoutSet set, double value) {
    set.plannedWeight = value;
    set.weight = value;
    notifyListeners();
  }

  void saveRoutineFromExerciseIds(String name, List<String> exerciseIds) {
    routines.insert(
      0,
      Routine(
        id: 'routine-${DateTime.now().microsecondsSinceEpoch}',
        name: name,
        folder: '官方计划',
        exercises: [
          for (var index = 0; index < exerciseIds.length; index++)
            _makeWorkout(
              exerciseIds[index],
              'official-$index-${exerciseIds[index]}',
            ),
        ],
        updatedAt: DateTime.now(),
      ),
    );
    _persistTrainingLibrary();
    notifyListeners();
  }

  void renameRoutine(Routine routine, String name) {
    routine.name = name.trim().isEmpty ? routine.name : name.trim();
    routine.updatedAt = DateTime.now();
    _persistTrainingLibrary();
    notifyListeners();
  }

  void deleteRoutine(Routine routine) {
    routines.remove(routine);
    _persistTrainingLibrary();
    notifyListeners();
  }

  void startRoutine(Routine routine) {
    startWorkout(source: routine.exercises, name: routine.name);
    openLiveWorkout();
  }

  void moveRoutine(Routine routine, String folder) {
    if (!routineFolders.contains(folder)) routineFolders.add(folder);
    routine.folder = folder;
    routine.updatedAt = DateTime.now();
    _persistTrainingLibrary();
    notifyListeners();
  }

  void addRoutineFolder(String folder) {
    final value = folder.trim();
    if (value.isEmpty || routineFolders.contains(value)) return;
    routineFolders.add(value);
    _persistTrainingLibrary();
    notifyListeners();
  }

  void schedule(DateTime date, String label) {
    final value =
        '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    if (!scheduled.contains(value)) scheduled.add(value);
    scheduledLabels[value] = label;
    _persistTrainingLibrary();
    notifyListeners();
  }

  void reschedule(String date, String label) {
    if (!scheduled.contains(date)) scheduled.add(date);
    scheduledLabels[date] = label;
    _persistTrainingLibrary();
    notifyListeners();
  }

  void unschedule(String date) {
    scheduled.remove(date);
    scheduledLabels.remove(date);
    _persistTrainingLibrary();
    notifyListeners();
  }

  void newConversation() {
    _saveActiveConversation();
    final id = 'conversation-${DateTime.now().microsecondsSinceEpoch}';
    activeConversationId = id;
    chat
      ..clear()
      ..add(
        ChatMessage(
          id: 'welcome-$id',
          role: 'assistant',
          body: '新的对话已开始。你想了解哪个训练问题？',
        ),
      );
    conversations.add(
      AiConversation(
        id: id,
        title: '新对话',
        messages: List<ChatMessage>.from(chat),
      ),
    );
    _persistAiConversations();
    notifyListeners();
  }

  void selectConversation(String id) {
    if (id == activeConversationId) return;
    _saveActiveConversation();
    final selected = conversations.firstWhere((item) => item.id == id);
    activeConversationId = id;
    chat
      ..clear()
      ..addAll(selected.messages);
    _persistAiConversations();
    notifyListeners();
  }

  void deleteConversation(String id) {
    if (conversations.length <= 1) {
      newConversation();
      return;
    }
    conversations.removeWhere((item) => item.id == id);
    if (id == activeConversationId) {
      final selected = conversations.first;
      activeConversationId = selected.id;
      chat
        ..clear()
        ..addAll(selected.messages);
    }
    _persistAiConversations();
    notifyListeners();
  }

  void _saveActiveConversation() {
    AiConversation? current;
    for (final item in conversations) {
      if (item.id == activeConversationId) {
        current = item;
        break;
      }
    }
    if (current == null) {
      current = AiConversation(
        id: activeConversationId,
        title: '新对话',
        messages: const [],
      );
      conversations.add(current);
    }
    current.messages = List<ChatMessage>.from(chat);
    if (chat.isEmpty) {
      current.title = '新对话';
      _persistAiConversations();
      return;
    }
    final latestUser = chat.lastWhere(
      (item) => item.role == 'user',
      orElse: () => chat.first,
    );
    if (latestUser.role == 'user') {
      current.title = latestUser.body.length > 16
          ? '${latestUser.body.substring(0, 16)}…'
          : latestUser.body;
    }
    _persistAiConversations();
  }

  AiConversation? _currentAiConversation() {
    for (final conversation in conversations) {
      if (conversation.id == activeConversationId) return conversation;
    }
    return null;
  }

  Future<void> pickVideo() async {
    mediaPicking = true;
    mediaError = null;
    notifyListeners();
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: false,
        withData: false,
      );
      if (result == null || result.files.isEmpty) {
        mediaError = '已取消选择视频。';
        recognitionStatus = RecognitionStatus.idle;
      } else {
        final file = result.files.single;
        final extension = (file.extension ?? '').toLowerCase();
        if (!['mp4', 'mov', 'm4v', 'webm'].contains(extension)) {
          mediaError = '仅支持 MP4、MOV、M4V 或 WebM 视频。';
          recognitionStatus = RecognitionStatus.idle;
        } else {
          selectedMediaPath = file.path;
          selectedMediaName = file.name;
          selectedMediaBytes = file.size;
          _invalidateRecognitionAnalysis();
        }
      }
    } catch (_) {
      mediaError = '文件选择失败，请重试。';
      recognitionStatus = RecognitionStatus.idle;
    } finally {
      mediaPicking = false;
      notifyListeners();
    }
  }

  void useEditedRecognitionVideo(String path) {
    final file = File(path);
    if (!file.existsSync()) {
      mediaError = '裁剪后的视频不存在，请重新编辑。';
      notifyListeners();
      return;
    }
    selectedMediaPath = path;
    selectedMediaName = '已裁剪_${path.split(RegExp(r'[/\\]')).last}';
    selectedMediaBytes = file.lengthSync();
    _invalidateRecognitionAnalysis();
    notifyListeners();
  }

  void startRecognition() {
    if (recognitionStatus != RecognitionStatus.ready &&
        recognitionStatus != RecognitionStatus.error) {
      return;
    }
    if (selectedMediaPath == null || selectedMediaPath!.isEmpty) return;
    _recognitionReservation?.rollback();
    _recognitionReservation = null;
    recognitionStatus = RecognitionStatus.processing;
    recognitionStage = RecognitionStage.preparing;
    recognitionProgress = 0;
    recognitionElapsedSeconds = 0;
    recognitionResult = null;
    mediaError = null;
    _recognitionTicker?.cancel();
    _recognitionTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      recognitionElapsedSeconds += 1;
      if (!_disposed) notifyListeners();
    });
    notifyListeners();
    unawaited(_submitRecognition());
  }

  void setRecognitionIncludeOverlay(bool value) {
    if (recognitionStatus == RecognitionStatus.processing) return;
    if (recognitionIncludeOverlay == value) return;
    recognitionIncludeOverlay = value;
    _invalidateRecognitionAnalysis();
    notifyListeners();
  }

  void _invalidateRecognitionAnalysis() {
    _recognitionReservation?.rollback();
    _recognitionReservation = null;
    _recognitionTicker?.cancel();
    recognitionStatus = selectedMediaPath == null
        ? RecognitionStatus.idle
        : RecognitionStatus.ready;
    recognitionStage = RecognitionStage.idle;
    recognitionProgress = 0;
    recognitionElapsedSeconds = 0;
    recognitionResult = null;
    savedCue = false;
    analysisAttached = false;
    mediaError = null;
  }

  void _updateRecognitionProgress(RecognitionProgressUpdate update) {
    if (_disposed || recognitionStatus != RecognitionStatus.processing) return;
    recognitionStage = update.stage;
    if (update.fraction != null) {
      recognitionProgress = update.fraction!.clamp(0, 1);
    }
    notifyListeners();
  }

  Future<void> _submitRecognition() async {
    try {
      final api = await _activeRecognitionApi();
      if (!isAuthenticated) {
        throw const RecognitionApiException('recognition_unauthenticated');
      }
      _recognitionReservation = accountService.reserveRecognition();
      if (_recognitionReservation == null) {
        recognitionStatus = RecognitionStatus.error;
        recognitionResult = RecognitionResult(
          status: RecognitionStatus.error,
          confidence: 0,
          repetitions: 0,
          summary: _recognitionQuotaExhaustedMessage(),
          error: 'quota_exhausted',
        );
        _recognitionTicker?.cancel();
        notifyListeners();
        return;
      }
      final mediaPath = selectedMediaPath;
      if (mediaPath == null || mediaPath.isEmpty) {
        throw const RecognitionApiException('recognition_file_missing');
      }
      final uploadPath = await _prepareRecognitionUpload(mediaPath);
      final result = await api.analyze(
        exerciseId: recognitionExerciseId,
        camera: recognitionCamera,
        scenario: scenario,
        mediaPath: uploadPath,
        includeOverlay: recognitionIncludeOverlay,
        onProgress: _updateRecognitionProgress,
      );
      final succeeded =
          result.error == null &&
          result.status != RecognitionStatus.error &&
          result.status != RecognitionStatus.offline;
      if (succeeded) {
        _recognitionReservation?.commit();
      } else {
        _recognitionReservation?.rollback();
      }
      _recognitionReservation = null;
      recognitionResult = result;
      recognitionStatus = result.status;
    } on RecognitionApiException catch (error) {
      _recognitionReservation?.rollback();
      _recognitionReservation = null;
      recognitionStatus = RecognitionStatus.error;
      recognitionResult = RecognitionResult(
        status: RecognitionStatus.error,
        confidence: 0,
        repetitions: 0,
        summary: error.code == 'quota_exhausted'
            ? _recognitionQuotaExhaustedMessage()
            : recognitionErrorMessage(error.code),
        error: error.code,
      );
    } catch (error) {
      _recognitionReservation?.rollback();
      _recognitionReservation = null;
      recognitionStatus = RecognitionStatus.error;
      recognitionResult = RecognitionResult(
        status: RecognitionStatus.error,
        confidence: 0,
        repetitions: 0,
        summary: recognitionErrorMessage('unexpected_error'),
        error: 'unexpected_error',
      );
    }
    _recognitionTicker?.cancel();
    notifyListeners();
  }

  Future<String> _prepareRecognitionUpload(String sourcePath) async {
    final source = File(sourcePath);
    if (!source.existsSync() ||
        source.lengthSync() < 25 * 1024 * 1024 ||
        !(Platform.isAndroid || Platform.isIOS)) {
      return sourcePath;
    }
    recognitionStage = RecognitionStage.preparing;
    recognitionProgress = .03;
    notifyListeners();
    try {
      final compressed = await VideoCompress.compressVideo(
        sourcePath,
        quality: VideoQuality.MediumQuality,
        deleteOrigin: false,
        includeAudio: true,
      );
      final output = compressed?.file;
      if (output != null && output.existsSync() && output.lengthSync() > 0) {
        return output.path;
      }
    } catch (_) {
      // Fall back to the selected source; the backend still performs its
      // normal size/type validation and returns a specific error if needed.
    }
    return sourcePath;
  }

  String _recognitionQuotaExhaustedMessage() => entitlements?.isMember == true
      ? '本周动作识别次数已用完，请等待下周补充或完成一次有效训练。'
      : '免费动作识别次数已用完，请开通会员后继续使用。';

  String _aiQuotaExhaustedMessage() => entitlements?.isMember == true
      ? '今日 AI 次数已用完，请明天再试。'
      : '免费 AI 次数已用完，请开通会员后继续使用。';

  void addExercises(Iterable<String> ids) {
    WorkoutExercise? latest;
    for (final id in ids) {
      if (workout.any((item) => item.exerciseId == id)) continue;
      final inheritedRestSeconds = _restSecondsForNewExercise();
      final stamp = DateTime.now().microsecondsSinceEpoch;
      latest = freeWorkout
          ? WorkoutExercise(
              id: 'we-$stamp-$id',
              exerciseId: id,
              sets: <WorkoutSet>[],
              restSeconds: inheritedRestSeconds,
            )
          : createBlankWorkoutExercise(id, 'we-$stamp-$id');
      latest.restSeconds = inheritedRestSeconds;
      for (final set in latest.sets) {
        set.restSeconds = inheritedRestSeconds;
      }
      workout.add(latest);
    }
    workoutDraft = true;
    _syncPlatformWorkoutState(latest);
    persistActiveWorkout();
    notifyListeners();
  }

  // A new free-training action is deliberately unset until the user chooses
  // the session rest once. The selected value is copied into
  // [defaultRestSeconds] by the rest editor, so inheriting from an existing
  // card would re-introduce an implicit/default rest for newly added actions.
  int _restSecondsForNewExercise() => defaultRestSeconds;

  void resetRecognition() {
    _recognitionReservation?.rollback();
    _recognitionReservation = null;
    recognitionStatus = RecognitionStatus.idle;
    recognitionStage = RecognitionStage.idle;
    recognitionProgress = 0;
    recognitionElapsedSeconds = 0;
    _recognitionTicker?.cancel();
    analysisAttached = false;
    recognitionResult = null;
    selectedMediaPath = null;
    selectedMediaName = null;
    selectedMediaBytes = null;
    mediaError = null;
    notifyListeners();
  }

  void saveRecognitionCue() {
    savedCue = true;
    notifyListeners();
  }

  void approveAiData(bool value) {
    aiUseTrainingData = value;
    aiConsentSeen = true;
    notifyListeners();
  }

  Future<RecognitionApi> _activeRecognitionApi() async {
    final injected = recognitionApi;
    if (injected != null) return injected;

    final baseUrl = aiBaseUrl.trim();
    if (baseUrl.isEmpty) {
      throw const RecognitionApiException('recognition_base_url_missing');
    }
    if (_defaultRecognitionApi == null ||
        _defaultRecognitionApiBaseUrl != baseUrl) {
      _defaultRecognitionApi = HttpRecognitionApi(
        baseUrl: baseUrl,
        onSessionInvalidated: _handleRemoteSessionInvalidated,
      );
      _defaultRecognitionApiBaseUrl = baseUrl;
    }
    final api = _defaultRecognitionApi!;
    if (!api.hasSession) {
      final restored = await _restoreRecognitionSession(api);
      if (restored) return api;
      final identifier = _remoteIdentifier ?? currentUser?.identifier;
      final password =
          _remotePassword ??
          ((identifier == '123' || identifier == '1234') ? identifier : null);
      if (identifier == null || identifier.isEmpty || password == null) {
        _handleRemoteSessionInvalidated();
        throw const RecognitionApiException('recognition_session_expired');
      }
      await api.signIn(identifier: identifier, password: password);
    }
    return api;
  }

  Future<CoachApi> _activeCoachApi() async {
    final injected = coachApi;
    if (injected != null) return injected;

    final baseUrl = aiBaseUrl.trim();
    if (baseUrl.isEmpty) {
      throw const CoachApiException('coach_base_url_missing');
    }
    if (_defaultCoachApi == null || _defaultCoachApiBaseUrl != baseUrl) {
      _defaultCoachApi = HttpCoachApi(
        baseUrl: baseUrl,
        onSessionInvalidated: _handleRemoteSessionInvalidated,
      );
      _defaultCoachApiBaseUrl = baseUrl;
    }
    final api = _defaultCoachApi!;
    if (!api.hasSession) {
      final restored = await _restoreCoachSession(api);
      if (restored) return api;
      final identifier = _remoteIdentifier ?? currentUser?.identifier;
      final password =
          _remotePassword ??
          ((identifier == '123' || identifier == '1234') ? identifier : null);
      if (identifier == null || identifier.isEmpty || password == null) {
        _handleRemoteSessionInvalidated();
        throw const CoachApiException('coach_session_expired');
      }
      await api.signIn(identifier: identifier, password: password);
    }
    return api;
  }

  Future<void> restoreRemoteSession() async {
    final user = currentUser;
    if (user == null || user.identifier.trim().isEmpty) return;
    final session = await _readStoredRemoteSession();
    if (session == null ||
        !session.matches(
          accountIdentifier: user.identifier,
          apiOrigin: aiBaseUrl,
        )) {
      if (session != null) await _clearStoredRemoteSession();
      return;
    }
    final coach = coachApi;
    if (coach is HttpCoachApi) {
      coach.restoreSession(session, accountIdentifier: user.identifier);
    } else if (coach == null) {
      final api = _defaultCoachApi ??= HttpCoachApi(
        baseUrl: aiBaseUrl,
        onSessionInvalidated: _handleRemoteSessionInvalidated,
      );
      _defaultCoachApiBaseUrl = aiBaseUrl;
      api.restoreSession(session, accountIdentifier: user.identifier);
    }
    final recognition = recognitionApi;
    if (recognition is HttpRecognitionApi) {
      recognition.restoreSession(session, accountIdentifier: user.identifier);
    } else if (recognition == null) {
      final api = _defaultRecognitionApi ??= HttpRecognitionApi(
        baseUrl: aiBaseUrl,
        onSessionInvalidated: _handleRemoteSessionInvalidated,
      );
      _defaultRecognitionApiBaseUrl = aiBaseUrl;
      api.restoreSession(session, accountIdentifier: user.identifier);
    }
    _remoteIdentifier = user.identifier;
    notifyListeners();
  }

  Future<bool> _restoreCoachSession(HttpCoachApi api) async {
    final user = currentUser;
    final session = await _readStoredRemoteSession();
    if (user == null || session == null) return false;
    if (!api.restoreSession(session, accountIdentifier: user.identifier)) {
      await _clearStoredRemoteSession();
      return false;
    }
    _remoteIdentifier = user.identifier;
    return true;
  }

  Future<bool> _restoreRecognitionSession(HttpRecognitionApi api) async {
    final user = currentUser;
    final session = await _readStoredRemoteSession();
    if (user == null || session == null) return false;
    if (!api.restoreSession(session, accountIdentifier: user.identifier)) {
      await _clearStoredRemoteSession();
      return false;
    }
    _remoteIdentifier = user.identifier;
    return true;
  }

  Future<RemoteSession?> _readStoredRemoteSession() async {
    if (!_secureSessionLoaded) {
      _storedRemoteSession = await secureSessionStore.read();
      _secureSessionLoaded = true;
    }
    final session = _storedRemoteSession;
    if (session?.isExpired() == true) {
      await _clearStoredRemoteSession();
      return null;
    }
    return session;
  }

  Future<void> _clearStoredRemoteSession() async {
    _storedRemoteSession = null;
    _secureSessionLoaded = true;
    await secureSessionStore.clear();
  }

  void _handleRemoteSessionInvalidated() {
    _storedRemoteSession = null;
    _secureSessionLoaded = true;
    _remotePassword = null;
    _sessionExpiredMessage = '登录已过期，请重新登录。';
    unawaited(secureSessionStore.clear());
    _defaultCoachApi?.clearSession();
    _defaultRecognitionApi?.clearSession();
    accountService.logout();
    notifyListeners();
  }

  String _buildAiTrainingSummary() {
    final lines = <String>[];
    final profile = trainingProfile;
    final profileParts = <String>[
      if (profile.gender != null)
        '性别 ${profile.gender == 'male'
            ? '男'
            : profile.gender == 'female'
            ? '女'
            : '其他'}',
      if (profile.age != null) '年龄 ${profile.age}',
      if (profile.trainingYears != null)
        '训练 ${profile.trainingYears!.toStringAsFixed(1)} 年',
      if (profile.goal != null) '目标 ${profile.goal}',
      if (profile.heightCm != null) '身高 ${profile.heightCm} cm',
      if (profile.weightKg != null) '体重 ${profile.weightKg} kg',
    ];
    if (profileParts.isNotEmpty) lines.add('用户训练资料：${profileParts.join('，')}。');
    final todayNutrition = nutritionForDay(DateTime.now());
    if (todayNutrition.isNotEmpty) {
      lines.add(
        '今日饮食：${todayCalories.toStringAsFixed(0)} kcal，'
        '蛋白质 ${todayProtein.toStringAsFixed(1)} g；'
        '${todayNutrition.take(12).map((item) => '${item.mealType} ${item.foodName} ${item.amount} ${item.calories.toStringAsFixed(0)} kcal').join('；')}。',
      );
    }
    if (workoutStarted || workoutDraft) {
      lines.add(
        '当前训练「$workoutName」：训练时长 ${currentElapsed ~/ 60} 分钟，'
        '已完成 $completedSets/$totalSets 组，当前训练量 ${workoutVolume.toStringAsFixed(1)} kg。',
      );
      for (final exercise in workout.take(12)) {
        final sets = exercise.sets
            .take(12)
            .map((set) {
              final status = set.completed ? '已完成' : '未完成';
              return '$status ${set.weight.toStringAsFixed(1)} kg × ${set.reps}'
                  '${set.note.trim().isEmpty ? '' : '，备注：${set.note.trim()}'}';
            })
            .join('；');
        if (sets.isNotEmpty) {
          lines.add(
            '${exerciseFor(exercise.exerciseId).name}'
            '${exercise.note.trim().isEmpty ? '' : '，动作备注：${exercise.note.trim()}'}：$sets',
          );
        }
      }
    }
    if (history.isEmpty && lines.isEmpty) return '用户尚无训练或饮食记录。';
    if (history.isNotEmpty) lines.add('最近已完成训练：');
    for (final record in history.take(5)) {
      lines.add(
        '${record.date.toIso8601String().split('T').first} ${record.name}：'
        '${record.durationSeconds ~/ 60} 分钟，训练量 ${record.volume.toStringAsFixed(1)} kg，'
        '有效组 ${record.effectiveSets}。',
      );
      for (final exercise in record.exercises.take(8)) {
        final completed = exercise.sets.where((set) => set.completed).take(8);
        if (completed.isEmpty) continue;
        final sets = completed
            .map(
              (set) =>
                  '${set.weight.toStringAsFixed(1)} kg × ${set.reps}'
                  '${set.note.trim().isEmpty ? '' : '，备注：${set.note.trim()}'}',
            )
            .join('；');
        lines.add(
          '${exerciseFor(exercise.exerciseId).name}'
          '${exercise.note.trim().isEmpty ? '' : '，动作备注：${exercise.note.trim()}'}：$sets',
        );
      }
    }
    return lines.join('\n');
  }

  List<AiContextSelection> get availableAiContexts {
    final now = DateTime.now();
    return [
      if (workoutStarted || workoutDraft)
        AiContextSelection(
          type: AiContextType.activeWorkout,
          id: 'active',
          label: '当前训练',
        ),
      for (final record in history.take(30))
        AiContextSelection(
          type: AiContextType.workoutRecord,
          id: record.id,
          label: '${record.date.month}/${record.date.day} ${record.name}',
        ),
      for (final routine in routines.take(30))
        AiContextSelection(
          type: AiContextType.routine,
          id: routine.id,
          label: '计划 · ${routine.name}',
        ),
      AiContextSelection(
        type: AiContextType.week,
        id: '${now.year}-w${_weekNumber(now)}',
        label: '本周训练汇总',
      ),
      AiContextSelection(
        type: AiContextType.month,
        id: '${now.year}-${now.month}',
        label: '本月训练汇总',
      ),
    ];
  }

  /// The only tools exposed to the model. They are read-only and run against
  /// this device's in-memory state; no server can call Dart or mutate a plan.
  List<Map<String, dynamic>> get aiAvailableTools => const [
    {
      'type': 'function',
      'function': {
        'name': 'read_training_plans',
        'description': '读取当前用户保存的训练计划及动作组数据',
        'parameters': {
          'type': 'object',
          'properties': {
            'query': {'type': 'string'},
            'limit': {'type': 'integer', 'minimum': 1, 'maximum': 10},
          },
          'additionalProperties': false,
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'read_workout_history',
        'description': '读取当前用户的已完成训练及每组数据',
        'parameters': {
          'type': 'object',
          'properties': {
            'startDate': {
              'type': 'string',
              'description': 'YYYY-MM-DD；相对日期必须换算为设备当前日期对应的绝对日期',
            },
            'endDate': {
              'type': 'string',
              'description': 'YYYY-MM-DD；单日查询与 startDate 相同',
            },
            'query': {'type': 'string'},
            'limit': {'type': 'integer', 'minimum': 1, 'maximum': 20},
          },
          'additionalProperties': false,
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'read_active_workout',
        'description': '读取当前正在进行的训练',
        'parameters': {
          'type': 'object',
          'properties': {},
          'additionalProperties': false,
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'read_nutrition_history',
        'description': '读取当前用户的饮食、热量和三大营养素记录',
        'parameters': {
          'type': 'object',
          'properties': {
            'startDate': {'type': 'string'},
            'endDate': {'type': 'string'},
            'limit': {'type': 'integer', 'minimum': 1, 'maximum': 50},
          },
          'additionalProperties': false,
        },
      },
    },
  ];

  Map<String, dynamic> executeAiTool(CoachToolCall call) {
    final args = call.arguments;
    if (call.name == 'read_training_plans') {
      final query = (args['query'] ?? '').toString().trim().toLowerCase();
      final limit = (((args['limit'] as num?)?.toInt() ?? 10).clamp(
        1,
        10,
      )).toInt();
      final selected = routines
          .where((routine) {
            if (query.isEmpty) return true;
            return routine.name.toLowerCase().contains(query) ||
                routine.exercises.any(
                  (exercise) => displayExerciseName(
                    exerciseFor(exercise.exerciseId),
                  ).toLowerCase().contains(query),
                );
          })
          .take(limit)
          .map(_aiRoutinePayload)
          .toList();
      return {'tool': call.name, 'plans': selected, 'count': selected.length};
    }
    if (call.name == 'read_workout_history') {
      final query = (args['query'] ?? '').toString().trim().toLowerCase();
      final start = _aiDate(args['startDate']);
      final end = _aiDate(args['endDate']);
      final limit = (((args['limit'] as num?)?.toInt() ?? 20).clamp(
        1,
        20,
      )).toInt();
      final selected = history
          .where((record) {
            final day = DateTime(
              record.date.year,
              record.date.month,
              record.date.day,
            );
            if (start != null && day.isBefore(start)) return false;
            if (end != null && day.isAfter(end)) return false;
            if (query.isEmpty) return true;
            return record.name.toLowerCase().contains(query) ||
                record.exercises.any(
                  (exercise) => displayExerciseName(
                    exerciseFor(exercise.exerciseId),
                  ).toLowerCase().contains(query),
                );
          })
          .take(limit)
          .map(_aiRecordPayload)
          .toList();
      return {'tool': call.name, 'records': selected, 'count': selected.length};
    }
    if (call.name == 'read_active_workout') {
      if (!workoutStarted && !workoutDraft) {
        return {'tool': call.name, 'active': false, 'message': '当前没有正在进行的训练。'};
      }
      return {
        'tool': call.name,
        'active': true,
        'name': workoutName,
        'timerStarted': workoutTimerStarted,
        'paused': workoutPaused,
        'elapsedSeconds': currentElapsed,
        'completedSets': completedSets,
        'totalSets': totalSets,
        'exercises': workout.take(12).map(_aiWorkoutExercisePayload).toList(),
      };
    }
    if (call.name == 'read_nutrition_history') {
      final start = _aiDate(args['startDate']);
      final end = _aiDate(args['endDate']);
      final limit = (((args['limit'] as num?)?.toInt() ?? 30).clamp(
        1,
        50,
      )).toInt();
      final selected = nutritionEntries
          .where((entry) {
            final day = DateTime(
              entry.recordedAt.year,
              entry.recordedAt.month,
              entry.recordedAt.day,
            );
            if (start != null && day.isBefore(start)) return false;
            if (end != null && day.isAfter(end)) return false;
            return true;
          })
          .take(limit)
          .map((entry) => entry.toJson())
          .toList();
      return {'tool': call.name, 'entries': selected, 'count': selected.length};
    }
    throw ArgumentError('unsupported_ai_tool');
  }

  DateTime? _aiDate(Object? value) {
    if (value is! String || value.isEmpty) return null;
    final normalized = value.trim().toLowerCase();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (const {'today', '今天', '今日'}.contains(normalized)) return today;
    if (const {'yesterday', '昨天', '昨日'}.contains(normalized)) {
      return today.subtract(const Duration(days: 1));
    }
    if (const {'tomorrow', '明天', '明日'}.contains(normalized)) {
      return today.add(const Duration(days: 1));
    }
    final parsed = DateTime.tryParse(normalized);
    return parsed == null
        ? null
        : DateTime(parsed.year, parsed.month, parsed.day);
  }

  Map<String, dynamic> _aiSetPayload(WorkoutSet set) => {
    'type': set.type,
    'weightKg': set.weight,
    'plannedWeightKg': set.plannedWeight,
    'reps': set.reps,
    'targetMin': set.targetMin,
    'targetMax': set.targetMax,
    'restSeconds': set.restSeconds,
    'completed': set.completed,
    'note': set.note.trim(),
    'durationSeconds': set.durationSeconds,
  };

  Map<String, dynamic> _aiWorkoutExercisePayload(WorkoutExercise exercise) => {
    'exerciseId': exercise.exerciseId,
    'name': displayExerciseName(exerciseFor(exercise.exerciseId)),
    'note': exercise.note.trim(),
    'restSeconds': exercise.restSeconds,
    'sets': exercise.sets.take(12).map(_aiSetPayload).toList(),
  };

  Map<String, dynamic> _aiRoutinePayload(Routine routine) => {
    'id': routine.id,
    'name': routine.name,
    'updatedAt': routine.updatedAt.toIso8601String(),
    'exercises': routine.exercises
        .take(12)
        .map(_aiWorkoutExercisePayload)
        .toList(),
  };

  Map<String, dynamic> _aiRecordPayload(WorkoutRecord record) => {
    'id': record.id,
    'date': record.date.toIso8601String().split('T').first,
    'name': record.name,
    'durationSeconds': record.durationSeconds,
    'volumeKg': record.volume,
    'completedSets': record.effectiveSets,
    'note': record.note.trim(),
    'exercises': record.exercises
        .take(12)
        .map(_aiWorkoutExercisePayload)
        .toList(),
  };

  int _weekNumber(DateTime date) {
    final first = DateTime(date.year, 1, 1);
    return ((date.difference(first).inDays + first.weekday) / 7).ceil();
  }

  String _recordAiSummary(WorkoutRecord record) {
    final lines = <String>[
      '${record.date.toIso8601String().split('T').first} ${record.name}：'
          '${record.durationSeconds ~/ 60} 分钟，总容量 '
          '${record.volume.toStringAsFixed(1)} kg，完成 ${record.effectiveSets} 组。',
    ];
    if (record.note.trim().isNotEmpty) lines.add('训练备注：${record.note.trim()}');
    for (final exercise in record.exercises) {
      final definition = exerciseFor(exercise.exerciseId);
      final values = exercise.sets
          .where((set) => set.completed)
          .map(
            (set) =>
                '${set.weight.toStringAsFixed(1)} kg×${set.reps}'
                '${set.note.trim().isEmpty ? '' : '（${set.note.trim()}）'}',
          )
          .join('；');
      lines.add(
        '${displayExerciseName(definition)}'
        '（主练：${definition.muscle}'
        '${definition.secondary.trim().isEmpty || definition.secondary == '无' ? '' : '；辅助：${definition.secondary}'}）'
        '${exercise.note.trim().isEmpty ? '' : '（动作备注：${exercise.note.trim()}）'}：'
        '${values.isEmpty ? '没有完成组' : values}',
      );
    }
    return lines.join('\n');
  }

  String _routineAiSummary(Routine routine) {
    final lines = <String>['训练计划「${routine.name}」：'];
    for (final exercise in routine.exercises) {
      final sets = exercise.sets
          .map(
            (set) =>
                '${set.plannedWeight == null ? '重量待定' : '${set.plannedWeight!.toStringAsFixed(1)} kg'}'
                '×${set.targetMax > 0 ? set.targetMax : set.reps}，休息 ${set.restSeconds} 秒',
          )
          .join('；');
      lines.add(
        '${displayExerciseName(exerciseFor(exercise.exerciseId))}：'
        '${sets.isEmpty ? '组数待定' : sets}',
      );
    }
    return lines.join('\n');
  }

  String _buildSelectedAiContext(List<AiContextSelection> selections) {
    final blocks = <String>[];
    for (final selection in selections) {
      switch (selection.type) {
        case AiContextType.activeWorkout:
          blocks.add(_buildAiTrainingSummary().split('最近已完成训练：').first);
        case AiContextType.workoutRecord:
          final matches = history.where((item) => item.id == selection.id);
          if (matches.isNotEmpty) blocks.add(_recordAiSummary(matches.first));
        case AiContextType.routine:
          final matches = routines.where((item) => item.id == selection.id);
          if (matches.isNotEmpty) blocks.add(_routineAiSummary(matches.first));
        case AiContextType.week:
          final now = DateTime.now();
          final start = DateTime(
            now.year,
            now.month,
            now.day,
          ).subtract(Duration(days: now.weekday - 1));
          final records = history.where((item) => !item.date.isBefore(start));
          blocks.add('本周训练汇总：\n${records.map(_recordAiSummary).join('\n\n')}');
        case AiContextType.month:
          final now = DateTime.now();
          final records = history.where(
            (item) =>
                item.date.year == now.year && item.date.month == now.month,
          );
          blocks.add('本月训练汇总：\n${records.map(_recordAiSummary).join('\n\n')}');
      }
    }
    return blocks.where((item) => item.trim().isNotEmpty).join('\n\n---\n\n');
  }

  Future<CoachAnswer> _requestAgentAnswer(
    AgentCoachApi api,
    String prompt, {
    required bool includeSummary,
    String? selectedTrainingContext,
    void Function(String delta)? onDelta,
    String? conversationId,
  }) async {
    final requestId = 'ai_${DateTime.now().microsecondsSinceEpoch}';
    aiToolUses = const [];
    aiToolError = null;
    notifyListeners();
    // With the automatic authorization toggle, do not silently attach the
    // complete local summary. The model must request one of the three tools;
    // an explicitly selected context remains supported for legacy/manual use.
    final summary = selectedTrainingContext;
    final first = await api.answer(
      prompt: prompt,
      requestId: requestId,
      includeTrainingSummary: includeSummary,
      locale: appLanguage.storageValue,
      trainingSummary: summary,
      exerciseCatalog: _aiExerciseCatalog(),
      skills: _activeAiSkillPayload(),
      availableTools: aiAvailableTools,
      conversationId: conversationId,
    );
    if (first.toolCalls.isEmpty) return first;
    if (first.toolCalls.length > 3) {
      await _rollbackAgentQuota(api, requestId);
      throw const CoachApiException('too_many_ai_tool_calls');
    }
    aiToolReading = true;
    aiToolError = null;
    aiToolUses = first.toolCalls
        .fold<Map<String, int>>({}, (counts, call) {
          counts[call.name] = (counts[call.name] ?? 0) + 1;
          return counts;
        })
        .entries
        .map((entry) => CoachToolUse(name: entry.key, count: entry.value))
        .toList(growable: false);
    notifyListeners();
    try {
      final toolResults = <Map<String, dynamic>>[];
      for (final call in first.toolCalls) {
        try {
          toolResults.add({
            'id': call.id,
            'name': call.name,
            'arguments': call.arguments,
            'result': executeAiTool(call),
          });
        } catch (_) {
          aiToolError = '部分训练资料暂时无法读取';
          notifyListeners();
          rethrow;
        }
      }
      final answer = api is StreamingCoachApi && onDelta != null
          ? await _consumeCoachStream(
              api as StreamingCoachApi,
              prompt: prompt,
              includeTrainingSummary: includeSummary,
              trainingSummary: summary,
              requestId: requestId,
              conversationId: first.conversationId ?? conversationId,
              toolResults: toolResults,
              onDelta: onDelta,
            )
          : await api.answer(
              prompt: prompt,
              requestId: requestId,
              includeTrainingSummary: includeSummary,
              locale: appLanguage.storageValue,
              trainingSummary: summary,
              exerciseCatalog: _aiExerciseCatalog(),
              skills: _activeAiSkillPayload(),
              conversationId: first.conversationId ?? conversationId,
              toolResults: toolResults,
            );
      aiToolUses = answer.toolUses.isEmpty ? aiToolUses : answer.toolUses;
      return answer;
    } catch (_) {
      aiToolError = '训练资料读取失败，可重试';
      await _rollbackAgentQuota(api, requestId);
      rethrow;
    } finally {
      aiToolReading = false;
      notifyListeners();
    }
  }

  int _positivePlanRest(List<WorkoutExercise>? source) {
    if (source == null) return 0;
    for (final exercise in source) {
      if (exercise.restSeconds > 0) return exercise.restSeconds;
      for (final set in exercise.sets) {
        if (set.restSeconds > 0) return set.restSeconds;
      }
    }
    return 0;
  }

  Future<void> _rollbackAgentQuota(AgentCoachApi api, String requestId) async {
    try {
      await api.rollbackQuotaReservation(requestId);
    } catch (_) {
      // Preserve the original answer/tool error. The server also rolls back
      // requests that reached it, while a later retry uses a fresh request id.
    }
  }

  Future<CoachAnswer> _requestCoachAnswer(
    String prompt, {
    bool includeTrainingContext = false,
    String? selectedTrainingContext,
    void Function(String delta)? onDelta,
    String? conversationId,
  }) async {
    final includeSummary =
        aiUseTrainingData ||
        includeTrainingContext ||
        selectedTrainingContext != null;
    var streamedOutput = false;
    Future<CoachAnswer> request() async {
      final api = await _activeCoachApi();
      if (includeSummary && api is AgentCoachApi) {
        return _requestAgentAnswer(
          api as AgentCoachApi,
          prompt,
          includeSummary: includeSummary,
          selectedTrainingContext: selectedTrainingContext,
          onDelta: onDelta,
          conversationId: conversationId,
        );
      }
      if (api is StreamingCoachApi && onDelta != null) {
        return _consumeCoachStream(
          api as StreamingCoachApi,
          prompt: prompt,
          includeTrainingSummary: includeSummary,
          trainingSummary: includeSummary
              ? selectedTrainingContext ?? _buildAiTrainingSummary()
              : null,
          conversationId: conversationId,
          onDelta: (delta) {
            streamedOutput = true;
            onDelta(delta);
          },
        );
      }
      return api.answer(
        prompt: prompt,
        includeTrainingSummary: includeSummary,
        locale: appLanguage.storageValue,
        trainingSummary: includeSummary
            ? selectedTrainingContext ?? _buildAiTrainingSummary()
            : null,
        exerciseCatalog: _aiExerciseCatalog(),
        skills: _activeAiSkillPayload(),
        conversationId: conversationId,
      );
    }

    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        return await request();
      } on CoachApiException catch (error) {
        // Re-authenticate once after an expired session. Transient upstream and
        // network failures also receive one bounded retry so users do not lose
        // a plan request because of a short queue spike or tunnel reconnect.
        final retryable =
            error.code == 'coach_http_502' ||
            error.code == 'coach_http_503' ||
            error.code == 'coach_http_504' ||
            error.code == 'coach_timeout' ||
            error.code == 'coach_network';
        if (attempt == 0 &&
            !streamedOutput &&
            (retryable ||
                (coachApi == null && error.code == 'coach_http_401'))) {
          await Future<void>.delayed(const Duration(milliseconds: 650));
          continue;
        }
        rethrow;
      }
    }
    throw const CoachApiException('coach_retry_exhausted');
  }

  Future<CoachAnswer> _consumeCoachStream(
    StreamingCoachApi api, {
    required String prompt,
    required bool includeTrainingSummary,
    String? trainingSummary,
    String? requestId,
    String? conversationId,
    List<Map<String, dynamic>> toolResults = const [],
    required void Function(String delta) onDelta,
  }) async {
    final done = Completer<CoachAnswer>();
    _activeAiCompleter = done;
    _aiStreamSubscription = api
        .streamAnswer(
          prompt: prompt,
          includeTrainingSummary: includeTrainingSummary,
          locale: appLanguage.storageValue,
          trainingSummary: trainingSummary,
          exerciseCatalog: _aiExerciseCatalog(),
          skills: _activeAiSkillPayload(),
          requestId: requestId,
          conversationId: conversationId,
          toolResults: toolResults,
        )
        .listen(
          (event) {
            if (event is CoachStreamDelta) {
              onDelta(event.text);
            } else if (event is CoachStreamDone && !done.isCompleted) {
              done.complete(event.answer);
            }
          },
          onError: (Object error) {
            if (!done.isCompleted) done.completeError(error);
          },
          onDone: () {
            if (!done.isCompleted) {
              done.completeError(
                const CoachApiException('coach_stream_incomplete'),
              );
            }
          },
        );
    final answer = await done.future;
    if (_aiCancelled) throw const CoachApiException('coach_cancelled');
    return answer;
  }

  bool _isAiPlanRequest(String prompt) {
    final normalized = prompt.toLowerCase();
    final asksToCreate = RegExp(
      r'(生成|制定|安排|创建|做一份|设计|帮我做|帮我排|generate|create|build|make)',
    ).hasMatch(normalized);
    final mentionsPlan = RegExp(
      r'(计划|方案|workout plan|training plan)',
    ).hasMatch(normalized);
    final shortPlanIntent = RegExp(
      r'(今日|今天|明天|本周|这周|练胸|练背|练腿|练肩|练手臂)',
    ).hasMatch(normalized);
    return mentionsPlan && (asksToCreate || shortPlanIntent);
  }

  List<Map<String, String>> _aiExerciseCatalog() {
    final selected = <Exercise>[];
    final seenGroups = <String>{};
    for (final exercise in selectableExercises) {
      final key = '${exercise.equipment}|${exercise.muscle}';
      if (selected.length < 80 &&
          (curatedCatalog.contains(exercise) || seenGroups.add(key))) {
        selected.add(exercise);
      }
      if (selected.length >= 80) break;
    }
    return [
      for (final exercise in selected)
        {
          'id': exercise.id,
          'name': exercise.name,
          'equipment': exercise.equipment,
          'muscle': exercise.muscle,
          'cue': exercise.cue,
        },
    ];
  }

  List<Map<String, String>> _activeAiSkillPayload() => [
    for (final skill in enabledAiSkills)
      {'id': skill.id, 'name': skill.name, 'instructions': skill.instructions},
  ];

  WorkoutExercise _makeAiWorkout(AiPlanExerciseDraft draft, String id) =>
      WorkoutExercise(
        id: id,
        exerciseId: draft.exerciseId,
        note: draft.note.trim().isNotEmpty
            ? draft.note.trim()
            : exerciseFor(draft.exerciseId).cue.trim(),
        restSeconds: draft.sets.isEmpty
            ? defaultRestSeconds
            : draft.sets.first.restSeconds,
        sets: [
          for (var index = 0; index < draft.sets.length; index++)
            WorkoutSet(
              id: '$id-set-$index',
              type: draft.sets[index].type,
              weight: draft.sets[index].weight,
              plannedWeight: draft.sets[index].weight,
              reps: draft.sets[index].reps,
              targetMin: draft.sets[index].reps,
              targetMax: draft.sets[index].reps,
              restSeconds: draft.sets[index].restSeconds,
            ),
        ],
      );

  void saveAiPlan(
    AiPlanDraft plan, {
    required bool scheduleCalendar,
    DateTime? scheduleStartDate,
  }) {
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final scheduleAnchor = scheduleStartDate ?? DateTime.now();
    for (
      var sessionIndex = 0;
      sessionIndex < plan.sessions.length;
      sessionIndex++
    ) {
      final session = plan.sessions[sessionIndex];
      final validIds = session.effectiveExerciseIds
          .where((id) => allExercises.any((exercise) => exercise.id == id))
          .toList();
      if (validIds.isEmpty) continue;
      final routineName = '${plan.title} · ${session.name}';
      if (!routineFolders.contains('AI 生成')) routineFolders.add('AI 生成');
      routines.add(
        Routine(
          id: 'ai-routine-$stamp-$sessionIndex',
          name: routineName,
          folder: 'AI 生成',
          exercises: session.exercises.isNotEmpty
              ? [
                  for (
                    var exerciseIndex = 0;
                    exerciseIndex < session.exercises.length;
                    exerciseIndex++
                  )
                    if (validIds.contains(
                      session.exercises[exerciseIndex].exerciseId,
                    ))
                      _makeAiWorkout(
                        session.exercises[exerciseIndex],
                        'ai-$stamp-$sessionIndex-$exerciseIndex',
                      ),
                ]
              : [
                  for (
                    var exerciseIndex = 0;
                    exerciseIndex < validIds.length;
                    exerciseIndex++
                  )
                    _makeWorkout(
                      validIds[exerciseIndex],
                      'ai-$stamp-$sessionIndex-$exerciseIndex',
                    ),
                ],
          updatedAt: DateTime.now(),
        ),
      );
      if (!scheduleCalendar) continue;
      for (var week = 0; week < plan.weeks; week++) {
        final dayOffset = session.dayOffset.clamp(0, 6).toInt();
        schedule(
          scheduleAnchor.add(Duration(days: dayOffset + week * 7)),
          routineName,
        );
      }
    }
    _persistTrainingLibrary();
    notifyListeners();
  }

  Future<void> sendTodayWorkoutForReview() => sendChat(
    '请从整节训练而不是逐个动作点评：先判断训练目标，再评价主要肌群与动作模式是否覆盖完整、训练量分配是否合理，'
    '指出遗漏或重复，并给出下一次最值得执行的一项调整。没有历史数据时直接评价本次训练结构，不要输出“数据不足”等免责声明。',
    includeTrainingContext: true,
  );

  Future<void> requestAiCustomizedWorkout({String details = ''}) {
    final request = details.trim();
    return sendChat(
      '请为我生成一节可直接执行的训练计划。${request.isEmpty ? '' : '我的要求：$request。'}'
      '请结合我的历史训练和当前能力，明确给出动作、组数、每组重量、次数和组间休息；'
      '如果数据不足请留空并说明依据，不要虚构我的能力。生成结构化计划卡，方便我查看和保存。',
      includeTrainingContext: true,
    );
  }

  Future<void> sendWorkoutComparisonForReview(
    WorkoutRecord record, {
    WorkoutRecord? baseline,
  }) {
    final selected = <AiContextSelection>[
      AiContextSelection(
        type: AiContextType.workoutRecord,
        id: record.id,
        label: '本次训练 · ${record.name}',
      ),
      if (baseline != null)
        AiContextSelection(
          type: AiContextType.workoutRecord,
          id: baseline.id,
          label: '上次训练 · ${baseline.name}',
        ),
    ];
    selectAiView(AiView.chat);
    return sendChat(
      baseline == null
          ? '请判断本次整节训练的目标、主要肌群与动作模式覆盖是否完整、训练量分配是否合理，并指出遗漏或重复。没有历史数据时直接评价本次结构，不要输出“数据不足”等免责声明。'
          : '请对比本次训练与上一次可比训练的动作、重量、次数、训练容量、有效组和时长，指出真正的进步或回退，并解释下一次增加或降低重量的依据。不要泛泛而谈。',
      includeTrainingContext: true,
      contexts: selected,
    );
  }

  /// Generates a private completion review without creating a chat message or
  /// navigating away from the saved workout. Free users never call the AI
  /// endpoint; their completion screen renders a local locked preview instead.
  Future<String> generateWorkoutCompletionReview(
    WorkoutRecord record, {
    WorkoutRecord? baseline,
    void Function(String delta)? onDelta,
  }) async {
    if (entitlements?.isMember != true) {
      throw const CoachApiException('membership_required');
    }
    if (scenario == 'offline') {
      throw const CoachApiException('coach_network');
    }
    if (coachApi == null && aiBaseUrl.trim().isEmpty) {
      throw const CoachApiException('coach_not_configured');
    }
    QuotaReservation? reservation;
    if (isAuthenticated) {
      reservation = accountService.reserveAi();
      if (reservation == null) {
        throw const CoachApiException('quota_exhausted');
      }
    }
    final contexts = <AiContextSelection>[
      AiContextSelection(
        type: AiContextType.workoutRecord,
        id: record.id,
        label: '本次训练 · ${record.name}',
      ),
      if (baseline != null)
        AiContextSelection(
          type: AiContextType.workoutRecord,
          id: baseline.id,
          label: '上次训练 · ${baseline.name}',
        ),
    ];
    try {
      final answer = await _requestCoachAnswer(
        baseline == null
            ? '请评价整节训练是否合理，而不是逐个动作复述。根据训练名称、动作的主练与辅助肌群、完成组数和容量，判断训练目标、肌群区域与动作模式覆盖、训练量分配和明显遗漏。'
                  '例如背部训练若只有背阔肌导向动作而缺少中下斜方肌等肩胛控制动作，应明确指出覆盖不完整；但若训练名称或上下文表明是专项或拆分日，不要强迫一节训练覆盖所有部位。'
                  '没有历史数据时仍要直接评价本次训练结构，跳过趋势比较即可。禁止输出“数据不足”“只能初步判断”“无法判断”等免责声明，禁止凭空推测热身、疲劳或伤病。'
                  '请用三段简短内容：整体结论、覆盖或分配问题、下一次唯一且具体的调整。'
            : '请先评价本次整节训练的目标、肌群与动作模式覆盖、训练量分配和明显遗漏，再比较本次与上次相同动作的重量、次数和容量。'
                  '指出真正的进步或回退，并给出下一次最值得执行的一项调整及依据。禁止输出“数据不足”等免责声明，也不要虚构疲劳、热身或伤病原因。',
        includeTrainingContext: true,
        selectedTrainingContext: _buildSelectedAiContext(contexts),
        onDelta: onDelta,
      );
      final body = answer.body.trim();
      if (body.isEmpty) throw const CoachApiException('coach_empty');
      reservation?.commit();
      return body;
    } catch (_) {
      reservation?.rollback();
      rethrow;
    }
  }

  Future<void> sendChat(
    String text, {
    bool includeTrainingContext = false,
    List<AiContextSelection> contexts = const [],
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || aiTyping) return;
    final serverConversationId = _currentAiConversation()?.serverConversationId;
    chat.add(
      ChatMessage(
        id: 'user-${DateTime.now().microsecondsSinceEpoch}',
        role: 'user',
        body: trimmed,
      ),
    );
    aiTyping = true;
    _aiCancelled = false;
    aiWaitingSeconds = 0;
    _aiWaitingTimer?.cancel();
    _aiWaitingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      aiWaitingSeconds++;
      notifyListeners();
    });
    final answerMessage = ChatMessage(
      id: 'answer-${DateTime.now().microsecondsSinceEpoch}',
      role: 'assistant',
      body: '',
    );
    chat.add(answerMessage);
    _saveActiveConversation();
    notifyListeners();
    CoachAnswer? remoteAnswer;
    String? serviceError;
    QuotaReservation? aiReservation;
    if (scenario == 'offline') {
      serviceError = '当前处于离线状态，AI 服务暂不可用。';
    } else if (scenario == 'empty') {
      serviceError = '暂未找到可用训练证据，请先完成训练或补充数据。';
    } else if (coachApi == null && aiBaseUrl.trim().isEmpty) {
      serviceError = 'AI 服务未配置，请在设置中配置 Coach 服务后重试。';
    } else {
      if (isAuthenticated) {
        aiReservation = accountService.reserveAi();
        if (aiReservation == null) {
          serviceError = _aiQuotaExhaustedMessage();
        }
      }
      if (serviceError == null) {
        try {
          final selected = contexts.isEmpty
              ? null
              : _buildSelectedAiContext(contexts);
          remoteAnswer = await _requestCoachAnswer(
            trimmed,
            includeTrainingContext: includeTrainingContext,
            selectedTrainingContext: selected,
            conversationId: serverConversationId,
            onDelta: _isAiPlanRequest(trimmed)
                ? null
                : (delta) {
                    answerMessage.body += delta;
                    notifyListeners();
                  },
          );
          answerMessage
            ..body = remoteAnswer.body
            ..citations = remoteAnswer.citations
            ..plan = remoteAnswer.plan;
          final returnedConversationId = remoteAnswer.conversationId?.trim();
          if (returnedConversationId?.isNotEmpty == true) {
            _currentAiConversation()?.serverConversationId =
                returnedConversationId;
          }
          if (remoteAnswer.body.trim().isNotEmpty) {
            aiReservation?.commit();
          } else {
            aiReservation?.rollback();
            serviceError =
                '\u0041\u0049 \u670d\u52a1\u672a\u8fd4\u56de\u53ef\u7528\u56de\u7b54\u3002';
          }
        } on CoachApiException catch (error) {
          aiReservation?.rollback();
          serviceError = switch (error.code) {
            'coach_cancelled' =>
              answerMessage.body.trim().isEmpty ? '已停止回答。' : null,
            'coach_account_not_synced' ||
            'coach_session_expired' ||
            'session_expired' ||
            'coach_http_401' => '登录已过期，请重新登录后再试。',
            'quota_exhausted' => _aiQuotaExhaustedMessage(),
            'coach_timeout' => 'AI 响应超时，已自动重试一次，请稍后再试。',
            'coach_network' => '当前网络无法连接 AI 服务，请检查网络后重试。',
            'coach_http_429' ||
            'coach_http_503' => 'AI 当前请求较多，已自动重试但仍在排队，请稍后再试。',
            'coach_http_502' || 'coach_http_504' => 'AI 上游服务短暂波动，已自动重试，请稍后再试。',
            _ => 'AI 服务暂时不可用（${error.code}），请稍后重试。',
          };
        } catch (_) {
          aiReservation?.rollback();
          serviceError = 'AI 服务暂时不可用，请稍后重试。';
        }
      }
    }
    aiTyping = false;
    _aiWaitingTimer?.cancel();
    _aiWaitingTimer = null;
    _aiStreamSubscription = null;
    _activeAiCompleter = null;
    if (answerMessage.body.trim().isEmpty) {
      answerMessage.body = remoteAnswer?.body.isNotEmpty == true
          ? remoteAnswer!.body
          : serviceError ?? 'AI 服务未返回可用回答。';
    }
    _saveActiveConversation();
    notifyListeners();
  }

  Future<void> cancelAiResponse() async {
    if (!aiTyping) return;
    _aiCancelled = true;
    final assistants = chat.where((item) => item.role == 'assistant');
    final partial = assistants.isEmpty ? '' : assistants.last.body.trim();
    if (_activeAiCompleter?.isCompleted == false) {
      _activeAiCompleter!.complete(CoachAnswer(body: partial));
    }
    await _aiStreamSubscription?.cancel();
    _aiStreamSubscription = null;
    _aiWaitingTimer?.cancel();
    _aiWaitingTimer = null;
    aiTyping = false;
    if (assistants.isNotEmpty && assistants.last.body.trim().isEmpty) {
      assistants.last.body = '已停止回答。';
    }
    _saveActiveConversation();
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    accountService.removeListener(_handleAccountChanged);
    PlatformTimerBridge.setSystemActionHandlers();
    _workoutTicker?.cancel();
    _restTicker?.cancel();
    _recognitionTicker?.cancel();
    _completionBurstTimer?.cancel();
    _aiWaitingTimer?.cancel();
    unawaited(_aiStreamSubscription?.cancel());
    super.dispose();
  }
}
