import 'package:flutter/material.dart';

import 'core/theme/app_style.dart';
import 'dev/widget_gallery.dart';

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
        scaffoldBackgroundColor: AppStyle.background,
      ),
      // Temporary: shows every shared widget. Replace with the map screen later.
      home: const WidgetGallery(),
    );
  }
}
