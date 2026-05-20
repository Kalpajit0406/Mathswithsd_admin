import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/admin_provider.dart';
import '../../models/test_model.dart';
import 'leaderboard_screen.dart';

class YourTestsScreen extends StatefulWidget {
  const YourTestsScreen({super.key});

  @override
  State<YourTestsScreen> createState() => _YourTestsScreenState();
}

class _YourTestsScreenState extends State<YourTestsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AdminProvider>(context, listen: false).loadTests();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF191C1E)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Assessments', style: TextStyle(color: Color(0xFF191C1E), fontWeight: FontWeight.w700)),
        elevation: 0,
      ),
      body: Consumer<AdminProvider>(
        builder: (context, provider, _) {
          if (provider.testsState == LoadState.loading) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF0051D5)));
          }
          if (provider.testsState == LoadState.error) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.cloud_off, size: 72, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(provider.testsError ?? 'Failed to load tests', style: const TextStyle(color: Colors.grey)),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => provider.loadTests(),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0051D5)),
                    child: const Text('Retry', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            );
          }
          if (provider.tests.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.fact_check_outlined, size: 80, color: Colors.grey.shade200),
                  const SizedBox(height: 16),
                  const Text('No tests created yet.', style: TextStyle(color: Colors.grey, fontSize: 16)),
                ],
              ),
            );
          }
          return RefreshIndicator(
            color: const Color(0xFF0051D5),
            onRefresh: () => provider.loadTests(),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: provider.tests.length,
              itemBuilder: (context, i) => _TestCard(test: provider.tests[i]),
            ),
          );
        },
      ),
    );
  }
}

class _TestCard extends StatelessWidget {
  final TestConfig test;
  const _TestCard({required this.test});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE0E3E5)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F4FF),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.fact_check_rounded, color: Color(0xFF0051D5), size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Class ${test.classNo} • ${test.language}',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${test.date} at ${test.time}',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                _badge('${test.totalQuestions}Q'),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(height: 1),
            const SizedBox(height: 16),
            Row(
              children: [
                _infoChip(Icons.timer_outlined, '${test.totalTime}m'),
                const SizedBox(width: 12),
                _infoChip(Icons.add_chart_outlined, '${test.marksPerQuestion} pts'),
                const Spacer(),
                TextButton.icon(
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(
                      builder: (_) => LeaderboardScreen(
                        examId: test.id,
                        testTitle: 'Class ${test.classNo} - ${test.date}',
                      ),
                    ));
                  },
                  icon: const Icon(Icons.leaderboard_outlined, size: 18),
                  label: const Text('Leaderboard', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF0051D5),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _badge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: const Color(0xFFE0F7FA), borderRadius: BorderRadius.circular(8)),
      child: Text(text, style: const TextStyle(color: Color(0xFF006064), fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }

  Widget _infoChip(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey.shade400),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
