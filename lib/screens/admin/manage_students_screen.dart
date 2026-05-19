import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/admin_provider.dart';
import '../../models/user_model.dart';

class ManageStudentsScreen extends StatefulWidget {
  const ManageStudentsScreen({super.key});

  @override
  State<ManageStudentsScreen> createState() => _ManageStudentsScreenState();
}

class _ManageStudentsScreenState extends State<ManageStudentsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AdminProvider>(context, listen: false).loadStudents();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF009688),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Manage Students', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          tabs: const [
            Tab(text: 'Pending'),
            Tab(text: 'Verified'),
            Tab(text: 'Rejected'),
          ],
        ),
        elevation: 0,
      ),
      body: Consumer<AdminProvider>(
        builder: (context, provider, _) {
          if (provider.studentsState == LoadState.loading) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF009688)));
          }
          if (provider.studentsState == LoadState.error) {
            return _ErrorWidget(
              message: provider.studentsError ?? 'Failed to load students',
              onRetry: () => provider.loadStudents(),
              color: const Color(0xFF009688),
            );
          }
          return TabBarView(
            controller: _tabController,
            children: [
              _StudentList(
                students: provider.pendingStudents,
                showActions: true,
                onAccept: (id) => provider.acceptStudent(id),
                onReject: (id) => provider.rejectStudent(id),
                emptyMsg: 'No pending registrations',
              ),
              _StudentList(
                students: provider.verifiedStudents,
                showActions: false,
                onAccept: (_) async => false,
                onReject: (_) async => false,
                emptyMsg: 'No verified students',
              ),
              _StudentList(
                students: provider.rejectedStudents,
                showActions: false,
                onAccept: (_) async => false,
                onReject: (_) async => false,
                emptyMsg: 'No rejected students',
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StudentList extends StatelessWidget {
  final List<StudentUser> students;
  final bool showActions;
  final Future<bool> Function(String) onAccept;
  final Future<bool> Function(String) onReject;
  final String emptyMsg;

  const _StudentList({
    required this.students,
    required this.showActions,
    required this.onAccept,
    required this.onReject,
    required this.emptyMsg,
  });

  @override
  Widget build(BuildContext context) {
    if (students.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 72, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(emptyMsg, style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
          ],
        ),
      );
    }
    return RefreshIndicator(
      color: const Color(0xFF009688),
      onRefresh: () => Provider.of<AdminProvider>(context, listen: false).loadStudents(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: students.length,
        itemBuilder: (context, i) => _StudentCard(
          student: students[i],
          showActions: showActions,
          onAccept: onAccept,
          onReject: onReject,
        ),
      ),
    );
  }
}

class _StudentCard extends StatefulWidget {
  final StudentUser student;
  final bool showActions;
  final Future<bool> Function(String) onAccept;
  final Future<bool> Function(String) onReject;

  const _StudentCard({required this.student, required this.showActions, required this.onAccept, required this.onReject});

  @override
  State<_StudentCard> createState() => _StudentCardState();
}

class _StudentCardState extends State<_StudentCard> {
  bool _isActing = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.student;
    final isVerified = s.verified == true;
    final isRejected = s.isRejected == true;

    Color statusColor = isVerified ? const Color(0xFF43A047) : isRejected ? Colors.red : const Color(0xFFFF9800);
    String statusText = isVerified ? 'Verified' : isRejected ? 'Rejected' : 'Pending';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 3,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: isVerified ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3E0),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(Icons.person, color: statusColor, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.fullName,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
                      ),
                      const SizedBox(height: 2),
                      Text('📱 ${s.phone ?? 'N/A'}', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                      Text('Class ${s.classNo ?? 'N/A'}', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: Text(statusText, style: TextStyle(color: statusColor, fontWeight: FontWeight.w600, fontSize: 12)),
                ),
              ],
            ),
            if (widget.showActions) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isActing ? null : () async {
                        setState(() => _isActing = true);
                        await widget.onReject(s.id);
                        if (mounted) setState(() => _isActing = false);
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Decline'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isActing ? null : () async {
                        setState(() => _isActing = true);
                        await widget.onAccept(s.id);
                        if (mounted) setState(() => _isActing = false);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF43A047),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: _isActing
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('Accept', style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ErrorWidget extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final Color color;

  const _ErrorWidget({required this.message, required this.onRetry, required this.color});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_off, size: 72, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(message, style: const TextStyle(color: Colors.grey), textAlign: TextAlign.center),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: onRetry,
            style: ElevatedButton.styleFrom(backgroundColor: color),
            child: const Text('Retry', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
