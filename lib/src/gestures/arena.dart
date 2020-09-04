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

  UIPointerRouter _pointerRouter;
  UIPointerRouter get pointerRouter =>
      _pointerRouter ??= type == UIGestureArenaType.Alone
          ? _AlonePointerRouter(_onAddRoute, _onRemoveRoute)
          : _GlobalPointerRouter(GestureBinding.instance.pointerRouter);

  UIGestureArenaManager _manager;
  UIGestureArenaManager get manager =>
      _manager ??= type == UIGestureArenaType.Alone
          ? _GestureArenaManager(GestureArenaManager())
          : _GestureArenaManager(GestureBinding.instance.gestureArena);

  UIPointerSignalResolver _pointerSignalResolver;
  UIPointerSignalResolver get pointerSignalResolver =>
      _pointerSignalResolver ??= type == UIGestureArenaType.Alone
          ? _PointerSignalResolver(
              PointerSignalResolver(),
            )
          : _PointerSignalResolver(
              GestureBinding.instance.pointerSignalResolver,
            );

  // 有手势加入竞技场，在GestureBinding.pointerRouter
  // 上添加监听，以便在所有点击测试完成后，触发本场手势竞争。
  void _onAddRoute(int pointer) {
    GestureBinding.instance.pointerRouter.addRoute(pointer, _onPointerRoute);
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
  void _onRemoveRoute(int pointer) {
    GestureBinding.instance.pointerRouter.removeRoute(pointer, _onPointerRoute);
  }
}

abstract class UIGestureArenaManager {
  void hold(int pointer);
  void close(int pointer);
  void sweep(int pointer);
  void release(int pointer);
  GestureArenaEntry add(int pointer, GestureArenaMember member);
}

abstract class UIPointerSignalResolver {
  void resolve(PointerSignalEvent event);
  void register(
      PointerSignalEvent event, PointerSignalResolvedCallback callback);
}

abstract class UIPointerRouter {
  void route(PointerEvent event);
  void removeRoute(int pointer, PointerRoute route);
  void addRoute(int pointer, PointerRoute route, [Matrix4 transform]);
}

class _GestureArenaManager implements UIGestureArenaManager {
  final GestureArenaManager implement;
  _GestureArenaManager(this.implement) : assert(implement != null);
  void hold(int pointer) => implement.hold(pointer);
  void close(int pointer) => implement.close(pointer);
  void sweep(int pointer) => implement.sweep(pointer);
  void release(int pointer) => implement.release(pointer);
  GestureArenaEntry add(int pointer, GestureArenaMember member) =>
      implement.add(pointer, member);
}

class _PointerSignalResolver implements UIPointerSignalResolver {
  final PointerSignalResolver implement;
  _PointerSignalResolver(this.implement) : assert(implement != null);
  void resolve(PointerSignalEvent event) => implement.resolve(event);
  void register(
          PointerSignalEvent event, PointerSignalResolvedCallback callback) =>
      implement.register(event, callback);
}

class _GlobalPointerRouter implements UIPointerRouter {
  final PointerRouter implement;
  _GlobalPointerRouter(this.implement) : assert(implement != null);
  void route(PointerEvent event) => implement.route(event);
  void removeRoute(int pointer, PointerRoute route) =>
      implement.removeRoute(pointer, route);
  void addRoute(int pointer, PointerRoute route, [Matrix4 transform]) =>
      implement.addRoute(pointer, route, transform);
}

class _AlonePointerRouter implements UIPointerRouter {
  final void Function(int pointer) onAddRoute;
  final void Function(int pointer) onRemoveRoute;

  _AlonePointerRouter(this.onAddRoute, this.onRemoveRoute)
      : assert(onAddRoute != null),
        assert(onRemoveRoute != null);

  final Map<int, Map<PointerRoute, Matrix4>> _routeMap =
      <int, Map<PointerRoute, Matrix4>>{};

  void addRoute(int pointer, PointerRoute route, [Matrix4 transform]) {
    final Map<PointerRoute, Matrix4> routes = _routeMap.putIfAbsent(
      pointer,
      () {
        onAddRoute(pointer);
        return <PointerRoute, Matrix4>{};
      },
    );
    assert(!routes.containsKey(route));
    routes[route] = transform;
  }

  void removeRoute(int pointer, PointerRoute route) {
    assert(_routeMap.containsKey(pointer));
    final Map<PointerRoute, Matrix4> routes = _routeMap[pointer];
    assert(routes.containsKey(route));
    routes.remove(route);
    if (routes.isEmpty) {
      onRemoveRoute(pointer);
      _routeMap.remove(pointer);
    }
  }

  void _dispatch(PointerEvent event, PointerRoute route, Matrix4 transform) {
    try {
      event = event.transformed(transform);
      route(event);
    } catch (exception, stack) {
      InformationCollector collector;
      assert(() {
        collector = () sync* {
          yield DiagnosticsProperty<PointerEvent>('Event', event,
              style: DiagnosticsTreeStyle.errorProperty);
        };
        return true;
      }());
      FlutterError.reportError(FlutterErrorDetailsForUIPointerRouter(
          exception: exception,
          stack: stack,
          library: 'gesture library',
          context: ErrorDescription('while routing a pointer event'),
          router: this,
          route: route,
          event: event,
          informationCollector: collector));
    }
  }

  void route(PointerEvent event) {
    final Map<PointerRoute, Matrix4> routes = _routeMap[event.pointer];
    if (routes != null) {
      _dispatchEventToRoutes(
        event,
        routes,
        Map<PointerRoute, Matrix4>.from(routes),
      );
    }
  }

  void _dispatchEventToRoutes(
    PointerEvent event,
    Map<PointerRoute, Matrix4> referenceRoutes,
    Map<PointerRoute, Matrix4> copiedRoutes,
  ) {
    copiedRoutes.forEach((PointerRoute route, Matrix4 transform) {
      if (referenceRoutes.containsKey(route)) {
        _dispatch(event, route, transform);
      }
    });
  }
}

class FlutterErrorDetailsForUIPointerRouter extends FlutterErrorDetails {
  const FlutterErrorDetailsForUIPointerRouter({
    dynamic exception,
    StackTrace stack,
    String library,
    DiagnosticsNode context,
    this.router,
    this.route,
    this.event,
    InformationCollector informationCollector,
    bool silent = false,
  }) : super(
          exception: exception,
          stack: stack,
          library: library,
          context: context,
          informationCollector: informationCollector,
          silent: silent,
        );
  final UIPointerRouter router;
  final PointerRoute route;
  final PointerEvent event;
}
