import 'package:flutter/material.dart';

class ResultScreen extends StatelessWidget {
  final int score;
  final int totalQuestions;
  final int totalTime;
  final int timeTaken;

  const ResultScreen({
    super.key,
    required this.score,
    required this.totalQuestions,
    required this.totalTime,
    required this.timeTaken,
  });

  @override
  Widget build(BuildContext context) {
    final double percentage = totalQuestions > 0 ? (score / totalQuestions) * 100 : 0;
    final bool passed = percentage >= 40;

    return Scaffold(
      backgroundColor: const Color(0xFFF3E5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF4A148C),
        title: const Text('Exam Result', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Icon(
                      passed ? Icons.emoji_events : Icons.sentiment_dissatisfied,
                      size: 80,
                      color: passed ? const Color(0xFFFFC107) : const Color(0xFFE53935),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      passed ? 'Congratulations!' : 'Keep Practicing!',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: passed ? const Color(0xFF4CAF50) : const Color(0xFFE53935),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'You scored',
                      style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$score / $totalQuestions',
                      style: const TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF4A148C),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _StatColumn(label: 'Accuracy', value: '${percentage.toStringAsFixed(1)}%'),
                        _StatColumn(
                          label: 'Time Taken',
                          value: '${(timeTaken / 60).floor()}m ${timeTaken % 60}s',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pushNamedAndRemoveUntil('/student', (_) => false);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4A148C),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 4,
                  ),
                  child: const Text(
                    'Return to Dashboard',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  final String label;
  final String value;

  const _StatColumn({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFF1A1A2E)),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
        ),
      ],
    );
  }
}
