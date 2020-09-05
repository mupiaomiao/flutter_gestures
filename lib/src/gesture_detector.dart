import 'package:flutter/widgets.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/foundation.dart';

import 'gestures/tap.dart';
import 'gestures/arena.dart';
import 'gestures/scale.dart';
import 'gestures/multitap.dart';
import 'gestures/monodrag.dart';
import 'gestures/long_press.dart';
import 'gestures/recognizer.dart';
import 'gestures/force_press.dart';

@optionalTypeArgs
abstract class UIGestureRecognizerFactory<T extends UIGestureRecognizer> {
  const UIGestureRecognizerFactory();

  T constructor(UIGestureArena gestureArena);

  void initializer(T instance);

  bool _debugAssertTypeMatches(Type type) {
    assert(type == T,
        'UIGestureRecognizerFactory of type $T was used where type $type was specified.');
    return true;
  }
}

typedef UIGestureRecognizerFactoryConstructor<T extends UIGestureRecognizer> = T
    Function(UIGestureArena gestureArena);

typedef UIGestureRecognizerFactoryInitializer<T extends UIGestureRecognizer>
    = void Function(T instance);

class UIGestureRecognizerFactoryWithHandlers<T extends UIGestureRecognizer>
    extends UIGestureRecognizerFactory<T> {
  const UIGestureRecognizerFactoryWithHandlers(
      this._constructor, this._initializer)
      : assert(_constructor != null),
        assert(_initializer != null);

  final UIGestureRecognizerFactoryConstructor<T> _constructor;

  final UIGestureRecognizerFactoryInitializer<T> _initializer;

  @override
  T constructor(UIGestureArena gestureArena) => _constructor(gestureArena);

  @override
  void initializer(T instance) => _initializer(instance);
}

class UIGestureDetector extends StatelessWidget {
  UIGestureDetector({
    Key key,
    this.child,
    this.onTapDown,
    this.onTapUp,
    this.onTap,
    this.onTapCancel,
    this.onSecondaryTap,
    this.onSecondaryTapDown,
    this.onSecondaryTapUp,
    this.onSecondaryTapCancel,
    this.onDoubleTap,
    this.onLongPress,
    this.onLongPressStart,
    this.onLongPressMoveUpdate,
    this.onLongPressUp,
    this.onLongPressEnd,
    this.onSecondaryLongPress,
    this.onSecondaryLongPressStart,
    this.onSecondaryLongPressMoveUpdate,
    this.onSecondaryLongPressUp,
    this.onSecondaryLongPressEnd,
    this.onVerticalDragDown,
    this.onVerticalDragStart,
    this.onVerticalDragUpdate,
    this.onVerticalDragEnd,
    this.onVerticalDragCancel,
    this.onHorizontalDragDown,
    this.onHorizontalDragStart,
    this.onHorizontalDragUpdate,
    this.onHorizontalDragEnd,
    this.onHorizontalDragCancel,
    this.onForcePressStart,
    this.onForcePressPeak,
    this.onForcePressUpdate,
    this.onForcePressEnd,
    this.onPanDown,
    this.onPanStart,
    this.onPanUpdate,
    this.onPanEnd,
    this.onPanCancel,
    this.onScaleStart,
    this.onScaleUpdate,
    this.onScaleEnd,
    this.behavior,
    this.gestureArena,
    this.excludeFromSemantics = false,
    this.dragStartBehavior = DragStartBehavior.start,
  })  : assert(excludeFromSemantics != null),
        assert(dragStartBehavior != null),
        assert(() {
          final bool haveVerticalDrag = onVerticalDragStart != null ||
              onVerticalDragUpdate != null ||
              onVerticalDragEnd != null;
          final bool haveHorizontalDrag = onHorizontalDragStart != null ||
              onHorizontalDragUpdate != null ||
              onHorizontalDragEnd != null;
          final bool havePan =
              onPanStart != null || onPanUpdate != null || onPanEnd != null;
          final bool haveScale = onScaleStart != null ||
              onScaleUpdate != null ||
              onScaleEnd != null;
          if (havePan || haveScale) {
            if (havePan && haveScale) {
              throw FlutterError.fromParts(<DiagnosticsNode>[
                ErrorSummary('Incorrect GestureDetector arguments.'),
                ErrorDescription(
                    'Having both a pan gesture recognizer and a scale gesture recognizer is redundant; scale is a superset of pan.'),
                ErrorHint('Just use the scale gesture recognizer.')
              ]);
            }
            final String recognizer = havePan ? 'pan' : 'scale';
            if (haveVerticalDrag && haveHorizontalDrag) {
              throw FlutterError('Incorrect GestureDetector arguments.\n'
                  'Simultaneously having a vertical drag gesture recognizer, a horizontal drag gesture recognizer, and a $recognizer gesture recognizer '
                  'will result in the $recognizer gesture recognizer being ignored, since the other two will catch all drags.');
            }
          }
          return true;
        }()),
        super(key: key);

