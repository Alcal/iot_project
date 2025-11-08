import 'package:flutter/material.dart';

class ControlButton extends StatefulWidget {
  const ControlButton({
    super.key,
    required this.label,
    required this.onDown,
    required this.onUp,
    this.circular = false,
    this.diameter,
    this.color,
    this.pressedColor,
    this.borderColor,
    this.textStyle,
  });

  final String label;
  final VoidCallback onDown;
  final VoidCallback onUp;
  final bool circular;
  final double? diameter;
  final Color? color;
  final Color? pressedColor;
  final Color? borderColor;
  final TextStyle? textStyle;

  @override
  State<ControlButton> createState() => ControlButtonState();
}

class ControlButtonState extends State<ControlButton> {
  bool _pressed = false;

  void _handleDown() {
    if (_pressed) return;
    setState(() => _pressed = true);
    widget.onDown();
  }

  void _handleUp() {
    if (!_pressed) return;
    setState(() => _pressed = false);
    widget.onUp();
  }

  @override
  Widget build(BuildContext context) {
    final Color defaultColor = const Color(0xFF333333);
    final Color defaultPressed = const Color(0xFF2A2A2A);
    final Color defaultBorder = const Color(0xFF444444);
    final double size = widget.diameter ?? 56;

    final Widget decorated = AnimatedContainer(
      duration: const Duration(milliseconds: 80),
      width: widget.circular ? size : null,
      height: widget.circular ? size : null,
      padding: widget.circular
          ? EdgeInsets.zero
          : const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _pressed
            ? (widget.pressedColor ?? defaultPressed)
            : (widget.color ?? defaultColor),
        border: Border.all(color: widget.borderColor ?? defaultBorder),
        // Use rectangular shape with a large radius to avoid the circle+borderRadius assertion.
        shape: BoxShape.rectangle,
        borderRadius: widget.circular
            ? BorderRadius.circular(size / 2)
            : BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: Text(
        widget.label,
        style: widget.textStyle ?? const TextStyle(color: Colors.white),
      ),
    );

    return Listener(
      onPointerDown: (_) => _handleDown(),
      onPointerUp: (_) => _handleUp(),
      onPointerCancel: (_) => _handleUp(),
      child: decorated,
    );
  }
}

/// ActionButton is a specialized circular, cherry-red, animated control button
/// intended exclusively for the A and B buttons.
class ActionButton extends ControlButton {
  const ActionButton({
    super.key,
    required super.label,
    required super.onDown,
    required super.onUp,
    double diameter = 64,
    TextStyle? textStyle,
  }) : super(
         circular: true,
         diameter: diameter,
         color: const Color(0xFFD2042D), // cherry red
         pressedColor: const Color(0xFFB00325),
         borderColor: const Color(0xFF7A0218),
         textStyle:
             textStyle ??
             const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
       );

  @override
  State<ControlButton> createState() => ActionButtonState();
}

class ActionButtonState extends ControlButtonState {
  @override
  Widget build(BuildContext context) {
    // Enforce circular cherry-red styling with a subtle press animation.
    final double size = widget.diameter ?? 64;
    final bool pressed = _pressed;
    const Color base = Color(0xFFD2042D);
    const Color pressedColor = Color(0xFFB00325);
    const Color border = Color(0xFF7A0218);

    final Widget decorated = AnimatedContainer(
      duration: const Duration(milliseconds: 80),
      width: size,
      height: size,
      padding: EdgeInsets.zero,
      decoration: BoxDecoration(
        color: pressed ? pressedColor : base,
        border: Border.all(color: border),
        shape: BoxShape.rectangle,
        borderRadius: BorderRadius.circular(size / 2),
        boxShadow: [
          if (!pressed)
            const BoxShadow(
              color: Color(0x55000000),
              blurRadius: 1,
              offset: Offset(0, 4),
            )
          else
            const BoxShadow(
              color: Color(0x44000000),
              blurRadius: 1,
              offset: Offset(0, 2),
            ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        widget.label,
        style:
            widget.textStyle ??
            const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      ),
    );

    return Listener(
      onPointerDown: (_) => _handleDown(),
      onPointerUp: (_) => _handleUp(),
      onPointerCancel: (_) => _handleUp(),
      child: AnimatedScale(
        scale: pressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        child: decorated,
      ),
    );
  }
}

/// DButton is a specialized square, dark-gray control button intended
/// exclusively for the directional (D-pad) buttons. It renders a light
/// gray icon passed in as a parameter and provides a subtle press
/// animation for feedback.
class DButton extends ControlButton {
  const DButton({
    super.key,
    required this.icon,
    required super.onDown,
    required super.onUp,
    this.size = 48,
  }) : super(label: '', circular: false);

  final IconData icon;
  final double size;

  @override
  State<ControlButton> createState() => DButtonState();
}

class DButtonState extends ControlButtonState {
  @override
  Widget build(BuildContext context) {
    final DButton btn = widget as DButton;
    final bool pressed = _pressed;

    // Dark gray base with slightly darker press, and a subtle border.
    const Color base = Color(0xFF2D2D2D);
    const Color pressedColor = Color(0xFF242424);
    const Color border = Color(0xFF3A3A3A);
    const Color iconColor = Color(0xFFCCCCCC); // light gray icon

    final Widget decorated = AnimatedContainer(
      duration: const Duration(milliseconds: 80),
      width: btn.size,
      height: btn.size,
      padding: EdgeInsets.zero,
      decoration: BoxDecoration(
        color: pressed ? pressedColor : base,
        border: Border.all(color: border),
        shape: BoxShape.rectangle,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          if (!pressed)
            const BoxShadow(
              color: Color(0x33000000),
              blurRadius: 1,
              offset: Offset(0, 3),
            )
          else
            const BoxShadow(
              color: Color(0x22000000),
              blurRadius: 1,
              offset: Offset(0, 1),
            ),
        ],
      ),
      alignment: Alignment.center,
      child: Icon(btn.icon, color: iconColor, size: btn.size * 0.58),
    );

    return Listener(
      onPointerDown: (_) => _handleDown(),
      onPointerUp: (_) => _handleUp(),
      onPointerCancel: (_) => _handleUp(),
      child: AnimatedScale(
        scale: pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        child: decorated,
      ),
    );
  }
}
