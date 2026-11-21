import "package:flow/l10n/extensions.dart";
import "package:flow/theme/navbar_theme.dart";
import "package:flow/widgets/home/navbar/navbar_button.dart";
import "package:flutter/material.dart";
import "package:material_symbols_icons_flow/symbols.dart";

class Navbar extends StatelessWidget {
  final Function(int i) onTap;

  final int activeIndex;
  final VoidCallback? onAdd;

  const Navbar({
    super.key,
    required this.onTap,
    this.activeIndex = 0,
    this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    if (onAdd case final add?) {
      final colors = Theme.of(context).colorScheme;
      return Material(
        color: colors.surface,
        shape: Border(top: BorderSide(color: colors.outlineVariant)),
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              NavbarButton(
                index: 0,
                tooltip: "tabs.home".t(context),
                icon: Symbols.receipt_long_rounded,
                onTap: onTap,
                activeIndex: activeIndex,
              ),
              NavbarButton(
                index: 1,
                tooltip: "tabs.stats".t(context),
                icon: Symbols.bar_chart_rounded,
                onTap: onTap,
                activeIndex: activeIndex,
              ),
              Expanded(
                child: InkWell(
                  onTap: add,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: colors.brightness == Brightness.light
                                ? const Color(0xFFFFD453)
                                : colors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Padding(
                            padding: EdgeInsets.all(9),
                            child: Icon(Icons.add, color: Color(0xFF30200C)),
                          ),
                        ),
                        Text(
                          "transaction.new".t(context),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              NavbarButton(
                index: 2,
                tooltip: "tabs.accounts".t(context),
                icon: Symbols.wallet_rounded,
                onTap: onTap,
                activeIndex: activeIndex,
              ),
              NavbarButton(
                index: 3,
                tooltip: "tabs.profile".t(context),
                icon: Symbols.person_rounded,
                onTap: onTap,
                activeIndex: activeIndex,
              ),
            ],
          ),
        ),
      );
    }
    final NavbarTheme navbarTheme = Theme.of(context).extension<NavbarTheme>()!;

    return Container(
      constraints: BoxConstraints(maxWidth: 480.0),
      decoration: BoxDecoration(
        shape: BoxShape.rectangle,
        borderRadius: .circular(999.9),
        color: navbarTheme.backgroundColor,
        boxShadow: [
          BoxShadow(
            color: const Color(0x05000000),
            blurRadius: 16.0,
            offset: const Offset(0, 0),
          ),
          BoxShadow(
            color: const Color(0x10000000),
            blurRadius: 4.0,
            offset: const Offset(0, 0),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: .spaceEvenly,
        children: [
          NavbarButton(
            index: 0,
            tooltip: "tabs.home".t(context),
            icon: Symbols.circle_rounded,
            onTap: onTap,
            activeIndex: activeIndex,
          ),
          NavbarButton(
            index: 1,
            tooltip: "tabs.stats".t(context),
            icon: Symbols.bar_chart_rounded,
            onTap: onTap,
            activeIndex: activeIndex,
          ),
          const SizedBox(width: 64.0 + 12.0 + 12.0),
          NavbarButton(
            index: 2,
            tooltip: "tabs.accounts".t(context),
            icon: Symbols.wallet_rounded,
            onTap: onTap,
            activeIndex: activeIndex,
          ),
          NavbarButton(
            index: 3,
            tooltip: "tabs.profile".t(context),
            icon: Symbols.person_rounded,
            onTap: onTap,
            activeIndex: activeIndex,
          ),
        ],
      ),
    );
  }
}
