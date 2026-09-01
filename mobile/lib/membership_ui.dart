import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:url_launcher/url_launcher.dart';

import 'account_membership.dart';
import 'ai_api.dart';
import 'controller.dart';

const _paper = Color(0xFFFFF7F0);
const _ink = Color(0xFF241A15);
const _muted = Color(0xFF756156);
const _ember = Color(0xFFD95718);
const _emberBright = Color(0xFFF36A1D);
const _emberSoft = Color(0xFFFFE3D2);
const _line = Color(0xFFEAD9CD);
const _success = Color(0xFF21845A);

enum MembershipPaywallReason {
  aiQuota,
  recognitionQuota,
  nutritionPhoto,
  advancedStatistics,
  premiumFeature,
}

const Map<MembershipPlan, String> membershipProductIds = {
  MembershipPlan.oneMonth: 'com.kilostrength.pro.monthly',
  MembershipPlan.threeMonths: 'com.kilostrength.pro.quarterly',
  MembershipPlan.yearly: 'com.kilostrength.pro.yearly',
};

const Map<MembershipPlan, String> _fallbackPrices = {
  MembershipPlan.oneMonth: '¥12',
  MembershipPlan.threeMonths: '¥38',
  MembershipPlan.yearly: '¥128',
};

const Map<MembershipPlan, double> _fallbackRawPrices = {
  MembershipPlan.oneMonth: 12,
  MembershipPlan.threeMonths: 38,
  MembershipPlan.yearly: 128,
};

class MembershipMark extends StatelessWidget {
  const MembershipMark({super.key, required this.isMember, this.size = 28});

  final bool isMember;
  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
    label: isMember ? '形域 PRO 会员' : '免费账号',
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isMember ? _ink : Colors.white,
        border: Border.all(
          color: isMember ? _emberBright : _line,
          width: size < 24 ? 1.5 : 2,
        ),
        boxShadow: isMember
            ? const [BoxShadow(color: Color(0x33D95718), blurRadius: 10)]
            : null,
      ),
      child: Icon(
        isMember
            ? Icons.local_fire_department_rounded
            : Icons.person_outline_rounded,
        size: size * .58,
        color: isMember ? const Color(0xFFFFB47F) : _muted,
      ),
    ),
  );
}

class MembershipPurchaseCoordinator extends ChangeNotifier {
  MembershipPurchaseCoordinator(this.controller);

  final AppController controller;
  final InAppPurchase _store = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  final Map<String, ProductDetails> _products = {};
  final Map<String, String> _pendingOrderByProduct = {};
  bool loading = false;
  bool storeAvailable = false;
  bool wechatPayAvailable = false;
  bool alipayAvailable = false;
  String? errorMessage;

  ProductDetails? productFor(MembershipPlan plan) =>
      _products[membershipProductIds[plan]];

  String priceFor(MembershipPlan plan) =>
      productFor(plan)?.price ?? _fallbackPrices[plan] ?? '';

