import 'package:flutter/material.dart';

import '../widgets/travel_map.dart';

class MapPage extends StatelessWidget {
  const MapPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: TravelMap());
  }
}
