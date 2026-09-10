import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'progress_storage.dart';
import 'core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ProgressStorage.init();
  LevelProgress.loadFromStorage();
  runApp(const MyApp());
}


class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Arrow Puzzle',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1A1A2E)),
        scaffoldBackgroundColor: Colors.white,
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