  final Widget child;
  final UIGestureArena gestureArena;

  final GestureTapDownCallback onTapDown;
  final GestureTapUpCallback onTapUp;
  final GestureTapCallback onTap;
  final GestureTapCancelCallback onTapCancel;

  final GestureTapCallback onSecondaryTap;
  final GestureTapDownCallback onSecondaryTapDown;
  final GestureTapUpCallback onSecondaryTapUp;
  final GestureTapCancelCallback onSecondaryTapCancel;

  final GestureTapCallback onDoubleTap;

  final GestureLongPressCallback onLongPress;
  final GestureLongPressStartCallback onLongPressStart;
  final GestureLongPressMoveUpdateCallback onLongPressMoveUpdate;
  final GestureLongPressUpCallback onLongPressUp;
  final GestureLongPressEndCallback onLongPressEnd;

  final GestureLongPressCallback onSecondaryLongPress;
  final GestureLongPressStartCallback onSecondaryLongPressStart;
  final GestureLongPressMoveUpdateCallback onSecondaryLongPressMoveUpdate;
  final GestureLongPressUpCallback onSecondaryLongPressUp;
  final GestureLongPressEndCallback onSecondaryLongPressEnd;

  final GestureDragDownCallback onVerticalDragDown;
  final GestureDragStartCallback onVerticalDragStart;
  final GestureDragUpdateCallback onVerticalDragUpdate;
  final GestureDragEndCallback onVerticalDragEnd;
  final GestureDragCancelCallback onVerticalDragCancel;

  final GestureDragDownCallback onHorizontalDragDown;
  final GestureDragStartCallback onHorizontalDragStart;
  final GestureDragUpdateCallback onHorizontalDragUpdate;
  final GestureDragEndCallback onHorizontalDragEnd;
  final GestureDragCancelCallback onHorizontalDragCancel;

  final GestureDragDownCallback onPanDown;
  final GestureDragStartCallback onPanStart;
  final GestureDragUpdateCallback onPanUpdate;
  final GestureDragEndCallback onPanEnd;
  final GestureDragCancelCallback onPanCancel;

  final GestureScaleStartCallback onScaleStart;
  final GestureScaleUpdateCallback onScaleUpdate;
  final GestureScaleEndCallback onScaleEnd;

  final GestureForcePressStartCallback onForcePressStart;
  final GestureForcePressPeakCallback onForcePressPeak;
  final GestureForcePressUpdateCallback onForcePressUpdate;
  final GestureForcePressEndCallback onForcePressEnd;

  final HitTestBehavior behavior;

  final bool excludeFromSemantics;

  final DragStartBehavior dragStartBehavior;

