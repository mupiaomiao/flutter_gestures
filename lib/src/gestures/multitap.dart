import 'dart:async';
import 'dart:ui' show Offset;
import 'package:flutter/gestures.dart';
import 'package:vector_math/vector_math_64.dart';
import 'package:flutter/foundation.dart' show required;

import 'arena.dart';
import 'recognizer.dart';
import 'recognizer_extension.dart';

class _CountdownZoned {
  _CountdownZoned({@required Duration duration}) : assert(duration != null) {
    Timer(duration, _onTimeout);
  }

  bool _timeout = false;

  bool get timeout => _timeout;

  void _onTimeout() {
    _timeout = true;
  }
}

class _TapTracker {
  _TapTracker(
    this.gestureBinding, {
    @required PointerDownEvent event,
    this.entry,
    @required Duration doubleTapMinTime,
  })  : assert(gestureBinding != null),
        assert(doubleTapMinTime != null),
        assert(event != null),
        assert(event.buttons != null),
        pointer = event.pointer,
        _initialGlobalPosition = event.position,
        initialButtons = event.buttons,
        _doubleTapMinTimeCountdown =
            _CountdownZoned(duration: doubleTapMinTime);

  final int pointer;
  final GestureArenaEntry entry;
  final Offset _initialGlobalPosition;
  final int initialButtons;
  final _CountdownZoned _doubleTapMinTimeCountdown;
  final UIGestureBinding gestureBinding;

  bool _isTrackingPointer = false;

  void startTrackingPointer(PointerRoute route, Matrix4 transform) {
    if (!_isTrackingPointer) {
      _isTrackingPointer = true;
      gestureBinding.pointerRouter.addRoute(pointer, route, transform);
    }
  }

  void stopTrackingPointer(PointerRoute route) {
    if (_isTrackingPointer) {
      _isTrackingPointer = false;
      gestureBinding.pointerRouter.removeRoute(pointer, route);
    }
  }

  bool isWithinGlobalTolerance(PointerEvent event, double tolerance) {
    final Offset offset = event.position - _initialGlobalPosition;
    return offset.distance <= tolerance;
  }

  bool hasElapsedMinTime() {
    return _doubleTapMinTimeCountdown.timeout;
  }

  bool hasSameButton(PointerDownEvent event) {
    return event.buttons == initialButtons;
  }
}

class UIDoubleTapGestureRecognizer extends UIGestureRecognizer {
  UIDoubleTapGestureRecognizer({
    Object debugOwner,
    PointerDeviceKind kind,
  }) : super(kind: kind, debugOwner: debugOwner);

  GestureDoubleTapCallback onDoubleTap;

  Timer _doubleTapTimer;
  _TapTracker _firstTap;
  final Map<int, _TapTracker> _trackers = <int, _TapTracker>{};

  @override
  bool isPointerAllowed(PointerEvent event) {
    if (_firstTap == null) {
      switch (event.buttons) {
        case kPrimaryButton:
          if (onDoubleTap == null) return false;
          break;
        default:
          return false;
      }
    }
    return super.isPointerAllowed(event as PointerDownEvent);
  }

  @override
  void addAllowedPointer(PointerEvent event) {
    if (_firstTap != null) {
      if (!_firstTap.isWithinGlobalTolerance(event, kDoubleTapSlop)) {
        return;
      } else if (!_firstTap.hasElapsedMinTime() ||
          !_firstTap.hasSameButton(event as PointerDownEvent)) {
        _reset();
        return _trackFirstTap(event);
      }
    }
    _trackFirstTap(event);
  }

  void _trackFirstTap(PointerEvent event) {
    _stopDoubleTapTimer();
    final _TapTracker tracker = _TapTracker(
      gestureBinding,
      event: event as PointerDownEvent,
      doubleTapMinTime: kDoubleTapMinTime,
      entry: gestureBinding.gestureArena.add(event.pointer, this),
    );
    _trackers[event.pointer] = tracker;
    tracker.startTrackingPointer(_handleEvent, event.transform);
  }

