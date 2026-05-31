import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/admin_provider.dart';
import '../../models/user_model.dart';

enum BulkActionType { accept, reject, delete }

class ManageStudentsScreen extends StatefulWidget {
  const ManageStudentsScreen({super.key});

  @override
  State<ManageStudentsScreen> createState() => _ManageStudentsScreenState();
}

class _ManageStudentsScreenState extends State<ManageStudentsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isSelectionMode = false;
  final Set<String> _selectedStudentIds = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabChange);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AdminProvider>(context, listen: false).loadStudents();
    });
  }

  void _handleTabChange() {
    if (_tabController.indexIsChanging) {
      setState(() {
        _isSelectionMode = false;
        _selectedStudentIds.clear();
      });
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }

  void _selectAllVisible() {
    final provider = Provider.of<AdminProvider>(context, listen: false);
    List<StudentUser> visibleStudents = [];
    if (_tabController.index == 0) {
      visibleStudents = provider.pendingStudents;
    } else if (_tabController.index == 1) {
      visibleStudents = provider.verifiedStudents;
    } else if (_tabController.index == 2) {
      visibleStudents = provider.rejectedStudents;
    }

    final visibleIds = visibleStudents.map((s) => s.id).toList();
    
    setState(() {
      final allSelected = visibleIds.every((id) => _selectedStudentIds.contains(id));
      if (allSelected) {
        _selectedStudentIds.removeAll(visibleIds);
        if (_selectedStudentIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedStudentIds.addAll(visibleIds);
        _isSelectionMode = true;
      }
    });
  }

  Future<void> _handleBulkAction(BuildContext context, BulkActionType actionType) async {
    final ids = _selectedStudentIds.toList();
    if (ids.isEmpty) return;

    String actionName = '';
    String confirmMessage = '';
    Color confirmColor = const Color(0xFF009688);
    
    switch (actionType) {
      case BulkActionType.accept:
        actionName = 'Accept';
        confirmMessage = 'Are you sure you want to accept and verify ${ids.length} student(s)?';
        confirmColor = const Color(0xFF43A047);
        break;
      case BulkActionType.reject:
        actionName = 'Decline';
        confirmMessage = 'Are you sure you want to decline/reject ${ids.length} student(s)?';
        confirmColor = Colors.orange.shade800;
        break;
      case BulkActionType.delete:
        actionName = 'Delete';
        confirmMessage = 'Are you sure you want to permanently delete ${ids.length} student(s) from the database? This action is irreversible.';
        confirmColor = Colors.red.shade700;
        break;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Bulk $actionName', style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(confirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: confirmColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(actionName, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(20.0),
            child: CircularProgressIndicator(color: Color(0xFF009688)),
          ),
        ),
      ),
    );

    final provider = Provider.of<AdminProvider>(context, listen: false);
    bool success = false;
    
    try {
      if (actionType == BulkActionType.accept) {
        success = await provider.bulkAcceptStudents(ids);
      } else if (actionType == BulkActionType.reject) {
        success = await provider.bulkRejectStudents(ids);
      } else if (actionType == BulkActionType.delete) {
        success = await provider.bulkDeleteStudents(ids);
      }
    } catch (_) {
      success = false;
    }

    if (context.mounted) Navigator.pop(context);

    if (success) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully processed $actionName for ${ids.length} student(s)'),
            backgroundColor: confirmColor,
          ),
        );
      }
      setState(() {
        _isSelectionMode = false;
        _selectedStudentIds.clear();
      });
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to perform bulk action. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget? _buildBottomSelectionBar() {
    if (!_isSelectionMode || _selectedStudentIds.isEmpty) return null;

    final count = _selectedStudentIds.length;
    final currentTab = _tabController.index;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 12, left: 4),
              child: Text(
                '$count student(s) selected',
                style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF64748B), fontSize: 13),
              ),
            ),
            Row(
              children: [
                if (currentTab == 0 || currentTab == 2) ...[
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _handleBulkAction(context, BulkActionType.accept),
                      icon: const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
                      label: const Text('Accept', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF43A047),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                if (currentTab == 0 || currentTab == 1) ...[
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _handleBulkAction(context, BulkActionType.reject),
                      icon: const Icon(Icons.block, color: Colors.white, size: 20),
                      label: const Text('Decline', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange.shade800,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _handleBulkAction(context, BulkActionType.delete),
                    icon: const Icon(Icons.delete_outline, color: Colors.white, size: 20),
                    label: const Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade700,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _toggleSelection(String studentId) {
    setState(() {
      if (_selectedStudentIds.contains(studentId)) {
        _selectedStudentIds.remove(studentId);
        if (_selectedStudentIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedStudentIds.add(studentId);
        _isSelectionMode = true;
      }
    });
  }

  void _enterSelectionMode(String studentId) {
    setState(() {
      _isSelectionMode = true;
      _selectedStudentIds.clear();
      _selectedStudentIds.add(studentId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _isSelectionMode ? const Color(0xFF0051D5) : const Color(0xFF009688),
        leading: _isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () {
                  setState(() {
                    _isSelectionMode = false;
                    _selectedStudentIds.clear();
                  });
                },
              )
            : IconButton(
                icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
        title: _isSelectionMode
            ? Text('${_selectedStudentIds.length} Selected', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))
            : const Text('Manage Students', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        actions: _isSelectionMode
            ? [
                IconButton(
                  icon: const Icon(Icons.select_all, color: Colors.white),
                  tooltip: 'Select All',
                  onPressed: _selectAllVisible,
                ),
              ]
            : null,
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
                isSelectionMode: _isSelectionMode,
                selectedStudentIds: _selectedStudentIds,
                onLongPressCard: _enterSelectionMode,
                onTapCard: _toggleSelection,
              ),
              _StudentList(
                students: provider.verifiedStudents,
                showActions: false,
                onAccept: (_) async => false,
                onReject: (_) async => false,
                emptyMsg: 'No verified students',
                isSelectionMode: _isSelectionMode,
                selectedStudentIds: _selectedStudentIds,
                onLongPressCard: _enterSelectionMode,
                onTapCard: _toggleSelection,
              ),
              _StudentList(
                students: provider.rejectedStudents,
                showActions: false,
                onAccept: (_) async => false,
                onReject: (_) async => false,
                emptyMsg: 'No rejected students',
                isSelectionMode: _isSelectionMode,
                selectedStudentIds: _selectedStudentIds,
                onLongPressCard: _enterSelectionMode,
                onTapCard: _toggleSelection,
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: _buildBottomSelectionBar(),
    );
  }
}

class _StudentList extends StatelessWidget {
  final List<StudentUser> students;
  final bool showActions;
  final Future<bool> Function(String) onAccept;
  final Future<bool> Function(String) onReject;
  final String emptyMsg;
  final bool isSelectionMode;
  final Set<String> selectedStudentIds;
  final Function(String) onLongPressCard;
  final Function(String) onTapCard;

  const _StudentList({
    required this.students,
    required this.showActions,
    required this.onAccept,
    required this.onReject,
    required this.emptyMsg,
    required this.isSelectionMode,
    required this.selectedStudentIds,
    required this.onLongPressCard,
    required this.onTapCard,
  });

  @override
  Widget build(BuildContext context) {
    if (students.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF009688).withOpacity(0.05),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.people_outline,
                  size: 64,
                  color: Color(0xFF009688),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                emptyMsg,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'No student registration records are currently listed under this category.',
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
          isSelectionMode: isSelectionMode,
          isSelected: selectedStudentIds.contains(students[i].id),
          onLongPress: () => onLongPressCard(students[i].id),
          onTap: () => onTapCard(students[i].id),
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
  final bool isSelectionMode;
  final bool isSelected;
  final VoidCallback onLongPress;
  final VoidCallback onTap;

  const _StudentCard({
    required this.student,
    required this.showActions,
    required this.onAccept,
    required this.onReject,
    required this.isSelectionMode,
    required this.isSelected,
    required this.onLongPress,
    required this.onTap,
  });

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
      child: InkWell(
        onTap: widget.isSelectionMode ? widget.onTap : null,
        onLongPress: widget.onLongPress,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (widget.isSelectionMode) ...[
                    Checkbox(
                      value: widget.isSelected,
                      activeColor: const Color(0xFF009688),
                      onChanged: (_) => widget.onTap(),
                    ),
                    const SizedBox(width: 8),
                  ],
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
              if (widget.showActions && !widget.isSelectionMode) ...[
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