  @override
  Widget build(BuildContext context) {
    final Map<Type, UIGestureRecognizerFactory> gestures =
        <Type, UIGestureRecognizerFactory>{};

    if (onTapDown != null ||
        onTapUp != null ||
        onTap != null ||
        onTapCancel != null ||
        onSecondaryTap != null ||
        onSecondaryTapDown != null ||
        onSecondaryTapUp != null ||
        onSecondaryTapCancel != null) {
      gestures[UITapGestureRecognizer] =
          UIGestureRecognizerFactoryWithHandlers<UITapGestureRecognizer>(
        (UIGestureArena gestureArena) => UITapGestureRecognizer(
            debugOwner: this, gestureArena: gestureArena),
        (UITapGestureRecognizer instance) {
          instance
            ..onTapDown = onTapDown
            ..onTapUp = onTapUp
            ..onTap = onTap
            ..onTapCancel = onTapCancel
            ..onSecondaryTap = onSecondaryTap
            ..onSecondaryTapDown = onSecondaryTapDown
            ..onSecondaryTapUp = onSecondaryTapUp
            ..onSecondaryTapCancel = onSecondaryTapCancel;
        },
      );
    }

    if (onDoubleTap != null) {
      gestures[UIDoubleTapGestureRecognizer] =
          UIGestureRecognizerFactoryWithHandlers<UIDoubleTapGestureRecognizer>(
        (UIGestureArena gestureArena) => UIDoubleTapGestureRecognizer(
            debugOwner: this, gestureArena: gestureArena),
        (UIDoubleTapGestureRecognizer instance) {
          instance.onDoubleTap = onDoubleTap;
        },
      );
    }

    if (onLongPress != null ||
        onLongPressUp != null ||
        onLongPressStart != null ||
        onLongPressMoveUpdate != null ||
        onLongPressEnd != null) {
      gestures[UILongPressGestureRecognizer] =
          UIGestureRecognizerFactoryWithHandlers<UILongPressGestureRecognizer>(
        (UIGestureArena gestureArena) => UILongPressGestureRecognizer(
            debugOwner: this, gestureArena: gestureArena),
        (UILongPressGestureRecognizer instance) {
          instance
            ..onLongPress = onLongPress
            ..onLongPressStart = onLongPressStart
            ..onLongPressMoveUpdate = onLongPressMoveUpdate
            ..onLongPressEnd = onLongPressEnd
            ..onLongPressUp = onLongPressUp;
        },
      );
    }

    if (onSecondaryLongPress != null ||
        onSecondaryLongPressUp != null ||
        onSecondaryLongPressStart != null ||
        onSecondaryLongPressMoveUpdate != null ||
        onSecondaryLongPressEnd != null) {
      gestures[UILongPressGestureRecognizer] =
          UIGestureRecognizerFactoryWithHandlers<UILongPressGestureRecognizer>(
        (UIGestureArena gestureArena) => UILongPressGestureRecognizer(
            debugOwner: this, gestureArena: gestureArena),
        (UILongPressGestureRecognizer instance) {
          instance
            ..onSecondaryLongPress = onSecondaryLongPress
            ..onSecondaryLongPressStart = onSecondaryLongPressStart
            ..onSecondaryLongPressMoveUpdate = onSecondaryLongPressMoveUpdate
            ..onSecondaryLongPressEnd = onSecondaryLongPressEnd
            ..onSecondaryLongPressUp = onSecondaryLongPressUp;
        },
      );
    }

    if (onVerticalDragDown != null ||
        onVerticalDragStart != null ||
        onVerticalDragUpdate != null ||
        onVerticalDragEnd != null ||
        onVerticalDragCancel != null) {
      gestures[UIVerticalDragGestureRecognizer] =
          UIGestureRecognizerFactoryWithHandlers<
              UIVerticalDragGestureRecognizer>(
        (UIGestureArena gestureArena) => UIVerticalDragGestureRecognizer(
            debugOwner: this, gestureArena: gestureArena),
        (UIVerticalDragGestureRecognizer instance) {
          instance
            ..onDown = onVerticalDragDown
            ..onStart = onVerticalDragStart
            ..onUpdate = onVerticalDragUpdate
            ..onEnd = onVerticalDragEnd
            ..onCancel = onVerticalDragCancel
            ..dragStartBehavior = dragStartBehavior;
        },
      );
    }

    if (onHorizontalDragDown != null ||
        onHorizontalDragStart != null ||
        onHorizontalDragUpdate != null ||
        onHorizontalDragEnd != null ||
        onHorizontalDragCancel != null) {
      gestures[UIHorizontalDragGestureRecognizer] =
          UIGestureRecognizerFactoryWithHandlers<
              UIHorizontalDragGestureRecognizer>(
        (UIGestureArena gestureArena) => UIHorizontalDragGestureRecognizer(
            debugOwner: this, gestureArena: gestureArena),
        (UIHorizontalDragGestureRecognizer instance) {
          instance
            ..onDown = onHorizontalDragDown
            ..onStart = onHorizontalDragStart
            ..onUpdate = onHorizontalDragUpdate
            ..onEnd = onHorizontalDragEnd
            ..onCancel = onHorizontalDragCancel
            ..dragStartBehavior = dragStartBehavior;
        },
      );
    }

    if (onPanDown != null ||
        onPanStart != null ||
        onPanUpdate != null ||
        onPanEnd != null ||
        onPanCancel != null) {
      gestures[UIPanGestureRecognizer] =
          UIGestureRecognizerFactoryWithHandlers<UIPanGestureRecognizer>(
        (UIGestureArena gestureArena) => UIPanGestureRecognizer(
            debugOwner: this, gestureArena: gestureArena),
        (UIPanGestureRecognizer instance) {
          instance
            ..onDown = onPanDown
            ..onStart = onPanStart
            ..onUpdate = onPanUpdate
            ..onEnd = onPanEnd
            ..onCancel = onPanCancel
            ..dragStartBehavior = dragStartBehavior;
        },
      );
    }

    if (onScaleStart != null || onScaleUpdate != null || onScaleEnd != null) {
      gestures[UIScaleGestureRecognizer] =
          UIGestureRecognizerFactoryWithHandlers<UIScaleGestureRecognizer>(
        (UIGestureArena gestureArena) => UIScaleGestureRecognizer(
            debugOwner: this, gestureArena: gestureArena),
        (UIScaleGestureRecognizer instance) {
          instance
            ..onStart = onScaleStart
            ..onUpdate = onScaleUpdate
            ..onEnd = onScaleEnd;
        },
      );
    }

    if (onForcePressStart != null ||
        onForcePressPeak != null ||
        onForcePressUpdate != null ||
        onForcePressEnd != null) {
      gestures[UIForcePressGestureRecognizer] =
          UIGestureRecognizerFactoryWithHandlers<UIForcePressGestureRecognizer>(
        (UIGestureArena gestureArena) => UIForcePressGestureRecognizer(
            debugOwner: this, gestureArena: gestureArena),
        (UIForcePressGestureRecognizer instance) {
          instance
            ..onStart = onForcePressStart
            ..onPeak = onForcePressPeak
            ..onUpdate = onForcePressUpdate
            ..onEnd = onForcePressEnd;
        },
      );
    }

    return UIRawGestureDetector(
      child: child,
      gestures: gestures,
      behavior: behavior,
      gestureArena: gestureArena,
      excludeFromSemantics: excludeFromSemantics,
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(
        EnumProperty<DragStartBehavior>('startBehavior', dragStartBehavior));
  }
}

class UIRawGestureDetector extends StatefulWidget {
  const UIRawGestureDetector({
    Key key,
    this.child,
    this.gestures = const <Type, UIGestureRecognizerFactory>{},
    this.behavior,
    this.excludeFromSemantics = false,
    this.semantics,
    this.gestureArena,
  })  : assert(gestures != null),
        assert(excludeFromSemantics != null),
        super(key: key);