  void _handleEvent(PointerEvent event) {
    final _TapTracker tracker = _trackers[event.pointer];
    assert(tracker != null);
    if (event is PointerUpEvent) {
      if (_firstTap == null)
        _registerFirstTap(tracker);
      else
        _registerSecondTap(tracker);
    } else if (event is PointerMoveEvent) {
      if (!tracker.isWithinGlobalTolerance(event, kDoubleTapTouchSlop))
        _reject(tracker);
    } else if (event is PointerCancelEvent) {
      _reject(tracker);
    }
  }

  @override
  void acceptGesture(int pointer) {}

  @override
  void rejectGesture(int pointer) {
    _TapTracker tracker = _trackers[pointer];
    // If tracker isn't in the list, check if this is the first tap tracker
    if (tracker == null && _firstTap != null && _firstTap.pointer == pointer)
      tracker = _firstTap;
    // If tracker is still null, we rejected ourselves already
    if (tracker != null) _reject(tracker);
  }

  void _reject(_TapTracker tracker) {
    _trackers.remove(tracker.pointer);
    tracker.entry.resolve(GestureDisposition.rejected);
    _freezeTracker(tracker);
    if (_firstTap != null && (_trackers.isEmpty || tracker == _firstTap))
      _reset();
  }

  @override
  void dispose() {
    _reset();
    super.dispose();
  }

  void _reset() {
    _stopDoubleTapTimer();
    if (_firstTap != null) {
      final _TapTracker tracker = _firstTap;
      _firstTap = null;
      _reject(tracker);
      gestureBinding.gestureArena.release(tracker.pointer);
    }
    _clearTrackers();
  }

  void _registerFirstTap(_TapTracker tracker) {
    _startDoubleTapTimer();
    gestureBinding.gestureArena.hold(tracker.pointer);
    _freezeTracker(tracker);
    _trackers.remove(tracker.pointer);
    _clearTrackers();
    _firstTap = tracker;
  }

  void _registerSecondTap(_TapTracker tracker) {
    _firstTap.entry.resolve(GestureDisposition.accepted);
    tracker.entry.resolve(GestureDisposition.accepted);
    _freezeTracker(tracker);
    _trackers.remove(tracker.pointer);
    _checkUp(tracker.initialButtons);
    _reset();
  }

  void _clearTrackers() {
    _trackers.values.toList().forEach(_reject);
    assert(_trackers.isEmpty);
  }

  void _freezeTracker(_TapTracker tracker) {
    tracker.stopTrackingPointer(_handleEvent);
  }

  void _startDoubleTapTimer() {
    _doubleTapTimer ??= Timer(kDoubleTapTimeout, _reset);
  }

  void _stopDoubleTapTimer() {
    if (_doubleTapTimer != null) {
      _doubleTapTimer.cancel();
      _doubleTapTimer = null;
    }
  }

  void _checkUp(int buttons) {
    assert(buttons == kPrimaryButton);
    if (onDoubleTap != null) invokeCallback<void>('onDoubleTap', onDoubleTap);
  }

  @override
  String get debugDescription => 'double tap';
}

class _TapGesture extends _TapTracker {
  _TapGesture(
    UIGestureBinding gestureBinding, {
    this.gestureRecognizer,
    PointerEvent event,
    Duration longTapDelay,
  })  : assert(gestureBinding != null),
        _lastPosition = OffsetPair.fromEventPosition(event),
        super(
          gestureBinding,
          event: event as PointerDownEvent,
          doubleTapMinTime: kDoubleTapMinTime,
          entry:
              gestureBinding.gestureArena.add(event.pointer, gestureRecognizer),
        ) {
    startTrackingPointer(handleEvent, event.transform);
    if (longTapDelay > Duration.zero) {
      _timer = Timer(longTapDelay, () {
        _timer = null;
        gestureRecognizer._dispatchLongTap(event.pointer, _lastPosition);
      });
    }
  }

  final UIMultiTapGestureRecognizer gestureRecognizer;

  bool _wonArena = false;
  Timer _timer;

  OffsetPair _lastPosition;
  OffsetPair _finalPosition;

