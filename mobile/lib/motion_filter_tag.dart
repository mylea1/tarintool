import 'package:flutter/material.dart';

/// Animate layout space, not a transform that paints over adjacent labels.
class MotionFilterTag extends StatelessWidget {
  const MotionFilterTag({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.rail = false,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool rail;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      child: AnimatedContainer(
        duration: Duration(
          milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 160,
        ),
        curve: Curves.easeOutCubic,
        constraints: const BoxConstraints(minHeight: 44),
        decoration: BoxDecoration(
          color: selected ? colors.primaryContainer : colors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? colors.primary : colors.outlineVariant,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: AnimatedPadding(
              duration: Duration(
                milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 160,
              ),
              curve: Curves.easeOutCubic,
              padding: EdgeInsets.symmetric(
                horizontal: rail ? 4 : (selected ? 16 : 10),
                vertical: 10,
              ),
              child: Center(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: rail ? 12 : 14,
                    fontWeight: FontWeight.w600,
                    color: selected
                        ? colors.onPrimaryContainer
                        : colors.onSurface,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
