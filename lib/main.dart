import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'providers/auth_provider.dart';
import 'providers/admin_provider.dart';
import 'providers/exam_provider.dart';
import 'providers/question_provider.dart';
import 'providers/planner_provider.dart';

import 'utils/app_theme.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/admin/admin_dashboard.dart';
import 'screens/student/student_dashboard.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()..tryAutoLogin()),
        ChangeNotifierProvider(create: (_) => AdminProvider()),
        ChangeNotifierProvider(create: (_) => ExamProvider()),
        ChangeNotifierProvider(create: (_) => QuestionProvider()),
        ChangeNotifierProvider(create: (_) => PlannerProvider()..loadPlanner()),
      ],
      child: const MathsWithSDApp(),
    ),
  );
}

class MathsWithSDApp extends StatelessWidget {
  const MathsWithSDApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MathswithSD Admin',
      theme: AppTheme.lightTheme,
      debugShowCheckedModeBanner: false,
      home: const SplashScreen(),
      routes: {
        '/login': (context) => LoginScreen(
              onNavigateToRegister: () => Navigator.pushReplacementNamed(context, '/register'),
            ),
        '/register': (context) => RegisterScreen(
              onBackToLogin: () => Navigator.pushReplacementNamed(context, '/login'),
            ),
        '/admin': (context) => const AdminDashboard(),
        '/student': (context) => const StudentDashboard(),
      },
    );
  }
}