  Future<void> initialize() async {
    if (_subscription != null) return;
    loading = true;
    notifyListeners();
    try {
      if (Platform.isAndroid) {
        final capabilities = await controller.androidPaymentCapabilities();
        wechatPayAvailable = capabilities['wechatPay'] == true;
        alipayAvailable = capabilities['alipay'] == true;
        storeAvailable = wechatPayAvailable || alipayAvailable;
        if (!storeAvailable) {
          errorMessage = '微信支付和支付宝商户通道尚未配置。';
        }
        return;
      }
      if (Platform.isIOS || Platform.isMacOS) {
        // StoreKit 1 is intentionally kept until the server migrates from
        // receipt verification to signed StoreKit 2 transaction JWS data.
        // ignore: deprecated_member_use
        InAppPurchaseStoreKitPlatform.enableStoreKit1();
      }
      _subscription = _store.purchaseStream.listen(
        _handlePurchaseUpdates,
        onError: (Object error) {
          errorMessage = '商店连接中断，请稍后重试。';
          notifyListeners();
        },
      );
      storeAvailable = await _store.isAvailable();
      if (storeAvailable) {
        final response = await _store.queryProductDetails(
          membershipProductIds.values.toSet(),
        );
        _products
          ..clear()
          ..addEntries(
            response.productDetails.map((item) => MapEntry(item.id, item)),
          );
        if (response.error != null) errorMessage = '会员商品加载失败，请稍后重试。';
        if (response.notFoundIDs.isNotEmpty) {
          errorMessage = '部分会员商品尚未在商店启用。';
        }
      }
    } catch (_) {
      storeAvailable = false;
      errorMessage = '当前无法连接 App Store，请检查网络后重试。';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<bool> purchaseAndroid(
    MembershipPlan plan,
    MembershipOrderProvider provider,
  ) async {
    final enabled = provider == MembershipOrderProvider.wechatPay
        ? wechatPayAvailable
        : alipayAvailable;
    if (!enabled) {
      errorMessage = provider == MembershipOrderProvider.wechatPay
          ? '微信支付尚未完成商户配置。'
          : '支付宝尚未完成商户配置。';
      notifyListeners();
      return false;
    }
    loading = true;
    errorMessage = null;
    notifyListeners();
    try {
      final uri = await controller.createAndroidMembershipCheckout(
        plan: plan,
        provider: provider,
      );
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) throw const CoachApiException('payment_app_unavailable');
      return true;
    } on CoachApiException catch (error) {
      errorMessage = error.code == 'payment_provider_not_configured'
          ? '支付通道尚未完成商户配置。'
          : '未能打开支付，请检查对应支付应用后重试。';
      return false;
    } catch (_) {
      errorMessage = '未能打开支付，请稍后重试。';
      return false;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<bool> purchase(MembershipPlan plan) async {
    final product = productFor(plan);
    if (!storeAvailable || product == null) {
      errorMessage = '该会员方案尚未在 App Store 配置完成。';
      notifyListeners();
      return false;
    }
    late final MembershipOrder? order;
    try {
      order = await controller.createMembershipOrderRemote(
        plan: plan,
        productId: product.id,
        displayPrice: product.price,
        provider: Platform.isIOS
            ? MembershipOrderProvider.appStore
            : MembershipOrderProvider.googlePlay,
      );
    } on CoachApiException catch (error) {
      errorMessage = error.code == 'coach_unauthenticated'
          ? '请先登录后再开通会员。'
          : '订单创建失败，请检查网络后重试。';
      notifyListeners();
      return false;
    } catch (_) {
      errorMessage = '订单创建失败，请检查网络后重试。';
      notifyListeners();
      return false;
    }
    if (order == null) {
      errorMessage = '请先登录后再开通会员。';
      notifyListeners();
      return false;
    }
    _pendingOrderByProduct[product.id] = order.id;
    controller.updateMembershipOrder(
      order.id,
      status: MembershipOrderStatus.processing,
    );
    try {
      final started = await _store.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: product),
      );
      if (!started) {
        await _cancelRemoteQuietly(order.id);
        controller.updateMembershipOrder(
          order.id,
          status: MembershipOrderStatus.cancelled,
        );
      }
      return started;
    } catch (_) {
      await _cancelRemoteQuietly(order.id);
      controller.updateMembershipOrder(
        order.id,
        status: MembershipOrderStatus.cancelled,
        failureReason: 'store_start_failed',
      );
      errorMessage = '未能拉起系统支付，请稍后重试。';
      notifyListeners();
      return false;
    }
  }

  Future<void> restore() async {
    errorMessage = null;
    notifyListeners();
    try {
      await _store.restorePurchases();
    } catch (_) {
      errorMessage = '恢复购买失败，请确认当前 Apple ID 后重试。';
      notifyListeners();
    }
  }

  Future<void> _handlePurchaseUpdates(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      final orderId = _pendingOrderByProduct[purchase.productID];
      if (purchase.status == PurchaseStatus.pending) {
        if (orderId != null) {
          controller.updateMembershipOrder(
            orderId,
            status: MembershipOrderStatus.processing,
          );
        }
        continue;
      }
      if (purchase.status == PurchaseStatus.canceled ||
          purchase.status == PurchaseStatus.error) {
        if (orderId != null) {
          await _cancelRemoteQuietly(orderId);
          controller.updateMembershipOrder(
            orderId,
            status: MembershipOrderStatus.cancelled,
            failureReason: purchase.error?.code,
          );
        }
        continue;
      }
      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        final plan = membershipProductIds.entries
            .where((entry) => entry.value == purchase.productID)
            .map((entry) => entry.key)
            .firstOrNull;
        final trackedOrder =
            orderId ??
            controller
                .createMembershipOrder(
                  plan: plan ?? MembershipPlan.oneMonth,
                  productId: purchase.productID,
                  displayPrice:
                      productFor(plan ?? MembershipPlan.oneMonth)?.price ?? '',
                  provider: MembershipOrderProvider.appStore,
                )
                ?.id;
        try {
          await controller.verifyAppleMembershipPurchase(
            productId: purchase.productID,
            verificationData: purchase.verificationData.serverVerificationData,
            transactionId: purchase.purchaseID,
            localOrderId: trackedOrder,
          );
          if (trackedOrder != null) {
            controller.updateMembershipOrder(
              trackedOrder,
              status: purchase.status == PurchaseStatus.restored
                  ? MembershipOrderStatus.restored
                  : MembershipOrderStatus.paid,
              transactionId: purchase.purchaseID,
            );
          }
          if (purchase.pendingCompletePurchase) {
            await _store.completePurchase(purchase);
          }
        } on CoachApiException catch (error) {
          if (trackedOrder != null) {
            controller.updateMembershipOrder(
              trackedOrder,
              status: MembershipOrderStatus.failed,
              transactionId: purchase.purchaseID,
              failureReason: error.code,
            );
          }
          errorMessage = '支付已收到，但会员校验未完成，请勿重复付款，可稍后点击恢复购买。';
        } catch (_) {
          errorMessage = '会员校验暂时不可用，请稍后点击恢复购买。';
        }
      }
    }
    notifyListeners();
  }

  Future<void> _cancelRemoteQuietly(String orderId) async {
    try {
      await controller.cancelMembershipOrderRemote(orderId);
    } catch (_) {
      // Keep the local terminal state. A later order refresh reconciles it
      // with the server when the temporary network/tunnel failure recovers.
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

Future<void> showMembershipPaywall(
  BuildContext context, {
  required AppController controller,
  required MembershipPaywallReason reason,
}) async {
  final title = switch (reason) {
    MembershipPaywallReason.aiQuota => '今日 AI 使用已达到免费上限',
    MembershipPaywallReason.recognitionQuota => '本周动作识别已达到免费上限',
    MembershipPaywallReason.nutritionPhoto => '拍照识别营养属于形域 PRO',
    MembershipPaywallReason.advancedStatistics => '进阶数据统计属于形域 PRO',
    MembershipPaywallReason.premiumFeature => '这项能力属于形域 PRO',
  };
  final caption = switch (reason) {
    MembershipPaywallReason.aiQuota => '开通 PRO 后，训练数据分析和 AI 决策能力持续可用。',
    MembershipPaywallReason.recognitionQuota => '开通 PRO 后可继续使用动作技术分析。',
    MembershipPaywallReason.nutritionPhoto => '多图识别会自动填入热量、蛋白质、碳水和脂肪；手动记录仍然免费。',
    MembershipPaywallReason.advancedStatistics =>
      '解锁上期对比、营养达标率、训练与饮食联动趋势和下一步建议。',
    MembershipPaywallReason.premiumFeature => '升级后即可解锁更完整的训练分析与会员权益。',
  };
  await showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: _paper,
    builder: (sheetContext) => SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          22,
          12,
          22,
          20 + MediaQuery.viewPaddingOf(sheetContext).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: _line,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Align(child: MembershipMark(isMember: true, size: 58)),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _ink,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              caption,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _muted),
            ),
            const SizedBox(height: 18),
            const _PaywallBenefit(
              icon: Icons.auto_awesome_rounded,
              title: 'AI 训练决策',
              caption: '结合训练历史、恢复与动作质量给出下一步建议',
            ),
            const _PaywallBenefit(
              icon: Icons.center_focus_strong_rounded,
              title: '动作技术分析',
              caption: '记录动作表现并持续追踪技术成长',
            ),
            const _PaywallBenefit(
              icon: Icons.add_a_photo_outlined,
              title: '饮食拍照识别',
              caption: '一次最多 8 张，自动生成热量与三大营养素候选',
            ),
            const _PaywallBenefit(
              icon: Icons.query_stats_rounded,
              title: '训练 × 饮食进阶统计',
              caption: '同期对比、周均、达标率与可执行的下一步',
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: () {
                Navigator.pop(sheetContext);
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        MembershipCenterPage(controller: controller),
                  ),
                );
              },
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                backgroundColor: _ember,
              ),
              child: const Text('查看会员方案'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(sheetContext),
              child: Text(
                reason == MembershipPaywallReason.aiQuota ? '明天再用' : '暂不开通',
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _PaywallBenefit extends StatelessWidget {
  const _PaywallBenefit({
    required this.icon,
    required this.title,
    required this.caption,
  });
  final IconData icon;
  final String title;
  final String caption;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: _emberSoft,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: _ember, size: 20),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: _ink,
                ),
              ),
              Text(
                caption,
                style: const TextStyle(fontSize: 12, color: _muted),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class MembershipCenterPage extends StatefulWidget {
  const MembershipCenterPage({super.key, required this.controller});
  final AppController controller;

  @override
  State<MembershipCenterPage> createState() => _MembershipCenterPageState();
}

class _MembershipCenterPageState extends State<MembershipCenterPage>
    with WidgetsBindingObserver {
  late final MembershipPurchaseCoordinator purchase;
  late final ScrollController _planScrollController;
  MembershipPlan selected = MembershipPlan.yearly;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _planScrollController = ScrollController(initialScrollOffset: 576);
    purchase = MembershipPurchaseCoordinator(widget.controller)
      ..addListener(_refresh);
    unawaited(purchase.initialize());
    unawaited(widget.controller.hydrateMembershipOrders());
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    purchase
      ..removeListener(_refresh)
      ..dispose();
    _planScrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !Platform.isAndroid) return;
    // WeChat/Alipay returns through the app link. The server callback remains
    // authoritative, so resuming only refreshes the order and entitlement.
    unawaited(widget.controller.hydrateMembershipOrders());
  }

  @override
  Widget build(BuildContext context) {
    final entitlement = widget.controller.entitlements;
    return Scaffold(
      backgroundColor: _paper,
      appBar: AppBar(
        backgroundColor: _paper,
        title: const Text('会员中心'),
        actions: [
          TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) =>
                    MembershipOrdersPage(controller: widget.controller),
              ),
            ),
            child: const Text('订单'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 118),
        children: [
          _MemberHero(entitlement: entitlement),
          const SizedBox(height: 12),
          _CloudSyncStatus(isEnabled: widget.controller.cloudSyncAllowed),
          const SizedBox(height: 16),
          const Text(
            '选择适合你的方案',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: _ink,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            '所有方案均解锁完整 PRO 能力，区别仅在订阅周期。',
            style: TextStyle(fontSize: 12, color: _muted),
          ),
          const SizedBox(height: 12),
          _PlanComparison(
            selected: selected,
            purchase: purchase,
            scrollController: _planScrollController,
            onSelected: (plan) => setState(() => selected = plan),
          ),
          const SizedBox(height: 8),
          const _BenefitsCard(),
          if (purchase.errorMessage != null) ...[
            const SizedBox(height: 12),
            _InlineNotice(message: purchase.errorMessage!),
          ],
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (Platform.isIOS || Platform.isMacOS) ...[
                TextButton(
                  onPressed: purchase.restore,
                  child: const Text('恢复购买'),
                ),
                const Text('·', style: TextStyle(color: _muted)),
              ],
              TextButton(
                onPressed: () => _showRedeem(context, widget.controller),
                child: const Text('兑换会员'),
              ),
            ],
          ),
          Text(
            Platform.isIOS || Platform.isMacOS
                ? '付款由 App Store 安全处理。月度、季度和年度方案会按 Apple 规则自动续订，可在 Apple ID 中管理或恢复。'
                : '微信或支付宝完成支付后，由服务端回调确认订单并发放会员；不要重复支付同一订单。',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, height: 1.45, color: _muted),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 14),
        child: Platform.isAndroid
            ? Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const Key('membership-wechat-pay'),
                      onPressed:
                          purchase.loading || !purchase.wechatPayAvailable
                          ? null
                          : () => purchase.purchaseAndroid(
                              selected,
                              MembershipOrderProvider.wechatPay,
                            ),
                      icon: const Icon(Icons.chat_bubble_rounded, size: 18),
                      label: const Text('微信支付'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(54),
                        foregroundColor: const Color(0xFF168F55),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      key: const Key('membership-alipay'),
                      onPressed: purchase.loading || !purchase.alipayAvailable
                          ? null
                          : () => purchase.purchaseAndroid(
                              selected,
                              MembershipOrderProvider.alipay,
                            ),
                      icon: const Icon(
                        Icons.account_balance_wallet_rounded,
                        size: 18,
                      ),
                      label: const Text('支付宝'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(54),
                        backgroundColor: const Color(0xFF1677FF),
                      ),
                    ),
                  ),
                ],
              )
            : FilledButton(
                onPressed: purchase.loading
                    ? null
                    : () => purchase.purchase(selected),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(54),
                  backgroundColor: _ember,
                  disabledBackgroundColor: _line,
                ),
                child: purchase.loading
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text('使用 Apple 内购 · ${purchase.priceFor(selected)}'),
              ),
      ),
    );
  }
}

