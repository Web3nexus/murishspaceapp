import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// An animated button that transitions smoothly between idle (e.g. "Copy", "Send")
/// and active (e.g. "Copied ✓", "Sent ✓") states in-place, eliminating jarring
/// green SnackBar banners.
class AnimatedActionFeedbackButton extends StatefulWidget {
  final String idleLabel;
  final IconData idleIcon;
  final Color idleColor;
  final Color idleTextColor;
  final String activeLabel;
  final IconData activeIcon;
  final Color activeColor;
  final Color activeTextColor;
  final Future<void> Function() onAction;
  final VoidCallback? onComplete;
  final Duration activeDuration;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final double fontSize;
  final double iconSize;

  const AnimatedActionFeedbackButton({
    super.key,
    this.idleLabel = 'Copy',
    this.idleIcon = Icons.copy_rounded,
    this.idleColor = const Color(0xFF007AFF),
    this.idleTextColor = Colors.white,
    this.activeLabel = 'Copied!',
    this.activeIcon = Icons.check_rounded,
    this.activeColor = const Color(0xFF34C759),
    this.activeTextColor = Colors.white,
    required this.onAction,
    this.onComplete,
    this.activeDuration = const Duration(milliseconds: 1000),
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    this.borderRadius = 10.0,
    this.fontSize = 12.0,
    this.iconSize = 14.0,
  });

  @override
  State<AnimatedActionFeedbackButton> createState() =>
      _AnimatedActionFeedbackButtonState();
}

class _AnimatedActionFeedbackButtonState
    extends State<AnimatedActionFeedbackButton> {
  bool _isActive = false;
  bool _isLoading = false;

  Future<void> _handleTap() async {
    if (_isActive || _isLoading) return;
    setState(() => _isLoading = true);
    try {
      await widget.onAction();
      HapticFeedback.mediumImpact();
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isActive = true;
      });

      await Future.delayed(widget.activeDuration);
      if (!mounted) return;
      if (widget.onComplete != null) {
        widget.onComplete!();
      } else {
        setState(() => _isActive = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = _isActive ? widget.activeColor : widget.idleColor;
    final textColor = _isActive ? widget.activeTextColor : widget.idleTextColor;
    final icon = _isActive ? widget.activeIcon : widget.idleIcon;
    final label = _isActive ? widget.activeLabel : widget.idleLabel;

    return GestureDetector(
      onTap: _handleTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: widget.padding,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(widget.borderRadius),
          boxShadow: _isActive
              ? [
                  BoxShadow(
                    color: widget.activeColor.withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          transitionBuilder: (child, anim) => ScaleTransition(
            scale: anim,
            child: FadeTransition(opacity: anim, child: child),
          ),
          child: _isLoading
              ? SizedBox(
                  key: const ValueKey('loading'),
                  width: widget.iconSize,
                  height: widget.iconSize,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: textColor,
                  ),
                )
              : Row(
                  key: ValueKey(_isActive ? 'active' : 'idle'),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, color: textColor, size: widget.iconSize),
                    const SizedBox(width: 5),
                    Text(
                      label,
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.bold,
                        fontSize: widget.fontSize,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// An inline icon or trailing widget that transitions smoothly between copy and copied
/// states with haptics, replacing intrusive snackbars.
class AnimatedCopyIcon extends StatefulWidget {
  final Future<void> Function() onCopy;
  final double size;
  final Color idleColor;
  final Color activeColor;
  final Duration activeDuration;

  const AnimatedCopyIcon({
    super.key,
    required this.onCopy,
    this.size = 18.0,
    this.idleColor = const Color(0xFF8E8E93),
    this.activeColor = const Color(0xFF34C759),
    this.activeDuration = const Duration(milliseconds: 1500),
  });

  @override
  State<AnimatedCopyIcon> createState() => _AnimatedCopyIconState();
}

class _AnimatedCopyIconState extends State<AnimatedCopyIcon> {
  bool _copied = false;

  Future<void> triggerCopy() async {
    if (_copied) return;
    await widget.onCopy();
    HapticFeedback.mediumImpact();
    if (!mounted) return;
    setState(() => _copied = true);
    await Future.delayed(widget.activeDuration);
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: triggerCopy,
      behavior: HitTestBehavior.opaque,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        transitionBuilder: (child, anim) =>
            ScaleTransition(scale: anim, child: FadeTransition(opacity: anim, child: child)),
        child: _copied
            ? Row(
                key: const ValueKey('copied'),
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_rounded, color: widget.activeColor, size: widget.size),
                  const SizedBox(width: 4),
                  Text(
                    'Copied',
                    style: TextStyle(
                      color: widget.activeColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              )
            : Icon(
                Icons.copy_rounded,
                key: const ValueKey('idle'),
                color: widget.idleColor,
                size: widget.size,
              ),
      ),
    );
  }
}
