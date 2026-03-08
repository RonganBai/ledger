import 'package:flutter/material.dart';

import 'ledger_quick_actions_texts.dart';

class LedgerQuickActions extends StatelessWidget {
  final bool isSearchOpen;

  final VoidCallback onToggleSearch;
  final VoidCallback onOpenAdd;

  final IconData slot3Icon;
  final String slot3Tooltip;
  final VoidCallback onSlot3;
  final VoidCallback? onSlot3LongPress;

  final IconData slot4Icon;
  final String slot4Tooltip;
  final VoidCallback onSlot4;
  final VoidCallback? onSlot4LongPress;
  final Key? searchButtonKey;
  final Key? addButtonKey;
  final Key? slot3ButtonKey;
  final Key? slot4ButtonKey;

  const LedgerQuickActions({
    super.key,
    required this.isSearchOpen,
    required this.onToggleSearch,
    required this.onOpenAdd,
    required this.slot3Icon,
    required this.slot3Tooltip,
    required this.onSlot3,
    this.onSlot3LongPress,
    required this.slot4Icon,
    required this.slot4Tooltip,
    required this.onSlot4,
    this.onSlot4LongPress,
    this.searchButtonKey,
    this.addButtonKey,
    this.slot3ButtonKey,
    this.slot4ButtonKey,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    Widget btn({
      Key? key,
      required double size,
      required IconData icon,
      required String tooltip,
      required VoidCallback onTap,
      VoidCallback? onLongPress,
      bool selected = false,
    }) {
      final bg = selected ? scheme.primaryContainer : scheme.surface;
      final fg = selected ? scheme.onPrimaryContainer : scheme.onSurface;
      final border = Theme.of(context).dividerColor.withValues(alpha: 90);

      final body = Material(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          onLongPress: onLongPress,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: border),
            ),
            child: Center(
              child: Icon(icon, color: fg, size: size * 0.48),
            ),
          ),
        ),
      );
      final wrapped = Tooltip(
        message: tooltip,
        // Slot 3/4 use long-press for edit, so avoid tooltip hijacking long-press.
        triggerMode: onLongPress != null
            ? TooltipTriggerMode.tap
            : TooltipTriggerMode.longPress,
        child: body,
      );
      if (key == null) return wrapped;
      return KeyedSubtree(key: key, child: wrapped);
    }

    return LayoutBuilder(
      builder: (context, c) {
        final hGap = (c.maxWidth * 0.07).clamp(6.0, 14.0);
        final minVGap = (c.maxHeight * 0.012).clamp(1.0, 6.0);

        double sizeByWidth = (c.maxWidth - hGap) / 2;
        double sizeByHeight = (c.maxHeight - minVGap) / 2;
        double size = sizeByWidth < sizeByHeight ? sizeByWidth : sizeByHeight;
        size = size.clamp(34.0, 96.0);

        // Keep top row touching the top edge and bottom row touching the bottom edge.
        return Column(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                btn(
                  key: searchButtonKey,
                  size: size,
                  icon: Icons.search_rounded,
                  tooltip: lqat(context, 'Search'),
                  onTap: onToggleSearch,
                  selected: isSearchOpen,
                ),
                SizedBox(width: hGap),
                btn(
                  key: addButtonKey,
                  size: size,
                  icon: Icons.add_rounded,
                  tooltip: lqat(context, 'Add'),
                  onTap: onOpenAdd,
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                btn(
                  key: slot3ButtonKey,
                  size: size,
                  icon: slot3Icon,
                  tooltip: slot3Tooltip,
                  onTap: onSlot3,
                  onLongPress: onSlot3LongPress,
                ),
                SizedBox(width: hGap),
                btn(
                  key: slot4ButtonKey,
                  size: size,
                  icon: slot4Icon,
                  tooltip: slot4Tooltip,
                  onTap: onSlot4,
                  onLongPress: onSlot4LongPress,
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