  final Widget child;

  final Map<Type, UIGestureRecognizerFactory> gestures;

  final HitTestBehavior behavior;

  final bool excludeFromSemantics;

  final SemanticsGestureDelegate semantics;

  final UIGestureArena gestureArena;

  @override
  _UIRawGestureDetectorState createState() => _UIRawGestureDetectorState();
}

class _UIRawGestureDetectorState extends State<UIRawGestureDetector> {
  UIGestureArena _gestureArena;
  SemanticsGestureDelegate _semantics;
  final _excludeAreas = List<RenderBox>();
  Map<Type, UIGestureRecognizer> _recognizers =
      const <Type, UIGestureRecognizer>{};

  void addExcludeArea(RenderBox area) {
    _excludeAreas.add(area);
    final ancestor =
        context.findAncestorStateOfType<_UIRawGestureDetectorState>();
    if (ancestor != null) {
      ancestor.addExcludeArea(area);
    }
  }

  void removeExcludeArea(RenderBox area) {
    _excludeAreas.remove(area);
    final ancestor =
        context.findAncestorStateOfType<_UIRawGestureDetectorState>();
    if (ancestor != null) {
      ancestor.removeExcludeArea(area);
    }
  }

  @override
  void initState() {
    super.initState();
    _gestureArena = widget.gestureArena ?? UIGestureArena();
    _semantics = widget.semantics ?? _DefaultSemanticsGestureDelegate(this);
    _syncAll(widget.gestures);
  }

