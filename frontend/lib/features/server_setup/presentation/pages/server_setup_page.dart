import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/theme/app_tokens.dart';
import '../../application/server_setup_cubit.dart';
import '../../application/server_setup_state.dart';
import '../../../../app/theme/app_colors.dart';

class ServerSetupPage extends StatefulWidget {
  const ServerSetupPage({super.key});

  @override
  State<ServerSetupPage> createState() => _ServerSetupPageState();
}

class _ServerSetupPageState extends State<ServerSetupPage> {
  final _serverController = TextEditingController();

  @override
  void dispose() {
    _serverController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildHeader(context),
                        _buildForm(),
                        _buildFooter(context),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(top: 36),
      child: Column(
        children: [
          _buildCompass(context),
          const SizedBox(height: AppSpacing.xl),
          Text(
            'BeenAround',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Connect to your server',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: -0.8,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Your travels. Your server. Your story.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(color: colors.secondary),
          ),
          const SizedBox(height: 10),
          Text(
            'Enter your BeenAround server address to\nget started.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompass(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return SizedBox(
      width: 86,
      height: 86,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 78,
            height: 78,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.surfaceContainerHigh,
              border: Border.all(color: colors.outline),
            ),
            child: Icon(
              Icons.explore_outlined,
              size: 43,
              color: colors.onSurfaceVariant,
            ),
          ),
          Positioned(
            right: 0,
            top: 28,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.navigation_rounded,
                size: 22,
                color: colors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return BlocBuilder<ServerSetupCubit, ServerSetupState>(
      builder: (context, state) {
        final theme = Theme.of(context);
        final colors = theme.colorScheme;
        final cubit = context.read<ServerSetupCubit>();

        final isBusy = state.isChecking || state.isSaving;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'SERVER ADDRESS',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 6),

              TextField(
                controller: _serverController,
                enabled: !state.isSaving,
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.done,
                autocorrect: false,
                enableSuggestions: false,
                onChanged: cubit.addressChanged,
                onSubmitted: (_) => cubit.testConnection(),
                style: theme.textTheme.bodyMedium?.copyWith(fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'https://beenaround.example.com',
                  hintStyle: TextStyle(color: colors.onSurfaceVariant),
                  prefixIcon: Icon(
                    Icons.dns_outlined,
                    color: colors.onSurfaceVariant,
                    size: 20,
                  ),
                  filled: true,
                  fillColor: colors.surfaceContainerHigh,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: BorderSide(color: colors.primary, width: 1.5),
                  ),
                ),
              ),

              const SizedBox(height: 10),

              Text(
                'Connect to your own self-hosted BeenAround instance '
                'or private server.',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 12,
                  height: 1.4,
                  color: colors.onSurfaceVariant,
                ),
              ),

              if (state.showHttpWarning) ...[
                const SizedBox(height: AppSpacing.lg),
                _buildHttpWarning(context),
              ],

              const SizedBox(height: AppSpacing.xl),

              // Secondary action: verify the server.
              SizedBox(
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: isBusy ? null : cubit.testConnection,
                  icon: state.isChecking
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.wifi_tethering_rounded),
                  label: Text(
                    state.isChecking
                        ? 'Testing Connection...'
                        : 'Test Connection',
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colors.onSurface,
                    side: BorderSide(color: colors.outline),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                ),
              ),

              if (state.phase == ServerSetupPhase.available ||
                  state.phase == ServerSetupPhase.unavailable ||
                  state.phase == ServerSetupPhase.incompatible ||
                  state.phase == ServerSetupPhase.saveFailed) ...[
                const SizedBox(height: AppSpacing.lg),
                _buildConnectionStatus(context, state),
              ],

              const SizedBox(height: AppSpacing.lg),

              // Primary action: enabled only after successful verification.
              SizedBox(
                height: 52,
                child: FilledButton(
                  onPressed: state.canConnect ? cubit.connect : null,
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                  child: state.isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Connect to Server',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(width: AppSpacing.md),
                            Icon(Icons.arrow_forward_rounded, size: 20),
                          ],
                        ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFooter(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        children: [
          Container(
            constraints: const BoxConstraints(maxWidth: 320),
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: colors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(30),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.lock_outline_rounded,
                  size: 15,
                  color: colors.onSurfaceVariant,
                ),
                const SizedBox(width: AppSpacing.sm),
                Flexible(
                  child: Text(
                    'Self-hosted. Your data stays yours.',
                    textAlign: TextAlign.center,
                    softWrap: true,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 12,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'BEENAROUND MOBILE CLIENT',
            style: theme.textTheme.labelSmall?.copyWith(
              fontSize: 10,
              letterSpacing: 0.8,
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHttpWarning(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final warningColor = colors.tertiary;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: warningColor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: warningColor.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, size: 20, color: warningColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Unencrypted connection. HTTP does not protect '
              'your login credentials or travel data while in transit.',
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 12,
                height: 1.4,
                color: colors.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionStatus(BuildContext context, ServerSetupState state) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final successColor = colors.brightness == Brightness.dark
        ? AppColors.darkSuccess
        : AppColors.lightSuccess;

    final (color, icon, title, description) = switch (state.phase) {
      ServerSetupPhase.available => (
        successColor,
        Icons.check_circle_outline_rounded,
        'Server available',
        'BeenAround server verified.',
      ),
      ServerSetupPhase.unavailable => (
        colors.error,
        Icons.error_outline_rounded,
        'Unable to reach server',
        'Check the address and try again.',
      ),
      ServerSetupPhase.incompatible => (
        colors.error,
        Icons.error_outline_rounded,
        'Incompatible server',
        'This address does not appear to host BeenAround.',
      ),
      ServerSetupPhase.saveFailed => (
        colors.error,
        Icons.error_outline_rounded,
        'Unable to save server',
        'Please try again.',
      ),
      _ => (colors.onSurfaceVariant, Icons.info_outline, '', ''),
    };

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 12,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
