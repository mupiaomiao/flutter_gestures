import 'dart:async';
import 'dart:collection';
import 'package:flutter/widgets.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart';

import 'team.dart';
import 'arena.dart';

abstract class UIGestureRecognizer extends GestureRecognizer {
  UIGestureRecognizer({
    Object debugOwner,
    PointerDeviceKind kind,
    UIGestureArena gestureArena,
  })  : _gestureArena = gestureArena ?? UIGestureArena.globalArena,
        super(kind: kind, debugOwner: debugOwner);

  UIGestureArena _gestureArena;
  UIGestureArena get gestureArena => _gestureArena;
}

abstract class UIOneSequenceGestureRecognizer extends UIGestureRecognizer {
  UIOneSequenceGestureRecognizer({
    Object debugOwner,
    PointerDeviceKind kind,
    UIGestureArena gestureArena,
  }) : super(kind: kind, debugOwner: debugOwner, gestureArena: gestureArena);

  final Map<int, GestureArenaEntry> _entries = <int, GestureArenaEntry>{};
  final Set<int> _trackedPointers = HashSet<int>();

  @override
  void handleNonAllowedPointer(PointerDownEvent event) {
    resolve(GestureDisposition.rejected);
  }

  @protected
  void handleEvent(PointerEvent event);

  @override
  void acceptGesture(int pointer) {}

  @override
  void rejectGesture(int pointer) {}

  @protected
  void didStopTrackingLastPointer(int pointer);

  @protected
  @mustCallSuper
  void resolve(GestureDisposition disposition) {
    final List<GestureArenaEntry> localEntries =
        List<GestureArenaEntry>.from(_entries.values);
    _entries.clear();
    for (final GestureArenaEntry entry in localEntries)
      entry.resolve(disposition);
  }

  @protected
  @mustCallSuper
  void resolvePointer(int pointer, GestureDisposition disposition) {
    final GestureArenaEntry entry = _entries[pointer];
    if (entry != null) {
      entry.resolve(disposition);
      _entries.remove(pointer);
    }
  }

  @override
  void dispose() {
    resolve(GestureDisposition.rejected);
    for (final int pointer in _trackedPointers) {
      gestureArena.pointerRouter.removeRoute(pointer, handleEvent);
    }
    _trackedPointers.clear();
    assert(_entries.isEmpty);
    super.dispose();
  }

  UIGestureArenaTeam _team;
  UIGestureArenaTeam get team => _team;
  set team(UIGestureArenaTeam value) {
    assert(value != null);
    assert(_entries.isEmpty);
    assert(_trackedPointers.isEmpty);
    assert(_team == null);
    _team = value;
  }

  GestureArenaEntry _addPointerToArena(int pointer) {
    if (_team != null) return _team.add(pointer, this);
    return gestureArena.manager.add(pointer, this);
  }

  @protected
  void startTrackingPointer(int pointer, [Matrix4 transform]) {
    gestureArena.pointerRouter.addRoute(pointer, handleEvent, transform);
    _trackedPointers.add(pointer);
    assert(!_entries.containsValue(pointer));
    _entries[pointer] = _addPointerToArena(pointer);
  }

  @protected
  void stopTrackingPointer(int pointer) {
    if (_trackedPointers.contains(pointer)) {
      gestureArena.pointerRouter.removeRoute(pointer, handleEvent);
      _trackedPointers.remove(pointer);
      if (_trackedPointers.isEmpty) didStopTrackingLastPointer(pointer);
    }
  }

  @protected
  void stopTrackingIfPointerNoLongerDown(PointerEvent event) {
    if (event is PointerUpEvent || event is PointerCancelEvent)
      stopTrackingPointer(event.pointer);
  }
}

abstract class UIPrimaryPointerGestureRecognizer
    extends UIOneSequenceGestureRecognizer {
  UIPrimaryPointerGestureRecognizer({
    this.deadline,
    this.preAcceptSlopTolerance = kTouchSlop,
    this.postAcceptSlopTolerance = kTouchSlop,
    Object debugOwner,
    PointerDeviceKind kind,
    UIGestureArena gestureArena,
  })  : assert(
          preAcceptSlopTolerance == null || preAcceptSlopTolerance >= 0,
          'The preAcceptSlopTolerance must be positive or null',
        ),
        assert(
          postAcceptSlopTolerance == null || postAcceptSlopTolerance >= 0,
          'The postAcceptSlopTolerance must be positive or null',
        ),
        super(kind: kind, debugOwner: debugOwner, gestureArena: gestureArena);

  final Duration deadline;

  final double preAcceptSlopTolerance;

  final double postAcceptSlopTolerance;

  GestureRecognizerState state = GestureRecognizerState.ready;

  int primaryPointer;

  OffsetPair initialPosition;

  bool _gestureAccepted = false;
  Timer _timer;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    startTrackingPointer(event.pointer, event.transform);
    if (state == GestureRecognizerState.ready) {
      state = GestureRecognizerState.possible;
      primaryPointer = event.pointer;
      initialPosition =
          OffsetPair(local: event.localPosition, global: event.position);
      if (deadline != null)
        _timer = Timer(deadline, () => didExceedDeadlineWithEvent(event));
    }
  }

  @override
  void handleEvent(PointerEvent event) {
    assert(state != GestureRecognizerState.ready);
    if (state == GestureRecognizerState.possible &&
        event.pointer == primaryPointer) {
      final bool isPreAcceptSlopPastTolerance = !_gestureAccepted &&
          preAcceptSlopTolerance != null &&
          _getGlobalDistance(event) > preAcceptSlopTolerance;
      final bool isPostAcceptSlopPastTolerance = _gestureAccepted &&
          postAcceptSlopTolerance != null &&
          _getGlobalDistance(event) > postAcceptSlopTolerance;

      if (event is PointerMoveEvent &&
          (isPreAcceptSlopPastTolerance || isPostAcceptSlopPastTolerance)) {
        resolve(GestureDisposition.rejected);
        stopTrackingPointer(primaryPointer);
      } else {
        handlePrimaryPointer(event);
      }
    }
    stopTrackingIfPointerNoLongerDown(event);
  }

  @protected
  void handlePrimaryPointer(PointerEvent event);

  @protected
  void didExceedDeadline() {
    assert(deadline == null);
  }

  @protected
  void didExceedDeadlineWithEvent(PointerDownEvent event) {
    didExceedDeadline();
  }

  @override
  void acceptGesture(int pointer) {
    if (pointer == primaryPointer) {
      _stopTimer();
      _gestureAccepted = true;
    }
  }

  @override
  void rejectGesture(int pointer) {
    if (pointer == primaryPointer && state == GestureRecognizerState.possible) {
      _stopTimer();
      state = GestureRecognizerState.defunct;
    }
  }

  @override
  void didStopTrackingLastPointer(int pointer) {
    assert(state != GestureRecognizerState.ready);
    _stopTimer();
    state = GestureRecognizerState.ready;
  }

  @override
  void dispose() {
    _stopTimer();
    super.dispose();
  }

  void _stopTimer() {
    if (_timer != null) {
      _timer.cancel();
      _timer = null;
    }
  }

  double _getGlobalDistance(PointerEvent event) {
    final Offset offset = event.position - initialPosition.global;
    return offset.distance;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(EnumProperty<GestureRecognizerState>('state', state));
  }
}
