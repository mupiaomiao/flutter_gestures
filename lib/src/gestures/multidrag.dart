import 'dart:async';
import 'dart:ui' show Offset;
import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart';

import 'recognizer.dart';
import 'recognizer_extension.dart';

abstract class UIMultiDragPointerState {
  UIMultiDragPointerState(this.initialPosition)
      : assert(initialPosition != null);

  final Offset initialPosition;

  final VelocityTracker _velocityTracker = VelocityTracker();
  Drag _client;

  Offset get pendingDelta => _pendingDelta;
  Offset _pendingDelta = Offset.zero;

  Duration _lastPendingEventTimestamp;

  GestureArenaEntry _arenaEntry;
  void _setArenaEntry(GestureArenaEntry entry) {
    assert(_arenaEntry == null);
    assert(pendingDelta != null);
    assert(_client == null);
    _arenaEntry = entry;
  }

  @protected
  @mustCallSuper
  void resolve(GestureDisposition disposition) {
    _arenaEntry.resolve(disposition);
  }

  void _move(PointerMoveEvent event) {
    assert(_arenaEntry != null);
    if (!event.synthesized)
      _velocityTracker.addPosition(event.timeStamp, event.position);
    if (_client != null) {
      assert(pendingDelta == null);
      // Call client last to avoid reentrancy.
      _client.update(DragUpdateDetails(
        sourceTimeStamp: event.timeStamp,
        delta: event.delta,
        globalPosition: event.position,
      ));
    } else {
      assert(pendingDelta != null);
      _pendingDelta += event.delta;
      _lastPendingEventTimestamp = event.timeStamp;
      checkForResolutionAfterMove();
    }
  }

  @protected
  void checkForResolutionAfterMove() {}

  @protected
  void accepted(GestureMultiDragStartCallback starter);

  @protected
  @mustCallSuper
  void rejected() {
    assert(_arenaEntry != null);
    assert(_client == null);
    assert(pendingDelta != null);
    _pendingDelta = null;
    _lastPendingEventTimestamp = null;
    _arenaEntry = null;
  }

  void _startDrag(Drag client) {
    assert(_arenaEntry != null);
    assert(_client == null);
    assert(client != null);
    assert(pendingDelta != null);
    _client = client;
    final DragUpdateDetails details = DragUpdateDetails(
      sourceTimeStamp: _lastPendingEventTimestamp,
      delta: pendingDelta,
      globalPosition: initialPosition,
    );
    _pendingDelta = null;
    _lastPendingEventTimestamp = null;
    // Call client last to avoid reentrancy.
    _client.update(details);
  }

  void _up() {
    assert(_arenaEntry != null);
    if (_client != null) {
      assert(pendingDelta == null);
      final DragEndDetails details =
          DragEndDetails(velocity: _velocityTracker.getVelocity());
      final Drag client = _client;
      _client = null;
      // Call client last to avoid reentrancy.
      client.end(details);
    } else {
      assert(pendingDelta != null);
      _pendingDelta = null;
      _lastPendingEventTimestamp = null;
    }
  }

  void _cancel() {
    assert(_arenaEntry != null);
    if (_client != null) {
      assert(pendingDelta == null);
      final Drag client = _client;
      _client = null;
      // Call client last to avoid reentrancy.
      client.cancel();
    } else {
      assert(pendingDelta != null);
      _pendingDelta = null;
      _lastPendingEventTimestamp = null;
    }
  }

  /// Releases any resources used by the object.
  @protected
  @mustCallSuper
  void dispose() {
    _arenaEntry?.resolve(GestureDisposition.rejected);
    _arenaEntry = null;
    assert(() {
      _pendingDelta = null;
      return true;
    }());
  }
}

