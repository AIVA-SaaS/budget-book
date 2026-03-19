import 'package:flutter/material.dart';

/// A generic reorderable list widget that wraps [ReorderableListView.builder].
///
/// Each item automatically gets a drag handle icon on the trailing side.
/// Applies Material 3 elevation on drag.
class ReorderableEntityList<T> extends StatelessWidget {
  final List<T> items;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final void Function(int oldIndex, int newIndex) onReorder;
  final bool enabled;

  const ReorderableEntityList({
    super.key,
    required this.items,
    required this.itemBuilder,
    required this.onReorder,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!enabled) {
      return ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: items.length,
        itemBuilder: (context, index) =>
            itemBuilder(context, items[index], index),
      );
    }

    return ReorderableListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: items.length,
      onReorder: _handleReorder,
      proxyDecorator: _proxyDecorator,
      itemBuilder: (context, index) {
        final item = items[index];
        return _ReorderableItem(
          key: ValueKey(index),
          child: itemBuilder(context, item, index),
        );
      },
    );
  }

  void _handleReorder(int oldIndex, int newIndex) {
    // ReorderableListView adjusts newIndex when moving downward
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    onReorder(oldIndex, newIndex);
  }

  Widget _proxyDecorator(Widget child, int index, Animation<double> animation) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final elevationTween = Tween<double>(begin: 0, end: 4);
        final elevation = elevationTween.evaluate(animation);
        return Material(
          elevation: elevation,
          color: Colors.transparent,
          shadowColor: Theme.of(context).shadowColor,
          borderRadius: BorderRadius.circular(12),
          child: child,
        );
      },
      child: child,
    );
  }
}

class _ReorderableItem extends StatelessWidget {
  final Widget child;

  const _ReorderableItem({
    required super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: child),
        ReorderableDragStartListener(
          index: _resolveIndex(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            child: Icon(
              Icons.drag_handle,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.4),
            ),
          ),
        ),
      ],
    );
  }

  int _resolveIndex(BuildContext context) {
    // The key is a ValueKey<int> containing the index
    final valueKey = key as ValueKey<int>;
    return valueKey.value;
  }
}
