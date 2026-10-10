import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:video_player/video_player.dart';
import 'ai_api.dart';

class SharedExerciseMedia extends StatefulWidget {
  const SharedExerciseMedia({
    super.key,
    required this.api,
    required this.exerciseId,
    required this.exerciseName,
  });
  final HttpCoachApi api;
  final String exerciseId, exerciseName;
  @override
  State<SharedExerciseMedia> createState() => _SharedExerciseMediaState();
}

class _SharedExerciseMediaState extends State<SharedExerciseMedia> {
  List<Map<String, dynamic>> records = [];
  bool busy = false;
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final data = await widget.api.fetchExerciseMedia(widget.exerciseId);
      if (mounted)
        setState(() {
          records = data;
          error = null;
        });
    } catch (e) {
      if (mounted) setState(() => error = '读取失败：$e');
    }
  }

  Future<String?> nameDialog(String value) async {
    final input = TextEditingController(text: value);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('器械 / 动作素材名称'),
        content: TextField(controller: input, maxLength: 100),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, input.text.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    input.dispose();
    return result;
  }

  Future<void> upload() async {
    final selected = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'mp4', 'mov', 'webm'],
      withData: false,
    );
    if (selected == null || selected.files.single.path == null || !mounted)
      return;
    final name = await nameDialog(widget.exerciseName);
    if (name == null || name.isEmpty || !mounted) return;
    setState(() => busy = true);
    try {
      await widget.api.uploadExerciseMedia(
        widget.exerciseId,
        name,
        selected.files.single.path!,
      );
      await load();
    } catch (e) {
      if (mounted) setState(() => error = '上传失败：$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> edit(Map<String, dynamic> r, bool delete) async {
    final name = delete ? null : await nameDialog(r['name'] as String);
    if (!delete && (name == null || name.isEmpty)) return;
    try {
      await widget.api.editExerciseMedia(
        widget.exerciseId,
        r['id'] as String,
        name: name,
        delete: delete,
      );
      await load();
    } catch (e) {
      if (mounted) setState(() => error = '保存失败：$e');
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text('我的动作照片与视频', style: TextStyle(fontWeight: FontWeight.bold)),
      const Text('与网页共用会员账户和动作 ID。照片最多 5MB，视频最多 30MB。'),
      OutlinedButton.icon(
        onPressed: busy ? null : upload,
        icon: const Icon(Icons.upload_file),
        label: Text(busy ? '上传中…' : '上传照片 / 视频'),
      ),
      if (error != null) Text(error!),
      for (final r in records)
        Card(
          child: Column(
            children: [
              ListTile(
                title: Text(r['name'] as String),
                subtitle: Text((r['contentType'] ?? 'image/jpeg') as String),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => edit(r, false),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => edit(r, true),
                    ),
                  ],
                ),
              ),
              if (r['photo'] != null)
                Image.memory(
                  base64Decode((r['photo'] as String).split(',').last),
                  height: 180,
                )
              else if ((r['contentType'] as String).startsWith('image/'))
                Image.network(
                  widget.api
                      .exerciseMediaEndpoint(r['id'] as String)
                      .toString(),
                  headers: widget.api.exerciseMediaHeaders,
                  height: 180,
                  errorBuilder: (_, __, ___) => const Text('图片读取失败'),
                )
              else
                _ExerciseVideo(api: widget.api, id: r['id'] as String),
            ],
          ),
        ),
    ],
  );
}

class _ExerciseVideo extends StatefulWidget {
  const _ExerciseVideo({required this.api, required this.id});
  final HttpCoachApi api;
  final String id;
  @override
  State<_ExerciseVideo> createState() => _ExerciseVideoState();
}

class _ExerciseVideoState extends State<_ExerciseVideo> {
  late final VideoPlayerController player;
  String? error;
  @override
  void initState() {
    super.initState();
    player = VideoPlayerController.networkUrl(
      widget.api.exerciseMediaEndpoint(widget.id),
      httpHeaders: widget.api.exerciseMediaHeaders,
    );
    player
        .initialize()
        .then((_) {
          if (mounted) setState(() {});
        })
        .catchError((Object e) {
          if (mounted) setState(() => error = '视频读取失败');
        });
  }

  @override
  void dispose() {
    player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => error != null
      ? Text(error!)
      : !player.value.isInitialized
      ? const SizedBox(
          height: 40,
          child: Center(child: CircularProgressIndicator()),
        )
      : Column(
          children: [
            AspectRatio(
              aspectRatio: player.value.aspectRatio,
              child: VideoPlayer(player),
            ),
            IconButton(
              onPressed: () {
                setState(() {
                  player.value.isPlaying ? player.pause() : player.play();
                });
              },
              icon: Icon(
                player.value.isPlaying ? Icons.pause : Icons.play_arrow,
              ),
            ),
          ],
        );
}
