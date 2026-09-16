import 'package:flutter/material.dart';
import 'controller.dart';
import 'legal_links.dart';

class AccountSettingsPage extends StatefulWidget {
  const AccountSettingsPage({super.key, required this.controller});
  final AppController controller;
  @override
  State<AccountSettingsPage> createState() => _AccountSettingsPageState();
}

class _AccountSettingsPageState extends State<AccountSettingsPage> {
  bool deleting = false;
  String? error;

  Future<void> deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('永久删除账号？'),
        content: const Text(
          '账号、云端训练记录、计划、AI 对话及关联资料将永久删除，无法恢复。\n\n删除账号不会自动取消 App Store 订阅，请在系统订阅设置中管理续订。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('保留账号'),
          ),
          TextButton(
            key: const Key('confirm-delete-account'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('永久删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      deleting = true;
      error = null;
    });
    try {
      await widget.controller.deleteCurrentAccountRemote();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('账号已删除'),
          content: const Text('账号及关联数据已删除。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('完成'),
            ),
          ],
        ),
      );
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (_) {
      if (mounted) {
        setState(() {
          error = '删除未完成，请稍后重试。Apple 账号需完成系统身份确认。';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          deleting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !deleting,
    child: Scaffold(
      appBar: AppBar(title: const Text('账号与法律信息')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text('法律信息', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              const LegalLinks(),
              if (widget.controller.currentUser != null) ...[
                const Divider(height: 32),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.person_remove_outlined,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  title: const Text('删除账号'),
                  subtitle: const Text('永久删除账号及关联数据'),
                  trailing: deleting
                      ? const SizedBox.square(
                          dimension: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.chevron_right),
                  key: const Key('delete-account-entry'),
                  onTap: deleting ? null : deleteAccount,
                ),
                if (error != null)
                  Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}
