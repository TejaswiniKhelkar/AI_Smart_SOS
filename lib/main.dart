import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';
import 'app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SmartSOSApp());
}

class SmartSOSApp extends StatelessWidget {
  const SmartSOSApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'AI Smart SOS',
      theme: AppTheme.darkTheme,
      home: const SplashScreen(),
    );
  }
}