  @override
  void didUpdateWidget(UIRawGestureDetector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!(oldWidget.semantics == null && widget.semantics == null)) {
      _semantics = widget.semantics ?? _DefaultSemanticsGestureDelegate(this);
    }
    if (!identical(widget.gestureArena, oldWidget.gestureArena)) {
      _gestureArena = widget.gestureArena ?? UIGestureArena();
    }
    _syncAll(widget.gestures);
  }

  void replaceGestureRecognizers(
      Map<Type, UIGestureRecognizerFactory> gestures) {
    assert(() {
      if (!context.findRenderObject().owner.debugDoingLayout) {
        throw FlutterError.fromParts(<DiagnosticsNode>[
          ErrorSummary(
              'Unexpected call to replaceGestureRecognizers() method of UIRawGestureDetectorState.'),
          ErrorDescription(
              'The replaceGestureRecognizers() method can only be called during the layout phase.'),
          ErrorHint(
              'To set the gesture recognizers at other times, trigger a new build using setState() '
              'and provide the new gesture recognizers as constructor arguments to the corresponding '
              'UIRawGestureDetector or UIGestureDetector object.')
        ]);
      }
      return true;
    }());
    _syncAll(gestures);
    if (!widget.excludeFromSemantics) {
      final RenderSemanticsGestureHandler semanticsGestureHandler =
          context.findRenderObject() as RenderSemanticsGestureHandler;
      _updateSemanticsForRenderObject(semanticsGestureHandler);
    }
  }

  void replaceSemanticsActions(Set<SemanticsAction> actions) {
    if (widget.excludeFromSemantics) return;

    final RenderSemanticsGestureHandler semanticsGestureHandler =
        context.findRenderObject() as RenderSemanticsGestureHandler;
    assert(() {
      if (semanticsGestureHandler == null) {
        throw FlutterError(
            'Unexpected call to replaceSemanticsActions() method of UIRawGestureDetectorState.\n'
            'The replaceSemanticsActions() method can only be called after the RenderSemanticsGestureHandler has been created.');
      }
      return true;
    }());

    semanticsGestureHandler.validActions =
        actions; // will call _markNeedsSemanticsUpdate(), if required.
  }

  @override
  void dispose() {
    for (final UIGestureRecognizer recognizer in _recognizers.values) {
      recognizer.dispose();
    }
    _gestureArena = null;
    _recognizers = null;
    super.dispose();
  }

