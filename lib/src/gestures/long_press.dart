import 'package:flutter/gestures.dart';

import 'recognizer.dart';

class UILongPressGestureRecognizer extends UIPrimaryPointerGestureRecognizer {
  UILongPressGestureRecognizer({
    Duration duration,
    double postAcceptSlopTolerance,
    PointerDeviceKind kind,
    Object debugOwner,
  }) : super(
          deadline: duration ?? kLongPressTimeout,
          postAcceptSlopTolerance: postAcceptSlopTolerance,
          kind: kind,
          debugOwner: debugOwner,
        );

  bool _longPressAccepted = false;
  OffsetPair _longPressOrigin;
  int _initialButtons;

  GestureLongPressCallback onLongPress;
  GestureLongPressUpCallback onLongPressUp;
  GestureLongPressEndCallback onLongPressEnd;
  GestureLongPressCallback onSecondaryLongPress;
  GestureLongPressStartCallback onLongPressStart;
  GestureLongPressUpCallback onSecondaryLongPressUp;
  GestureLongPressEndCallback onSecondaryLongPressEnd;
  GestureLongPressStartCallback onSecondaryLongPressStart;
  GestureLongPressMoveUpdateCallback onLongPressMoveUpdate;
  GestureLongPressMoveUpdateCallback onSecondaryLongPressMoveUpdate;

  VelocityTracker _velocityTracker;

  @override
  bool isPointerAllowed(PointerDownEvent event) {
    switch (event.buttons) {
      case kPrimaryButton:
        if (onLongPressStart == null &&
            onLongPress == null &&
            onLongPressMoveUpdate == null &&
            onLongPressEnd == null &&
            onLongPressUp == null) return false;
        break;
      case kSecondaryButton:
        if (onSecondaryLongPressStart == null &&
            onSecondaryLongPress == null &&
            onSecondaryLongPressMoveUpdate == null &&
            onSecondaryLongPressEnd == null &&
            onSecondaryLongPressUp == null) return false;
        break;
      default:
        return false;
    }
    return super.isPointerAllowed(event);
  }

  @override
  void didExceedDeadline() {
    resolve(GestureDisposition.accepted);
    _longPressAccepted = true;
    super.acceptGesture(primaryPointer);
    _checkLongPressStart();
  }

  @override
  void handlePrimaryPointer(PointerEvent event) {
    if (!event.synthesized) {
      if (event is PointerDownEvent) {
        _velocityTracker = VelocityTracker();
        _velocityTracker.addPosition(event.timeStamp, event.localPosition);
      }
      if (event is PointerMoveEvent) {
        assert(_velocityTracker != null);
        _velocityTracker.addPosition(event.timeStamp, event.localPosition);
      }
    }

    if (event is PointerUpEvent) {
      if (_longPressAccepted == true) {
        _checkLongPressEnd(event);
      } else {
        resolve(GestureDisposition.rejected);
      }
      _reset();
    } else if (event is PointerCancelEvent) {
      _reset();
    } else if (event is PointerDownEvent) {
      _longPressOrigin = OffsetPair.fromEventPosition(event);
      _initialButtons = event.buttons;
    } else if (event is PointerMoveEvent) {
      if (event.buttons != _initialButtons) {
        resolve(GestureDisposition.rejected);
        stopTrackingPointer(primaryPointer);
      } else if (_longPressAccepted) {
        _checkLongPressMoveUpdate(event);
      }
    }
  }

  void _checkLongPressStart() {
    switch (_initialButtons) {
      case kPrimaryButton:
        if (onLongPressStart != null) {
          final LongPressStartDetails details = LongPressStartDetails(
            globalPosition: _longPressOrigin.global,
            localPosition: _longPressOrigin.local,
          );
          invokeCallback<void>(
              'onLongPressStart', () => onLongPressStart(details));
        }
        if (onLongPress != null) {
          invokeCallback<void>('onLongPress', onLongPress);
        }
        break;
      case kSecondaryButton:
        if (onSecondaryLongPressStart != null) {
          final LongPressStartDetails details = LongPressStartDetails(
            globalPosition: _longPressOrigin.global,
            localPosition: _longPressOrigin.local,
          );
          invokeCallback<void>('onSecondaryLongPressStart',
              () => onSecondaryLongPressStart(details));
        }
        if (onSecondaryLongPress != null) {
          invokeCallback<void>('onSecondaryLongPress', onSecondaryLongPress);
        }
        break;
      default:
        assert(false, 'Unhandled button $_initialButtons');
    }
  }

  void _checkLongPressMoveUpdate(PointerEvent event) {
    final LongPressMoveUpdateDetails details = LongPressMoveUpdateDetails(
      globalPosition: event.position,
      localPosition: event.localPosition,
      offsetFromOrigin: event.position - _longPressOrigin.global,
      localOffsetFromOrigin: event.localPosition - _longPressOrigin.local,
    );
    switch (_initialButtons) {
      case kPrimaryButton:
        if (onLongPressMoveUpdate != null) {
          invokeCallback<void>(
              'onLongPressMoveUpdate', () => onLongPressMoveUpdate(details));
        }
        break;
      case kSecondaryButton:
        if (onSecondaryLongPressMoveUpdate != null) {
          invokeCallback<void>('onSecondaryLongPressMoveUpdate',
              () => onSecondaryLongPressMoveUpdate(details));
        }
        break;
      default:
        assert(false, 'Unhandled button $_initialButtons');
    }
  }

  void _checkLongPressEnd(PointerEvent event) {
    final VelocityEstimate estimate = _velocityTracker.getVelocityEstimate();
    final Velocity velocity = estimate == null
        ? Velocity.zero
        : Velocity(pixelsPerSecond: estimate.pixelsPerSecond);
    final LongPressEndDetails details = LongPressEndDetails(
      globalPosition: event.position,
      localPosition: event.localPosition,
      velocity: velocity,
    );

    _velocityTracker = null;
    switch (_initialButtons) {
      case kPrimaryButton:
        if (onLongPressEnd != null) {
          invokeCallback<void>('onLongPressEnd', () => onLongPressEnd(details));
        }
        if (onLongPressUp != null) {
          invokeCallback<void>('onLongPressUp', onLongPressUp);
        }
        break;
      case kSecondaryButton:
        if (onSecondaryLongPressEnd != null) {
          invokeCallback<void>('onSecondaryLongPressEnd',
              () => onSecondaryLongPressEnd(details));
        }
        if (onSecondaryLongPressUp != null) {
          invokeCallback<void>(
              'onSecondaryLongPressUp', onSecondaryLongPressUp);
        }
        break;
      default:
        assert(false, 'Unhandled button $_initialButtons');
    }
  }

  void _reset() {
    _longPressAccepted = false;
    _longPressOrigin = null;
    _initialButtons = null;
    _velocityTracker = null;
  }

  @override
  void resolve(GestureDisposition disposition) {
    if (_longPressAccepted && disposition == GestureDisposition.rejected) {
      _reset();
    }
    super.resolve(disposition);
  }

  @override
  void acceptGesture(int pointer) {}

  @override
  String get debugDescription => 'long press';
}
