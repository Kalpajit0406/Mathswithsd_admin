import 'package:flutter/material.dart';

/// Widget to display OCR confidence level
class ConfidenceBadge extends StatelessWidget {
  final double confidence; // 0-100 percentage
  final bool compact;

  const ConfidenceBadge({
    Key? key,
    required this.confidence,
    this.compact = false,
  }) : super(key: key);

  Color _getConfidenceColor() {
    if (confidence >= 90) return Colors.green;
    if (confidence >= 80) return Colors.blue;
    if (confidence >= 70) return Colors.amber;
    if (confidence >= 60) return Colors.orange;
    return Colors.red;
  }

  String _getConfidenceLabel() {
    if (confidence >= 90) return 'Excellent';
    if (confidence >= 80) return 'Good';
    if (confidence >= 70) return 'Fair';
    if (confidence >= 60) return 'Poor';
    return 'Very Poor';
  }

  String _getRecommendation() {
    if (confidence >= 90) return 'Ready to use';
    if (confidence >= 80) return 'Review recommended';
    if (confidence >= 70) return 'Please review';
    if (confidence >= 60) return 'Manual correction needed';
    return 'Re-crop or re-upload recommended';
  }

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: _getConfidenceColor().withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: _getConfidenceColor(),
            width: 1,
          ),
        ),
        child: Text(
          '${confidence.toStringAsFixed(1)}% ${_getConfidenceLabel()}',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: _getConfidenceColor(),
          ),
        ),
      );
    }

    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _getConfidenceColor().withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _getConfidenceColor().withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.check_circle_outline,
                color: _getConfidenceColor(),
                size: 20,
              ),
              SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'OCR Confidence',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    '${confidence.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: _getConfidenceColor(),
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            _getConfidenceLabel(),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _getConfidenceColor(),
            ),
          ),
          SizedBox(height: 6),
          Container(
            width: double.infinity,
            height: 6,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(3),
            ),
            child: FractionallySizedBox(
              widthFactor: confidence / 100,
              child: Container(
                decoration: BoxDecoration(
                  color: _getConfidenceColor(),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
          SizedBox(height: 8),
          Row(
            children: [
              Icon(
                _getRecommendationIcon(),
                size: 16,
                color: Colors.grey[700],
              ),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  _getRecommendation(),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[700],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _getRecommendationIcon() {
    if (confidence >= 90) return Icons.thumb_up_outlined;
    if (confidence >= 80) return Icons.info_outlined;
    if (confidence >= 70) return Icons.warning_outlined;
    return Icons.error_outline;
  }
}

/// Compact confidence indicator for lists
class ConfidenceIndicator extends StatelessWidget {
  final double confidence;
  final EdgeInsets padding;

  const ConfidenceIndicator({
    Key? key,
    required this.confidence,
    this.padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
  }) : super(key: key);

  Color _getColor() {
    if (confidence >= 90) return Colors.green;
    if (confidence >= 80) return Colors.blue;
    if (confidence >= 70) return Colors.amber;
    if (confidence >= 60) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: _getColor().withOpacity(0.2),
        shape: BoxShape.circle,
      ),
      child: Text(
        '${confidence.toStringAsFixed(0)}%',
        style: TextStyle(
          color: _getColor(),
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
      ),
    );
  }
}
