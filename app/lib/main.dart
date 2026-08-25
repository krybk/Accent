import 'package:flutter/material.dart';

import 'screens/servers_screen.dart';

void main() => runApp(const AccentApp());

class AccentApp extends StatelessWidget {
  const AccentApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Accent',
      debugShowCheckedModeBanner: false,
      // Both schemes are built from one seed so light and dark stay consistent
      // without a second palette to keep in sync by hand.
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3F6EA8)),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF3F6EA8),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const ServersScreen(),
    );
  }
}
