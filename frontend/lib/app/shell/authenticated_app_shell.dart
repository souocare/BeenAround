import 'package:flutter/material.dart';

import '../../features/auth/domain/authenticated_user.dart';
import 'app_destination.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../theme/theme_cubit.dart';
import '../../features/explore/presentation/pages/explore_page.dart';

class AuthenticatedAppShell extends StatefulWidget {
  const AuthenticatedAppShell({
    required this.user,
    required this.onLogout,
    super.key,
  });

  final AuthenticatedUser user;
  final Future<void> Function() onLogout;

  @override
  State<AuthenticatedAppShell> createState() => _AuthenticatedAppShellState();
}

class _AuthenticatedAppShellState extends State<AuthenticatedAppShell> {
  static const double _desktopBreakpoint = 800;

  AppDestination _selectedDestination = AppDestination.explore;

  void _selectDestination(AppDestination destination) {
    if (_selectedDestination == destination) return;

    setState(() {
      _selectedDestination = destination;
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useTopNavigation = constraints.maxWidth >= _desktopBreakpoint;

        return Scaffold(
          appBar: useTopNavigation ? _buildDesktopAppBar(context) : null,
          body: _buildDestinationContent(context),
          bottomNavigationBar: useTopNavigation
              ? null
              : _buildMobileNavigation(),
        );
      },
    );
  }

  PreferredSizeWidget _buildDesktopAppBar(BuildContext context) {
    return AppBar(
      titleSpacing: 24,
      title: const Text(
        'BeenAround',
        style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.5),
      ),
      actions: [
        for (final destination in AppDestination.values)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: _DesktopNavigationItem(
              destination: destination,
              isSelected: _selectedDestination == destination,
              onPressed: () => _selectDestination(destination),
            ),
          ),
        const SizedBox(width: 16),
      ],
    );
  }

  Widget _buildMobileNavigation() {
    return NavigationBar(
      selectedIndex: _selectedDestination.index,
      onDestinationSelected: (index) {
        _selectDestination(AppDestination.values[index]);
      },
      destinations: [
        for (final destination in AppDestination.values)
          NavigationDestination(
            icon: Icon(destination.icon),
            selectedIcon: Icon(destination.selectedIcon),
            label: destination.label,
          ),
      ],
    );
  }

  Widget _buildDestinationContent(BuildContext context) {
    return switch (_selectedDestination) {
      AppDestination.explore => const ExplorePage(),
      AppDestination.trips => const _DestinationPlaceholder(
        title: 'Trips',
        subtitle: 'Organize your travel memories.',
        icon: Icons.luggage_outlined,
      ),
      AppDestination.map => const _DestinationPlaceholder(
        title: 'Map',
        subtitle: 'Discover your travel history on the map.',
        icon: Icons.map_outlined,
      ),
      AppDestination.statistics => const _DestinationPlaceholder(
        title: 'Statistics',
        subtitle: 'Explore your travel statistics.',
        icon: Icons.bar_chart_outlined,
      ),
      AppDestination.profile => _ProfilePlaceholder(
        user: widget.user,
        onLogout: widget.onLogout,
      ),
    };
  }
}

class _DesktopNavigationItem extends StatelessWidget {
  const _DesktopNavigationItem({
    required this.destination,
    required this.isSelected,
    required this.onPressed,
  });

  final AppDestination destination;
  final bool isSelected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(
        isSelected ? destination.selectedIcon : destination.icon,
        size: 18,
      ),
      label: Text(destination.label),
      style: TextButton.styleFrom(
        foregroundColor: isSelected
            ? colorScheme.primary
            : colorScheme.onSurfaceVariant,
        backgroundColor: isSelected
            ? colorScheme.primaryContainer.withValues(alpha: 0.45)
            : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

class _DestinationPlaceholder extends StatelessWidget {
  const _DestinationPlaceholder({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 20),
            Text(title, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfilePlaceholder extends StatelessWidget {
  const _ProfilePlaceholder({required this.user, required this.onLogout});

  final AuthenticatedUser user;
  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CircleAvatar(
                radius: 36,
                backgroundColor: colors.surfaceContainerHigh,
                child: Icon(Icons.person, size: 36, color: colors.primary),
              ),

              const SizedBox(height: 20),

              Text(
                user.displayName,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall,
              ),

              const SizedBox(height: 8),

              Text(
                '@${user.username}',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),

              const SizedBox(height: 36),

              Text(
                'Appearance',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                'Choose how BeenAround looks on this device.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),

              const SizedBox(height: 16),

              BlocBuilder<ThemeCubit, ThemeMode>(
                builder: (context, selectedMode) {
                  return Column(
                    children: [
                      _ThemeOption(
                        title: 'Dark',
                        subtitle: 'Use the dark appearance.',
                        icon: Icons.dark_mode_outlined,
                        mode: ThemeMode.dark,
                        selectedMode: selectedMode,
                      ),
                      _ThemeOption(
                        title: 'Light',
                        subtitle: 'Use the light appearance.',
                        icon: Icons.light_mode_outlined,
                        mode: ThemeMode.light,
                        selectedMode: selectedMode,
                      ),
                      _ThemeOption(
                        title: 'System',
                        subtitle: 'Follow your device settings.',
                        icon: Icons.brightness_auto_outlined,
                        mode: ThemeMode.system,
                        selectedMode: selectedMode,
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 32),

              FilledButton.icon(
                onPressed: onLogout,
                icon: const Icon(Icons.logout),
                label: const Text('Sign Out'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  const _ThemeOption({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.mode,
    required this.selectedMode,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final ThemeMode mode;
  final ThemeMode selectedMode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final selected = mode == selectedMode;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected
            ? colors.primary.withValues(alpha: 0.10)
            : colors.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            context.read<ThemeCubit>().setThemeMode(mode);
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? colors.primary : colors.outline,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: selected ? colors.primary : colors.onSurfaceVariant,
                ),

                const SizedBox(width: 16),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),

                if (selected) Icon(Icons.check_circle, color: colors.primary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
