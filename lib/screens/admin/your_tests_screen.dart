import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:ui';
import 'dart:math' as math;
import '../../providers/admin_provider.dart';
import '../../models/test_model.dart';
import 'leaderboard_screen.dart';

class YourTestsScreen extends StatefulWidget {
  const YourTestsScreen({super.key});

  @override
  State<YourTestsScreen> createState() => _YourTestsScreenState();
}

class _YourTestsScreenState extends State<YourTestsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _bgController;

  @override
  void initState() {
    super.initState();
    _bgController = AnimationController(
      duration: const Duration(seconds: 18),
      vsync: this,
    )..repeat(reverse: true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AdminProvider>(context, listen: false).loadTests();
    });
  }

  @override
  void dispose() {
    _bgController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Color(0xFF0F172A),
                  size: 20,
                ),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        title: const Text(
          'Assessments',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w800,
            fontSize: 22,
            letterSpacing: -0.5,
          ),
        ),
      ),
      body: Stack(
        children: [
          // Animated ambient glows — same as dashboard
          AnimatedBuilder(
            animation: _bgController,
            builder: (context, child) {
              final t = _bgController.value;
              final x1 = 0.15 + 0.55 * math.sin(t * 2 * math.pi);
              final y1 = 0.2 + 0.4 * math.cos(t * 2 * math.pi);
              final x2 =
                  0.75 + 0.3 * math.cos(t * 2 * math.pi + math.pi / 2);
              final y2 =
                  0.65 + 0.3 * math.sin(t * 2 * math.pi + math.pi / 3);
              final x3 =
                  0.5 + 0.35 * math.sin(t * 2 * math.pi + math.pi);
              final y3 =
                  0.85 + 0.15 * math.cos(t * 2 * math.pi + math.pi / 4);

              final w = MediaQuery.of(context).size.width;
              final h = MediaQuery.of(context).size.height;

              return Stack(
                children: [
                  Positioned.fill(
                    child: Container(color: const Color(0xFFF8FAFC)),
                  ),
                  Positioned(
                    left: w * x1 - 200,
                    top: h * y1 - 200,
                    child: Container(
                      width: 400,
                      height: 400,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color:
                            const Color(0xFF0051D5).withValues(alpha: 0.09),
                      ),
                    ),
                  ),
                  Positioned(
                    left: w * x2 - 200,
                    top: h * y2 - 200,
                    child: Container(
                      width: 380,
                      height: 380,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color:
                            const Color(0xFF009688).withValues(alpha: 0.07),
                      ),
                    ),
                  ),
                  Positioned(
                    left: w * x3 - 160,
                    top: h * y3 - 160,
                    child: Container(
                      width: 320,
                      height: 320,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color:
                            const Color(0xFF7C3AED).withValues(alpha: 0.06),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
                      child: const SizedBox.shrink(),
                    ),
                  ),
                ],
              );
            },
          ),

          // Content layer
          Consumer<AdminProvider>(
            builder: (context, provider, _) {
              if (provider.testsState == LoadState.loading) {
                return const Center(
                  child: CircularProgressIndicator(
                      color: Color(0xFF0051D5)),
                );
              }
              if (provider.testsState == LoadState.error) {
                return Center(
                  child: _GlassPanel(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.cloud_off,
                            size: 64, color: Color(0xFF0051D5)),
                        const SizedBox(height: 16),
                        Text(
                          provider.testsError ?? 'Failed to load tests',
                          style: const TextStyle(
                              color: Color(0xFF475569),
                              fontWeight: FontWeight.w600),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: () => provider.loadTests(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0051D5),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.refresh_rounded,
                              color: Colors.white, size: 18),
                          label: const Text('Retry',
                              style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  ),
                );
              }
              if (provider.tests.isEmpty) {
                return Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(32.0),
                    child: _GlassPanel(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0051D5)
                                  .withValues(alpha: 0.08),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.fact_check_outlined,
                              size: 64,
                              color: Color(0xFF0051D5),
                            ),
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'No Assessments Found',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'No exams or assessments have been created yet. Go back to the dashboard to create a new test.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF64748B),
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }
              return RefreshIndicator(
                color: const Color(0xFF0051D5),
                onRefresh: () => provider.loadTests(),
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  itemCount: provider.tests.length,
                  itemBuilder: (context, i) =>
                      _TestCard(test: provider.tests[i]),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ─── Glassmorphism panel helper ──────────────────────────────────────────────

class _GlassPanel extends StatelessWidget {
  final Widget child;
  const _GlassPanel({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.6),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0051D5).withValues(alpha: 0.06),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

// ─── Test Card ───────────────────────────────────────────────────────────────

class _TestCard extends StatelessWidget {
  final TestConfig test;
  const _TestCard({required this.test});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.75),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0051D5).withValues(alpha: 0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    children: [
                      // Icon badge with glass tint
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFF0051D5).withValues(alpha: 0.12),
                              const Color(0xFF316BF3).withValues(alpha: 0.08),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFF0051D5)
                                .withValues(alpha: 0.15),
                          ),
                        ),
                        child: const Icon(
                          Icons.fact_check_rounded,
                          color: Color(0xFF0051D5),
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${test.classNo == 13 ? 'Joint Entrance' : 'Class ${test.classNo}'} • ${test.language}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 17,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.calendar_today_outlined,
                                    size: 12,
                                    color: const Color(0xFF64748B)),
                                const SizedBox(width: 4),
                                Text(
                                  '${test.date} at ${test.time}',
                                  style: const TextStyle(
                                    color: Color(0xFF64748B),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      _badge('${test.totalQuestions}Q'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Divider(
                    height: 1,
                    color: const Color(0xFF0051D5).withValues(alpha: 0.08),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      _infoChip(Icons.timer_outlined,
                          '${test.totalTime} min'),
                      const SizedBox(width: 14),
                      _infoChip(Icons.add_chart_outlined,
                          '${test.marksPerQuestion} pts'),
                      const Spacer(),
                      _LeaderboardButton(test: test),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _badge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE0F7FA), Color(0xFFB2EBF2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: const Color(0xFF006064).withValues(alpha: 0.2)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF006064),
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: const Color(0xFF94A3B8)),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(
            color: Color(0xFF64748B),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _LeaderboardButton extends StatelessWidget {
  final TestConfig test;
  const _LeaderboardButton({required this.test});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => LeaderboardScreen(
              examId: test.id,
              testTitle:
                  '${test.classNo == 13 ? 'Joint Entrance' : 'Class ${test.classNo}'} - ${test.date}',
            ),
          ),
        );
      },
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0051D5), Color(0xFF316BF3)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0051D5).withValues(alpha: 0.25),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.leaderboard_rounded,
                size: 16, color: Colors.white),
            SizedBox(width: 6),
            Text(
              'Leaderboard',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
