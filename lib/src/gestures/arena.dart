import 'package:flutter/gestures.dart';

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
          ? GestureBinding.instance.pointerRouter
          : PointerRouter();

  GestureArenaManager _manager;
  GestureArenaManager get manager =>
      _manager ??= type == UIGestureArenaType.Alone
          ? GestureBinding.instance.gestureArena
          : _GestureArenaManager(_onAdd);

  PointerSignalResolver _pointerSignalResolver;
  PointerSignalResolver get pointerSignalResolver =>
      _pointerSignalResolver ??= type == UIGestureArenaType.Alone
          ? GestureBinding.instance.pointerSignalResolver
          : PointerSignalResolver();

  /// 有手势加入竞技场，在GestureBinding.pointerRouter
  /// 上添加监听，以便在所有点击测试完成后，触发本场手势竞争。
  void _onAdd(int pointer) =>
      GestureBinding.instance.pointerRouter.addRoute(pointer, _onPointerRoute);

  void _onPointerRoute(PointerEvent event) {
    pointerRouter.route(event);
    if (event is PointerDownEvent) {
      manager.close(event.pointer);
    } else if (event is PointerUpEvent) {
      manager.sweep(event.pointer);
    } else if (event is PointerSignalEvent) {
      pointerSignalResolver.resolve(event);
    }
    // 移除监听
    GestureBinding.instance.pointerRouter
        .removeRoute(event.pointer, _onPointerRoute);
  }
}

class _GestureArenaManager extends GestureArenaManager {
  _GestureArenaManager(this.onAdd);

  final void Function(int pointer) onAdd;

  @override
  GestureArenaEntry add(int pointer, GestureArenaMember member) {
    if (onAdd != null) {
      onAdd(pointer);
    }
    return super.add(pointer, member);
  }
}
