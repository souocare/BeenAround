import 'package:beenaround/app/theme/app_action_icons.dart';
import 'package:flutter/material.dart';

import '../../../../app/theme/app_tokens.dart';

/// Compact empty state for record sections inside Trip Details.
///
/// The parent owns the action and its availability.
/// This widget does not create or associate travel records.
class TripSectionEmptyState extends StatelessWidget {
  const TripSectionEmptyState({
    required this.title,
    required this.message,
    required this.icon,
    required this.actionLabel,
    required this.actionKey,
    required this.onAction,
    super.key,
  });

  final String title;
  final String message;
  final IconData icon;
  final String actionLabel;
  final Key actionKey;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xl,
      ),
      width: double.infinity,
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 32, color: colors.onSurfaceVariant),

          const SizedBox(height: AppSpacing.md),

          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),

          const SizedBox(height: AppSpacing.sm),

          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 300),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          FilledButton.tonalIcon(
            key: actionKey,
            onPressed: onAction,
            icon: Icon(AppActionIcons.add(context)),
            label: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}
