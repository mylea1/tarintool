import 'package:flutter/material.dart';
import 'models.dart';

/// A superset is one sortable unit, including members stored non-adjacently.
List<List<WorkoutExercise>> exerciseOrderGroups(List<WorkoutExercise> items) {
  final groups = <List<WorkoutExercise>>[];
  final supersets = <String, List<WorkoutExercise>>{};
  for (final item in items) {
    final id = item.supersetId;
    if (id == null) {
      groups.add([item]);
    } else {
      final group = supersets.putIfAbsent(id, () {
        final value = <WorkoutExercise>[];
        groups.add(value);
        return value;
      });
      group.add(item);
    }
  }
  return groups;
}

/// Validate the whole order before changing anything. Keeps original objects.
bool applyExerciseOrder(List<WorkoutExercise> items, List<String> ids) {
  if (ids.length != items.length || ids.toSet().length != items.length) {
    return false;
  }
  final byId = {for (final item in items) item.id: item};
  if (ids.any((id) => !byId.containsKey(id))) return false;
  if (List.generate(
    items.length,
    (i) => items[i].id == ids[i],
  ).every((v) => v)) {
    return false;
  }
  items.replaceRange(0, items.length, ids.map((id) => byId[id]!));
  return true;
}

List<String>? adjacentExerciseOrder(
  List<WorkoutExercise> items,
  String id,
  int direction,
) {
  final groups = exerciseOrderGroups(items);
  final index = groups.indexWhere((g) => g.any((e) => e.id == id));
  final target = index + direction;
  if (index < 0 || target < 0 || target >= groups.length) return null;
  groups.insert(target, groups.removeAt(index));
  return [
    for (final group in groups)
      for (final item in group) item.id,
  ];
}

class ExerciseReorderList extends StatelessWidget {
  const ExerciseReorderList({
    super.key,
    required this.items,
    required this.itemBuilder,
    required this.onOrder,
    this.header,
    this.padding = EdgeInsets.zero,
    this.footer,
  });
  final List<WorkoutExercise> items;
  final Widget Function(WorkoutExercise item, int index, int dragIndex)
  itemBuilder;
  final ValueChanged<List<String>> onOrder;
  final Widget? header;
  final EdgeInsets padding;
  final Widget? footer;
  @override
  Widget build(BuildContext context) {
    final groups = exerciseOrderGroups(items);
    final reduced = MediaQuery.disableAnimationsOf(context);
    return ReorderableListView(
      onReorderStart: (_) {
        void hideSelectionOverlay(Element element) {
          if (element is StatefulElement &&
              element.state is EditableTextState) {
            (element.state as EditableTextState).hideToolbar();
          }
          element.visitChildElements(hideSelectionOverlay);
        }

        (context as Element).visitChildElements(hideSelectionOverlay);
        Tooltip.dismissAllToolTips();
      },
      buildDefaultDragHandles: false,
      padding: padding,
      header: header == null
          ? null
          : Semantics(container: true, explicitChildNodes: true, child: header),
      footer: footer == null
          ? null
          : Semantics(container: true, explicitChildNodes: true, child: footer),
      proxyDecorator: (child, index, animation) => AnimatedBuilder(
        animation: animation,
        child: child,
        builder: (context, child) => Transform.scale(
          scale: reduced
              ? 1
              : 1 + .02 * Curves.easeOut.transform(animation.value),
          child: Material(
            color: Colors.transparent,
            elevation: reduced ? 0 : 6 * animation.value,
            borderRadius: BorderRadius.circular(16),
            child: child,
          ),
        ),
      ),
      onReorderItem: (oldIndex, newIndex) {
        if (oldIndex == newIndex) return;
        final moved = [...groups];
        moved.insert(newIndex, moved.removeAt(oldIndex));
        onOrder([
          for (final group in moved)
            for (final item in group) item.id,
        ]);
      },
      children: [
        for (var groupIndex = 0; groupIndex < groups.length; groupIndex++)
          Semantics(
            key: ValueKey('order-group-${groups[groupIndex].first.id}'),
            container: true,
            explicitChildNodes: true,
            child: Column(
              children: [
                for (final item in groups[groupIndex])
                  KeyedSubtree(
                    key: ValueKey(item.id),
                    child: itemBuilder(item, items.indexOf(item), groupIndex),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Only the name accepts a drag; inputs and the rest of the card keep scrolling.
class ExerciseNameDrag extends StatelessWidget {
  const ExerciseNameDrag({super.key, required this.index, required this.child});
  final int? index;
  final Widget child;
  @override
  Widget build(BuildContext context) => index == null
      ? child
      : ReorderableDragStartListener(
          index: index!,
          child: Semantics(label: '按住动作名称拖动排序', child: child),
        );
}
