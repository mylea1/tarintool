part of 'main.dart';

List<String> _planFolders(AppController c) => {
  ...c.routineFolders.where((f) => f.isNotEmpty),
  ...c.routines.map((r) => r.folder).where((f) => f.isNotEmpty),
}.toList()..sort();
Future<String?> _choosePlanFolder(BuildContext context, AppController c) =>
    showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      builder: (context) => ListView(
        shrinkWrap: true,
        children: [
          const ListTile(title: Text('存放位置')),
          ListTile(
            title: const Text('不放入文件夹'),
            onTap: () => Navigator.pop(context, ''),
          ),
          for (final f in _planFolders(c))
            ListTile(
              leading: const Icon(Icons.folder_outlined),
              title: Text(f),
              onTap: () => Navigator.pop(context, f),
            ),
        ],
      ),
    );

class _PlanFolderLibrary extends StatefulWidget {
  const _PlanFolderLibrary({required this.controller});
  final AppController controller;
  @override
  State<_PlanFolderLibrary> createState() => _PlanFolderLibraryState();
}

class _PlanFolderLibraryState extends State<_PlanFolderLibrary> {
  String? selected;
  Future<void> createFolder() async {
    final input = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('新建文件夹'),
        content: TextField(
          controller: input,
          autofocus: true,
          maxLength: 30,
          decoration: const InputDecoration(labelText: '文件夹名称'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              if (input.text.trim().isNotEmpty) {
                Navigator.pop(context, input.text.trim());
              }
            },
            child: const Text('创建'),
          ),
        ],
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 300));
    input.dispose();
    if (!mounted || name == null) return;
    widget.controller.addRoutineFolder(name);
    setState(() => selected = name);
  }

  Future<void> deleteFolder() async {
    final folder = selected;
    if (folder == null || folder.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除文件夹？'),
        content: Text('“$folder”中的计划会保留，并移至未分类。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    widget.controller.deleteRoutineFolder(folder);
    setState(() => selected = null);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final folders = _planFolders(c);
    final active =
        selected != null && selected!.isNotEmpty && !folders.contains(selected)
        ? null
        : selected;
    final routines = c.routines
        .where((r) => active == null || r.folder == active)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ChoiceChip(
              label: const Text('全部'),
              selected: active == null,
              onSelected: (_) => setState(() => selected = null),
            ),
            ChoiceChip(
              label: const Text('未分类'),
              selected: active == '',
              onSelected: (_) => setState(() => selected = ''),
            ),
            for (final f in folders)
              ChoiceChip(
                label: Text(f),
                selected: active == f,
                onSelected: (_) => setState(() => selected = f),
              ),
            TextButton.icon(
              key: const Key('create-plan-folder'),
              onPressed: createFolder,
              icon: const Icon(Icons.create_new_folder_outlined, size: 18),
              label: const Text('新建文件夹'),
            ),
            if (active != null && active.isNotEmpty)
              TextButton.icon(
                onPressed: deleteFolder,
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('删除文件夹'),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (routines.isEmpty && c.routines.isNotEmpty)
          const Padding(padding: EdgeInsets.all(12), child: Text('暂无计划')),
        for (final r in routines) _RoutineCard(controller: c, routine: r),
      ],
    );
  }
}
