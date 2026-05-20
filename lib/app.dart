import 'package:flutter/material.dart';
import 'features/home/presentation/home_screen.dart';

class StreamGateApp extends StatelessWidget {
  const StreamGateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'StreamGate',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
