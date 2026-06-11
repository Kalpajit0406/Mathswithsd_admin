import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'dart:ui';
import 'dart:math' as math;

import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../providers/admin_provider.dart';
import '../../providers/planner_provider.dart';
import '../../services/image_service.dart';
import 'test_planner_screen.dart';
import 'manage_students_screen.dart';
import 'create_test_screen.dart';
import 'your_tests_screen.dart';
import '../shared/announcements_screen.dart';
import '../shared/settings_screen.dart';
import 'create_question_screen.dart';
import 'question_bank_screen.dart';
import '../../widgets/fade_in_slide.dart';
import '../../widgets/glass_card.dart';
import 'chapter_management_screen.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  final ImageService _imageService = ImageService();
  late AnimationController _bgAnimationController;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  late final List<Widget> _pages = [
    _buildHomeTab(),
    const YourTestsScreen(),
    const QuestionBankScreen(),
    const SettingsScreen(),
    ChapterManagementScreen(
      onOpenDrawer: () => _scaffoldKey.currentState?.openDrawer(),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _bgAnimationController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat(reverse: true);
    // Check for lost data if the app was killed during camera session
    _checkLostData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AdminProvider>(context, listen: false).loadStudents();
    });
  }

  @override
  void dispose() {
    _bgAnimationController.dispose();
    super.dispose();
  }

  void _showUpcomingNotifications(BuildContext context, PlannerProvider planner) {
    final upcoming = planner.upcomingExams;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.notifications_active_rounded, color: Color(0xFF0051D5)),
            SizedBox(width: 10),
            Text(
              'Upcoming Exams Info',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: upcoming.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24.0),
                  child: Text(
                    'No upcoming planned exams.',
                    style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: upcoming.length,
                  itemBuilder: (context, index) {
                    final exam = upcoming[index];
                    final dateStr = DateFormat('MMM d, hh:mm a').format(exam.dateTime);
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFF0051D5).withValues(alpha: 0.1),
                        child: Text(
                          'C${exam.classNo}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0051D5),
                          ),
                        ),
                      ),
                      title: Text(
                        exam.title,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      subtitle: Text('$dateStr • ${exam.chapters}', style: const TextStyle(fontSize: 12)),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Dismiss'),
          ),
        ],
      ),
    );
  }

  Future<void> _checkLostData() async {
    // getLostData() now returns a stable File? (bytes copied from content:// URI)
    final lostFile = await _imageService.getLostData();
    if (lostFile == null || !mounted) return;

    // Show crop screen first — the recovered photo was never cropped because
    // the app was killed before ImageCropper could open.
    final croppedFile = await _imageService.cropExistingImage(context, lostFile);
    if (croppedFile != null && mounted) {
      _navigateToCreateQuestion(fileToProcess: croppedFile);
    }
  }

  void _navigateToCreateQuestion({File? fileToProcess}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Color(0xFF0F172A),
                size: 20,
              ),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text(
              'Create Question',
              style: TextStyle(
                color: Color(0xFF0F172A),
                fontWeight: FontWeight.w800,
                fontSize: 20,
              ),
            ),
          ),
          body: Stack(
            children: [
              // Drifting ambient glows
              AnimatedBuilder(
                animation: _bgAnimationController,
                builder: (context, child) {
                  final progress = _bgAnimationController.value;
                  final x1 = 0.2 + 0.5 * math.sin(progress * 2 * math.pi);
                  final y1 = 0.3 + 0.4 * math.cos(progress * 2 * math.pi);
                  final x2 =
                      0.8 +
                      0.4 * math.cos(progress * 2 * math.pi + math.pi / 2);
                  final y2 =
                      0.7 +
                      0.3 * math.sin(progress * 2 * math.pi + math.pi / 2);

                  return Stack(
                    children: [
                      Positioned.fill(
                        child: Container(color: const Color(0xFFF8FAFC)),
                      ),
                      Positioned(
                        left: MediaQuery.of(context).size.width * x1 - 180,
                        top: MediaQuery.of(context).size.height * y1 - 180,
                        child: Container(
                          width: 360,
                          height: 360,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(
                              0xFF009688,
                            ).withValues(alpha: 0.08),
                          ),
                        ),
                      ),
                      Positioned(
                        left: MediaQuery.of(context).size.width * x2 - 180,
                        top: MediaQuery.of(context).size.height * y2 - 180,
                        child: Container(
                          width: 360,
                          height: 360,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(
                              0xFF0051D5,
                            ).withValues(alpha: 0.08),
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 70, sigmaY: 70),
                          child: const SizedBox.shrink(),
                        ),
                      ),
                    ],
                  );
                },
              ),
              Positioned.fill(
                child: CreateQuestionTab(initialScanFile: fileToProcess),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _currentIndex == 0,
      onPopInvoked: (didPop) {
        if (didPop) return;
        setState(() {
          _currentIndex = 0;
        });
      },
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: _currentIndex == 0
            ? AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                scrolledUnderElevation: 0,
                iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
                title: Row(
                  children: [
                    const Icon(
                      Icons.school_rounded,
                      color: Color(0xFF0051D5),
                      size: 26,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'MathsAdmin',
                      style: TextStyle(
                        color: Color(0xFF0F172A),
                        fontWeight: FontWeight.w900,
                        fontSize: 22,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
                actions: [
                  Consumer<PlannerProvider>(
                    builder: (context, plannerProvider, child) {
                      final upcomingCount = plannerProvider.upcomingExams.length;
                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.notifications_none_rounded,
                              color: Color(0xFF0F172A),
                              size: 24,
                            ),
                            onPressed: () => _showUpcomingNotifications(context, plannerProvider),
                          ),
                          if (upcomingCount > 0)
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                constraints: const BoxConstraints(
                                  minWidth: 16,
                                  minHeight: 16,
                                ),
                                child: Text(
                                  upcomingCount.toString(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  Container(
                    margin: const EdgeInsets.only(right: 16, left: 8),
                    child: const CircleAvatar(
                      backgroundColor: Color(0xFF0051D5),
                      radius: 16,
                      child: Text(
                        'S',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ],
              )
            : null,
        drawer: _AdminDrawer(
          onNavigate: (index) {
            setState(() => _currentIndex = index);
          },
          currentIndex: _currentIndex,
        ),
        body: Stack(
          children: [
            // Drifting ambient glows
            AnimatedBuilder(
              animation: _bgAnimationController,
              builder: (context, child) {
                final progress = _bgAnimationController.value;
                final x1 = 0.2 + 0.5 * math.sin(progress * 2 * math.pi);
                final y1 = 0.3 + 0.4 * math.cos(progress * 2 * math.pi);
                final x2 =
                    0.8 + 0.4 * math.cos(progress * 2 * math.pi + math.pi / 2);
                final y2 =
                    0.7 + 0.3 * math.sin(progress * 2 * math.pi + math.pi / 2);

                return Stack(
                  children: [
                    Positioned.fill(
                      child: Container(color: const Color(0xFFF8FAFC)),
                    ),
                    Positioned(
                      left: MediaQuery.of(context).size.width * x1 - 180,
                      top: MediaQuery.of(context).size.height * y1 - 180,
                      child: Container(
                        width: 360,
                        height: 360,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(
                            0xFF009688,
                          ).withValues(alpha: 0.08),
                        ),
                      ),
                    ),
                    Positioned(
                      left: MediaQuery.of(context).size.width * x2 - 180,
                      top: MediaQuery.of(context).size.height * y2 - 180,
                      child: Container(
                        width: 360,
                        height: 360,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(
                            0xFF0051D5,
                          ).withValues(alpha: 0.08),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 70, sigmaY: 70),
                        child: const SizedBox.shrink(),
                      ),
                    ),
                  ],
                );
              },
            ),

            // Content
            Positioned.fill(
              child: IndexedStack(index: _currentIndex, children: _pages),
            ),
          ],
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        floatingActionButton: Container(
          margin: const EdgeInsets.only(top: 20),
          child: FloatingActionButton(
            onPressed: () => _navigateToCreateQuestion(),
            backgroundColor: const Color(0xFF0051D5),
            shape: const CircleBorder(),
            elevation: 6,
            child: const Icon(Icons.add_rounded, color: Colors.white, size: 32),
          ),
        ),
        bottomNavigationBar: BottomAppBar(
          color: Colors.white,
          shape: const CircularNotchedRectangle(),
          notchMargin: 8.0,
          elevation: 15,
          shadowColor: Colors.black.withValues(alpha: 0.08),
          child: SizedBox(
            height: 60,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildNavItem(0, Icons.dashboard_rounded, 'Dashboard'),
                _buildNavItem(1, Icons.assignment_rounded, 'Tests'),
                const SizedBox(width: 48), // Space for FAB
                _buildNavItem(2, Icons.quiz_rounded, 'Bank'),
                _buildNavItem(3, Icons.settings_rounded, 'Settings'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isActive = _currentIndex == index;
    final color = isActive ? const Color(0xFF0051D5) : const Color(0xFF75859D);
    return InkWell(
      onTap: () {
        setState(() => _currentIndex = index);
      },
      customBorder: const CircleBorder(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 6 && hour < 12) {
      return 'Good morning,\nSoumen Sir 🎓';
    } else if (hour >= 12 && hour < 17) {
      return 'Good afternoon,\nSoumen Sir 🎓';
    } else if (hour >= 17 && hour < 23) {
      return 'Good evening,\nSoumen Sir 🎓';
    } else {
      return 'Have some Rest,\nSoumen Sir 💤';
    }
  }

  Widget _buildHomeTab() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FadeInSlide(
            duration: const Duration(milliseconds: 600),
            slideOffset: 24,
            child: GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          _getGreeting(),
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0F172A),
                            height: 1.2,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0051D5).withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(
                              0xFF0051D5,
                            ).withValues(alpha: 0.2),
                          ),
                        ),
                        child: const Icon(
                          Icons.admin_panel_settings_rounded,
                          color: Color(0xFF0051D5),
                          size: 28,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Consumer<AdminProvider>(
                    builder: (context, adminProvider, child) {
                      final pendingCount = adminProvider.pendingStudents.length;
                      final pendingProfileEdits = adminProvider.verifiedStudents
                          .where((s) => s.pendingProfileEdit != null)
                          .length;
                      final totalPending = pendingCount + pendingProfileEdits;

                      String text;
                      if (adminProvider.studentsState == LoadState.loading) {
                        text = 'Checking student management tasks...';
                      } else if (adminProvider.studentsState == LoadState.error) {
                        text = 'Failed to retrieve student management status.';
                      } else {
                        if (totalPending == 0) {
                          text = 'No student management tasks pending.';
                        } else if (totalPending == 1) {
                          text = '1 student management task pending.';
                        } else {
                          text = '$totalPending student management tasks pending.';
                        }
                      }

                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0051D5).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(0xFF0051D5).withValues(alpha: 0.15),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.notifications_active_outlined,
                              color: Color(0xFF0051D5),
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                text,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0051D5),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            shrinkWrap: true,
            childAspectRatio: 0.85,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              FadeInSlide(
                duration: const Duration(milliseconds: 500),
                delay: const Duration(milliseconds: 200),
                slideOffset: 24,
                child: BounceOnTap(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ManageStudentsScreen(),
                    ),
                  ),
                  child: const _ActionCard(
                    icon: Icons.people_rounded,
                    iconBgColor: Color(0xFFDAE2FD),
                    iconColor: Color(0xFF0051D5),
                    title: 'Manage\nStudents',
                    subtitle:
                        'Review cohorts, verify signups, monitor student progress.',
                  ),
                ),
              ),
              FadeInSlide(
                duration: const Duration(milliseconds: 500),
                delay: const Duration(milliseconds: 250),
                slideOffset: 24,
                child: BounceOnTap(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CreateTestScreen()),
                  ),
                  child: const _ActionCard(
                    icon: Icons.add_box_rounded,
                    iconBgColor: Color(0xFFDBE1FF),
                    iconColor: Color(0xFF316BF3),
                    title: 'Create\nTests',
                    subtitle:
                        'Assemble dynamic structured quizzes from OCR bank.',
                  ),
                ),
              ),
              FadeInSlide(
                duration: const Duration(milliseconds: 500),
                delay: const Duration(milliseconds: 300),
                slideOffset: 24,
                child: BounceOnTap(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const YourTestsScreen()),
                  ),
                  child: const _ActionCard(
                    icon: Icons.bar_chart_rounded,
                    iconBgColor: Color(0xFFD3E4FE),
                    iconColor: Color(0xFF0B1C30),
                    title: 'Test\nAnalytics',
                    subtitle: 'Analyze overall performance & top leaderboards.',
                  ),
                ),
              ),
              FadeInSlide(
                duration: const Duration(milliseconds: 500),
                delay: const Duration(milliseconds: 350),
                slideOffset: 24,
                child: BounceOnTap(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AnnouncementsScreen(isAdmin: true),
                    ),
                  ),
                  child: const _ActionCard(
                    icon: Icons.campaign_rounded,
                    iconBgColor: Color(0xFFDAE2FD),
                    iconColor: Color(0xFF131B2E),
                    title: 'Publish\nNotices',
                    subtitle: 'Broadcast alerts to specific classroom classes.',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final Color iconBgColor;
  final Color iconColor;
  final String title;
  final String subtitle;

  const _ActionCard({
    required this.icon,
    required this.iconBgColor,
    required this.iconColor,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(18),
      borderRadius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconBgColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const Spacer(),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
              height: 1.25,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF75859D),
              fontWeight: FontWeight.w500,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminDrawer extends StatelessWidget {
  final void Function(int index) onNavigate;
  final int currentIndex;

  const _AdminDrawer({
    required this.onNavigate,
    required this.currentIndex,
  });

  Widget _drawerItem({
    required BuildContext context,
    required IconData icon,
    required String label,
    required int index,
  }) {
    final isActive = currentIndex == index;
    return ListTile(
      leading: Icon(
        icon,
        color: isActive ? const Color(0xFF0051D5) : const Color(0xFF75859D),
      ),
      title: Text(
        label,
        style: TextStyle(
          color: isActive ? const Color(0xFF0051D5) : const Color(0xFF0F172A),
          fontWeight: isActive ? FontWeight.w800 : FontWeight.bold,
        ),
      ),
      selected: isActive,
      selectedTileColor: const Color(0xFF0051D5).withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      onTap: () {
        Navigator.pop(context);
        onNavigate(index);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: const Color(0xFFF7F9FB),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
              child: Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: Color(0xFF0051D5),
                    radius: 24,
                    child: Text(
                      'S',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Soumen Sir',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                          fontSize: 18,
                        ),
                      ),
                      Text(
                        'Boss',
                        style: TextStyle(
                          color: Color(0xFF75859D),
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(color: Color(0xFFECEEF0)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Column(
                children: [
                  _drawerItem(
                    context: context,
                    icon: Icons.collections_bookmark_rounded,
                    label: 'Manage Chapters',
                    index: 4,
                  ),
                  const SizedBox(height: 4),
                  ListTile(
                    leading: const Icon(
                      Icons.calendar_month_rounded,
                      color: Color(0xFF75859D),
                    ),
                    title: const Text(
                      'Exam & Test Planner',
                      style: TextStyle(
                        color: Color(0xFF0F172A),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const TestPlannerScreen()),
                      );
                    },
                  ),
                ],
              ),
            ),
            const Divider(color: Color(0xFFECEEF0)),
            const Spacer(),
            const Divider(color: Color(0xFFECEEF0)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: ListTile(
                leading: const Icon(
                  Icons.logout_rounded,
                  color: Color(0xFFBA1A1A),
                ),
                title: const Text(
                  'Logout',
                  style: TextStyle(
                    color: Color(0xFFBA1A1A),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onTap: () async {
                  await Provider.of<AuthProvider>(
                    context,
                    listen: false,
                  ).logout();
                  if (context.mounted) {
                    Navigator.pushReplacementNamed(context, '/login');
                  }
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
