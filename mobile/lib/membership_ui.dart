import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';

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

enum MembershipPaywallReason { aiQuota, recognitionQuota, premiumFeature }

const Map<MembershipPlan, String> membershipProductIds = {
  MembershipPlan.oneMonth: 'com.kilostrength.pro.monthly',
  MembershipPlan.threeMonths: 'com.kilostrength.pro.quarterly',
  MembershipPlan.forever: 'com.kilostrength.pro.lifetime',
};

const Map<MembershipPlan, String> _fallbackPrices = {
  MembershipPlan.oneMonth: '¥18',
  MembershipPlan.threeMonths: '¥36',
  MembershipPlan.forever: '¥128',
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

  Future<bool> purchase(MembershipPlan plan) async {
    final product = productFor(plan);
    if (!storeAvailable || product == null) {
      errorMessage = '该会员方案尚未在 App Store 配置完成。';
      notifyListeners();
      return false;
    }
    final order = controller.createMembershipOrder(
      plan: plan,
      productId: product.id,
      displayPrice: product.price,
      provider: Platform.isIOS
          ? MembershipOrderProvider.appStore
          : MembershipOrderProvider.googlePlay,
    );
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
        controller.updateMembershipOrder(
          order.id,
          status: MembershipOrderStatus.cancelled,
        );
      }
      return started;
    } catch (_) {
      controller.updateMembershipOrder(
        order.id,
        status: MembershipOrderStatus.failed,
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
          controller.updateMembershipOrder(
            orderId,
            status: purchase.status == PurchaseStatus.canceled
                ? MembershipOrderStatus.cancelled
                : MembershipOrderStatus.failed,
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
  final entitlement = controller.entitlements;
  final title = switch (reason) {
    MembershipPaywallReason.aiQuota => '今天的 3 次免费问答已用完',
    MembershipPaywallReason.recognitionQuota => '本周免费动作识别已用完',
    MembershipPaywallReason.premiumFeature => '这项能力属于形域 PRO',
  };
  final caption = switch (reason) {
    MembershipPaywallReason.aiQuota => '免费额度会在明天恢复。开通 PRO 后，今天可继续使用。',
    MembershipPaywallReason.recognitionQuota => '免费额度会按周补充，完成有效训练也能获得额外次数。',
    MembershipPaywallReason.premiumFeature => '升级后即可解锁更完整的训练分析与会员权益。',
  };
  await showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: _paper,
    builder: (sheetContext) => Padding(
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
          _PaywallBenefit(
            icon: Icons.auto_awesome_rounded,
            title: 'AI 问答每日 20 次',
            caption: '免费账号每日 ${entitlement?.aiDailyLimit ?? 3} 次，按自然日恢复',
          ),
          const _PaywallBenefit(
            icon: Icons.center_focus_strong_rounded,
            title: '动作识别每周 3 次',
            caption: '训练完成奖励次数仍会保留',
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: () {
              Navigator.pop(sheetContext);
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => MembershipCenterPage(controller: controller),
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

class _MembershipCenterPageState extends State<MembershipCenterPage> {
  late final MembershipPurchaseCoordinator purchase;
  MembershipPlan selected = MembershipPlan.threeMonths;

  @override
  void initState() {
    super.initState();
    purchase = MembershipPurchaseCoordinator(widget.controller)
      ..addListener(_refresh);
    unawaited(purchase.initialize());
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    purchase
      ..removeListener(_refresh)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entitlement = widget.controller.entitlements;
    final member = entitlement?.isMember == true;
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
          const SizedBox(height: 16),
          const Text(
            '选择方案',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: _ink,
            ),
          ),
          const SizedBox(height: 10),
          for (final plan in const [
            MembershipPlan.oneMonth,
            MembershipPlan.threeMonths,
            MembershipPlan.forever,
          ]) ...[
            _PlanTile(
              plan: plan,
              price: purchase.priceFor(plan),
              selected: selected == plan,
              onTap: () => setState(() => selected = plan),
            ),
            const SizedBox(height: 9),
          ],
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
              TextButton(
                onPressed: purchase.restore,
                child: const Text('恢复购买'),
              ),
              const Text('·', style: TextStyle(color: _muted)),
              TextButton(
                onPressed: () => _showRedeem(context, widget.controller),
                child: const Text('兑换会员'),
              ),
            ],
          ),
          const Text(
            '付款由 App Store / Google Play 安全处理。订阅方案会按商店规则自动续订，可在系统账户中管理；永久会员为一次性购买。',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, height: 1.45, color: _muted),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 14),
        child: FilledButton(
          onPressed: member && entitlement?.membership == MembershipPlan.forever
              ? null
              : purchase.loading
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
              : Text(
                  member && entitlement?.membership == MembershipPlan.forever
                      ? '已是永久会员'
                      : '使用商店开通 · ${purchase.priceFor(selected)}',
                ),
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
                  member ? _memberValidity(entitlement!) : '让 AI 与动作反馈陪你持续进步',
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
                    _HeroPill(
                      'AI ${entitlement?.aiRemaining ?? 3}/${entitlement?.aiDailyLimit ?? 3}',
                    ),
                    _HeroPill('识别 ${entitlement?.recognitionRemaining ?? 0} 次'),
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

class _PlanTile extends StatelessWidget {
  const _PlanTile({
    required this.plan,
    required this.price,
    required this.selected,
    required this.onTap,
  });
  final MembershipPlan plan;
  final String price;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title = switch (plan) {
      MembershipPlan.oneMonth => '月度会员',
      MembershipPlan.threeMonths => '季度会员',
      MembershipPlan.forever => '永久会员',
      MembershipPlan.free => '免费账号',
    };
    final caption = switch (plan) {
      MembershipPlan.oneMonth => '灵活体验，按月续订',
      MembershipPlan.threeMonths => '约 ¥12/月 · 推荐',
      MembershipPlan.forever => '一次购买，长期使用',
      MembershipPlan.free => '',
    };
    return Material(
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
          padding: const EdgeInsets.all(15),
          child: Row(
            children: [
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: selected ? _ember : _muted,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              color: _ink,
                            ),
                          ),
                        ),
                        if (plan == MembershipPlan.threeMonths) ...[
                          const SizedBox(width: 7),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: _ember,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              '省 33%',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      caption,
                      style: const TextStyle(color: _muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                price,
                style: const TextStyle(
                  color: _ink,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
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
          title: 'AI 问答每日 20 次',
          caption: '可附带多次训练、计划和备注一起分析',
        ),
        Divider(height: 24),
        _BenefitRow(
          icon: Icons.center_focus_strong_rounded,
          title: '更多动作识别次数',
          caption: '每周补充 3 次，训练奖励继续累积',
        ),
        Divider(height: 24),
        _BenefitRow(
          icon: Icons.insights_rounded,
          title: '完整进步洞察',
          caption: '容量、表现趋势与训练总结更清楚',
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

class MembershipOrdersPage extends StatelessWidget {
  const MembershipOrdersPage({super.key, required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final orders = controller.membershipOrders;
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
              itemBuilder: (context, index) => _OrderCard(order: orders[index]),
            ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order});
  final MembershipOrder order;
  @override
  Widget build(BuildContext context) {
    final label = switch (order.status) {
      MembershipOrderStatus.pending => '待支付',
      MembershipOrderStatus.processing => '处理中',
      MembershipOrderStatus.paid => '已完成',
      MembershipOrderStatus.restored => '已恢复',
      MembershipOrderStatus.cancelled => '已取消',
      MembershipOrderStatus.failed => '校验待处理',
    };
    final color = switch (order.status) {
      MembershipOrderStatus.paid || MembershipOrderStatus.restored => _success,
      MembershipOrderStatus.failed || MembershipOrderStatus.cancelled => _muted,
      _ => _ember,
    };
    final plan = switch (order.plan) {
      MembershipPlan.oneMonth => '月度会员',
      MembershipPlan.threeMonths => '季度会员',
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
