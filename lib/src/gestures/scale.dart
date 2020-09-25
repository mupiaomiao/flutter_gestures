import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:vector_math/vector_math_64.dart';

import 'recognizer.dart';

enum _ScaleState {
  /// The recognizer is ready to start recognizing a gesture.
  ready,

  /// The sequence of pointer events seen thus far is consistent with a scale
  /// gesture but the gesture has not been accepted definitively.
  possible,

  /// The sequence of pointer events seen thus far has been accepted
  /// definitively as a scale gesture.
  accepted,

  /// The sequence of pointer events seen thus far has been accepted
  /// definitively as a scale gesture and the pointers established a focal point
  /// and initial scale.
  started,
}

bool _isFlingGesture(Velocity velocity) {
  assert(velocity != null);
  final double speedSquared = velocity.pixelsPerSecond.distanceSquared;
  return speedSquared > kMinFlingVelocity * kMinFlingVelocity;
}

class _LineBetweenPointers {
  /// Creates a [_LineBetweenPointers]. None of the [pointerStartLocation], [pointerStartId]
  /// [pointerEndLocation] and [pointerEndId] must be null. [pointerStartId] and [pointerEndId]
  /// should be different.
  _LineBetweenPointers({
    this.pointerStartLocation = Offset.zero,
    this.pointerStartId = 0,
    this.pointerEndLocation = Offset.zero,
    this.pointerEndId = 1,
  })  : assert(pointerStartLocation != null && pointerEndLocation != null),
        assert(pointerStartId != null && pointerEndId != null),
        assert(pointerStartId != pointerEndId);

  // The location and the id of the pointer that marks the start of the line.
  final Offset pointerStartLocation;
  final int pointerStartId;

  // The location and the id of the pointer that marks the end of the line.
  final Offset pointerEndLocation;
  final int pointerEndId;
}

class UIScaleGestureRecognizer extends UIOneSequenceGestureRecognizer {
  UIScaleGestureRecognizer({
    Object debugOwner,
    PointerDeviceKind kind,
  }) : super(kind: kind, debugOwner: debugOwner);

  GestureScaleStartCallback onStart;

  GestureScaleUpdateCallback onUpdate;

  GestureScaleEndCallback onEnd;

  _ScaleState _state = _ScaleState.ready;

  Matrix4 _lastTransform;

  Offset _initialFocalPoint;
  Offset _currentFocalPoint;
  double _initialSpan;
  double _currentSpan;
  double _initialHorizontalSpan;
  double _currentHorizontalSpan;
  double _initialVerticalSpan;
  double _currentVerticalSpan;
  _LineBetweenPointers _initialLine;
  _LineBetweenPointers _currentLine;
  Map<int, Offset> _pointerLocations;
  List<int> _pointerQueue; // A queue to sort pointers in order of entrance
  final Map<int, VelocityTracker> _velocityTrackers = <int, VelocityTracker>{};

  double get _scaleFactor =>
      _initialSpan > 0.0 ? _currentSpan / _initialSpan : 1.0;

  double get _horizontalScaleFactor => _initialHorizontalSpan > 0.0
      ? _currentHorizontalSpan / _initialHorizontalSpan
      : 1.0;

  double get _verticalScaleFactor => _initialVerticalSpan > 0.0
      ? _currentVerticalSpan / _initialVerticalSpan
      : 1.0;

  double _computeRotationFactor() {
    if (_initialLine == null || _currentLine == null) {
      return 0.0;
    }
    final double fx = _initialLine.pointerStartLocation.dx;
    final double fy = _initialLine.pointerStartLocation.dy;
    final double sx = _initialLine.pointerEndLocation.dx;
    final double sy = _initialLine.pointerEndLocation.dy;

    final double nfx = _currentLine.pointerStartLocation.dx;
    final double nfy = _currentLine.pointerStartLocation.dy;
    final double nsx = _currentLine.pointerEndLocation.dx;
    final double nsy = _currentLine.pointerEndLocation.dy;

    final double angle1 = math.atan2(fy - sy, fx - sx);
    final double angle2 = math.atan2(nfy - nsy, nfx - nsx);

    return angle2 - angle1;
  }

