import 'package:flutter/material.dart';

import 'core/theme/app_style.dart';
import 'features/map/presentation/map_screen.dart';

void main() {
  runApp(const ParkSureApp());
}

class ParkSureApp extends StatelessWidget {
  const ParkSureApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ParkSure',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: AppStyle.black),
        fontFamily: AppStyle.fontFamily,
        scaffoldBackgroundColor: AppStyle.background,
      ),
      // The widget gallery is still in lib/dev/widget_gallery.dart.
      home: const MapScreen(),
    );
  }
}
