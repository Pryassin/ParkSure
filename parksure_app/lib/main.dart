import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'screens/map_screen.dart';

void main() {
  runApp(const ProviderScope(child: ParkSureApp()));
}

class ParkSureApp extends StatelessWidget {
  const ParkSureApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'ParkSure',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(colorSchemeSeed: const Color(0xFF1565C0), useMaterial3: true),
        home: const MapScreen(),
      );
}
