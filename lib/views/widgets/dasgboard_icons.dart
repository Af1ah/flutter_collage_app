import 'package:flutter/material.dart';

class RoundedIconButtonWithLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget page;
  final Color? iconColor;
  final Color? backgroundColor;
  final double? iconSize;
  final double borderRadius;
  final TextStyle? labelStyle;
  final EdgeInsetsGeometry? padding;

  const RoundedIconButtonWithLabel({
    super.key,
    required this.icon,
    required this.label,
    required this.page,
    this.iconColor,
    this.backgroundColor,
    this.iconSize,
    this.borderRadius = 12.0,
    this.labelStyle,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap:
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => page),
          ),
      borderRadius: BorderRadius.circular(borderRadius),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              decoration: BoxDecoration(
                color:
                    backgroundColor ??
                    Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(borderRadius),
              ),
              padding: const EdgeInsets.all(12.0),
              child: Icon(
                icon,
                size: iconSize ?? 24.0,
                color:
                    iconColor ??
                    Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 8.0),
            Text(
              label,
              style: labelStyle ?? Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