abstract class UIMultiDragGestureRecognizer<T extends UIMultiDragPointerState>
    extends UIGestureRecognizer {
  UIMultiDragGestureRecognizer({
    PointerDeviceKind kind,
    @required Object debugOwner,
  }) : super(kind: kind, debugOwner: debugOwner);

  GestureMultiDragStartCallback onStart;

  Map<int, T> _pointers = <int, T>{};

  @override
  void addAllowedPointer(PointerDownEvent event) {
    assert(_pointers != null);
    assert(event.pointer != null);
    assert(event.position != null);
    assert(!_pointers.containsKey(event.pointer));
    final T state = createNewPointerState(event);
    _pointers[event.pointer] = state;
    gestureBinding.pointerRouter.addRoute(event.pointer, _handleEvent);
    state._setArenaEntry(gestureBinding.gestureArena.add(event.pointer, this));
  }

  @protected
  @factory
  T createNewPointerState(PointerDownEvent event);

  void _handleEvent(PointerEvent event) {
    assert(_pointers != null);
    assert(event.pointer != null);
    assert(event.timeStamp != null);
    assert(event.position != null);
    assert(_pointers.containsKey(event.pointer));
    final T state = _pointers[event.pointer];
    if (event is PointerMoveEvent) {
      state._move(event);
    } else if (event is PointerUpEvent) {
      assert(event.delta == Offset.zero);
      state._up();
      _removeState(event.pointer);
    } else if (event is PointerCancelEvent) {
      assert(event.delta == Offset.zero);
      state._cancel();
      _removeState(event.pointer);
    } else if (event is! PointerDownEvent) {
      assert(false);
    }
  }

  @override
  void acceptGesture(int pointer) {
    assert(_pointers != null);
    final T state = _pointers[pointer];
    if (state == null) return;
    state.accepted(
        (Offset initialPosition) => _startDrag(initialPosition, pointer));
  }

  Drag _startDrag(Offset initialPosition, int pointer) {
    assert(_pointers != null);
    final T state = _pointers[pointer];
    assert(state != null);
    assert(state._pendingDelta != null);
    Drag drag;
    if (onStart != null)
      drag = invokeCallback<Drag>('onStart', () => onStart(initialPosition));
    if (drag != null) {
      state._startDrag(drag);
    } else {
      _removeState(pointer);
    }
    return drag;
  }

  @override
  void rejectGesture(int pointer) {
    assert(_pointers != null);
    if (_pointers.containsKey(pointer)) {
      final T state = _pointers[pointer];
      assert(state != null);
      state.rejected();
      _removeState(pointer);
    } // else we already preemptively forgot about it (e.g. we got an up event)
  }

  void _removeState(int pointer) {
    if (_pointers == null) {
      return;
    }
    assert(_pointers.containsKey(pointer));
    gestureBinding.pointerRouter.removeRoute(pointer, _handleEvent);
    _pointers.remove(pointer).dispose();
  }

  @override
  void dispose() {
    _pointers.keys.toList().forEach(_removeState);
    assert(_pointers.isEmpty);
    _pointers = null;
    super.dispose();
  }
}

class _ImmediatePointerState extends UIMultiDragPointerState {
  _ImmediatePointerState(Offset initialPosition) : super(initialPosition);

  @override
  void checkForResolutionAfterMove() {
    assert(pendingDelta != null);
    if (pendingDelta.distance > kTouchSlop)
      resolve(GestureDisposition.accepted);
  }

  @override
  void accepted(GestureMultiDragStartCallback starter) {
    starter(initialPosition);
  }
}

class UIImmediateMultiDragGestureRecognizer
    extends UIMultiDragGestureRecognizer<_ImmediatePointerState> {
  UIImmediateMultiDragGestureRecognizer({
    Object debugOwner,
    PointerDeviceKind kind,
  }) : super(kind: kind, debugOwner: debugOwner);

  @override
  _ImmediatePointerState createNewPointerState(PointerDownEvent event) {
    return _ImmediatePointerState(event.position);
  }

  @override
  String get debugDescription => 'multidrag';
}

