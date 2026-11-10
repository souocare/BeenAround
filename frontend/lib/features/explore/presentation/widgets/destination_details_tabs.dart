import 'package:flutter/material.dart';

/// Shared segmented navigation for country and city details.
///
/// The parent owns the selected tab and its content.
/// This widget is responsible only for presentation and interaction.
class DestinationDetailsTabs extends StatelessWidget {
  const DestinationDetailsTabs({
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
    this.tabKeyPrefix,
    super.key,
  }) : assert(labels.length > 0),
       assert(selectedIndex >= 0),
       assert(selectedIndex < labels.length);

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  /// Optional prefix for stable widget test keys.
  ///
  /// Example: cityTab-overview.
  final String? tabKeyPrefix;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          for (var index = 0; index < labels.length; index++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: _DestinationTabButton(
                  label: labels[index],
                  selected: selectedIndex == index,
                  onTap: () => onSelected(index),
                  tabKey: tabKeyPrefix == null
                      ? null
                      : Key(
                          '$tabKeyPrefix-'
                          '${labels[index].toLowerCase()}',
                        ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DestinationTabButton extends StatelessWidget {
  const _DestinationTabButton({
    required this.label,
    required this.selected,
    required this.onTap,
    this.tabKey,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Key? tabKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Semantics(
      key: tabKey,
      button: true,
      selected: selected,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeInOut,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? colors.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelLarge?.copyWith(
                color: selected ? colors.onPrimary : colors.onSurfaceVariant,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
