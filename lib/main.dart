// Файл: lib/main.dart

import 'package:flutter/material.dart';

import 'package:med_history_app/screens/auth/login_screen.dart';
import 'package:med_history_app/screens/auth/register_screen.dart';
import 'package:med_history_app/screens/home/home_screen.dart';
import 'package:med_history_app/screens/profile/profile_screen.dart';
import 'package:med_history_app/screens/records/record_detail_screen.dart';
import 'package:med_history_app/screens/records/record_form_screen.dart';
import 'package:med_history_app/screens/splash_screen.dart';
import 'package:med_history_app/state/app_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final appController = AppController();
  runApp(HabitKeepApp(controller: appController));
}

class HabitKeepApp extends StatelessWidget {
  final AppController controller;

  const HabitKeepApp({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return AppStateScope(
      notifier: controller,
      child: Builder(
          builder: (context) {
            final appController = AppStateScope.of(context);
            return MaterialApp(
              title: 'HabitKeep — Контроль звичок',
              debugShowCheckedModeBanner: false,
              themeMode: appController.themeMode, // Підключаємо живу тему
              theme: ThemeData(
                useMaterial3: true,
                colorScheme: ColorScheme.fromSeed(
                  seedColor: const Color(0xFF4F46E5),
                  brightness: Brightness.light,
                ),
                appBarTheme: const AppBarTheme(
                  centerTitle: false,
                  scrolledUnderElevation: 0,
                ),
              ),
              darkTheme: ThemeData( // Додаємо налаштування для темного режиму
                useMaterial3: true,
                colorScheme: ColorScheme.fromSeed(
                  seedColor: const Color(0xFF4F46E5),
                  brightness: Brightness.dark,
                ),
                appBarTheme: const AppBarTheme(
                  centerTitle: false,
                  scrolledUnderElevation: 0,
                ),
              ),
              initialRoute: AppRoutes.splash,
              onGenerateRoute: (settings) {
                switch (settings.name) {
                  case AppRoutes.splash:
                    return MaterialPageRoute(builder: (_) => const SplashScreen());
                  case AppRoutes.login:
                    return MaterialPageRoute(builder: (_) => const LoginScreen());
                  case AppRoutes.register:
                    return MaterialPageRoute(builder: (_) => const RegisterScreen());
                  case AppRoutes.home:
                    return MaterialPageRoute(builder: (_) => const HomeScreen());
                  case AppRoutes.habitForm:
                    final existingId = settings.arguments as int?;
                    return MaterialPageRoute(builder: (_) => RecordFormScreen(existingRecordId: existingId));
                  case AppRoutes.habitDetail:
                    final habitId = settings.arguments as int;
                    return MaterialPageRoute(builder: (_) => RecordDetailScreen(recordId: habitId));
                  case AppRoutes.profile:
                    return MaterialPageRoute(builder: (_) => const ProfileScreen());
                  default:
                    return MaterialPageRoute(builder: (_) => const SplashScreen());
                }
              },
            );
          }
      ),
    );
  }
}