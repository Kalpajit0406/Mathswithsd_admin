import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class LeaderboardScreen extends StatefulWidget {
  final String examId;
  final String testTitle;
  const LeaderboardScreen({super.key, required this.examId, required this.testTitle});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  final ApiService _apiService = ApiService();
  List<Map<String, dynamic>> _data = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final results = await _apiService.getLeaderboard(widget.examId);
      setState(() {
        _data = results;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load leaderboard data.';
        _isLoading = false;
      });
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Leaderboard', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF0F172A), letterSpacing: -0.5)),
            Text(widget.testTitle, style: const TextStyle(fontSize: 12, color: Color(0xFF75859D), fontWeight: FontWeight.w600)),
          ],
        ),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : _error != null 
          ? Center(child: Text(_error!))
          : _data.isEmpty
            ? Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0051D5).withOpacity(0.05),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.emoji_events_outlined,
                          size: 64,
                          color: Color(0xFF0051D5),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'No Submissions Yet',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'No students have completed or submitted this test yet. Once students submit, their ranks and scores will appear here.',
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
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _data.length,
                itemBuilder: (context, index) {
                  final entry = _data[index];
                  final rank = index + 1;

                  return _RankCard(rank: rank, entry: entry);
                },
              ),
    );
  }
}

class _RankCard extends StatelessWidget {
  final int rank;
  final Map<String, dynamic> entry;

  const _RankCard({required this.rank, required this.entry});

  void _showAuditDialog(BuildContext context, Map<String, dynamic> entry) {
    final user = entry['userId'] ?? {};
    final name = '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'.trim();
    final isAutoSubmitted = entry['isAutoSubmitted'] == true;
    final reason = entry['autoSubmitReason'] ?? 'Unknown reason';
    final List violations = entry['violations'] as List? ?? [];
    final emulator = entry['emulatorDetected'] == true;
    final root = entry['rootDetected'] == true;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.security, color: Color(0xFF0051D5)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Security Audit: $name',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Integrity Section
                const Text('Platform Integrity', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 13)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: _statusIndicator(!root, 'Root: ${root ? "YES" : "NO"}')),
                    const SizedBox(width: 8),
                    Expanded(child: _statusIndicator(!emulator, 'Emulator: ${emulator ? "YES" : "NO"}')),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                // Submission Status
                const Text('Submission Status', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 13)),
                const SizedBox(height: 8),
                _statusIndicator(!isAutoSubmitted, isAutoSubmitted ? 'Auto-submitted ($reason)' : 'Normal Submission'),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                // Violations
                Text('Violations (${violations.length})', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 13)),
                const SizedBox(height: 8),
                if (violations.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('No violations recorded for this attempt.', style: TextStyle(color: Colors.green, fontStyle: FontStyle.italic, fontSize: 13)),
                  )
                else
                  Container(
                    constraints: const BoxConstraints(maxHeight: 200),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: violations.length,
                      itemBuilder: (c, idx) {
                        final v = violations[idx] as Map<String, dynamic>;
                        final type = v['type'] ?? 'Unknown';
                        final msg = v['message'] ?? '';
                        final severity = v['severity'] ?? 'low';
                        final tsStr = v['timestamp'];
                        final ts = tsStr != null ? DateTime.parse(tsStr).toLocal() : null;
                        
                        Color severityColor = Colors.orange;
                        if (severity == 'critical') severityColor = Colors.red;
                        if (severity == 'low') severityColor = Colors.blue;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: severityColor.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: severityColor.withOpacity(0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(color: severityColor, borderRadius: BorderRadius.circular(4)),
                                    child: Text(
                                      severity.toUpperCase(),
                                      style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    type,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                                  ),
                                  const Spacer(),
                                  if (ts != null)
                                    Text(
                                      '${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}:${ts.second.toString().padLeft(2, '0')}',
                                      style: const TextStyle(color: Colors.grey, fontSize: 9),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(msg, style: const TextStyle(fontSize: 11, color: Colors.black87)),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _statusIndicator(bool isSecure, String text) {
    Color color = isSecure ? Colors.green : Colors.red;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isSecure ? Icons.check_circle_outline : Icons.error_outline, color: color, size: 14),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = entry['userId'] ?? {};
    final name = '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'.trim();
    final phone = user['studentPhone'];
    final score = entry['score'] ?? 0;
    
    final bool isAutoSubmitted = entry['isAutoSubmitted'] == true;
    final List violations = entry['violations'] as List? ?? [];
    final bool emulator = entry['emulatorDetected'] == true;
    final bool root = entry['rootDetected'] == true;
    final bool hasAlerts = isAutoSubmitted || violations.isNotEmpty || emulator || root;

    Color rankColor = Colors.grey;
    if (rank == 1) rankColor = const Color(0xFFFFD700); // Gold
    if (rank == 2) rankColor = const Color(0xFFC0C0C0); // Silver
    if (rank == 3) rankColor = const Color(0xFFCD7F32); // Bronze

    return GestureDetector(
      onTap: () => _showAuditDialog(context, entry),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: hasAlerts ? Border.all(color: Colors.red.withOpacity(0.3), width: 1.5) : null,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: rankColor.withOpacity(0.1), shape: BoxShape.circle),
              child: Center(
                child: Text(
                  rank.toString(),
                  style: TextStyle(color: rankColor, fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        name.isEmpty ? 'Unknown Student' : name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      if (hasAlerts) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.security, color: Colors.red, size: 16),
                      ]
                    ],
                  ),
                  if (phone != null) Text(phone, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                  if (hasAlerts) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        if (isAutoSubmitted)
                          _badge('Auto-Submitted', Colors.red),
                        if (violations.isNotEmpty)
                          _badge('Violations: ${violations.length}', Colors.orange),
                        if (root)
                          _badge('Rooted', Colors.red.shade700),
                        if (emulator)
                          _badge('Emulator', Colors.orange.shade800),
                      ],
                    ),
                  ]
                ],
              ),
            ),
            Text(
              score.toString(),
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: Color(0xFF0051D5)),
            ),
            const SizedBox(width: 4),
            const Text('pts', style: TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold),
      ),
    );
  }
}
