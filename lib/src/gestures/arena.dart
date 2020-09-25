import 'package:flutter/widgets.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart';

class UIGestureBinding {
  UIGestureBinding();

  UIPointerRouter _pointerRouter;
  UIPointerRouter get pointerRouter => _pointerRouter ??=
      UIPointerRouter(onAddRoute: _onAddRoute, onRemoveRoute: _onRemoveRoute);

  final GestureArenaManager gestureArena = GestureArenaManager();
  final PointerSignalResolver pointerSignalResolver = PointerSignalResolver();

  void _onAddRoute(int pointer) {
    GestureBinding.instance.pointerRouter.addRoute(pointer, _onPointerRoute);
  }

  void _onPointerRoute(PointerEvent event) {
    pointerRouter.route(event);
    if (event is PointerDownEvent) {
      gestureArena.close(event.pointer);
    } else if (event is PointerUpEvent) {
      gestureArena.sweep(event.pointer);
    } else if (event is PointerSignalEvent) {
      pointerSignalResolver.resolve(event);
    }
  }

  void _onRemoveRoute(int pointer) {
    GestureBinding.instance.pointerRouter.removeRoute(pointer, _onPointerRoute);
  }
}

class UIGestureArena extends StatelessWidget {
  UIGestureArena({
    Key key,
    @required this.child,
    UIGestureBinding binding,
  })  : assert(child != null),
        gestureBinding = binding ?? UIGestureBinding(),
        super(key: key);

  final Widget child;
  final UIGestureBinding gestureBinding;

  static UIGestureBinding of(BuildContext context) {
    return _UIGestureArenaScope.of(context)?.gestureBinding;
  }

  @override
  Widget build(BuildContext context) {
    return _UIGestureArenaScope(
      child: child,
      gestureBinding: gestureBinding,
    );
  }
}

class _UIGestureArenaScope extends InheritedWidget {
  _UIGestureArenaScope({
    Key key,
    @required this.child,
    @required this.gestureBinding,
  })  : assert(child != null),
        assert(gestureBinding != null),
        super(key: key, child: child);

  final Widget child;
  final UIGestureBinding gestureBinding;

  static _UIGestureArenaScope of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<_UIGestureArenaScope>();
  }

  @override
  bool updateShouldNotify(_UIGestureArenaScope oldWidget) {
    return gestureBinding != oldWidget.gestureBinding;
  }
}

class UIPointerRouter {
  final void Function(int pointer) onAddRoute;
  final void Function(int pointer) onRemoveRoute;

  UIPointerRouter({this.onAddRoute, this.onRemoveRoute});

  final Map<int, Map<PointerRoute, Matrix4>> _routeMap =
      <int, Map<PointerRoute, Matrix4>>{};

  void addRoute(int pointer, PointerRoute route, [Matrix4 transform]) {
    final Map<PointerRoute, Matrix4> routes = _routeMap.putIfAbsent(
      pointer,
      () {
        if (onAddRoute != null) onAddRoute(pointer);
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
      _routeMap.remove(pointer);
      if (onRemoveRoute != null) onRemoveRoute(pointer);
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
          library: 'flutter_gestures library',
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

  final PointerRoute route;
  final PointerEvent event;
  final UIPointerRouter router;
}
