import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/question_provider.dart';
import '../models/question_model.dart';

/// Displays queue status with progress indicator and navigation buttons
class QuestionQueueStatusWidget extends StatelessWidget {
  final Function()? onPrevious;
  final Function()? onNext;
  final Function()? onSkip;
  final Function()? onDelete;
  final bool showNavigationButtons;
  final bool compact;

  const QuestionQueueStatusWidget({
    super.key,
    this.onPrevious,
    this.onNext,
    this.onSkip,
    this.onDelete,
    this.showNavigationButtons = true,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<QuestionProvider>(
      builder: (context, provider, _) {
        if (provider.isQueueEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          children: [
            _buildProgressBar(context, provider),
            if (showNavigationButtons && !compact) ...[
              const SizedBox(height: 12),
              _buildNavigationButtons(context, provider),
            ] else if (showNavigationButtons && compact)
              const SizedBox(height: 8),
          ],
        );
      },
    );
  }

  Widget _buildProgressBar(BuildContext context, QuestionProvider provider) {
    final total = provider.queueLength;
    final current = provider.currentQueueIndex + 1;
    final progress = current / total;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Question Verification',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF0F172A),
                    ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF4A148C).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                provider.queueProgress,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF4A148C),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Progress bar
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: const Color(0xFFE2E8F0),
            valueColor: AlwaysStoppedAnimation<Color>(
              _getProgressColor(progress),
            ),
          ),
        ),

        // Info row
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '$current of $total questions',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Color(0xFF64748B),
              ),
            ),
            if (provider.remainingQuestions > 0)
              Text(
                '${provider.remainingQuestions} remaining',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF4A148C).withOpacity(0.7),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildNavigationButtons(BuildContext context, QuestionProvider provider) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
      ),
      child: Row(
        children: [
          // Previous button
          Expanded(
            child: ElevatedButton.icon(
              onPressed: provider.hasPreviousQuestion ? onPrevious : null,
              icon: const Icon(Icons.chevron_left, size: 20),
              label: const Text('Previous'),
              style: ElevatedButton.styleFrom(
                backgroundColor: provider.hasPreviousQuestion
                    ? const Color(0xFF4A148C)
                    : Colors.grey[300],
                disabledBackgroundColor: Colors.grey[300],
                foregroundColor: Colors.white,
                disabledForegroundColor: Colors.grey[600],
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Skip button
          if (provider.queueLength > 1)
            Expanded(
              child: OutlinedButton(
                onPressed: onSkip,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFFFC107), width: 2),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                child: const Text(
                  'Skip',
                  style: TextStyle(
                    color: Color(0xFFFFC107),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          if (provider.queueLength > 1) const SizedBox(width: 8),

          // Delete button
          Expanded(
            child: OutlinedButton(
              onPressed: onDelete,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFBA1A1A), width: 2),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              child: const Text(
                'Delete',
                style: TextStyle(
                  color: Color(0xFFBA1A1A),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Next button
          Expanded(
            child: ElevatedButton.icon(
              onPressed: provider.hasNextQuestion ? onNext : null,
              icon: const Icon(Icons.chevron_right, size: 20),
              label: const Text('Next'),
              style: ElevatedButton.styleFrom(
                backgroundColor: provider.hasNextQuestion
                    ? const Color(0xFF4A148C)
                    : Colors.grey[300],
                disabledBackgroundColor: Colors.grey[300],
                foregroundColor: Colors.white,
                disabledForegroundColor: Colors.grey[600],
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getProgressColor(double progress) {
    if (progress < 0.5) return const Color(0xFFFFC107); // Warning
    if (progress < 0.9) return const Color(0xFF2196F3); // Info
    return const Color(0xFF4CAF50); // Success
  }
}

/// Quick summary widget showing all questions in queue
class QueueSummaryWidget extends StatelessWidget {
  final Function(int)? onTap;

  const QueueSummaryWidget({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Consumer<QuestionProvider>(
      builder: (context, provider, _) {
        if (provider.isQueueEmpty) {
          return const SizedBox.shrink();
        }

        return ExpansionTile(
          title: Text(
            'All Questions (${provider.queueLength})',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: List.generate(
                  provider.questionQueue.length,
                  (index) {
                    final item = provider.questionQueue[index];
                    final isActive = index == provider.currentQueueIndex;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _buildQueueItemTile(context, item, index, isActive),
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildQueueItemTile(
    BuildContext context,
    ScanData item,
    int index,
    bool isActive,
  ) {
    return GestureDetector(
      onTap: () => onTap?.call(index),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF4A148C).withOpacity(0.1) : Colors.transparent,
          border: Border.all(
            color: isActive ? const Color(0xFF4A148C) : const Color(0xFFE2E8F0),
            width: isActive ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            // Question number
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isActive ? const Color(0xFF4A148C) : const Color(0xFFE2E8F0),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isActive ? Colors.white : const Color(0xFF64748B),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Question preview
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.questionNumber != null
                        ? 'Question ${item.questionNumber}'
                        : 'Question ${index + 1}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.questionText.length > 50
                        ? '${item.questionText.substring(0, 50)}...'
                        : item.questionText,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isActive ? const Color(0xFF4A148C) : const Color(0xFF0F172A),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // Status indicator
            if (item.verified)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle, size: 14, color: Color(0xFF4CAF50)),
                    SizedBox(width: 4),
                    Text(
                      'Done',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF4CAF50),
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
