import 'package:flutter/material.dart';
import 'dart:async';
import 'package:babushka_pressure/screens/profile_selection_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // 3 секунды смотрим на сердечко и летим в историю
    Timer(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
              builder: (context) => const ProfileSelectionScreen()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B100B), // Темный фон под твою картинку
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Твоя картинка из сообщения
            Image.asset(
              'assets/images/heart_pulse.png', // Проверь путь к файлу!
              width: 300,
            ),
            const SizedBox(height: 30),
            const Text(
              "КОНТРОЛЬ\nДАВЛЕНИЯ",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.greenAccent,
                fontSize: 28,
                fontWeight: FontWeight.bold,
                letterSpacing: 4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
