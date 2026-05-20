import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/exam_provider.dart';
import '../../models/test_model.dart';

class AnnouncementsScreen extends StatefulWidget {
  final bool isAdmin;
  final String? studentClass; // for filtering

  const AnnouncementsScreen({super.key, required this.isAdmin, this.studentClass});

  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ExamProvider>(context, listen: false)
          .loadAnnouncements(targetClass: widget.isAdmin ? null : widget.studentClass);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1565C0),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Announcements', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        elevation: 0,
      ),
      body: Consumer<ExamProvider>(
        builder: (context, provider, _) {
          if (provider.announcementsState == LoadState.loading) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF1565C0)));
          }
          if (provider.announcementsState == LoadState.error) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.cloud_off, size: 72, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(provider.announcementsError ?? 'Failed to load', style: const TextStyle(color: Colors.grey)),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => provider.loadAnnouncements(targetClass: widget.studentClass),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1565C0)),
                    child: const Text('Retry', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            );
          }
          if (provider.announcements.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_none, size: 80, color: Colors.grey.shade200),
                  const SizedBox(height: 16),
                  const Text('No announcements yet.', style: TextStyle(color: Colors.grey, fontSize: 16)),
                ],
              ),
            );
          }
          return RefreshIndicator(
            color: const Color(0xFF1565C0),
            onRefresh: () => provider.loadAnnouncements(targetClass: widget.studentClass),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: provider.announcements.length,
              itemBuilder: (context, i) => _AnnouncementCard(ann: provider.announcements[i]),
            ),
          );
        },
      ),
    );
  }
}

class _AnnouncementCard extends StatelessWidget {
  final Announcement ann;
  const _AnnouncementCard({required this.ann});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image if available
          if (ann.image != null && ann.image!.isNotEmpty)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: Image.network(
                ann.image!,
                width: double.infinity,
                height: 180,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Class chip
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE3F2FD),
                        borderRadius: BorderRadius.circular(50),
                      ),
                      child: Text(
                        ann.targetClass == 'all' ? 'All Classes' : 'Class ${ann.targetClass}',
                        style: const TextStyle(
                          color: Color(0xFF1565C0),
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const Spacer(),
                    const Icon(Icons.schedule, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(ann.formattedDate, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  ann.title,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: Color(0xFF1A237E)),
                ),
                const SizedBox(height: 6),
                Text(
                  ann.message,
                  style: const TextStyle(fontSize: 14, color: Color(0xFF424242), height: 1.5),
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
