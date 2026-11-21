import "package:flutter/material.dart";

/// A compact set of mutually exclusive choices with full-size tap targets.
class LedgerChoiceBar<T> extends StatelessWidget {
  const LedgerChoiceBar({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelect,
    this.label,
  });

  final Map<T, String> options;
  final T selected;
  final ValueChanged<T> onSelect;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      child: Row(
        children: [
          for (final entry in options.entries)
            Expanded(
              child: LedgerChoice(
                label: entry.value,
                selected: entry.key == selected,
                onTap: () => onSelect(entry.key),
              ),
            ),
        ],
      ),
    );
  }
}

/// A compact selection chip with enough space around the visible label.
class LedgerChoice extends StatelessWidget {
  const LedgerChoice({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Center(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: selected ? color.secondaryContainer : null,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.25,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    color: selected
                        ? color.onSecondaryContainer
                        : color.onSurfaceVariant,
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
