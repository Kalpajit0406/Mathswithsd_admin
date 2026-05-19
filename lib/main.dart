import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'providers/auth_provider.dart';
import 'providers/admin_provider.dart';
import 'providers/exam_provider.dart';
import 'providers/question_provider.dart';

import 'utils/app_theme.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/admin/admin_dashboard.dart';
import 'screens/student/student_dashboard.dart';

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
      title: 'MathsWithSD',
      theme: AppTheme.lightTheme,
      debugShowCheckedModeBanner: false,
      home: const _AuthGate(),
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

class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        if (auth.status == AuthStatus.initial || auth.status == AuthStatus.loading && auth.user == null) {
          // Splash screen while checking auto-login
          return const Scaffold(
            backgroundColor: Color(0xFF0A1628),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.school, color: Color(0xFF00BCD4), size: 80),
                  SizedBox(height: 24),
                  CircularProgressIndicator(color: Color(0xFF00BCD4)),
                ],
              ),
            ),
          );
        }

        if (auth.isAuthenticated) {
          if (auth.isAdmin) {
            return const AdminDashboard();
          } else {
            return const StudentDashboard();
          }
        }

        // Unauthenticated
        return LoginScreen(
          onNavigateToRegister: () {
            Navigator.pushReplacementNamed(context, '/register');
          },
        );
      },
    );
  }
}