class _HorizontalPointerState extends UIMultiDragPointerState {
  _HorizontalPointerState(Offset initialPosition) : super(initialPosition);

  @override
  void checkForResolutionAfterMove() {
    assert(pendingDelta != null);
    if (pendingDelta.dx.abs() > kTouchSlop)
      resolve(GestureDisposition.accepted);
  }

  @override
  void accepted(GestureMultiDragStartCallback starter) {
    starter(initialPosition);
  }
}

class UIHorizontalMultiDragGestureRecognizer
    extends UIMultiDragGestureRecognizer<_HorizontalPointerState> {
  UIHorizontalMultiDragGestureRecognizer({
    Object debugOwner,
    PointerDeviceKind kind,
  }) : super(kind: kind, debugOwner: debugOwner);

  @override
  _HorizontalPointerState createNewPointerState(PointerDownEvent event) {
    return _HorizontalPointerState(event.position);
  }

  @override
  String get debugDescription => 'horizontal multidrag';
}

class _VerticalPointerState extends UIMultiDragPointerState {
  _VerticalPointerState(Offset initialPosition) : super(initialPosition);

  @override
  void checkForResolutionAfterMove() {
    assert(pendingDelta != null);
    if (pendingDelta.dy.abs() > kTouchSlop)
      resolve(GestureDisposition.accepted);
  }

  @override
  void accepted(GestureMultiDragStartCallback starter) {
    starter(initialPosition);
  }
}

class UIVerticalMultiDragGestureRecognizer
    extends UIMultiDragGestureRecognizer<_VerticalPointerState> {
  UIVerticalMultiDragGestureRecognizer({
    Object debugOwner,
    PointerDeviceKind kind,
  }) : super(kind: kind, debugOwner: debugOwner);

  @override
  _VerticalPointerState createNewPointerState(PointerDownEvent event) {
    return _VerticalPointerState(event.position);
  }

  @override
  String get debugDescription => 'vertical multidrag';
}

class _DelayedPointerState extends UIMultiDragPointerState {
  _DelayedPointerState(Offset initialPosition, Duration delay)
      : assert(delay != null),
        super(initialPosition) {
    _timer = Timer(delay, _delayPassed);
  }

  Timer _timer;
  GestureMultiDragStartCallback _starter;

  void _delayPassed() {
    assert(_timer != null);
    assert(pendingDelta != null);
    assert(pendingDelta.distance <= kTouchSlop);
    _timer = null;
    if (_starter != null) {
      _starter(initialPosition);
      _starter = null;
    } else {
      resolve(GestureDisposition.accepted);
    }
    assert(_starter == null);
  }

  void _ensureTimerStopped() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void accepted(GestureMultiDragStartCallback starter) {
    assert(_starter == null);
    if (_timer == null)
      starter(initialPosition);
    else
      _starter = starter;
  }

  @override
  void checkForResolutionAfterMove() {
    if (_timer == null) {
      assert(_starter != null);
      return;
    }
    assert(pendingDelta != null);
    if (pendingDelta.distance > kTouchSlop) {
      resolve(GestureDisposition.rejected);
      _ensureTimerStopped();
    }
  }

  @override
  void dispose() {
    _ensureTimerStopped();
    super.dispose();
  }
}

class UIDelayedMultiDragGestureRecognizer
    extends UIMultiDragGestureRecognizer<_DelayedPointerState> {
  UIDelayedMultiDragGestureRecognizer({
    Object debugOwner,
    PointerDeviceKind kind,
    this.delay = kLongPressTimeout,
  })  : assert(delay != null),
        super(kind: kind, debugOwner: debugOwner);

  final Duration delay;

  @override
  _DelayedPointerState createNewPointerState(PointerDownEvent event) {
    return _DelayedPointerState(event.position, delay);
  }

  @override
  String get debugDescription => 'long multidrag';
}
