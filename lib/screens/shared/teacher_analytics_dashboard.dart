import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../models/exam_model.dart';
import '../../utils/constants.dart';

class TeacherAnalyticsDashboard extends StatefulWidget {
  const TeacherAnalyticsDashboard({super.key});

  @override
  State<TeacherAnalyticsDashboard> createState() => _TeacherAnalyticsDashboardState();
}

class _TeacherAnalyticsDashboardState extends State<TeacherAnalyticsDashboard> {
  late ApiService _apiService;
  late Future<Map<String, dynamic>> _analyticsData;
  int _selectedClass = 9;
  String _selectedLanguage = 'English';

  @override
  void initState() {
    super.initState();
    _apiService = ApiService();
    _loadAnalytics();
  }

  void _loadAnalytics() {
    setState(() {
      _analyticsData = _fetchClassAnalytics();
    });
  }

  Future<Map<String, dynamic>> _fetchClassAnalytics() async {
    try {
      // Since this is a teacher dashboard, we're using a GET request to the backend
      // The backend endpoint should return class analytics
      // For now, we'll mock this with sample data structure
      return Future.delayed(const Duration(milliseconds: 500), () {
        return {
          'success': true,
          'classNo': _selectedClass,
          'language': _selectedLanguage,
          'totalStudents': 35,
          'activeStudents': 28,
          'classAverageScore': 73.4,
          'topPerformers': [
            {'name': 'Raj Kumar', 'averageScore': 92.5, 'totalAttempts': 12},
            {'name': 'Priya Singh', 'averageScore': 89.3, 'totalAttempts': 10},
            {'name': 'Aditya Patel', 'averageScore': 87.2, 'totalAttempts': 11},
            {'name': 'Isha Verma', 'averageScore': 85.8, 'totalAttempts': 9},
            {'name': 'Vikas Sharma', 'averageScore': 84.1, 'totalAttempts': 8},
          ],
          'needsAttention': [
            {'name': 'Rohan Mishra', 'averageScore': 45.2, 'totalAttempts': 8},
            {'name': 'Ankita Gupta', 'averageScore': 52.1, 'totalAttempts': 7},
            {'name': 'Rahul Singh', 'averageScore': 58.5, 'totalAttempts': 9},
            {'name': 'Neha Sharma', 'averageScore': 61.3, 'totalAttempts': 6},
            {'name': 'Deepak Kumar', 'averageScore': 64.7, 'totalAttempts': 10},
          ],
        };
      });
    } catch (e) {
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FB),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF0F172A), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Class Analytics',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w800,
            fontSize: 22,
            letterSpacing: -0.5,
          ),
        ),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF0F172A)),
            onPressed: _loadAnalytics,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Class selector
            _buildClassSelector(),
            const SizedBox(height: 24),

            // Analytics summary
            FutureBuilder<Map<String, dynamic>>(
              future: _analyticsData,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text('Error: ${snapshot.error}'),
                    ),
                  );
                }

                final data = snapshot.data ?? {};
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Summary Cards
                    _buildSummaryCards(data),
                    const SizedBox(height: 24),

                    // Top Performers
                    _buildTopPerformers(data),
                    const SizedBox(height: 24),

                    // Needs Attention
                    _buildNeedsAttention(data),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClassSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select Class',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButton<int>(
                  value: _selectedClass,
                  isExpanded: true,
                  underline: Container(),
                  items: [9, 10, 11, 12]
                      .map((classNo) => DropdownMenuItem(
                            value: classNo,
                            child: Text('Class $classNo'),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value != null && value != _selectedClass) {
                      setState(() => _selectedClass = value);
                      _loadAnalytics();
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButton<String>(
                  value: _selectedLanguage,
                  isExpanded: true,
                  underline: Container(),
                  items: ['English', 'Hindi']
                      .map((lang) => DropdownMenuItem(
                            value: lang,
                            child: Text(lang),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value != null && value != _selectedLanguage) {
                      setState(() => _selectedLanguage = value);
                      _loadAnalytics();
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(Map<String, dynamic> data) {
    final totalStudents = data['totalStudents'] as int? ?? 0;
    final activeStudents = data['activeStudents'] as int? ?? 0;
    final classAverage = (data['classAverageScore'] as num?)?.toDouble() ?? 0.0;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Total Students',
                '$totalStudents',
                Icons.people_outline,
                const Color(0xFF4A148C),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Active Students',
                '$activeStudents',
                Icons.check_circle_outline,
                const Color(0xFF2E7D32),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildStatCard(
          'Class Average Score',
          '${classAverage.toStringAsFixed(1)}%',
          Icons.trending_up,
          classAverage >= 70 ? const Color(0xFF2E7D32) : const Color(0xFFF57C00),
          fullWidth: true,
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color, {
    bool fullWidth = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w600,
                ),
              ),
              Icon(icon, color: color, size: 20),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopPerformers(Map<String, dynamic> data) {
    final topPerformers = (data['topPerformers'] as List<dynamic>?) ?? [];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.emoji_events, color: Colors.green, size: 24),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Top Performers',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ...List.generate(
            topPerformers.length,
            (index) {
              final performer = topPerformers[index] as Map<String, dynamic>;
              final name = performer['name'] as String? ?? 'N/A';
              final score = (performer['averageScore'] as num?)?.toDouble() ?? 0.0;
              final attempts = performer['totalAttempts'] as int? ?? 0;

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  border: index < topPerformers.length - 1
                      ? Border(
                          bottom: BorderSide(color: Colors.grey[200]!, width: 0.5),
                        )
                      : null,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            '$attempts attempts',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${score.toStringAsFixed(1)}%',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNeedsAttention(Map<String, dynamic> data) {
    final needsAttention = (data['needsAttention'] as List<dynamic>?) ?? [];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.warning_outlined, color: Colors.orange, size: 24),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Needs Attention',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ...List.generate(
            needsAttention.length,
            (index) {
              final student = needsAttention[index] as Map<String, dynamic>;
              final name = student['name'] as String? ?? 'N/A';
              final score = (student['averageScore'] as num?)?.toDouble() ?? 0.0;
              final attempts = student['totalAttempts'] as int? ?? 0;

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  border: index < needsAttention.length - 1
                      ? Border(
                          bottom: BorderSide(color: Colors.grey[200]!, width: 0.5),
                        )
                      : null,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '⚠',
                        style: TextStyle(
                          color: Colors.orange[700],
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            '$attempts attempts',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${score.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: Colors.orange[700],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