class _MemberHero extends StatelessWidget {
  const _MemberHero({required this.entitlement});
  final EntitlementSnapshot? entitlement;

  @override
  Widget build(BuildContext context) {
    final member = entitlement?.isMember == true;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2E211B), Color(0xFF17110E)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33241A15),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          MembershipMark(isMember: member, size: 58),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member ? '形域 PRO' : '升级形域 PRO',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  member ? _memberValidity(entitlement!) : '让识别、数据与 AI 陪你持续进步',
                  style: const TextStyle(
                    color: Color(0xFFD9C8BE),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _HeroPill('AI 训练决策'),
                    const _HeroPill('动作分析'),
                    const _HeroPill('饮食识别'),
                    const _HeroPill('进阶统计'),
                    const _HeroPill('云同步'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _memberValidity(EntitlementSnapshot value) {
    if (value.membership == MembershipPlan.forever) return '永久会员 · 所有权益持续有效';
    final date = value.membershipExpiresAt;
    return date == null
        ? '会员权益已生效'
        : '有效期至 ${date.year}.${date.month}.${date.day}';
  }
}

class _HeroPill extends StatelessWidget {
  const _HeroPill(this.label);
  final String label;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: const Color(0x24FFFFFF),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label,
      style: const TextStyle(
        color: Color(0xFFFFC19A),
        fontSize: 11,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _CloudSyncStatus extends StatelessWidget {
  const _CloudSyncStatus({required this.isEnabled});

  final bool isEnabled;

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('membership-cloud-sync-status'),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: isEnabled ? const Color(0xFFEAF5EF) : Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: isEnabled ? const Color(0xFFB9DDC8) : _line),
    ),
    child: Row(
      children: [
        Icon(
          isEnabled ? Icons.cloud_done_outlined : Icons.cloud_outlined,
          color: isEnabled ? _success : _muted,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            isEnabled ? 'PRO 云同步已开启' : 'PRO 解锁多设备云同步',
            style: const TextStyle(fontWeight: FontWeight.w800, color: _ink),
          ),
        ),
        Text(
          isEnabled ? '登录后自动同步' : '会员权益',
          style: const TextStyle(fontSize: 11, color: _muted),
        ),
      ],
    ),
  );
}

