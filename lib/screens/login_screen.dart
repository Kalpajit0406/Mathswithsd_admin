import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../../widgets/fade_in_slide.dart';
import '../../widgets/glass_card.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback onNavigateToRegister;
  const LoginScreen({super.key, required this.onNavigateToRegister});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  Future<void> _loginAsAdmin() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    // Hardcoded teacher/admin credentials
    final success = await authProvider.login('6289855545', 'admin123');

    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authProvider.errorMessage ?? 'Login failed'),
          backgroundColor: const Color(0xFFBA1A1A),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    return Scaffold(
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0A0F1D), Color(0xFF1E1B4B)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 32.0,
                  vertical: 24.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 40),
                    // Logo / Branding with elegant slide
                    FadeInSlide(
                      duration: const Duration(milliseconds: 700),
                      slideOffset: 30,
                      child: Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF0051D5), Color(0xFF316BF3)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(26),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFF0051D5,
                              ).withValues(alpha: 0.35),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.admin_panel_settings_rounded,
                          color: Colors.white,
                          size: 52,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    FadeInSlide(
                      duration: const Duration(milliseconds: 700),
                      delay: const Duration(milliseconds: 100),
                      slideOffset: 20,
                      child: const Text(
                        'MathsAdmin',
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),

                    FadeInSlide(
                      duration: const Duration(milliseconds: 700),
                      delay: const Duration(milliseconds: 150),
                      slideOffset: 15,
                      child: const Text(
                        'Authorized Teacher Evaluation Suite',
                        style: TextStyle(
                          color: Color(0xFF75859D),
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),

                    const SizedBox(height: 80),

                    // Secure login information box with GlassCard
                    FadeInSlide(
                      duration: const Duration(milliseconds: 650),
                      delay: const Duration(milliseconds: 200),
                      slideOffset: 24,
                      child: GlassCard(
                        borderRadius: 20,
                        color: const Color(0xFF1E293B).withValues(alpha: 0.5),
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.lock_person_rounded,
                              color: Color(0xFF0051D5),
                              size: 36,
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Passwordless Secure Bypass Active',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Logging in using teacher identifier *******545. standard credentials will be bypassed dynamically.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: const Color(0xFF75859D),
                                fontSize: 12.5,
                                height: 1.45,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 48),

                    // Login Button
                    FadeInSlide(
                      duration: const Duration(milliseconds: 650),
                      delay: const Duration(milliseconds: 250),
                      slideOffset: 24,
                      child: SizedBox(
                        width: double.infinity,
                        height: 60,
                        child: auth.status == AuthStatus.loading
                            ? const Center(
                                child: CircularProgressIndicator(
                                  color: Color(0xFF0051D5),
                                ),
                              )
                            : BounceOnTap(
                                onTap: _loginAsAdmin,
                                child: Container(
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFF0051D5),
                                        Color(0xFF316BF3),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(18),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(
                                          0xFF0051D5,
                                        ).withValues(alpha: 0.3),
                                        blurRadius: 18,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: const [
                                      Icon(
                                        Icons.login_rounded,
                                        color: Colors.white,
                                      ),
                                      SizedBox(width: 10),
                                      Text(
                                        'Login as Teacher',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                          letterSpacing: -0.2,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
