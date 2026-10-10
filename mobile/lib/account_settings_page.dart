import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
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
  bool syncingWeb = false;
  Future<void> importWebRecords() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );
    if (picked == null || !mounted) return;
    final file = picked.files.single;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('导入 Web / MCP 记录？'),
        content: const Text(
          '将训练、逐组备注、计划、饮食、体重与目标合并到当前账号，保留较新的记录。本次导入不会发起云端上传；后续仍遵循 App 的会员备份设置。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('导入'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => syncingWeb = true);
    try {
      if (file.size > 8 * 1024 * 1024) throw StateError('文件超过 8 MiB');
      final text = file.bytes != null
          ? utf8.decode(file.bytes!)
          : await File(file.path!).readAsString();
      final parsed = jsonDecode(text);
      if (parsed is! Map ||
          parsed['source'] != 'traintool-web' ||
          parsed['schemaVersion'] != 2) {
        throw StateError('请选择新版网页导出的兼容备份');
      }
      await widget.controller.importWebBackup(
        Map<String, dynamic>.from(parsed),
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Web / MCP 记录已合并到 App')));
      }
    } catch (e) {
      if (mounted) setState(() => error = '导入未完成：$e');
    } finally {
      if (mounted) setState(() => syncingWeb = false);
    }
  }

  Future<void> uploadLocalData() async {
    setState(() => syncingWeb = true);
    try {
      await widget.controller.uploadLocalDataToCloud();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('本地记录已上传云端，网页 / MCP 可读取')));
      }
    } catch (e) {
      if (mounted) setState(() => error = '上传未完成：$e');
    } finally {
      if (mounted) setState(() => syncingWeb = false);
    }
  }

  Future<void> syncWebRecords() async {
    setState(() => syncingWeb = true);
    try {
      await widget.controller.syncWebRecords();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('MCP 云端记录已同步')));
      }
    } catch (e) {
      if (mounted) setState(() => error = '同步未完成：$e');
    } finally {
      if (mounted) setState(() => syncingWeb = false);
    }
  }

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
                  key: const Key('import-web-records'),
                  leading: const Icon(Icons.file_download_outlined),
                  title: const Text('导入 Web / MCP 本地备份'),
                  subtitle: const Text('合并训练、逐组备注、饮食、身体资料与每日目标'),
                  onTap: syncingWeb ? null : importWebRecords,
                ),
                ListTile(
                  key: const Key('upload-local-cloud-records'),
                  leading: const Icon(Icons.cloud_upload_outlined),
                  title: const Text('上传本地记录到云端'),
                  subtitle: const Text('读取手机本地记录，合并云端较新数据后上传'),
                  onTap: syncingWeb ? null : uploadLocalData,
                ),
                ListTile(
                  key: const Key('sync-web-records'),
                  leading: const Icon(Icons.sync),
                  title: const Text('同步 MCP 云端记录'),
                  subtitle: const Text('从同一会员账号获取外部 AI 保存的记录'),
                  onTap: syncingWeb ? null : syncWebRecords,
                ),
                if (syncingWeb) const LinearProgressIndicator(),
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