class _PlanComparison extends StatelessWidget {
  const _PlanComparison({
    required this.selected,
    required this.purchase,
    required this.scrollController,
    required this.onSelected,
  });

  final MembershipPlan selected;
  final MembershipPurchaseCoordinator purchase;
  final ScrollController scrollController;
  final ValueChanged<MembershipPlan> onSelected;

  static const plans = [
    MembershipPlan.oneMonth,
    MembershipPlan.threeMonths,
    MembershipPlan.yearly,
  ];

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final cards = [
        for (final plan in plans)
          _PlanCard(
            plan: plan,
            price: purchase.priceFor(plan),
            monthlyEquivalent: _monthlyEquivalent(purchase, plan),
            selected: selected == plan,
            onTap: () => onSelected(plan),
          ),
      ];
      if (constraints.maxWidth >= 760) {
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var index = 0; index < cards.length; index++) ...[
                Expanded(child: cards[index]),
                if (index != cards.length - 1) const SizedBox(width: 12),
              ],
            ],
          ),
        );
      }
      final cardWidth = (constraints.maxWidth - 18).clamp(248.0, 304.0);
      return Semantics(
        label: '会员方案，可横向滑动比较',
        child: SingleChildScrollView(
          key: const Key('membership-plan-comparison'),
          controller: scrollController,
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.only(right: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var index = 0; index < cards.length; index++) ...[
                SizedBox(width: cardWidth, child: cards[index]),
                if (index != cards.length - 1) const SizedBox(width: 12),
              ],
            ],
          ),
        ),
      );
    },
  );

  static String _monthlyEquivalent(
    MembershipPurchaseCoordinator purchase,
    MembershipPlan plan,
  ) {
    final product = purchase.productFor(plan);
    final raw = product?.rawPrice ?? _fallbackRawPrices[plan]!;
    final months = switch (plan) {
      MembershipPlan.oneMonth => 1,
      MembershipPlan.threeMonths => 3,
      MembershipPlan.yearly => 12,
      _ => 1,
    };
    final value = raw / months;
    final symbol = product == null
        ? '¥'
        : product.price.replaceAll(RegExp(r'[\d\s.,]'), '');
    final decimals = value == value.roundToDouble() ? 0 : 1;
    return '约 $symbol${value.toStringAsFixed(decimals)} / 月';
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.price,
    required this.monthlyEquivalent,
    required this.selected,
    required this.onTap,
  });

  final MembershipPlan plan;
  final String price;
  final String monthlyEquivalent;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title = switch (plan) {
      MembershipPlan.oneMonth => '月度会员',
      MembershipPlan.threeMonths => '季度会员',
      MembershipPlan.yearly => '年度会员',
      MembershipPlan.forever => '永久会员',
      MembershipPlan.free => '免费账号',
    };
    final caption = switch (plan) {
      MembershipPlan.oneMonth => '按月自动续订',
      MembershipPlan.threeMonths => '每 3 个月自动续订',
      MembershipPlan.yearly => '每 12 个月自动续订',
      MembershipPlan.forever => '一次购买，长期使用',
      MembershipPlan.free => '',
    };
    final features = switch (plan) {
      MembershipPlan.oneMonth => const [
        '完整 PRO 权益',
        '适合先体验 AI 训练闭环',
        '可在应用商店管理订阅',
      ],
      MembershipPlan.threeMonths => const [
        '完整 PRO 权益',
        '覆盖一个完整训练周期',
        '技术与力量趋势连续记录',
      ],
      MembershipPlan.yearly => const [
        '完整 PRO 权益',
        '长期训练记忆与云同步',
        '全年技术、力量与饮食趋势',
      ],
      _ => const <String>[],
    };
    return Material(
      key: Key('membership-plan-${plan.name}'),
      color: selected ? const Color(0xFFFFEEE2) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: selected ? _ember : _line,
          width: selected ? 1.7 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: _ink,
                      ),
                    ),
                  ),
                  if (plan == MembershipPlan.yearly)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _ember,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        '最受欢迎',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 22),
              Text(
                price,
                style: const TextStyle(
                  color: _ink,
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                caption,
                style: const TextStyle(color: _muted, fontSize: 12),
              ),
              Text(
                monthlyEquivalent,
                style: const TextStyle(
                  color: _ember,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: selected
                    ? FilledButton.icon(
                        onPressed: onTap,
                        icon: const Icon(Icons.check_rounded, size: 18),
                        label: const Text('已选择'),
                        style: FilledButton.styleFrom(backgroundColor: _ink),
                      )
                    : OutlinedButton(onPressed: onTap, child: Text('选择$title')),
              ),
              const SizedBox(height: 18),
              for (final feature in features) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.check_rounded, color: _success, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        feature,
                        style: const TextStyle(fontSize: 12, height: 1.35),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _BenefitsCard extends StatelessWidget {
  const _BenefitsCard();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: _line),
    ),
    child: const Column(
      children: [
        _BenefitRow(
          icon: Icons.auto_awesome_rounded,
          title: 'AI 训练决策',
          caption: '结合历史训练、恢复和动作质量调整下一步',
        ),
        Divider(height: 24),
        _BenefitRow(
          icon: Icons.center_focus_strong_rounded,
          title: '动作技术分析',
          caption: '动作质量与技术成长趋势持续记录',
        ),
        Divider(height: 24),
        _BenefitRow(
          icon: Icons.insights_rounded,
          title: '训练与饮食进阶统计',
          caption: '同期对比、营养趋势与下一步建议',
        ),
        Divider(height: 24),
        _BenefitRow(
          icon: Icons.add_a_photo_outlined,
          title: '饮食拍照识别',
          caption: '自动识别热量和三大营养素候选',
        ),
        Divider(height: 24),
        _BenefitRow(
          icon: Icons.cloud_sync_outlined,
          title: 'PRO 云同步',
          caption: '登录后在多台设备恢复训练与饮食资料',
        ),
      ],
    ),
  );
}

