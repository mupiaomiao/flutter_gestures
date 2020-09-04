import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart';
import 'package:vector_math/vector_math_64.dart' show Matrix4;

enum UIGestureArenaType {
  /// 独立手势竞技场
  Alone,

  /// 全局手势竞技场
  Global,
}

/// 手势竞技场
class UIGestureArena {
  UIGestureArena({
    this.type = UIGestureArenaType.Alone,
  }) : assert(type != null);

  static final globalArena = UIGestureArena(type: UIGestureArenaType.Global);

  /// 手势竞技场类型。
  /// Alone：独立于全局手势竞技场之外；
  /// Global：全局手势竞技场，与系统默认行为一致。
  final UIGestureArenaType type;

  PointerRouter _pointerRouter;
  PointerRouter get pointerRouter =>
      _pointerRouter ??= type == UIGestureArenaType.Alone
          ? _PointerRouter(_onAdd, _onRemove)
          : GestureBinding.instance.pointerRouter;

  GestureArenaManager _manager;
  GestureArenaManager get manager =>
      _manager ??= type == UIGestureArenaType.Alone
          ? GestureArenaManager()
          : GestureBinding.instance.gestureArena;

  PointerSignalResolver _pointerSignalResolver;
  PointerSignalResolver get pointerSignalResolver =>
      _pointerSignalResolver ??= type == UIGestureArenaType.Alone
          ? PointerSignalResolver()
          : GestureBinding.instance.pointerSignalResolver;

  final Map<int, int> _trakcedPointer = <int, int>{};

  // 有手势加入竞技场，在GestureBinding.pointerRouter
  // 上添加监听，以便在所有点击测试完成后，触发本场手势竞争。
  void _onAdd(int pointer) {
    _trakcedPointer.update(pointer, (value) => value + 1, ifAbsent: () {
      GestureBinding.instance.pointerRouter.addRoute(pointer, _onPointerRoute);
      return 1;
    });
  }

  void _onPointerRoute(PointerEvent event) {
    pointerRouter.route(event);
    if (event is PointerDownEvent) {
      manager.close(event.pointer);
    } else if (event is PointerUpEvent) {
      manager.sweep(event.pointer);
    } else if (event is PointerSignalEvent) {
      pointerSignalResolver.resolve(event);
    }
  }

  // 移除监听
  void _onRemove(int pointer) {
    final count = _trakcedPointer[pointer];
    if (count != null) {
      if (count > 1) {
        _trakcedPointer[pointer] = count - 1;
      } else {
        _trakcedPointer.remove(pointer);
        GestureBinding.instance.pointerRouter
            .removeRoute(pointer, _onPointerRoute);
      }
    }
  }
}

class _PointerRouter extends PointerRouter {
  final void Function(int pointer) onAdd;
  final void Function(int pointer) onRemove;

  _PointerRouter(this.onAdd, this.onRemove)
      : assert(onAdd != null),
        assert(onRemove != null);

  @override
  void addRoute(int pointer, PointerRoute route, [Matrix4 transform]) {
    onAdd(pointer);
    super.addRoute(pointer, route, transform);
  }

  @override
  void removeRoute(int pointer, PointerRoute route) {
    onRemove(pointer);
    super.removeRoute(pointer, route);
  }
}
