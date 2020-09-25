import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart' show debugPrint;

import 'recognizer.dart';

enum _ForceState {
  ready,
  possible,
  accepted,
  started,
  peaked,
}

class UIForcePressGestureRecognizer extends UIOneSequenceGestureRecognizer {
  UIForcePressGestureRecognizer({
    this.startPressure = 0.4,
    this.peakPressure = 0.85,
    this.interpolation = _inverseLerp,
    Object debugOwner,
    PointerDeviceKind kind,
  })  : assert(startPressure != null),
        assert(peakPressure != null),
        assert(interpolation != null),
        assert(peakPressure > startPressure),
        super(kind: kind, debugOwner: debugOwner);

  GestureForcePressStartCallback onStart;

  GestureForcePressUpdateCallback onUpdate;

  GestureForcePressPeakCallback onPeak;

  GestureForcePressEndCallback onEnd;

  final double startPressure;

  final double peakPressure;

  final GestureForceInterpolation interpolation;

  OffsetPair _lastPosition;
  double _lastPressure;
  _ForceState _state = _ForceState.ready;

  @override
  void addAllowedPointer(PointerEvent event) {
    if (event is! PointerUpEvent && event.pressureMax <= 1.0) {
      resolve(GestureDisposition.rejected);
    } else {
      startTrackingPointer(event.pointer, event.transform);
      if (_state == _ForceState.ready) {
        _state = _ForceState.possible;
        _lastPosition = OffsetPair.fromEventPosition(event);
      }
    }
  }

  @override
  void handleEvent(PointerEvent event) {
    assert(_state != _ForceState.ready);
    if (event is PointerMoveEvent || event is PointerDownEvent) {
      if (event.pressure > event.pressureMax ||
          event.pressure < event.pressureMin) {
        debugPrint(
          'The reported device pressure ' +
              event.pressure.toString() +
              ' is outside of the device pressure range where: ' +
              event.pressureMin.toString() +
              ' <= pressure <= ' +
              event.pressureMax.toString(),
        );
      }

      final double pressure =
          interpolation(event.pressureMin, event.pressureMax, event.pressure);
      assert((pressure >= 0.0 &&
                  pressure <=
                      1.0) || // Interpolated pressure must be between 1.0 and 0.0...
              pressure
                  .isNaN // and interpolation may return NaN for values it doesn't want to support...
          );

      _lastPosition = OffsetPair.fromEventPosition(event);
      _lastPressure = pressure;

      if (_state == _ForceState.possible) {
        if (pressure > startPressure) {
          _state = _ForceState.started;
          resolve(GestureDisposition.accepted);
        } else if (event.delta.distanceSquared > kTouchSlop) {
          resolve(GestureDisposition.rejected);
        }
      }
      // In case this is the only gesture detector we still don't want to start
      // the gesture until the pressure is greater than the startPressure.
      if (pressure > startPressure && _state == _ForceState.accepted) {
        _state = _ForceState.started;
        if (onStart != null) {
          invokeCallback<void>(
              'onStart',
              () => onStart(ForcePressDetails(
                    pressure: pressure,
                    globalPosition: _lastPosition.global,
                    localPosition: _lastPosition.local,
                  )));
        }
      }
      if (onPeak != null &&
          pressure > peakPressure &&
          (_state == _ForceState.started)) {
        _state = _ForceState.peaked;
        if (onPeak != null) {
          invokeCallback<void>(
              'onPeak',
              () => onPeak(ForcePressDetails(
                    pressure: pressure,
                    globalPosition: event.position,
                    localPosition: event.localPosition,
                  )));
        }
      }
      if (onUpdate != null &&
          !pressure.isNaN &&
          (_state == _ForceState.started || _state == _ForceState.peaked)) {
        if (onUpdate != null) {
          invokeCallback<void>(
              'onUpdate',
              () => onUpdate(ForcePressDetails(
                    pressure: pressure,
                    globalPosition: event.position,
                    localPosition: event.localPosition,
                  )));
        }
      }
    }
    stopTrackingIfPointerNoLongerDown(event);
  }

  @override
  void acceptGesture(int pointer) {
    if (_state == _ForceState.possible) _state = _ForceState.accepted;

    if (onStart != null && _state == _ForceState.started) {
      invokeCallback<void>(
          'onStart',
          () => onStart(ForcePressDetails(
                pressure: _lastPressure,
                globalPosition: _lastPosition.global,
                localPosition: _lastPosition.local,
              )));
    }
  }

  @override
  void didStopTrackingLastPointer(int pointer) {
    final bool wasAccepted =
        _state == _ForceState.started || _state == _ForceState.peaked;
    if (_state == _ForceState.possible) {
      resolve(GestureDisposition.rejected);
      return;
    }
    if (wasAccepted && onEnd != null) {
      if (onEnd != null) {
        invokeCallback<void>(
            'onEnd',
            () => onEnd(ForcePressDetails(
                  pressure: 0.0,
                  globalPosition: _lastPosition.global,
                  localPosition: _lastPosition.local,
                )));
      }
    }
    _state = _ForceState.ready;
  }

  @override
  void rejectGesture(int pointer) {
    stopTrackingPointer(pointer);
    didStopTrackingLastPointer(pointer);
  }

  static double _inverseLerp(double min, double max, double t) {
    assert(min <= max);
    double value = (t - min) / (max - min);

    // If the device incorrectly reports a pressure outside of pressureMin
    // and pressureMax, we still want this recognizer to respond normally.
    if (!value.isNaN) value = value.clamp(0.0, 1.0) as double;
    return value;
  }

  @override
  String get debugDescription => 'force press';
}
