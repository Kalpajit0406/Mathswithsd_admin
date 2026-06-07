import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_avif/flutter_avif.dart';

import '../providers/auth_provider.dart';
import 'admin/admin_dashboard.dart';
import 'student/student_dashboard.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _progressController;
  late final Animation<double> _progressAnimation;
  VoidCallback? _authListener;

  @override
  void initState() {
    super.initState();

    // 1. Setup loading bar progress animation (3.2 seconds duration)
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    );

    _progressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _progressController,
        curve: Curves.easeInOutCubic,
      ),
    );

    // Start progress loading animation
    _progressController.forward();

    // When progress finishes, orchestrate transition
    _progressController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _checkAndNavigate();
      }
    });
  }

  @override
  void dispose() {
    if (_authListener != null) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      auth.removeListener(_authListener!);
    }
    _progressController.dispose();
    super.dispose();
  }

  void _checkAndNavigate() {
    if (!mounted) return;
    final auth = Provider.of<AuthProvider>(context, listen: false);

    if (auth.status != AuthStatus.initial && !(auth.status == AuthStatus.loading && auth.user == null)) {
      _navigateToNext(auth);
    } else {
      _authListener = () {
        final updatedAuth = Provider.of<AuthProvider>(context, listen: false);
        if (updatedAuth.status != AuthStatus.initial && !(updatedAuth.status == AuthStatus.loading && updatedAuth.user == null)) {
          updatedAuth.removeListener(_authListener!);
          _authListener = null;
          _navigateToNext(updatedAuth);
        }
      };
      auth.addListener(_authListener!);
    }
  }

  void _navigateToNext(AuthProvider auth) {
    if (!mounted) return;
    
    final Widget nextWidget;
    if (auth.isAuthenticated) {
      if (auth.isAdmin) {
        nextWidget = const AdminDashboard();
      } else {
        nextWidget = const StudentDashboard();
      }
    } else {
      nextWidget = LoginScreen(
        onNavigateToRegister: () {
          Navigator.pushReplacementNamed(context, '/register');
        },
      );
    }

    // Smooth, cinematic 650ms CrossFade transition
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => nextWidget,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 650),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final width = screenSize.width;
    final height = screenSize.height;

    final double bookCenterX = width * 0.5;
    final double bookCenterY = height * 0.55;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        alignment: Alignment.center,
        children: [
          // 1. Vector Scenic Background
          Positioned.fill(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: BackgroundSceneryPainter(),
              ),
            ),
          ),

          // 2. Faint Watermark "M" in Background
          Positioned(
            top: bookCenterY - 145,
            child: IgnorePointer(
              child: Text(
                'M',
                style: TextStyle(
                  fontSize: 220,
                  fontWeight: FontWeight.w900,
                  height: 1.0,
                  letterSpacing: -5,
                  color: const Color(0xFFF97316).withValues(alpha: 0.025),
                  fontFamily: 'Outfit',
                ),
              ),
            ),
          ),

          // 3. Gentle Floating Math Symbols (Out-of-phase floating)
          FloatingMathSymbol(
            startX: bookCenterX - 55,
            startY: bookCenterY - 45,
            verticalAmplitude: 6.0,
            horizontalAmplitude: 2.0,
            phaseShift: 0.0,
            duration: const Duration(seconds: 4),
            child: Text(
              '√x',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: const Color(0xFFF97316).withValues(alpha: 0.65),
              ),
            ),
          ),
          FloatingMathSymbol(
            startX: bookCenterX + 12,
            startY: bookCenterY - 62,
            verticalAmplitude: 8.0,
            horizontalAmplitude: 3.5,
            phaseShift: 1.2,
            duration: const Duration(milliseconds: 4500),
            child: Text(
              'π',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: const Color(0xFFF97316).withValues(alpha: 0.75),
              ),
            ),
          ),
          FloatingMathSymbol(
            startX: bookCenterX + 48,
            startY: bookCenterY - 40,
            verticalAmplitude: 7.0,
            horizontalAmplitude: 2.5,
            phaseShift: 2.5,
            duration: const Duration(milliseconds: 3800),
            child: Text(
              'f(x)',
              style: TextStyle(
                fontSize: 17,
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.bold,
                color: const Color(0xFFF97316).withValues(alpha: 0.70),
              ),
            ),
          ),
          FloatingMathSymbol(
            startX: bookCenterX - 72,
            startY: bookCenterY - 12,
            verticalAmplitude: 5.5,
            horizontalAmplitude: 1.8,
            phaseShift: 3.8,
            duration: const Duration(seconds: 5),
            child: Text(
              'Σ',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: const Color(0xFFF97316).withValues(alpha: 0.60),
              ),
            ),
          ),
          FloatingMathSymbol(
            startX: bookCenterX - 22,
            startY: bookCenterY - 14,
            verticalAmplitude: 9.0,
            horizontalAmplitude: 3.0,
            phaseShift: 0.7,
            duration: const Duration(milliseconds: 4200),
            child: SizedBox(
              width: 22,
              height: 22,
              child: CustomPaint(
                painter: TrianglePainter(),
              ),
            ),
          ),
          FloatingMathSymbol(
            startX: bookCenterX + 46,
            startY: bookCenterY + 14,
            verticalAmplitude: 6.5,
            horizontalAmplitude: 2.0,
            phaseShift: 4.8,
            duration: const Duration(milliseconds: 4900),
            child: Text(
              'x²',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: const Color(0xFFF97316).withValues(alpha: 0.65),
              ),
            ),
          ),

          // 4. Premium Branding Text
          Positioned(
            top: height * 0.22,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'MathsWith',
                      style: TextStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF0F172A),
                        letterSpacing: -1.5,
                      ),
                    ),
                    Text(
                      'SD',
                      style: TextStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFFF97316),
                        letterSpacing: -1.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  width: 48,
                  height: 3,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF97316),
                    borderRadius: BorderRadius.circular(1.5),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'PRACTICE TODAY, EXCEL TOMORROW',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF75859D),
                    letterSpacing: 1.8,
                  ),
                ),
              ],
            ),
          ),

          // 5. Progress Bar & Bike
          Positioned(
            bottom: height * 0.08,
            left: 28,
            right: 28,
            child: AnimatedBuilder(
              animation: _progressAnimation,
              builder: (context, child) {
                final progress = _progressAnimation.value;
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final trackWidth = constraints.maxWidth;
                          const bikeWidth = 52.0;
                          const bikeHeight = 32.0;
                          
                          final bikeLeft = (progress * trackWidth - 16.0).clamp(-12.0, trackWidth - bikeWidth + 6.0);
                          final isMoving = progress > 0.001 && progress < 0.999;
                          final jitterY = isMoving ? sin(DateTime.now().microsecondsSinceEpoch / 14000.0) * 0.75 : 0.0;

                          return SizedBox(
                            height: 44,
                            child: Stack(
                              clipBehavior: Clip.none,
                              alignment: Alignment.bottomLeft,
                              children: [
                                // Track background
                                Container(
                                  width: double.infinity,
                                  height: 4.5,
                                  margin: const EdgeInsets.only(bottom: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFECEEF0),
                                    borderRadius: BorderRadius.circular(2.25),
                                  ),
                                ),

                                // Progress fill
                                FractionallySizedBox(
                                  widthFactor: progress,
                                  child: Container(
                                    height: 4.5,
                                    margin: const EdgeInsets.only(bottom: 4),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(2.25),
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFFEA580C),
                                          Color(0xFFF97316),
                                        ],
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFFF97316).withValues(alpha: 0.35),
                                          blurRadius: 6,
                                          spreadRadius: 0.5,
                                          offset: const Offset(0, 0.5),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                // Speed lines
                                if (isMoving) ...[
                                  Positioned(
                                    left: (bikeLeft - 22.0).clamp(-28.0, trackWidth),
                                    bottom: 12 + jitterY,
                                    child: Opacity(
                                      opacity: (0.45 * progress).clamp(0.0, 1.0),
                                      child: Container(
                                        width: 18 + sin(DateTime.now().microsecondsSinceEpoch / 20000.0) * 4,
                                        height: 1.0,
                                        color: const Color(0xFFF97316),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    left: (bikeLeft - 32.0).clamp(-36.0, trackWidth),
                                    bottom: 8 + jitterY,
                                    child: Opacity(
                                      opacity: (0.35 * progress).clamp(0.0, 1.0),
                                      child: Container(
                                        width: 24 + cos(DateTime.now().microsecondsSinceEpoch / 18000.0) * 5,
                                        height: 1.0,
                                        color: const Color(0xFFF97316),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    left: (bikeLeft - 18.0).clamp(-24.0, trackWidth),
                                    bottom: 4 + jitterY,
                                    child: Opacity(
                                      opacity: (0.40 * progress).clamp(0.0, 1.0),
                                      child: Container(
                                        width: 14 + sin(DateTime.now().microsecondsSinceEpoch / 22000.0) * 3,
                                        height: 1.0,
                                        color: const Color(0xFFF97316),
                                      ),
                                    ),
                                  ),
                                ],

                                // Motorcycle
                                Positioned(
                                  left: bikeLeft,
                                  bottom: 4.5 + jitterY,
                                  child: RepaintBoundary(
                                    child: AvifSafeImage(
                                      assetPath: 'assets/images/himalayan.avif',
                                      width: bikeWidth,
                                      height: bikeHeight,
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 18),
                    Container(
                      width: 42,
                      alignment: Alignment.centerRight,
                      child: Text(
                        '${(progress * 100).toInt()}%',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                          fontFeatures: [
                            FontFeature.tabularFigures(),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class BackgroundSceneryPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;

    // 1. Background Gradient
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        colors: [
          Color(0xFFFFFFFF),
          Color(0xFFFCF8F2),
          Color(0xFFFDF4E7),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, bgPaint);

    // 2. Rising Sun
    final sunCenter = Offset(width * 0.72, height * 0.44);
    final sunPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFF97316).withValues(alpha: 0.12),
          const Color(0xFFFDE8E0).withValues(alpha: 0.04),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: sunCenter, radius: 110));
    canvas.drawCircle(sunCenter, 110, sunPaint);

    // 3. Mountains Layer 1
    final backMountainPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          const Color(0xFFFDBA74).withValues(alpha: 0.12),
          const Color(0xFFFED7AA).withValues(alpha: 0.04),
          Colors.transparent,
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, height * 0.38, width, height * 0.28));

    final backPath = Path()
      ..moveTo(0, height * 0.65)
      ..lineTo(0, height * 0.44)
      ..quadraticBezierTo(width * 0.18, height * 0.39, width * 0.38, height * 0.46)
      ..quadraticBezierTo(width * 0.60, height * 0.52, width * 0.75, height * 0.49)
      ..lineTo(width, height * 0.54)
      ..lineTo(width, height * 0.66)
      ..close();
    canvas.drawPath(backPath, backMountainPaint);

    // 4. Mountains Layer 2
    final frontMountainPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          const Color(0xFFFDBA74).withValues(alpha: 0.18),
          const Color(0xFFFDE8E0).withValues(alpha: 0.06),
          Colors.transparent,
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, height * 0.42, width, height * 0.24));

    final frontPath = Path()
      ..moveTo(0, height * 0.66)
      ..lineTo(0, height * 0.52)
      ..quadraticBezierTo(width * 0.25, height * 0.56, width * 0.45, height * 0.50)
      ..quadraticBezierTo(width * 0.68, height * 0.43, width * 0.82, height * 0.46)
      ..lineTo(width, height * 0.52)
      ..lineTo(width, height * 0.66)
      ..close();
    canvas.drawPath(frontPath, frontMountainPaint);

    // 5. Pine Trees
    final treePaint = Paint()
      ..color = const Color(0xFFF97316).withValues(alpha: 0.05)
      ..style = PaintingStyle.fill;

    _drawPineTree(canvas, width * 0.08, height * 0.53, 14, 28, treePaint);
    _drawPineTree(canvas, width * 0.14, height * 0.55, 18, 34, treePaint);
    _drawPineTree(canvas, width * 0.20, height * 0.58, 12, 24, treePaint);

    _drawPineTree(canvas, width * 0.82, height * 0.57, 12, 24, treePaint);
    _drawPineTree(canvas, width * 0.88, height * 0.54, 18, 36, treePaint);
    _drawPineTree(canvas, width * 0.94, height * 0.56, 14, 28, treePaint);

    // 6. Open Book
    final bookCenterY = height * 0.55;
    final bookCenterX = width * 0.5;
    final bookHalfWidth = 65.0;
    final bookHeight = 32.0;

    final bookOutlinePaint = Paint()
      ..color = const Color(0xFFF97316).withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    final bookFillPaint = Paint()
      ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.75)
      ..style = PaintingStyle.fill;

    final leftPage = Path()
      ..moveTo(bookCenterX, bookCenterY + 4)
      ..cubicTo(
        bookCenterX - bookHalfWidth * 0.4, bookCenterY - 4,
        bookCenterX - bookHalfWidth * 0.8, bookCenterY - 6,
        bookCenterX - bookHalfWidth, bookCenterY - 1,
      )
      ..lineTo(bookCenterX - bookHalfWidth, bookCenterY - 1 + bookHeight)
      ..cubicTo(
        bookCenterX - bookHalfWidth * 0.8, bookCenterY - 6 + bookHeight,
        bookCenterX - bookHalfWidth * 0.4, bookCenterY - 4 + bookHeight,
        bookCenterX, bookCenterY + 4 + bookHeight,
      )
      ..close();

    final rightPage = Path()
      ..moveTo(bookCenterX, bookCenterY + 4)
      ..cubicTo(
        bookCenterX + bookHalfWidth * 0.4, bookCenterY - 4,
        bookCenterX + bookHalfWidth * 0.8, bookCenterY - 6,
        bookCenterX + bookHalfWidth, bookCenterY - 1,
      )
      ..lineTo(bookCenterX + bookHalfWidth, bookCenterY - 1 + bookHeight)
      ..cubicTo(
        bookCenterX + bookHalfWidth * 0.8, bookCenterY - 6 + bookHeight,
        bookCenterX + bookHalfWidth * 0.4, bookCenterY - 4 + bookHeight,
        bookCenterX, bookCenterY + 4 + bookHeight,
      )
      ..close();

    canvas.drawPath(leftPage, bookFillPaint);
    canvas.drawPath(rightPage, bookFillPaint);

    canvas.drawPath(leftPage, bookOutlinePaint);
    canvas.drawPath(rightPage, bookOutlinePaint);

    canvas.drawLine(
      Offset(bookCenterX, bookCenterY + 4),
      Offset(bookCenterX, bookCenterY + 4 + bookHeight),
      bookOutlinePaint..strokeWidth = 2.0,
    );

    final pagesThicknessPaint = Paint()
      ..color = const Color(0xFFF97316).withValues(alpha: 0.10)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (int i = 1; i <= 3; i++) {
      final offset = i * 2.0;
      final extraLeftPage = Path()
        ..moveTo(bookCenterX, bookCenterY + 4 + offset)
        ..cubicTo(
          bookCenterX - bookHalfWidth * 0.4, bookCenterY - 4 + offset,
          bookCenterX - bookHalfWidth * 0.8, bookCenterY - 6 + offset,
          bookCenterX - bookHalfWidth + 1, bookCenterY - 1 + offset,
        );
      final extraRightPage = Path()
        ..moveTo(bookCenterX, bookCenterY + 4 + offset)
        ..cubicTo(
          bookCenterX + bookHalfWidth * 0.4, bookCenterY - 4 + offset,
          bookCenterX + bookHalfWidth * 0.8, bookCenterY - 6 + offset,
          bookCenterX + bookHalfWidth - 1, bookCenterY - 1 + offset,
        );
      canvas.drawPath(extraLeftPage, pagesThicknessPaint);
      canvas.drawPath(extraRightPage, pagesThicknessPaint);
    }
  }

  void _drawPineTree(Canvas canvas, double x, double y, double width, double height, Paint paint) {
    final path = Path()
      ..moveTo(x, y - height)
      ..lineTo(x - width / 2, y)
      ..lineTo(x + width / 2, y)
      ..close();
    canvas.drawPath(path, paint);

    final innerPaint = Paint()
      ..color = const Color(0xFFF97316).withValues(alpha: 0.03)
      ..style = PaintingStyle.fill;
    final path2 = Path()
      ..moveTo(x, y - height * 0.6)
      ..lineTo(x - width * 0.35, y)
      ..lineTo(x + width * 0.35, y)
      ..close();
    canvas.drawPath(path2, innerPaint);
  }

  @override
  bool shouldRepaint(covariant BackgroundSceneryPainter oldDelegate) => false;
}

class TrianglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFF97316).withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final path = Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(0, size.height)
      ..lineTo(size.width, size.height)
      ..close();

    canvas.drawPath(path, paint);

    final dashPaint = Paint()
      ..color = const Color(0xFFF97316).withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    
    double startY = 0;
    double endY = size.height;
    double dashHeight = 3;
    double dashSpace = 2;
    while (startY < endY) {
      canvas.drawLine(
        Offset(size.width / 2, startY),
        Offset(size.width / 2, startY + dashHeight),
        dashPaint,
      );
      startY += dashHeight + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class FloatingMathSymbol extends StatefulWidget {
  final Widget child;
  final double startX;
  final double startY;
  final Duration duration;
  final double verticalAmplitude;
  final double horizontalAmplitude;
  final double phaseShift;

  const FloatingMathSymbol({
    super.key,
    required this.child,
    required this.startX,
    required this.startY,
    this.duration = const Duration(seconds: 4),
    this.verticalAmplitude = 8.0,
    this.horizontalAmplitude = 3.0,
    this.phaseShift = 0.0,
  });

  @override
  State<FloatingMathSymbol> createState() => _FloatingMathSymbolState();
}

class _FloatingMathSymbolState extends State<FloatingMathSymbol> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final val = _controller.value * 2.0 * pi + widget.phaseShift;
        final dy = sin(val) * widget.verticalAmplitude;
        final dx = cos(val) * widget.horizontalAmplitude;

        return Positioned(
          left: widget.startX + dx,
          top: widget.startY + dy,
          child: RepaintBoundary(child: child!),
        );
      },
      child: widget.child,
    );
  }
}

class AvifSafeImage extends StatelessWidget {
  final String assetPath;
  final double width;
  final double height;
  final BoxFit fit;

  const AvifSafeImage({
    super.key,
    required this.assetPath,
    required this.width,
    required this.height,
    this.fit = BoxFit.contain,
  });

  @override
  Widget build(BuildContext context) {
    return AvifImage.asset(
      assetPath,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (context, error, stackTrace) {
        debugPrint('[AvifSafeImage] Failed to decode AVIF: $error');
        return Icon(
          Icons.motorcycle_rounded,
          color: const Color(0xFFF97316),
          size: height * 0.8,
        );
      },
    );
  }
}
