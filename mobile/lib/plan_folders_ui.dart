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
  final Set<String> expanded = {};
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
    setState(() => expanded.add(name));
  }

  Future<void> deleteFolder(String folder) async {
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
    setState(() => expanded.remove(folder));
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final folders = _planFolders(c);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            key: const Key('create-plan-folder'),
            onPressed: createFolder,
            icon: const Icon(Icons.create_new_folder_outlined),
            label: const Text('新建文件夹'),
          ),
        ),
        for (final folder in folders)
          Card(
            child: Column(
              children: [
                ListTile(
                  key: ValueKey('plan-folder-$folder'),
                  leading: Icon(
                    expanded.contains(folder)
                        ? Icons.folder_open_outlined
                        : Icons.folder_outlined,
                  ),
                  title: Text(folder),
                  subtitle: Text(
                    '${c.routines.where((r) => r.folder == folder).length} 个计划',
                  ),
                  onTap: () => setState(() {
                    if (!expanded.remove(folder)) expanded.add(folder);
                  }),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: '删除文件夹',
                        onPressed: () => deleteFolder(folder),
                        icon: const Icon(Icons.delete_outline),
                      ),
                      AnimatedRotation(
                        turns: expanded.contains(folder) ? .5 : 0,
                        duration: MediaQuery.disableAnimationsOf(context)
                            ? Duration.zero
                            : const Duration(milliseconds: 200),
                        child: const Icon(Icons.expand_more),
                      ),
                    ],
                  ),
                ),
                TrainingDisclosure(
                  expanded: expanded.contains(folder),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                    child: Column(
                      children: [
                        if (!c.routines.any((r) => r.folder == folder))
                          const Padding(
                            padding: EdgeInsets.all(12),
                            child: Text('暂无计划'),
                          ),
                        for (final routine in c.routines.where(
                          (r) => r.folder == folder,
                        ))
                          _RoutineCard(controller: c, routine: routine),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        for (final routine in c.routines.where((r) => r.folder.isEmpty))
          _RoutineCard(controller: c, routine: routine),
      ],
    );
  }
}
