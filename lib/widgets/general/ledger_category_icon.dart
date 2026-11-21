import "package:flow/entity/category.dart";
import "package:flow/widgets/general/flow_icon.dart";
import "package:flutter/material.dart";

/// A category glyph shared by quick entry and chart rankings.
class LedgerCategoryIcon extends StatelessWidget {
  const LedgerCategoryIcon({
    super.key,
    required this.category,
    this.diameter = 42,
    this.selected = false,
    this.tint,
  });

  final Category? category;
  final double diameter;
  final bool selected;
  final Color? tint;

  static const _tints = [
    Color(0xFF9EE5D5),
    Color(0xFFFFDF88),
    Color(0xFFAAD7FF),
    Color(0xFFCEC1FF),
    Color(0xFFFFC4B8),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final category = this.category;
    final tone =
        tint ?? (category == null ? null : _tints[category.id % _tints.length]);
    final foreground = selected
        ? colors.onPrimaryContainer
        : colors.onSurfaceVariant;
    return SizedBox.square(
      dimension: diameter,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: selected
              ? colors.primaryContainer
              : tone?.withValues(
                      alpha: colors.brightness == Brightness.light ? .37 : .18,
                    ) ??
                    colors.surfaceContainer,
          borderRadius: BorderRadius.circular(diameter * .32),
        ),
        child: Center(
          child: category == null
              ? Icon(
                  Icons.category_outlined,
                  color: foreground,
                  size: diameter * .52,
                )
              : FlowIcon(
                  category.icon,
                  color: foreground,
                  fill: 0,
                  size: diameter * .52,
                ),
        ),
      ),
    );
  }
}
