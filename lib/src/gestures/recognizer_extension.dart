import 'arena.dart';
import 'recognizer.dart';

final _expando = Expando<UIGestureArena>();

extension RecognizerExtension on UIGestureRecognizer {
  UIGestureArena get gestureArena => _expando[this];
  set gestureArena(UIGestureArena value) {
    if (gestureArena == value) return;
    _expando[this] = value;
  }
}