class _BenefitRow extends StatelessWidget {
  const _BenefitRow({
    required this.icon,
    required this.title,
    required this.caption,
  });
  final IconData icon;
  final String title;
  final String caption;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, color: _ember),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w800, color: _ink),
            ),
            Text(caption, style: const TextStyle(fontSize: 12, color: _muted)),
          ],
        ),
      ),
      const Icon(Icons.check_circle_rounded, color: _success, size: 20),
    ],
  );
}

class _InlineNotice extends StatelessWidget {
  const _InlineNotice({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF1E8),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      children: [
        const Icon(Icons.info_outline_rounded, color: _ember, size: 20),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(fontSize: 12, color: _muted),
          ),
        ),
      ],
    ),
  );
}

class MembershipOrdersPage extends StatefulWidget {
  const MembershipOrdersPage({super.key, required this.controller});
  final AppController controller;

  @override
  State<MembershipOrdersPage> createState() => _MembershipOrdersPageState();
}

class _MembershipOrdersPageState extends State<MembershipOrdersPage> {
  bool cancelling = false;

  @override
  void initState() {
    super.initState();
    unawaited(widget.controller.hydrateMembershipOrders());
  }

  Future<void> _cancel(String id) async {
    if (cancelling) return;
    setState(() => cancelling = true);
    try {
      await widget.controller.cancelMembershipOrderRemote(id);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('订单已取消')));
      }
    } on CoachApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('取消失败：${error.code}')));
      }
    } finally {
      if (mounted) setState(() => cancelling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final orders = widget.controller.membershipOrders;
    return Scaffold(
      backgroundColor: _paper,
      appBar: AppBar(backgroundColor: _paper, title: const Text('会员订单')),
      body: orders.isEmpty
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.receipt_long_outlined, color: _muted, size: 48),
                  SizedBox(height: 10),
                  Text(
                    '还没有会员订单',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  Text('开通或恢复购买后，订单会显示在这里。', style: TextStyle(color: _muted)),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: orders.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) => _OrderCard(
                order: orders[index],
                onCancel: orders[index].status == MembershipOrderStatus.pending
                    ? () => _cancel(orders[index].id)
                    : null,
                cancelling: cancelling,
              ),
            ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({
    required this.order,
    this.onCancel,
    this.cancelling = false,
  });
  final MembershipOrder order;
  final VoidCallback? onCancel;
  final bool cancelling;
  @override
  Widget build(BuildContext context) {
    final label = switch (order.status) {
      MembershipOrderStatus.pending => '待支付',
      MembershipOrderStatus.processing => '处理中',
      MembershipOrderStatus.paid => '已完成',
      MembershipOrderStatus.restored => '已恢复',
      MembershipOrderStatus.cancelled => '已取消',
      MembershipOrderStatus.failed => '校验待处理',
      MembershipOrderStatus.refunded => '已退款',
    };
    final color = switch (order.status) {
      MembershipOrderStatus.paid || MembershipOrderStatus.restored => _success,
      MembershipOrderStatus.failed ||
      MembershipOrderStatus.cancelled ||
      MembershipOrderStatus.refunded => _muted,
      _ => _ember,
    };
    final plan = switch (order.plan) {
      MembershipPlan.oneMonth => '月度会员',
      MembershipPlan.threeMonths => '季度会员',
      MembershipPlan.yearly => '年度会员',
      MembershipPlan.forever => '永久会员',
      MembershipPlan.free => '免费账号',
    };
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const MembershipMark(isMember: true, size: 34),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  plan,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: _ink,
                  ),
                ),
              ),
              Text(
                label,
                style: TextStyle(color: color, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  '订单 ${order.id}',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: _muted),
                ),
              ),
              Text(
                order.displayPrice,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${order.createdAt.year}.${order.createdAt.month}.${order.createdAt.day} ${order.createdAt.hour.toString().padLeft(2, '0')}:${order.createdAt.minute.toString().padLeft(2, '0')}',
            style: const TextStyle(fontSize: 11, color: _muted),
          ),
          if (onCancel != null) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: cancelling ? null : onCancel,
                icon: const Icon(Icons.close_rounded, size: 16),
                label: const Text('取消待支付订单'),
                style: OutlinedButton.styleFrom(foregroundColor: _muted),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

Future<void> _showRedeem(BuildContext context, AppController controller) async {
  final code = TextEditingController();
  await showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: _paper,
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        20 + MediaQuery.viewInsetsOf(sheetContext).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '兑换会员',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          const Text('兑换码仅能使用一次，成功后会员会立即生效。', style: TextStyle(color: _muted)),
          const SizedBox(height: 16),
          TextField(
            controller: code,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: '兑换码',
              hintText: 'KILO-…',
              prefixIcon: Icon(Icons.confirmation_number_outlined),
            ),
          ),
          const SizedBox(height: 14),
          FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              backgroundColor: _ember,
            ),
            onPressed: () {
              final result = controller.redeemCode(code.text);
              if (result.isSuccess) {
                Navigator.pop(sheetContext);
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('兑换成功，会员权益已生效。')));
              } else {
                ScaffoldMessenger.of(
                  sheetContext,
                ).showSnackBar(const SnackBar(content: Text('兑换码无效或已使用。')));
              }
            },
            child: const Text('立即兑换'),
          ),
        ],
      ),
    ),
  );
  code.dispose();
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