  void handleEvent(PointerEvent event) {
    assert(event.pointer == pointer);
    if (event is PointerMoveEvent) {
      if (!isWithinGlobalTolerance(event, kTouchSlop))
        cancel();
      else
        _lastPosition = OffsetPair.fromEventPosition(event);
    } else if (event is PointerCancelEvent) {
      cancel();
    } else if (event is PointerUpEvent) {
      stopTrackingPointer(handleEvent);
      _finalPosition = OffsetPair.fromEventPosition(event);
      _check();
    }
  }

  @override
  void stopTrackingPointer(PointerRoute route) {
    _timer?.cancel();
    _timer = null;
    super.stopTrackingPointer(route);
  }

  void accept() {
    _wonArena = true;
    _check();
  }

  void reject() {
    stopTrackingPointer(handleEvent);
    gestureRecognizer._dispatchCancel(pointer);
  }

  void cancel() {
    if (_wonArena)
      reject();
    else
      entry.resolve(GestureDisposition.rejected);
  }

  void _check() {
    if (_wonArena && _finalPosition != null)
      gestureRecognizer._dispatchTap(pointer, _finalPosition);
  }
}

class UIMultiTapGestureRecognizer extends UIGestureRecognizer {
  UIMultiTapGestureRecognizer({
    Object debugOwner,
    PointerDeviceKind kind,
    this.longTapDelay = Duration.zero,
  }) : super(kind: kind, debugOwner: debugOwner);

  GestureMultiTapDownCallback onTapDown;

  GestureMultiTapUpCallback onTapUp;

  GestureMultiTapCallback onTap;

  GestureMultiTapCancelCallback onTapCancel;

  Duration longTapDelay;

  GestureMultiTapDownCallback onLongTapDown;

  final Map<int, _TapGesture> _gestureMap = <int, _TapGesture>{};

  @override
  void addAllowedPointer(PointerEvent event) {
    assert(!_gestureMap.containsKey(event.pointer));
    _gestureMap[event.pointer] = _TapGesture(
      gestureBinding,
      gestureRecognizer: this,
      event: event,
      longTapDelay: longTapDelay,
    );
    if (onTapDown != null)
      invokeCallback<void>('onTapDown', () {
        onTapDown(
            event.pointer,
            TapDownDetails(
              globalPosition: event.position,
              localPosition: event.localPosition,
              kind: event.kind,
            ));
      });
  }

  @override
  void acceptGesture(int pointer) {
    assert(_gestureMap.containsKey(pointer));
    _gestureMap[pointer].accept();
  }

  @override
  void rejectGesture(int pointer) {
    assert(_gestureMap.containsKey(pointer));
    _gestureMap[pointer].reject();
    assert(!_gestureMap.containsKey(pointer));
  }

  void _dispatchCancel(int pointer) {
    assert(_gestureMap.containsKey(pointer));
    _gestureMap.remove(pointer);
    if (onTapCancel != null)
      invokeCallback<void>('onTapCancel', () => onTapCancel(pointer));
  }

  void _dispatchTap(int pointer, OffsetPair position) {
    assert(_gestureMap.containsKey(pointer));
    _gestureMap.remove(pointer);
    if (onTapUp != null)
      invokeCallback<void>('onTapUp', () {
        onTapUp(
            pointer,
            TapUpDetails(
              localPosition: position.local,
              globalPosition: position.global,
            ));
      });
    if (onTap != null) invokeCallback<void>('onTap', () => onTap(pointer));
  }

  void _dispatchLongTap(int pointer, OffsetPair lastPosition) {
    assert(_gestureMap.containsKey(pointer));
    if (onLongTapDown != null)
      invokeCallback<void>('onLongTapDown', () {
        onLongTapDown(
          pointer,
          TapDownDetails(
            globalPosition: lastPosition.global,
            localPosition: lastPosition.local,
            kind: getKindForPointer(pointer),
          ),
        );
      });
  }

  @override
  void dispose() {
    final List<_TapGesture> localGestures =
        List<_TapGesture>.from(_gestureMap.values);
    for (final _TapGesture gesture in localGestures) gesture.cancel();
    assert(_gestureMap.isEmpty);
    super.dispose();
  }

  @override
  String get debugDescription => 'multitap';
}