  void _syncAll(Map<Type, UIGestureRecognizerFactory> gestures) {
    assert(_recognizers != null);
    assert(_gestureArena != null);

    final Map<Type, UIGestureRecognizer> oldRecognizers = _recognizers;
    _recognizers = <Type, UIGestureRecognizer>{};
    if ((oldRecognizers?.length ?? 0) == 0) {
      for (final Type type in gestures.keys) {
        assert(gestures[type] != null);
        assert(gestures[type]._debugAssertTypeMatches(type));
        assert(!_recognizers.containsKey(type));
        _recognizers[type] = gestures[type].constructor(_gestureArena);
        assert(_recognizers[type].runtimeType == type,
            'UIGestureRecognizerFactory of type $type created a UIGestureRecognizer of type ${_recognizers[type].runtimeType}. The UIGestureRecognizerFactory must be specialized with the type of the class that it returns from its constructor method.');
        gestures[type].initializer(_recognizers[type]);
      }
    } else {
      for (final Type type in gestures.keys) {
        assert(gestures[type] != null);
        assert(gestures[type]._debugAssertTypeMatches(type));
        assert(!_recognizers.containsKey(type));
        final oldRecognizer = oldRecognizers.remove(type);
        if (identical(_gestureArena, oldRecognizer.gestureArena)) {
          _recognizers[type] = oldRecognizer;
        } else {
          if (oldRecognizer != null) oldRecognizer.dispose();
          _recognizers[type] = gestures[type].constructor(_gestureArena);
        }
        assert(_recognizers[type].runtimeType == type,
            'UIGestureRecognizerFactory of type $type created a UIGestureRecognizer of type ${_recognizers[type].runtimeType}. The UIGestureRecognizerFactory must be specialized with the type of the class that it returns from its constructor method.');
        gestures[type].initializer(_recognizers[type]);
      }
      for (final UIGestureRecognizer recognizer in oldRecognizers.values) {
        recognizer.dispose();
      }
    }
  }

  void _handlePointerDownEvent(PointerDownEvent event) {
    assert(_recognizers != null);
    for (final UIGestureRecognizer recognizer in _recognizers.values) {
      recognizer.addPointer(event);
    }
  }

  HitTestBehavior get _defaultBehavior {
    return widget.child == null
        ? HitTestBehavior.translucent
        : HitTestBehavior.deferToChild;
  }

  void _updateSemanticsForRenderObject(
      RenderSemanticsGestureHandler renderObject) {
    assert(!widget.excludeFromSemantics);
    assert(_semantics != null);
    _semantics.assignSemantics(renderObject);
  }

  @override
  Widget build(BuildContext context) {
    Widget result = Listener(
      child: widget.child,
      onPointerDown: (PointerDownEvent event) {
        for (final RenderBox child in _excludeAreas) {
          if (child.hasSize && child.size.contains(event.position)) return;
        }
        _handlePointerDownEvent(event);
      },
      behavior: widget.behavior ?? _defaultBehavior,
    );
    if (!widget.excludeFromSemantics) {
      result = _GestureSemantics(
        child: result,
        assignSemantics: _updateSemanticsForRenderObject,
      );
    }
    return result;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    if (_recognizers == null) {
      properties.add(DiagnosticsNode.message('DISPOSED'));
    } else {
      final List<String> gestures = _recognizers.values
          .map<String>(
              (GestureRecognizer recognizer) => recognizer.debugDescription)
          .toList();
      properties.add(
          IterableProperty<String>('gestures', gestures, ifEmpty: '<none>'));
      properties.add(IterableProperty<GestureRecognizer>(
          'recognizers', _recognizers.values,
          level: DiagnosticLevel.fine));
      properties.add(DiagnosticsProperty<bool>(
          'excludeFromSemantics', widget.excludeFromSemantics,
          defaultValue: false));
      if (!widget.excludeFromSemantics) {
        properties.add(DiagnosticsProperty<SemanticsGestureDelegate>(
            'semantics', widget.semantics,
            defaultValue: null));
      }
    }
    properties.add(EnumProperty<HitTestBehavior>('behavior', widget.behavior,
        defaultValue: null));
  }
}

