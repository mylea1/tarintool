import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

const privacyPolicyUrl = 'https://kilostrength.cn/privacy/';
const appleEulaUrl =
    'https://www.apple.com/legal/internet-services/itunes/dev/stdeula/';

/// Legal documents remain accessible without signing in or buying membership.
class LegalLinks extends StatelessWidget {
  const LegalLinks({super.key, this.opener});

  final Future<bool> Function(Uri)? opener;

  Future<void> _open(BuildContext context, String url) async {
    try {
      final uri = Uri.parse(url);
      final opened = await (opener != null
          ? opener!(uri)
          : launchUrl(uri, mode: LaunchMode.externalApplication));
      if (opened) return;
    } catch (_) {
      // Keep the document URL available if the browser cannot be launched.
    }
    if (!context.mounted) return;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('暂时无法打开链接'),
        content: SelectableText('请复制网址到浏览器查看：\n$url'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final platform = Theme.of(context).platform;
    final apple =
        platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;
    return Wrap(
      alignment: WrapAlignment.center,
      children: [
        if (apple)
          TextButton(
            key: const Key('legal-eula-link'),
            onPressed: () => _open(context, appleEulaUrl),
            child: const Text('使用条款（EULA）'),
          ),
        TextButton(
          key: const Key('legal-privacy-link'),
          onPressed: () => _open(context, privacyPolicyUrl),
          child: const Text('隐私政策'),
        ),
      ],
    );
  }
}
