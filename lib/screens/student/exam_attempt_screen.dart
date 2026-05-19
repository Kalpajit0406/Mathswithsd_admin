import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../../providers/auth_provider.dart';
import '../../providers/exam_provider.dart';
import '../../models/exam_model.dart';
import '../shared/katex_widget.dart';
import 'result_screen.dart';

class ExamAttemptScreen extends StatefulWidget {
  final Exam exam;

  const ExamAttemptScreen({super.key, required this.exam});

  @override
  State<ExamAttemptScreen> createState() => _ExamAttemptScreenState();
}

class _ExamAttemptScreenState extends State<ExamAttemptScreen> with WidgetsBindingObserver {
  int _violations = 0;
  bool _isSubmitted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Prevent screenshots if possible using a plugin, or rely on native Android code.
    // In Flutter, we can use flutter_windowmanager for secure flag, but we'll stick to basic lifecycle observation here.
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_isSubmitted) return;
    
    // Security check: if app goes to background (user switched apps or opened split screen)
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      _violations++;
      if (_violations >= 2) {
        // Auto submit
        _autoSubmitExam('Multiple security violations detected. Exam auto-submitted.');
      } else {
        _showViolationWarning();
      }
    }
  }

  void _showViolationWarning() {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 8),
            Text('Security Warning'),
          ],
        ),
        content: const Text('Please do not switch apps during the exam. One more violation will result in automatic submission.'),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('I Understand', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _autoSubmitExam(String reason) async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(reason), backgroundColor: Colors.red));
    await _submit();
  }

  Future<void> _submit() async {
    if (_isSubmitted) return;
    _isSubmitted = true;

    final examProvider = Provider.of<ExamProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    // Build answer array
    List<Map<String, dynamic>> finalAnswers = [];
    int score = 0;

    for (var q in widget.exam.questions) {
      String? userAns = examProvider.userAnswers[q.id];
      if (userAns != null && userAns == q.correctAnswer) {
        score++;
      }
      finalAnswers.add({
        'questionId': q.id,
        'answer': userAns,
      });
    }

    try {
      await examProvider.submitExam(finalAnswers, authProvider.user!.token);
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ResultScreen(
              score: score,
              totalQuestions: widget.exam.questions.length,
              totalTime: widget.exam.duration * 60,
              timeTaken: (widget.exam.duration * 60) - examProvider.remainingSeconds,
            ),
          ),
        );
      }
    } catch (e) {
      _isSubmitted = false;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  String _formatTime(int seconds) {
    int m = seconds ~/ 60;
    int s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final examProvider = Provider.of<ExamProvider>(context);
    final totalQ = widget.exam.questions.length;
    final currentQIndex = examProvider.currentQuestionIndex;
    final currentQ = widget.exam.questions[currentQIndex];

    // Check if time is up
    if (examProvider.remainingSeconds == 0 && !_isSubmitted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _autoSubmitExam('Time is up! Exam auto-submitted.');
      });
    }

    return PopScope(
      canPop: false, // Disable back button
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: const Color(0xFF4A148C),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Q ${currentQIndex + 1}/$totalQ', style: const TextStyle(color: Colors.white, fontSize: 18)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: examProvider.remainingSeconds < 60 ? Colors.red : Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.timer, color: Colors.white, size: 18),
                    const SizedBox(width: 4),
                    Text(
                      _formatTime(examProvider.remainingSeconds),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Submit Exam?'),
                    content: const Text('Are you sure you want to submit your answers? You cannot change them later.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _submit();
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4A148C)),
                        child: const Text('Submit', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                );
              },
              child: const Text('FINISH', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        body: Column(
          children: [
            // Question Palette (Horizontal list of question numbers)
            Container(
              height: 60,
              color: Colors.white,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                itemCount: totalQ,
                itemBuilder: (context, i) {
                  bool isAnswered = examProvider.userAnswers.containsKey(widget.exam.questions[i].id);
                  bool isCurrent = i == currentQIndex;
                  return GestureDetector(
                    onTap: () {
                      // We don't have a direct jump method in provider, so we'll just ignore for now,
                      // or we could add a jumpToQuestion method. But navigation via next/prev is fine.
                    },
                    child: Container(
                      width: 40,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: isCurrent
                            ? const Color(0xFF4A148C)
                            : isAnswered
                                ? const Color(0xFF4CAF50)
                                : Colors.grey.shade300,
                        shape: BoxShape.circle,
                        border: isCurrent ? Border.all(color: const Color(0xFF9C27B0), width: 2) : null,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${i + 1}',
                        style: TextStyle(
                          color: (isCurrent || isAnswered) ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const Divider(height: 1),

            // Question Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Question text
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
                        ],
                      ),
                      child: KaTeXWidget(text: currentQ.questionText),
                    ),
                    const SizedBox(height: 24),

                    // Options
                    if (currentQ.options != null)
                      ...currentQ.options!.map((opt) {
                        bool isSelected = examProvider.userAnswers[currentQ.id] == opt;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: InkWell(
                            onTap: () => examProvider.setAnswer(currentQ.id, opt),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isSelected ? const Color(0xFFF3E5F5) : Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected ? const Color(0xFF9C27B0) : Colors.grey.shade300,
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                                    color: isSelected ? const Color(0xFF9C27B0) : Colors.grey,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(child: InlineMathText(text: opt, fontSize: 16)),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ),

            // Navigation Buttons
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -4)),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: currentQIndex > 0 ? () => examProvider.previousQuestion() : null,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('PREVIOUS'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: currentQIndex < totalQ - 1 ? () => examProvider.nextQuestion(totalQ) : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4A148C),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('NEXT', style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
