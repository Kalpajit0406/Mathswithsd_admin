import 'dart:ui';
import 'package:flutter/material.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;
  final double blur;
  final Color? color;
  final BoxBorder? border;
  final List<BoxShadow>? boxShadow;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius = 24.0,
    this.blur = 16.0,
    this.color,
    this.border,
    this.boxShadow,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final resolvedColor = color;
    
    final resolvedGradient = color != null ? null : (isDark 
        ? LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withOpacity(0.07), // Specular light highlight
              Colors.black.withOpacity(0.60), // Frosted smoked glass body
              Colors.black.withOpacity(0.85), // Fading to deep black background
            ],
            stops: const [0.0, 0.45, 1.0],
          )
        : LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withOpacity(0.92),
              Colors.white.withOpacity(0.78),
            ],
          ));
        
    final borderGradient = isDark 
        ? LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withOpacity(0.15),
              Colors.white.withOpacity(0.02),
            ],
          )
        : const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0x40FFFFFF),
              Color(0x0A000000),
            ],
          );

    final resolvedBoxShadow = boxShadow ?? (isDark 
        ? [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: const Color(0xFF0051D5).withOpacity(0.04), // Subtle ambient glow
              blurRadius: 32,
              offset: const Offset(0, 12),
            )
          ]
        : [
            BoxShadow(
              color: const Color(0xFF0F172A).withOpacity(0.03),
              blurRadius: 20,
              offset: const Offset(0, 8),
            )
          ]);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: resolvedBoxShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: CustomPaint(
            foregroundPainter: border != null
                ? null
                : GradientBorderPainter(
                    borderRadius: borderRadius,
                    width: 1.0,
                    gradient: borderGradient,
                  ),
            child: Container(
              padding: padding ?? const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: resolvedColor,
                gradient: resolvedGradient,
                borderRadius: BorderRadius.circular(borderRadius),
                border: border,
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class GradientBorderPainter extends CustomPainter {
  final double borderRadius;
  final double width;
  final Gradient gradient;

  GradientBorderPainter({
    required this.borderRadius,
    required this.width,
    required this.gradient,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(width / 2, width / 2, size.width - width, size.height - width);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(borderRadius - width / 2));
    
    final paint = Paint()
      ..shader = gradient.createShader(Offset.zero & size)
      ..strokeWidth = width
      ..style = PaintingStyle.stroke;

    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant GradientBorderPainter oldDelegate) {
    return oldDelegate.borderRadius != borderRadius ||
        oldDelegate.width != width ||
        oldDelegate.gradient != gradient;
  }
}