  @override
  void addAllowedPointer(PointerEvent event) {
    startTrackingPointer(event.pointer, event.transform);
    _velocityTrackers[event.pointer] = VelocityTracker();
    if (_state == _ScaleState.ready) {
      _state = _ScaleState.possible;
      _initialSpan = 0.0;
      _currentSpan = 0.0;
      _initialHorizontalSpan = 0.0;
      _currentHorizontalSpan = 0.0;
      _initialVerticalSpan = 0.0;
      _currentVerticalSpan = 0.0;
      _pointerLocations = <int, Offset>{};
      _pointerQueue = <int>[];
    }
  }

  @override
  void handleEvent(PointerEvent event) {
    assert(_state != _ScaleState.ready);
    bool didChangeConfiguration = false;
    bool shouldStartIfAccepted = false;
    if (event is PointerMoveEvent) {
      final VelocityTracker tracker = _velocityTrackers[event.pointer];
      assert(tracker != null);
      if (!event.synthesized)
        tracker.addPosition(event.timeStamp, event.position);
      _pointerLocations[event.pointer] = event.position;
      shouldStartIfAccepted = true;
      _lastTransform = event.transform;
    } else if (event is PointerDownEvent) {
      _pointerLocations[event.pointer] = event.position;
      _pointerQueue.add(event.pointer);
      didChangeConfiguration = true;
      shouldStartIfAccepted = true;
      _lastTransform = event.transform;
    } else if (event is PointerUpEvent || event is PointerCancelEvent) {
      _pointerLocations.remove(event.pointer);
      _pointerQueue.remove(event.pointer);
      didChangeConfiguration = true;
      _lastTransform = event.transform;
    }

    _updateLines();
    _update();

    if (!didChangeConfiguration || _reconfigure(event.pointer))
      _advanceStateMachine(shouldStartIfAccepted);
    stopTrackingIfPointerNoLongerDown(event);
  }

  void _update() {
    final int count = _pointerLocations.keys.length;

    // Compute the focal point
    Offset focalPoint = Offset.zero;
    for (final int pointer in _pointerLocations.keys)
      focalPoint += _pointerLocations[pointer];
    _currentFocalPoint =
        count > 0 ? focalPoint / count.toDouble() : Offset.zero;

    double totalDeviation = 0.0;
    double totalHorizontalDeviation = 0.0;
    double totalVerticalDeviation = 0.0;
    for (final int pointer in _pointerLocations.keys) {
      totalDeviation +=
          (_currentFocalPoint - _pointerLocations[pointer]).distance;
      totalHorizontalDeviation +=
          (_currentFocalPoint.dx - _pointerLocations[pointer].dx).abs();
      totalVerticalDeviation +=
          (_currentFocalPoint.dy - _pointerLocations[pointer].dy).abs();
    }
    _currentSpan = count > 0 ? totalDeviation / count : 0.0;
    _currentHorizontalSpan = count > 0 ? totalHorizontalDeviation / count : 0.0;
    _currentVerticalSpan = count > 0 ? totalVerticalDeviation / count : 0.0;
  }

  void _updateLines() {
    final int count = _pointerLocations.keys.length;
    assert(_pointerQueue.length >= count);

    if (count < 2) {
      _initialLine = _currentLine;
    } else if (_initialLine != null &&
        _initialLine.pointerStartId == _pointerQueue[0] &&
        _initialLine.pointerEndId == _pointerQueue[1]) {
      /// Rotation updated, set the [_currentLine]
      _currentLine = _LineBetweenPointers(
        pointerStartId: _pointerQueue[0],
        pointerStartLocation: _pointerLocations[_pointerQueue[0]],
        pointerEndId: _pointerQueue[1],
        pointerEndLocation: _pointerLocations[_pointerQueue[1]],
      );
    } else {
      /// A new rotation process is on the way, set the [_initialLine]
      _initialLine = _LineBetweenPointers(
        pointerStartId: _pointerQueue[0],
        pointerStartLocation: _pointerLocations[_pointerQueue[0]],
        pointerEndId: _pointerQueue[1],
        pointerEndLocation: _pointerLocations[_pointerQueue[1]],
      );
      _currentLine = null;
    }
  }

