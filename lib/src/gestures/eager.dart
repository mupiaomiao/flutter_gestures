import 'package:flutter/gestures.dart';

import 'arena.dart';
import 'recognizer.dart';

class UIEagerGestureRecognizer extends UIOneSequenceGestureRecognizer {
  UIEagerGestureRecognizer({
    PointerDeviceKind kind,
    UIGestureArena gestureArena,
  }) : super(kind: kind, gestureArena: gestureArena);

  @override
  void addAllowedPointer(PointerDownEvent event) {
    startTrackingPointer(event.pointer, event.transform);
    resolve(GestureDisposition.accepted);
    stopTrackingPointer(event.pointer);
  }

  @override
  String get debugDescription => 'eager';

  @override
  void didStopTrackingLastPointer(int pointer) {}

  @override
  void handleEvent(PointerEvent event) {}
}
