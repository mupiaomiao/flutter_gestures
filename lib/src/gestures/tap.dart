import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart';
import 'package:vector_math/vector_math_64.dart' show Matrix4;

import 'arena.dart';
import 'recognizer.dart';

abstract class UIBaseTapGestureRecognizer
    extends UIPrimaryPointerGestureRecognizer {
  UIBaseTapGestureRecognizer({
    Object debugOwner,
    UIGestureArena gestureArena,
  }) : super(
          debugOwner: debugOwner,
          deadline: kPressTimeout,
          gestureArena: gestureArena,
        );

  bool _sentTapDown = false;
  bool _wonArenaForPrimaryPointer = false;

  PointerDownEvent _down;
  PointerUpEvent _up;

  @protected
  void handleTapDown({PointerDownEvent down});

  @protected
  void handleTapUp({PointerDownEvent down, PointerUpEvent up});

  @protected
  void handleTapCancel(
      {PointerDownEvent down, PointerCancelEvent cancel, String reason});

  @override
  void addAllowedPointer(PointerDownEvent event) {
    assert(event != null);
    if (state == GestureRecognizerState.ready) {
      _down = event;
    }
    if (_down != null) {
      super.addAllowedPointer(event);
    }
  }

  @override
  @protected
  void startTrackingPointer(int pointer, [Matrix4 transform]) {
    assert(_down != null);
    super.startTrackingPointer(pointer, transform);
  }

  @override
  void handlePrimaryPointer(PointerEvent event) {
    if (event is PointerUpEvent) {
      _up = event;
      _checkUp();
    } else if (event is PointerCancelEvent) {
      resolve(GestureDisposition.rejected);
      if (_sentTapDown) {
        _checkCancel(event, '');
      }
      _reset();
    } else if (event.buttons != _down.buttons) {
      resolve(GestureDisposition.rejected);
      stopTrackingPointer(primaryPointer);
    }
  }

  @override
  void resolve(GestureDisposition disposition) {
    if (_wonArenaForPrimaryPointer &&
        disposition == GestureDisposition.rejected) {
      assert(_sentTapDown);
      _checkCancel(null, 'spontaneous');
      _reset();
    }
    super.resolve(disposition);
  }

  @override
  void didExceedDeadline() {
    _checkDown();
  }

  @override
  void acceptGesture(int pointer) {
    super.acceptGesture(pointer);
    if (pointer == primaryPointer) {
      _checkDown();
      _wonArenaForPrimaryPointer = true;
      _checkUp();
    }
  }

  @override
  void rejectGesture(int pointer) {
    super.rejectGesture(pointer);
    if (pointer == primaryPointer) {
      assert(state != GestureRecognizerState.possible);
      if (_sentTapDown) _checkCancel(null, 'forced');
      _reset();
    }
  }

  void _checkDown() {
    if (_sentTapDown) {
      return;
    }
    handleTapDown(down: _down);
    _sentTapDown = true;
  }

  void _checkUp() {
    if (!_wonArenaForPrimaryPointer || _up == null) {
      return;
    }
    handleTapUp(down: _down, up: _up);
    _reset();
  }

  void _checkCancel(PointerCancelEvent event, String note) {
    handleTapCancel(down: _down, cancel: event, reason: note);
  }

  void _reset() {
    _sentTapDown = false;
    _wonArenaForPrimaryPointer = false;
    _up = null;
    _down = null;
  }

  @override
  String get debugDescription => 'base tap';

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(FlagProperty('wonArenaForPrimaryPointer',
        value: _wonArenaForPrimaryPointer, ifTrue: 'won arena'));
    properties.add(DiagnosticsProperty<Offset>('finalPosition', _up?.position,
        defaultValue: null));
    properties.add(DiagnosticsProperty<Offset>(
        'finalLocalPosition', _up?.localPosition,
        defaultValue: _up?.position));
    properties.add(
        DiagnosticsProperty<int>('button', _down?.buttons, defaultValue: null));
    properties.add(FlagProperty('sentTapDown',
        value: _sentTapDown, ifTrue: 'sent tap down'));
  }
}

class UITapGestureRecognizer extends UIBaseTapGestureRecognizer {
  UITapGestureRecognizer({
    Object debugOwner,
    UIGestureArena gestureArena,
  }) : super(debugOwner: debugOwner, gestureArena: gestureArena);

  GestureTapDownCallback onTapDown;

  GestureTapUpCallback onTapUp;

  GestureTapCallback onTap;

  GestureTapCancelCallback onTapCancel;

  GestureTapCallback onSecondaryTap;

  GestureTapDownCallback onSecondaryTapDown;

  GestureTapUpCallback onSecondaryTapUp;

  GestureTapCancelCallback onSecondaryTapCancel;

  @override
  bool isPointerAllowed(PointerDownEvent event) {
    switch (event.buttons) {
      case kPrimaryButton:
        if (onTapDown == null &&
            onTap == null &&
            onTapUp == null &&
            onTapCancel == null) return false;
        break;
      case kSecondaryButton:
        if (onSecondaryTap == null &&
            onSecondaryTapDown == null &&
            onSecondaryTapUp == null &&
            onSecondaryTapCancel == null) return false;
        break;
      default:
        return false;
    }
    return super.isPointerAllowed(event);
  }

  @protected
  @override
  void handleTapDown({PointerDownEvent down}) {
    final TapDownDetails details = TapDownDetails(
      globalPosition: down.position,
      localPosition: down.localPosition,
      kind: getKindForPointer(down.pointer),
    );
    switch (down.buttons) {
      case kPrimaryButton:
        if (onTapDown != null)
          invokeCallback<void>('onTapDown', () => onTapDown(details));
        break;
      case kSecondaryButton:
        if (onSecondaryTapDown != null)
          invokeCallback<void>(
              'onSecondaryTapDown', () => onSecondaryTapDown(details));
        break;
      default:
    }
  }

  @protected
  @override
  void handleTapUp({PointerDownEvent down, PointerUpEvent up}) {
    final TapUpDetails details = TapUpDetails(
      globalPosition: up.position,
      localPosition: up.localPosition,
    );
    switch (down.buttons) {
      case kPrimaryButton:
        if (onTapUp != null)
          invokeCallback<void>('onTapUp', () => onTapUp(details));
        if (onTap != null) invokeCallback<void>('onTap', onTap);
        break;
      case kSecondaryButton:
        if (onSecondaryTapUp != null)
          invokeCallback<void>(
              'onSecondaryTapUp', () => onSecondaryTapUp(details));
        if (onSecondaryTap != null)
          invokeCallback<void>('onSecondaryTap', () => onSecondaryTap());
        break;
      default:
    }
  }

  @protected
  @override
  void handleTapCancel(
      {PointerDownEvent down, PointerCancelEvent cancel, String reason}) {
    final String note = reason == '' ? reason : '$reason ';
    switch (down.buttons) {
      case kPrimaryButton:
        if (onTapCancel != null)
          invokeCallback<void>('${note}onTapCancel', onTapCancel);
        break;
      case kSecondaryButton:
        if (onSecondaryTapCancel != null)
          invokeCallback<void>(
              '${note}onSecondaryTapCancel', onSecondaryTapCancel);
        break;
      default:
    }
  }

  @override
  String get debugDescription => 'tap';
}
