import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Reusable SVG Icon loader using the custom MurihSpace icon pack.
/// Automatically handles color filtering for light and dark modes.
class MurihIcon extends StatelessWidget {
  final String name;
  final double size;
  final Color? color;

  const MurihIcon(
    this.name, {
    super.key,
    this.size = 24,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ??
        (Theme.of(context).brightness == Brightness.dark
            ? Colors.white
            : const Color(0xFF17202B));

    final normalized = name.endsWith('.svg') ? name : '$name.svg';

    return SvgPicture.asset(
      'assets/icons/$normalized',
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(effectiveColor, BlendMode.srcIn),
    );
  }
}

