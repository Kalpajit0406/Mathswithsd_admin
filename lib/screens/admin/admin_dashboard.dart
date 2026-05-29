import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:io';

import '../../providers/auth_provider.dart';
import '../../services/image_service.dart';
import 'manage_students_screen.dart';
import 'create_test_screen.dart';
import 'your_tests_screen.dart';
import '../shared/announcements_screen.dart';
import '../shared/settings_screen.dart';
import 'create_question_screen.dart';
import 'question_bank_screen.dart';
import '../../widgets/fade_in_slide.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _currentIndex = 0;
  final ImageService _imageService = ImageService();

  late final List<Widget> _pages = [
    _buildHomeTab(),
    const YourTestsScreen(),
    const QuestionBankScreen(),
    const SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // Check for lost data if the app was killed during camera session
    _checkLostData();
  }

  Future<void> _checkLostData() async {
    final lostFile = await _imageService.getLostData();
    if (lostFile != null && mounted) {
      // Pass the recovered file directly into CreateQuestionTab — no race conditions
      _navigateToCreateQuestion(fileToProcess: File(lostFile.path));
    }
  }

  void _navigateToCreateQuestion({File? fileToProcess}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: const Color(0xFFF7F9FB),
          appBar: AppBar(
            backgroundColor: const Color(0xFF0F172A),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text(
              'Create Question',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 20),
            ),
            elevation: 0,
          ),
          // Pass file directly: tab scans it in initState via postFrameCallback
          body: CreateQuestionTab(initialScanFile: fileToProcess),
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
        backgroundColor: const Color(0xFFF7F9FB),
        appBar: _currentIndex == 0
            ? AppBar(
                backgroundColor: Colors.white,
                elevation: 0,
                scrolledUnderElevation: 0,
                iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
                title: Row(
                  children: [
                    const Icon(Icons.school_rounded, color: Color(0xFF0051D5), size: 26),
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
                  Container(
                    margin: const EdgeInsets.only(right: 16, left: 8),
                    child: const CircleAvatar(
                      backgroundColor: Color(0xFF0051D5),
                      radius: 16,
                      child: Text(
                        'T',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ),
                ],
              )
            : null,
        drawer: const _AdminDrawer(),
        body: IndexedStack(
          index: _currentIndex,
          children: _pages,
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
          shadowColor: Colors.black.withOpacity(0.08),
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

  Widget _buildHomeTab() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FadeInSlide(
            duration: const Duration(milliseconds: 550),
            slideOffset: 24,
            child: const Text(
              'Welcome Back,\nEducator SD 🎓',
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w900,
                color: Color(0xFF0F172A),
                height: 1.15,
                letterSpacing: -1,
              ),
            ),
          ),
          const SizedBox(height: 10),
          FadeInSlide(
            duration: const Duration(milliseconds: 550),
            delay: const Duration(milliseconds: 100),
            slideOffset: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF316BF3).withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                '12 new assessment responses received today.',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0051D5),
                ),
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
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageStudentsScreen())),
                  child: const _ActionCard(
                    icon: Icons.people_rounded,
                    iconBgColor: Color(0xFFDAE2FD),
                    iconColor: Color(0xFF0051D5),
                    title: 'Manage\nStudents',
                    subtitle: 'Review cohorts, verify signups, monitor student progress.',
                  ),
                ),
              ),
              FadeInSlide(
                duration: const Duration(milliseconds: 500),
                delay: const Duration(milliseconds: 250),
                slideOffset: 24,
                child: BounceOnTap(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateTestScreen())),
                  child: const _ActionCard(
                    icon: Icons.add_box_rounded,
                    iconBgColor: Color(0xFFDBE1FF),
                    iconColor: Color(0xFF316BF3),
                    title: 'Create\nTests',
                    subtitle: 'Assemble dynamic structured quizzes from OCR bank.',
                  ),
                ),
              ),
              FadeInSlide(
                duration: const Duration(milliseconds: 500),
                delay: const Duration(milliseconds: 300),
                slideOffset: 24,
                child: BounceOnTap(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const YourTestsScreen())),
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
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AnnouncementsScreen(isAdmin: true))),
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
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFECEEF0), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 12,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconBgColor.withOpacity(0.4),
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
  const _AdminDrawer();

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: const Color(0xFFF7F9FB),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: Color(0xFF0051D5),
                    radius: 24,
                    child: Text('T', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text('Teacher SD', style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF0F172A), fontSize: 18)),
                      Text('Lead Educator', style: TextStyle(color: Color(0xFF75859D), fontWeight: FontWeight.w500, fontSize: 14)),
                    ],
                  )
                ],
              ),
            ),
            const Divider(color: Color(0xFFECEEF0)),
            const Spacer(),
            const Divider(color: Color(0xFFECEEF0)),
            ListTile(
              leading: const Icon(Icons.logout_rounded, color: Color(0xFFBA1A1A)),
              title: const Text('Logout', style: TextStyle(color: Color(0xFFBA1A1A), fontWeight: FontWeight.bold)),
              onTap: () async {
                await Provider.of<AuthProvider>(context, listen: false).logout();
                if (context.mounted) Navigator.pushReplacementNamed(context, '/login');
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
