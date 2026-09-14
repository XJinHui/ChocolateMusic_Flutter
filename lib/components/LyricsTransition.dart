import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:chocolate_music/components/RemoteImage.dart';

/// Owns the overlay lifetime independently from the requested visibility.
class LyricsTransitionHost extends StatefulWidget {
  const LyricsTransitionHost({
    super.key,
    required this.visible,
    required this.coverUrl,
    required this.child,
    required this.page,
  });

  final bool visible;
  final String coverUrl;
  final Widget child;
  final Widget page;

  @override
  State<LyricsTransitionHost> createState() => _LyricsTransitionHostState();
}

class _LyricsTransitionHostState extends State<LyricsTransitionHost>
    with SingleTickerProviderStateMixin {
  final _rootKey = GlobalKey();
  final _sourceKey = GlobalKey();
  final _destinationKey = GlobalKey();
  final _sourceHidden = ValueNotifier(false);
  final _destinationHidden = ValueNotifier(true);
  late final AnimationController _controller;

  bool _pageMounted = false;
  bool _preparing = false;
  bool _opening = true;
  bool _reduceMotion = false;
  double _segmentStart = 0;
  double _backgroundStart = 0;
  double _contentStart = 0;
  Rect? _fromRect;
  Rect? _toRect;
  double _fromRadius = 12;
  double _toRadius = 12;
  double _fromShadow = 0;
  double _toShadow = 1;
  String _flightUrl = '';
  Size? _layoutSize;

  double get _progress {
    final distance = (_opening ? 1.0 : 0.0) - _segmentStart;
    if (distance == 0) return 1;
    return ((_controller.value - _segmentStart) / distance).clamp(0.0, 1.0);
  }

  double get _motion => (_opening ? Curves.easeOutCubic : Curves.easeInOutCubic)
      .transform(_progress);

  Rect? get _flightRect => _fromRect == null || _toRect == null
      ? null
      : Rect.lerp(_fromRect, _toRect, _motion);

  double get _radius => lerpDouble(_fromRadius, _toRadius, _motion)!;
  double get _shadow => lerpDouble(_fromShadow, _toShadow, _motion)!;

  double get _backgroundOpacity => lerpDouble(
    _backgroundStart,
    _opening ? 1 : 0,
    Curves.easeOut.transform(
      (_progress / (_opening ? .75 : 1)).clamp(0.0, 1.0),
    ),
  )!;

  double get _contentOpacity {
    final delay = _opening && _segmentStart == 0 ? .25 : 0.0;
    final duration = _opening ? 1 - delay : .45;
    return lerpDouble(
      _contentStart,
      _opening ? 1 : 0,
      Curves.easeOut.transform(
        ((_progress - delay) / duration).clamp(0.0, 1.0),
      ),
    )!;
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
      reverseDuration: const Duration(milliseconds: 320),
    )..addStatusListener(_onStatus);
    if (widget.visible) _mountPage();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (_reduceMotion && _controller.isAnimating) _finish();
  }

  @override
  void didUpdateWidget(covariant LyricsTransitionHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.visible == widget.visible) return;
    if (widget.visible && !_pageMounted) {
      _mountPage();
    } else if (!_preparing) {
      _transitionTo(widget.visible);
    }
  }

  void _mountPage() {
    _pageMounted = true;
    _preparing = true;
    _destinationHidden.value = true;
    // The destination must have completed layout before it can be measured.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _preparing = false;
      if (!widget.visible || _reduceMotion) {
        _finish();
      } else {
        _transitionTo(true);
      }
    });
  }

  Rect? _bounds(GlobalKey key) {
    final box = key.currentContext?.findRenderObject();
    final root = _rootKey.currentContext?.findRenderObject();
    if (box is! RenderBox ||
        root is! RenderBox ||
        !box.hasSize ||
        !box.attached) {
      return null;
    }
    // Include the destination's press scale as well as its layout offset.
    final rect = MatrixUtils.transformRect(
      box.getTransformTo(root),
      Offset.zero & box.size,
    );
    return rect.isFinite && !rect.isEmpty ? rect : null;
  }

  void _transitionTo(bool opening) {
    if (_reduceMotion) {
      _finish();
      return;
    }
    final inFlight = _controller.isAnimating;
    final currentRect = inFlight ? _flightRect : null;
    final currentRadius = _radius;
    final currentShadow = _shadow;
    final background = _backgroundOpacity;
    final content = _contentOpacity;
    final source = _bounds(_sourceKey);
    final destination = _bounds(_destinationKey);
    _fromRect = currentRect ?? (opening ? source : destination);
    _toRect = opening ? destination : source;
    _fromRadius = currentRect != null
        ? currentRadius
        : opening
        ? 12
        : (destination?.width ?? 120) / 10;
    _toRadius = opening ? (destination?.width ?? 120) / 10 : 12;
    _fromShadow = currentRect != null ? currentShadow : (opening ? 0 : 1);
    _toShadow = opening ? 1 : 0;
    if (!inFlight) _flightUrl = widget.coverUrl;
    _segmentStart = _controller.value;
    _backgroundStart = background;
    _contentStart = content;
    _opening = opening;
    final flying = _fromRect != null && _toRect != null;
    _sourceHidden.value = flying;
    _destinationHidden.value = flying;
    setState(() {});
    if (opening) {
      _controller.forward();
    } else {
      _controller.reverse();
      if (_controller.isDismissed) _finish();
    }
  }

  void _finish() {
    _opening = widget.visible;
    _segmentStart = widget.visible ? 0 : 1;
    _backgroundStart = widget.visible ? 0 : 1;
    _contentStart = _backgroundStart;
    _controller.value = widget.visible ? 1 : 0;
    _settle();
  }

  void _onStatus(AnimationStatus status) {
    if (!_preparing &&
        (status == AnimationStatus.completed ||
            status == AnimationStatus.dismissed)) {
      _settle();
    }
  }

  void _settle() {
    if (!mounted) return;
    setState(() {
      _pageMounted = widget.visible;
      _fromRect = null;
      _toRect = null;
    });
    _sourceHidden.value = false;
    _destinationHidden.value = false;
  }

  void _onLayout(Size size) {
    final changed = _layoutSize != null && _layoutSize != size;
    _layoutSize = size;
    if (!changed || !_pageMounted || _preparing) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_controller.isAnimating) return;
      // Rebase from the current visual frame toward the newly laid-out anchor.
      _transitionTo(widget.visible);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _sourceHidden.dispose();
    _destinationHidden.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _LyricsTransitionScope(
      host: this,
      child: LayoutBuilder(
        builder: (context, constraints) {
          _onLayout(constraints.biggest);
          return Stack(
            key: _rootKey,
            fit: StackFit.expand,
            children: [
              widget.child,
              if (_pageMounted) ...[
                const Positioned.fill(
                  child: ModalBarrier(
                    color: Colors.transparent,
                    dismissible: false,
                  ),
                ),
                Positioned.fill(child: widget.page),
              ],
              if (_fromRect != null && _toRect != null)
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) => Positioned.fromRect(
                    rect: _flightRect!,
                    child: IgnorePointer(
                      child: RemoteImage(
                        _flightUrl,
                        key: const ValueKey('lyrics-flying-cover'),
                        fit: BoxFit.cover,
                        borderRadius: _radius,
                        boxShadow: BoxShadow.lerpList(
                          const [
                            BoxShadow(
                              color: Color(0x33000000),
                              blurRadius: 8,
                              offset: Offset(0, 3),
                            ),
                          ],
                          kImageBoxShadow,
                          _shadow,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _LyricsTransitionScope extends InheritedWidget {
  const _LyricsTransitionScope({required this.host, required super.child});
  final _LyricsTransitionHostState host;

  static _LyricsTransitionHostState? of(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<_LyricsTransitionScope>()
      ?.host;

  @override
  bool updateShouldNotify(_LyricsTransitionScope oldWidget) =>
      host != oldWidget.host;
}

/// Keeps the original artwork laid out while the flight layer paints its copy.
class LyricsCoverAnchor extends StatelessWidget {
  const LyricsCoverAnchor({
    super.key,
    this.destination = false,
    required this.child,
  });
  final bool destination;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final host = _LyricsTransitionScope.of(context);
    if (host == null) return child;
    return SizedBox(
      key: destination ? host._destinationKey : host._sourceKey,
      child: ValueListenableBuilder<bool>(
        valueListenable: destination
            ? host._destinationHidden
            : host._sourceHidden,
        child: destination
            ? LyricsTransitionPart(background: true, child: child)
            : child,
        builder: (context, hidden, child) =>
            Opacity(opacity: hidden ? 0 : 1, child: child),
      ),
    );
  }
}

/// Animate a stable subtree, keeping blur and lyric layout out of the tick loop.
class LyricsTransitionPart extends StatelessWidget {
  const LyricsTransitionPart({
    super.key,
    this.background = false,
    required this.child,
  });
  final bool background;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final host = _LyricsTransitionScope.of(context);
    if (host == null) return child;
    return AnimatedBuilder(
      animation: host._controller,
      child: RepaintBoundary(child: child),
      builder: (context, child) {
        final opacity = background
            ? host._backgroundOpacity
            : host._contentOpacity;
        return IgnorePointer(
          ignoring: host._preparing || opacity < .99,
          child: Opacity(
            opacity: opacity,
            child: Transform.translate(
              offset: Offset(0, background ? 0 : 16 * (1 - opacity)),
              child: child,
            ),
          ),
        );
      },
    );
  }
}
