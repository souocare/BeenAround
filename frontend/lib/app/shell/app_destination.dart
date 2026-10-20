import 'package:flutter/material.dart';

enum AppDestination {
  explore(
    label: 'Explore',
    icon: Icons.explore_outlined,
    selectedIcon: Icons.explore,
  ),
  trips(
    label: 'Trips',
    icon: Icons.luggage_outlined,
    selectedIcon: Icons.luggage,
  ),
  map(label: 'Map', icon: Icons.map_outlined, selectedIcon: Icons.map),
  statistics(
    label: 'Statistics',
    icon: Icons.bar_chart_outlined,
    selectedIcon: Icons.bar_chart,
  ),
  profile(
    label: 'Profile',
    icon: Icons.person_outline,
    selectedIcon: Icons.person,
  );

  const AppDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}
