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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Leaderboard', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text(widget.testTitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : _error != null 
          ? Center(child: Text(_error!))
          : _data.isEmpty
            ? const Center(child: Text('No submissions yet for this test.'))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _data.length,
                itemBuilder: (context, index) {
                  final entry = _data[index];
                  final user = entry['userId'] ?? {};
                  final name = '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'.trim();
                  final rank = index + 1;
                  final score = entry['score'] ?? 0;

                  return _RankCard(rank: rank, name: name, score: score, phone: user['studentPhone']);
                },
              ),
    );
  }
}

class _RankCard extends StatelessWidget {
  final int rank;
  final String name;
  final int score;
  final String? phone;

  const _RankCard({required this.rank, required this.name, required this.score, this.phone});

  @override
  Widget build(BuildContext context) {
    Color rankColor = Colors.grey;
    if (rank == 1) rankColor = const Color(0xFFFFD700); // Gold
    if (rank == 2) rankColor = const Color(0xFFC0C0C0); // Silver
    if (rank == 3) rankColor = const Color(0xFFCD7F32); // Bronze

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
                Text(name.isEmpty ? 'Unknown Student' : name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                if (phone != null) Text(phone!, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
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
    );
  }
}