typedef void _AssignSemantics(RenderSemanticsGestureHandler handler);

class _GestureSemantics extends SingleChildRenderObjectWidget {
  const _GestureSemantics({
    Key key,
    Widget child,
    @required this.assignSemantics,
  })  : assert(assignSemantics != null),
        super(key: key, child: child);

  final _AssignSemantics assignSemantics;

  @override
  RenderObject createRenderObject(BuildContext context) {
    final RenderSemanticsGestureHandler renderObject =
        RenderSemanticsGestureHandler();
    assignSemantics(renderObject);
    return renderObject;
  }

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    assignSemantics(renderObject);
  }
}

class _DefaultSemanticsGestureDelegate extends SemanticsGestureDelegate {
  _DefaultSemanticsGestureDelegate(this.detectorState);

  final _UIRawGestureDetectorState detectorState;

  @override
  void assignSemantics(RenderSemanticsGestureHandler renderObject) {
    assert(!detectorState.widget.excludeFromSemantics);
    final Map<Type, UIGestureRecognizer> recognizers =
        detectorState._recognizers;
    renderObject
      ..onTap = _getTapHandler(recognizers)
      ..onLongPress = _getLongPressHandler(recognizers)
      ..onHorizontalDragUpdate = _getHorizontalDragUpdateHandler(recognizers)
      ..onVerticalDragUpdate = _getVerticalDragUpdateHandler(recognizers);
  }

  GestureTapCallback _getTapHandler(
      Map<Type, UIGestureRecognizer> recognizers) {
    final UITapGestureRecognizer tap =
        recognizers[UITapGestureRecognizer] as UITapGestureRecognizer;
    if (tap == null) return null;
    assert(tap is UITapGestureRecognizer);

    return () {
      assert(tap != null);
      if (tap.onTapDown != null) tap.onTapDown(TapDownDetails());
      if (tap.onTapUp != null) tap.onTapUp(TapUpDetails());
      if (tap.onTap != null) tap.onTap();
    };
  }

  GestureLongPressCallback _getLongPressHandler(
      Map<Type, UIGestureRecognizer> recognizers) {
    final UILongPressGestureRecognizer longPress =
        recognizers[UILongPressGestureRecognizer]
            as UILongPressGestureRecognizer;
    if (longPress == null) return null;

    return () {
      assert(longPress is UILongPressGestureRecognizer);
      if (longPress.onLongPressStart != null)
        longPress.onLongPressStart(const LongPressStartDetails());
      if (longPress.onLongPress != null) longPress.onLongPress();
      if (longPress.onLongPressEnd != null)
        longPress.onLongPressEnd(const LongPressEndDetails());
      if (longPress.onLongPressUp != null) longPress.onLongPressUp();
    };
  }

  GestureDragUpdateCallback _getHorizontalDragUpdateHandler(
      Map<Type, UIGestureRecognizer> recognizers) {
    final UIHorizontalDragGestureRecognizer horizontal =
        recognizers[UIHorizontalDragGestureRecognizer]
            as UIHorizontalDragGestureRecognizer;
    final UIPanGestureRecognizer pan =
        recognizers[UIPanGestureRecognizer] as UIPanGestureRecognizer;

    final GestureDragUpdateCallback horizontalHandler = horizontal == null
        ? null
        : (DragUpdateDetails details) {
            assert(horizontal is UIHorizontalDragGestureRecognizer);
            if (horizontal.onDown != null) horizontal.onDown(DragDownDetails());
            if (horizontal.onStart != null)
              horizontal.onStart(DragStartDetails());
            if (horizontal.onUpdate != null) horizontal.onUpdate(details);
            if (horizontal.onEnd != null)
              horizontal.onEnd(DragEndDetails(primaryVelocity: 0.0));
          };

    final GestureDragUpdateCallback panHandler = pan == null
        ? null
        : (DragUpdateDetails details) {
            assert(pan is UIPanGestureRecognizer);
            if (pan.onDown != null) pan.onDown(DragDownDetails());
            if (pan.onStart != null) pan.onStart(DragStartDetails());
            if (pan.onUpdate != null) pan.onUpdate(details);
            if (pan.onEnd != null) pan.onEnd(DragEndDetails());
          };

    if (horizontalHandler == null && panHandler == null) return null;
    return (DragUpdateDetails details) {
      if (horizontalHandler != null) horizontalHandler(details);
      if (panHandler != null) panHandler(details);
    };
  }

