import 'dart:async';
import 'package:flutter/material.dart';
import '../../data/scripture_range.dart';

/// Long press claims the gesture after normal scrolling has had its chance.
/// Autoscroll uses laid-out verse bounds, so large fonts and notes are supported.
class PassageSelectionLayer extends StatefulWidget {
  final Widget child;
  final ScrollController scrollController;
  final List<String> references;
  final Map<String, GlobalKey> anchors;
  final ValueChanged<String?> onChanged;
  final ValueChanged<String> onFinished;
  const PassageSelectionLayer(
      {super.key,
      required this.child,
      required this.scrollController,
      required this.references,
      required this.anchors,
      required this.onChanged,
      required this.onFinished});
  @override
  State<PassageSelectionLayer> createState() => _PassageSelectionLayerState();
}

class _PassageSelectionLayerState extends State<PassageSelectionLayer> {
  String? first, current;
  Offset? pointer;
  Timer? scrollTimer;
  bool framePending = false;

  Rect? get viewport {
    final box = context.findRenderObject();
    return box is RenderBox && box.hasSize
        ? box.localToGlobal(Offset.zero) & box.size
        : null;
  }

  String? hit(Offset point, {bool exact = false}) {
    final bounds = viewport;
    if (bounds == null || point.dx < bounds.left || point.dx > bounds.right) {
      return null;
    }
    final y = point.dy.clamp(bounds.top + 2, bounds.bottom - 2);
    String? nearest;
    double distance = double.infinity;
    for (final reference in widget.references) {
      final box = widget.anchors[reference]?.currentContext?.findRenderObject();
      if (box is! RenderBox || !box.hasSize) continue;
      final rect = box.localToGlobal(Offset.zero) & box.size;
      if (exact) {
        if (rect.contains(point)) {
          return reference;
        } else {
          continue;
        }
      }
      if (rect.bottom <= bounds.top || rect.top >= bounds.bottom) continue;
      final delta = y < rect.top
          ? rect.top - y
          : y > rect.bottom
              ? y - rect.bottom
              : 0.0;
      if (delta < distance) {
        nearest = reference;
        distance = delta;
      }
    }
    return exact ? null : nearest;
  }

  void update(Offset position) {
    pointer = position;
    final end = hit(position);
    if (first != null && end != null && current != end) {
      current = end;
      widget.onChanged(ScriptureRange.between(first!, end));
    }
  }

  void autoscroll() {
    final bounds = viewport;
    final position = pointer;
    if (bounds == null ||
        position == null ||
        first == null ||
        !widget.scrollController.hasClients) {
      return;
    }
    double delta = 0;
    if (position.dy < bounds.top + 56) {
      delta = -((bounds.top + 56 - position.dy) / 4).clamp(0, 16).toDouble();
    }
    if (position.dy > bounds.bottom - 72) {
      delta = ((position.dy - bounds.bottom + 72) / 4).clamp(0, 16).toDouble();
    }
    if (delta == 0) return;
    final scroll = widget.scrollController;
    final target =
        (scroll.offset + delta).clamp(0.0, scroll.position.maxScrollExtent);
    if (target == scroll.offset) return;
    scroll.jumpTo(target);
    if (!framePending) {
      framePending = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        framePending = false;
        if (mounted && first != null && pointer != null) update(pointer!);
      });
    }
  }

  void stop() {
    scrollTimer?.cancel();
    scrollTimer = null;
    first = null;
    current = null;
    pointer = null;
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.translucent,
        onLongPressStart: (details) {
          final reference = hit(details.globalPosition, exact: true);
          if (reference == null) return;
          first = current = reference;
          pointer = details.globalPosition;
          widget.onChanged(reference);
          scrollTimer?.cancel();
          scrollTimer = Timer.periodic(
              const Duration(milliseconds: 16), (_) => autoscroll());
        },
        onLongPressMoveUpdate: (details) => update(details.globalPosition),
        onLongPressEnd: (_) {
          final selection = first == null || current == null
              ? null
              : ScriptureRange.between(first!, current!);
          stop();
          if (selection != null) widget.onFinished(selection);
        },
        onLongPressCancel: () {
          final active = first != null;
          stop();
          if (active) widget.onChanged(null);
        },
        child: widget.child,
      );
}