  bool _reconfigure(int pointer) {
    _initialFocalPoint = _currentFocalPoint;
    _initialSpan = _currentSpan;
    _initialLine = _currentLine;
    _initialHorizontalSpan = _currentHorizontalSpan;
    _initialVerticalSpan = _currentVerticalSpan;
    if (_state == _ScaleState.started) {
      if (onEnd != null) {
        final VelocityTracker tracker = _velocityTrackers[pointer];
        assert(tracker != null);

        Velocity velocity = tracker.getVelocity();
        if (_isFlingGesture(velocity)) {
          final Offset pixelsPerSecond = velocity.pixelsPerSecond;
          if (pixelsPerSecond.distanceSquared >
              kMaxFlingVelocity * kMaxFlingVelocity)
            velocity = Velocity(
                pixelsPerSecond: (pixelsPerSecond / pixelsPerSecond.distance) *
                    kMaxFlingVelocity);
          invokeCallback<void>(
              'onEnd', () => onEnd(ScaleEndDetails(velocity: velocity)));
        } else {
          invokeCallback<void>(
              'onEnd', () => onEnd(ScaleEndDetails(velocity: Velocity.zero)));
        }
      }
      _state = _ScaleState.accepted;
      return false;
    }
    return true;
  }

  void _advanceStateMachine(bool shouldStartIfAccepted) {
    if (_state == _ScaleState.ready) _state = _ScaleState.possible;

    if (_state == _ScaleState.possible) {
      final double spanDelta = (_currentSpan - _initialSpan).abs();
      final double focalPointDelta =
          (_currentFocalPoint - _initialFocalPoint).distance;
      if (spanDelta > kScaleSlop || focalPointDelta > kPanSlop)
        resolve(GestureDisposition.accepted);
    } else if (_state.index >= _ScaleState.accepted.index) {
      resolve(GestureDisposition.accepted);
    }

    if (_state == _ScaleState.accepted && shouldStartIfAccepted) {
      _state = _ScaleState.started;
      _dispatchOnStartCallbackIfNeeded();
    }

    if (_state == _ScaleState.started && onUpdate != null)
      invokeCallback<void>('onUpdate', () {
        onUpdate(ScaleUpdateDetails(
          scale: _scaleFactor,
          horizontalScale: _horizontalScaleFactor,
          verticalScale: _verticalScaleFactor,
          focalPoint: _currentFocalPoint,
          localFocalPoint: PointerEvent.transformPosition(
              _lastTransform, _currentFocalPoint),
          rotation: _computeRotationFactor(),
        ));
      });
  }

  void _dispatchOnStartCallbackIfNeeded() {
    assert(_state == _ScaleState.started);
    if (onStart != null)
      invokeCallback<void>('onStart', () {
        onStart(ScaleStartDetails(
          focalPoint: _currentFocalPoint,
          localFocalPoint: PointerEvent.transformPosition(
              _lastTransform, _currentFocalPoint),
        ));
      });
  }

  @override
  void acceptGesture(int pointer) {
    if (_state == _ScaleState.possible) {
      _state = _ScaleState.started;
      _dispatchOnStartCallbackIfNeeded();
    }
  }

  @override
  void rejectGesture(int pointer) {
    stopTrackingPointer(pointer);
  }

  @override
  void didStopTrackingLastPointer(int pointer) {
    switch (_state) {
      case _ScaleState.possible:
        resolve(GestureDisposition.rejected);
        break;
      case _ScaleState.ready:
        assert(false); // We should have not seen a pointer yet
        break;
      case _ScaleState.accepted:
        break;
      case _ScaleState.started:
        assert(false); // We should be in the accepted state when user is done
        break;
    }
    _state = _ScaleState.ready;
  }

  @override
  void dispose() {
    _velocityTrackers.clear();
    super.dispose();
  }

  @override
  String get debugDescription => 'scale';
}