  GestureDragUpdateCallback _getVerticalDragUpdateHandler(
      Map<Type, UIGestureRecognizer> recognizers) {
    final UIVerticalDragGestureRecognizer vertical =
        recognizers[UIVerticalDragGestureRecognizer]
            as UIVerticalDragGestureRecognizer;
    final UIPanGestureRecognizer pan =
        recognizers[UIPanGestureRecognizer] as UIPanGestureRecognizer;

    final GestureDragUpdateCallback verticalHandler = vertical == null
        ? null
        : (DragUpdateDetails details) {
            assert(vertical is UIVerticalDragGestureRecognizer);
            if (vertical.onDown != null) vertical.onDown(DragDownDetails());
            if (vertical.onStart != null) vertical.onStart(DragStartDetails());
            if (vertical.onUpdate != null) vertical.onUpdate(details);
            if (vertical.onEnd != null)
              vertical.onEnd(DragEndDetails(primaryVelocity: 0.0));
          };

    final GestureDragUpdateCallback panHandler = pan == null
        ? null
        : (DragUpdateDetails details) {
            assert(pan is UIPanGestureRecognizer);
            if (pan.onDown != null) pan.onDown(DragDownDetails());
            if (pan.onStart != null) pan.onStart(DragStartDetails());
            if (pan.onUpdate != null) pan.onUpdate(details);
            if (pan.onEnd != null) pan.onEnd(DragEndDetails());
          };

    if (verticalHandler == null && panHandler == null) return null;
    return (DragUpdateDetails details) {
      if (verticalHandler != null) verticalHandler(details);
      if (panHandler != null) panHandler(details);
    };
  }
}

class UIExcludeArea extends SingleChildRenderObjectWidget {
  UIExcludeArea({Key key, Widget child}) : super(key: key, child: child);

  @override
  RenderProxyBox createRenderObject(BuildContext context) => RenderProxyBox();

  @override
  SingleChildRenderObjectElement createElement() => _UIExcludeAreaElement(this);
}

class _UIExcludeAreaElement extends SingleChildRenderObjectElement {
  _UIExcludeAreaElement(UIExcludeArea widget) : super(widget);

  @override
  void mount(Element parent, newSlot) {
    super.mount(parent, newSlot);
    final ancestor = findAncestorStateOfType<_UIRawGestureDetectorState>();
    if (ancestor != null) {
      ancestor.addExcludeArea(renderObject as RenderBox);
    }
  }

  @override
  void update(SingleChildRenderObjectWidget newWidget) {
    final ancestor = findAncestorStateOfType<_UIRawGestureDetectorState>();
    if (ancestor != null) {
      ancestor.removeExcludeArea(renderObject as RenderBox);
    }
    super.update(newWidget);
    if (ancestor != null) {
      ancestor.addExcludeArea(renderObject as RenderBox);
    }
  }

  @override
  void unmount() {
    final ancestor = findAncestorStateOfType<_UIRawGestureDetectorState>();
    if (ancestor != null) {
      ancestor.removeExcludeArea(renderObject as RenderBox);
    }
    super.unmount();
  }
}
