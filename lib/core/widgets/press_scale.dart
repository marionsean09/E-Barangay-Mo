import 'package:flutter/material.dart';

class PressScale extends StatefulWidget {
  const PressScale({super.key, required this.child, this.enabled = true});

  final Widget child;
  final bool enabled;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _pressed = false;

  void _set(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final animate =
        widget.enabled && !MediaQuery.disableAnimationsOf(context);

    return Listener(
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: animate && _pressed ? 0.98 : 1,
        duration: const Duration(milliseconds: 180),
        curve: const Cubic(0.16, 1, 0.3, 1),
        child: widget.child,
      ),
    );
  }
}
