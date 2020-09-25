import 'arena.dart';
import 'recognizer.dart';

final _expando = Expando<UIGestureBinding>();

extension RecognizerExtension on UIGestureRecognizer {
  UIGestureBinding get gestureBinding => _expando[this];
  set gestureBinding(UIGestureBinding value) {
    if (gestureBinding == value) return;
    _expando[this] = value;
  }
}
