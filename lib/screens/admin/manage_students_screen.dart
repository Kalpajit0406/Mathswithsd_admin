import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/admin_provider.dart';
import '../../models/user_model.dart';

enum BulkActionType { accept, reject, delete }

class ManageStudentsScreen extends StatefulWidget {
  const ManageStudentsScreen({super.key});

  @override
  State<ManageStudentsScreen> createState() => _ManageStudentsScreenState();
}

class _ManageStudentsScreenState extends State<ManageStudentsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isSelectionMode = false;
  final Set<String> _selectedStudentIds = {};
  String _searchQuery = '';
  String? _classFilter;

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
      final allSelected = visibleIds.every(
        (id) => _selectedStudentIds.contains(id),
      );
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

  Future<void> _handleBulkAction(
    BuildContext context,
    BulkActionType actionType,
  ) async {
    final ids = _selectedStudentIds.toList();
    if (ids.isEmpty) return;

    String actionName = '';
    String confirmMessage = '';
    Color confirmColor = const Color(0xFF009688);

    switch (actionType) {
      case BulkActionType.accept:
        actionName = 'Accept';
        confirmMessage =
            'Are you sure you want to accept and verify ${ids.length} student(s)?';
        confirmColor = const Color(0xFF43A047);
        break;
      case BulkActionType.reject:
        actionName = 'Decline';
        confirmMessage =
            'Are you sure you want to decline/reject ${ids.length} student(s)?';
        confirmColor = Colors.orange.shade800;
        break;
      case BulkActionType.delete:
        actionName = 'Delete';
        confirmMessage =
            'Are you sure you want to permanently delete ${ids.length} student(s) from the database? This action is irreversible.';
        confirmColor = Colors.red.shade700;
        break;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Bulk $actionName',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              actionName,
              style: const TextStyle(color: Colors.white),
            ),
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
            content: Text(
              'Successfully processed $actionName for ${ids.length} student(s)',
            ),
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
            color: Colors.black.withValues(alpha: 0.1),
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
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                  fontSize: 13,
                ),
              ),
            ),
            Row(
              children: [
                if (currentTab == 0 || currentTab == 2) ...[
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () =>
                          _handleBulkAction(context, BulkActionType.accept),
                      icon: const Icon(
                        Icons.check_circle_outline,
                        color: Colors.white,
                        size: 20,
                      ),
                      label: const Text(
                        'Accept',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF43A047),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                if (currentTab == 0 || currentTab == 1) ...[
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () =>
                          _handleBulkAction(context, BulkActionType.reject),
                      icon: const Icon(
                        Icons.block,
                        color: Colors.white,
                        size: 20,
                      ),
                      label: const Text(
                        'Decline',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange.shade800,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () =>
                        _handleBulkAction(context, BulkActionType.delete),
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Colors.white,
                      size: 20,
                    ),
                    label: const Text(
                      'Delete',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade700,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
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

  Widget _buildFilterBar(List<String> allClasses) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: InputDecoration(
                hintText: 'Search by name or phone...',
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 0,
                  horizontal: 16,
                ),
                filled: true,
                fillColor: const Color(0xFFF1F5F9),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.grey),
                        onPressed: () {
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String?>(
                value: _classFilter,
                hint: const Text(
                  'Class',
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
                icon: const Icon(Icons.filter_list, color: Color(0xFF009688)),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('All Classes', style: TextStyle(fontSize: 14)),
                  ),
                  ...allClasses.map(
                    (cls) => DropdownMenuItem<String?>(
                      value: cls,
                      child: Text(
                        'Class $cls',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ),
                ],
                onChanged: (val) {
                  setState(() {
                    _classFilter = val;
                  });
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _isSelectionMode
            ? const Color(0xFF0051D5)
            : Colors.transparent,
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
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Color(0xFF0F172A),
                  size: 20,
                ),
                onPressed: () => Navigator.pop(context),
              ),
        title: _isSelectionMode
            ? Text(
                '${_selectedStudentIds.length} Selected',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              )
            : const Text(
                'Manage Students',
                style: TextStyle(
                  color: Color(0xFF0F172A),
                  fontWeight: FontWeight.w800,
                  fontSize: 22,
                  letterSpacing: -0.5,
                ),
              ),
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
          labelColor: const Color(0xFF0051D5),
          unselectedLabelColor: const Color(0xFF75859D),
          indicatorColor: const Color(0xFF0051D5),
          indicatorWeight: 3,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
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
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF009688)),
            );
          }
          if (provider.studentsState == LoadState.error) {
            return _ErrorWidget(
              message: provider.studentsError ?? 'Failed to load students',
              onRetry: () => provider.loadStudents(),
              color: const Color(0xFF009688),
            );
          }

          // Gather all available classes dynamically from database list
          final allStudents = [
            ...provider.pendingStudents,
            ...provider.verifiedStudents,
            ...provider.rejectedStudents,
          ];
          final allClasses =
              allStudents
                  .map((s) => s.classNo?.toString())
                  .whereType<String>()
                  .toSet()
                  .toList()
                ..sort((a, b) {
                  final aNum = int.tryParse(a) ?? 0;
                  final bNum = int.tryParse(b) ?? 0;
                  return aNum.compareTo(bNum);
                });

          // Local filter logic
          List<StudentUser> filterStudents(List<StudentUser> list) {
            return list.where((s) {
              final matchesSearch =
                  _searchQuery.isEmpty ||
                  s.fullName.toLowerCase().contains(
                    _searchQuery.toLowerCase(),
                  ) ||
                  (s.phone != null && s.phone!.contains(_searchQuery));
              final matchesClass =
                  _classFilter == null || s.classNo?.toString() == _classFilter;
              return matchesSearch && matchesClass;
            }).toList();
          }

          final filteredPending = filterStudents(provider.pendingStudents);
          final filteredVerified = filterStudents(provider.verifiedStudents);
          final filteredRejected = filterStudents(provider.rejectedStudents);
          final editStudents = allStudents
              .where((s) => s.pendingProfileEdit != null)
              .toList();
          final filteredProfileEdits = filterStudents(editStudents);

          return Column(
            children: [
              _buildFilterBar(allClasses),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _PendingTabContent(
                      pendingRegistrations: filteredPending,
                      profileEdits: filteredProfileEdits,
                      onAcceptRegistration: (id) => provider.acceptStudent(id),
                      onRejectRegistration: (id) => provider.rejectStudent(id),
                      onResolveProfileEdit: (id, approve) =>
                          provider.resolveProfileEdit(id, approve),
                      isSelectionMode: _isSelectionMode,
                      selectedStudentIds: _selectedStudentIds,
                      onLongPressCard: _enterSelectionMode,
                      onTapCard: _toggleSelection,
                    ),
                    _StudentList(
                      students: filteredVerified,
                      showActions: false,
                      onAccept: (_) async => false,
                      onReject: (_) async => false,
                      emptyMsg: _searchQuery.isNotEmpty || _classFilter != null
                          ? 'No matching verified students'
                          : 'No verified students',
                      isSelectionMode: _isSelectionMode,
                      selectedStudentIds: _selectedStudentIds,
                      onLongPressCard: _enterSelectionMode,
                      onTapCard: _toggleSelection,
                    ),
                    _StudentList(
                      students: filteredRejected,
                      showActions: false,
                      onAccept: (_) async => false,
                      onReject: (_) async => false,
                      emptyMsg: _searchQuery.isNotEmpty || _classFilter != null
                          ? 'No matching rejected students'
                          : 'No rejected students',
                      isSelectionMode: _isSelectionMode,
                      selectedStudentIds: _selectedStudentIds,
                      onLongPressCard: _enterSelectionMode,
                      onTapCard: _toggleSelection,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: _buildBottomSelectionBar(),
    );
  }
}

class _StudentList extends StatefulWidget {
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
  State<_StudentList> createState() => _StudentListState();
}

class _StudentListState extends State<_StudentList> {
  final Map<String, GlobalKey> _itemKeys = {};
  final GlobalKey _listKey = GlobalKey();
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  String? _getStudentIdAtPosition(Offset globalPosition) {
    for (final entry in _itemKeys.entries) {
      final context = entry.value.currentContext;
      if (context == null) continue;

      final renderBox = context.findRenderObject() as RenderBox?;
      if (renderBox == null) continue;

      final localPosition = renderBox.globalToLocal(globalPosition);
      final boxSize = renderBox.size;

      if (localPosition.dx >= 0 &&
          localPosition.dx <= boxSize.width &&
          localPosition.dy >= 0 &&
          localPosition.dy <= boxSize.height) {
        return entry.key;
      }
    }
    return null;
  }

  void _detectAndSelectItems(Offset globalPosition) {
    final studentId = _getStudentIdAtPosition(globalPosition);
    if (studentId != null) {
      if (!widget.selectedStudentIds.contains(studentId)) {
        widget.onTapCard(studentId);
      }
    }
  }

  void _handleEdgeScrolling(Offset globalPosition) {
    final listRenderBox =
        _listKey.currentContext?.findRenderObject() as RenderBox?;
    if (listRenderBox == null) return;

    final localPos = listRenderBox.globalToLocal(globalPosition);
    final height = listRenderBox.size.height;

    if (localPos.dy < 80) {
      final target = _scrollController.offset - 15;
      if (target >= _scrollController.position.minScrollExtent) {
        _scrollController.jumpTo(target);
      }
    } else if (localPos.dy > height - 80) {
      final target = _scrollController.offset + 15;
      if (target <= _scrollController.position.maxScrollExtent) {
        _scrollController.jumpTo(target);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.students.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF009688).withValues(alpha: 0.05),
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
                widget.emptyMsg,
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
      key: _listKey,
      color: const Color(0xFF009688),
      onRefresh: () =>
          Provider.of<AdminProvider>(context, listen: false).loadStudents(),
      child: GestureDetector(
        onLongPressStart: (details) {
          final studentId = _getStudentIdAtPosition(details.globalPosition);
          if (studentId != null) {
            widget.onLongPressCard(studentId);
            Feedback.forLongPress(context);
          }
        },
        onLongPressMoveUpdate: (details) {
          _detectAndSelectItems(details.globalPosition);
          _handleEdgeScrolling(details.globalPosition);
        },
        child: ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.all(16),
          itemCount: widget.students.length,
          itemBuilder: (context, i) {
            final student = widget.students[i];
            final key = _itemKeys.putIfAbsent(student.id, () => GlobalKey());
            return _StudentCard(
              key: key,
              student: student,
              showActions: widget.showActions,
              onAccept: widget.onAccept,
              onReject: widget.onReject,
              isSelectionMode: widget.isSelectionMode,
              isSelected: widget.selectedStudentIds.contains(student.id),
              onTap: () => widget.onTapCard(student.id),
            );
          },
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
  final VoidCallback onTap;

  const _StudentCard({
    super.key,
    required this.student,
    required this.showActions,
    required this.onAccept,
    required this.onReject,
    required this.isSelectionMode,
    required this.isSelected,
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

    Color statusColor = isVerified
        ? const Color(0xFF43A047)
        : isRejected
        ? Colors.red
        : const Color(0xFFFF9800);
    String statusText = isVerified
        ? 'Verified'
        : isRejected
        ? 'Rejected'
        : 'Pending';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 3,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () {
          if (widget.isSelectionMode) {
            widget.onTap();
          } else {
            _showStudentDetailsSheet(context, s);
          }
        },
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
                      onChanged: (_) {
                        widget.onTap();
                      },
                    ),
                    const SizedBox(width: 8),
                  ],
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: isVerified
                          ? const Color(0xFFE8F5E9)
                          : const Color(0xFFFFF3E0),
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
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 17,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '📱 ${s.phone ?? 'N/A'}',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 13,
                          ),
                        ),
                        Row(
                          children: [
                            Text(
                              'Class ${s.classNo ?? 'N/A'}',
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(width: 8),
                            _buildAccountTypeBadge(s.accountType, s.isJoint),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              if (widget.showActions && !widget.isSelectionMode) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isActing
                            ? null
                            : () async {
                                setState(() => _isActing = true);
                                await widget.onReject(s.id);
                                if (mounted) setState(() => _isActing = false);
                              },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text('Decline'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isActing
                            ? null
                            : () async {
                                setState(() => _isActing = true);
                                await widget.onAccept(s.id);
                                if (mounted) setState(() => _isActing = false);
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF43A047),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: _isActing
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Accept',
                                style: TextStyle(color: Colors.white),
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAccountTypeBadge(String? type, bool? isJoint) {
    String text = type ?? 'NORMAL';
    Color color = const Color(0xFF2196F3); // Default blue for Normal
    if (text == 'TRIAL') {
      color = const Color(0xFFE65100); // Dark orange for Trial
    } else if (text == 'JOINT_ENTRANCE' || isJoint == true) {
      color = const Color(0xFF9C27B0); // Purple for Joint Entrance
      text = 'JOINT';
    } else if (text == 'PREMIUM') {
      color = const Color(0xFFFFB300); // Amber/Gold for Premium
    } else if (text == 'BLOCKED') {
      color = Colors.red;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _showStudentDetailsSheet(BuildContext context, StudentUser s) {
    final provider = Provider.of<AdminProvider>(context, listen: false);
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final sheetBg = isDark ? const Color(0xFF0F172A) : Colors.white;
        final textColor = isDark ? Colors.white : Colors.black87;
        final secondaryTextColor = isDark ? Colors.white60 : Colors.black54;
        final isVerified = s.verified == true;
        
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: sheetBg,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: const [
                  BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, -2))
                ]
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade400,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                s.fullName,
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: textColor,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Text(
                                    'Class ${s.classNo ?? 'N/A'} • ${s.language ?? 'English'} Medium',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: secondaryTextColor,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  _buildAccountTypeBadge(s.accountType, s.isJoint),
                                ],
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const Divider(height: 32),
                    
                    // Info blocks
                    _infoRow(context, Icons.phone_android_rounded, 'Phone Number', s.phone ?? 'N/A', 
                      action: IconButton(
                        icon: const Icon(Icons.copy_all_rounded, size: 20),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: s.phone ?? ''));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Phone number copied to clipboard')),
                          );
                        },
                      ),
                    ),
                    _infoRow(context, Icons.fingerprint_rounded, 'Device Fingerprint', s.deviceFingerprint ?? 'Not registered yet'),
                    _infoRow(context, Icons.warning_amber_rounded, 'Rejection Attempts', '${s.requestAttempts ?? 0} / 5'),
                    
                    const SizedBox(height: 24),
                    Text(
                      'Admin Actions',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    if (!isVerified) ...[
                      // If request is pending or rejected
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                Navigator.pop(ctx);
                                final ok = await provider.acceptStudent(s.id);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(ok ? 'Student approved successfully' : 'Failed to approve student'),
                                      backgroundColor: ok ? Colors.green : Colors.red,
                                    ),
                                  );
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF43A047),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              icon: const Icon(Icons.check_circle_outline_rounded, color: Colors.white),
                              label: const Text('Approve Student', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                Navigator.pop(ctx);
                                final ok = await provider.rejectStudent(s.id);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(ok ? 'Student declined successfully' : 'Failed to decline student'),
                                      backgroundColor: ok ? Colors.green : Colors.red,
                                    ),
                                  );
                                }
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red,
                                side: const BorderSide(color: Colors.red),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              icon: const Icon(Icons.cancel_outlined, color: Colors.red),
                              label: const Text('Decline Request'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            Navigator.pop(ctx);
                            final ok = await provider.blacklistStudent(s.id, true);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(ok ? 'Student blacklisted successfully' : 'Failed to blacklist student'),
                                  backgroundColor: ok ? Colors.black87 : Colors.red,
                                ),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black87,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.gavel_rounded, color: Colors.white),
                          label: const Text('Blacklist Student (Fingerprint & Phone)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ] else ...[
                      // If student is verified
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          if (s.accountType == 'TRIAL')
                            _actionChip(
                              context,
                              label: 'Convert TRIAL → NORMAL',
                              icon: Icons.person_add_rounded,
                              color: const Color(0xFF2196F3),
                              onTap: () async {
                                Navigator.pop(ctx);
                                final ok = await provider.updateAccountStatus(s.id, accountType: 'NORMAL');
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(ok ? 'Successfully converted account to NORMAL' : 'Failed to convert account'),
                                      backgroundColor: ok ? Colors.green : Colors.red,
                                    ),
                                  );
                                }
                              },
                            ),
                          if (s.accountType != 'TRIAL')
                            _actionChip(
                              context,
                              label: 'Convert NORMAL → TRIAL',
                              icon: Icons.hourglass_empty_rounded,
                              color: const Color(0xFFE65100),
                              onTap: () async {
                                Navigator.pop(ctx);
                                final ok = await provider.updateAccountStatus(s.id, accountType: 'TRIAL');
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(ok ? 'Successfully converted account to TRIAL' : 'Failed to convert account'),
                                      backgroundColor: ok ? Colors.green : Colors.red,
                                    ),
                                  );
                                }
                              },
                            ),
                          if (s.isJoint != true && (s.classNo == 11 || s.classNo == 12))
                            _actionChip(
                              context,
                              label: 'Approve JOINT entrance',
                              icon: Icons.school_rounded,
                              color: const Color(0xFF9C27B0),
                              onTap: () async {
                                Navigator.pop(ctx);
                                final ok = await provider.updateAccountStatus(s.id, isJoint: true);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(ok ? 'Successfully approved JOINT entrance' : 'Failed to approve JOINT entrance'),
                                      backgroundColor: ok ? Colors.green : Colors.red,
                                    ),
                                  );
                                }
                              },
                            ),
                          _actionChip(
                            context,
                            label: s.accountType == 'BLOCKED' ? 'Unblock Student' : 'Block Student',
                            icon: s.accountType == 'BLOCKED' ? Icons.lock_open_rounded : Icons.lock_outline_rounded,
                            color: Colors.redAccent,
                            onTap: () async {
                              Navigator.pop(ctx);
                              final block = s.accountType != 'BLOCKED';
                              final ok = await provider.updateAccountStatus(s.id, accountType: block ? 'BLOCKED' : 'NORMAL');
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(ok ? (block ? 'Student blocked successfully' : 'Student unblocked successfully') : 'Failed to update student block status'),
                                    backgroundColor: ok ? Colors.green : Colors.red,
                                  ),
                                );
                              }
                            },
                          ),
                          _actionChip(
                            context,
                            label: 'Reset Trial Limits',
                            icon: Icons.refresh_rounded,
                            color: Colors.teal,
                            onTap: () async {
                              Navigator.pop(ctx);
                              final ok = await provider.updateAccountStatus(s.id, resetTrialLimits: true);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(ok ? 'Successfully reset trial limits' : 'Failed to reset trial limits'),
                                    backgroundColor: ok ? Colors.green : Colors.red,
                                  ),
                                );
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _infoRow(BuildContext context, IconData icon, String label, String value, {Widget? action}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF009688), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          if (action != null) action,
        ],
      ),
    );
  }

  Widget _actionChip(BuildContext context, {
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ElevatedButton.icon(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withValues(alpha: 0.12),
        elevation: 0,
        side: BorderSide(color: color.withValues(alpha: 0.3)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      icon: Icon(icon, color: color, size: 16),
      label: Text(
        label,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _ErrorWidget extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final Color color;

  const _ErrorWidget({
    required this.message,
    required this.onRetry,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_off, size: 72, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
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

class _PendingTabContent extends StatefulWidget {
  final List<StudentUser> pendingRegistrations;
  final List<StudentUser> profileEdits;
  final Future<bool> Function(String) onAcceptRegistration;
  final Future<bool> Function(String) onRejectRegistration;
  final Function(String, bool) onResolveProfileEdit;
  final bool isSelectionMode;
  final Set<String> selectedStudentIds;
  final Function(String) onLongPressCard;
  final Function(String) onTapCard;

  const _PendingTabContent({
    required this.pendingRegistrations,
    required this.profileEdits,
    required this.onAcceptRegistration,
    required this.onRejectRegistration,
    required this.onResolveProfileEdit,
    required this.isSelectionMode,
    required this.selectedStudentIds,
    required this.onLongPressCard,
    required this.onTapCard,
  });

  @override
  State<_PendingTabContent> createState() => _PendingTabContentState();
}

class _PendingTabContentState extends State<_PendingTabContent> {
  int _activeSubTab = 0; // 0: Registrations, 1: Profile Edits

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Sub-tabs toggle bar
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _activeSubTab = 0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: _activeSubTab == 0
                          ? Colors.white
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: _activeSubTab == 0
                          ? [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Registrations (${widget.pendingRegistrations.length})',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: _activeSubTab == 0
                            ? const Color(0xFF0F172A)
                            : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _activeSubTab = 1),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: _activeSubTab == 1
                          ? Colors.white
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: _activeSubTab == 1
                          ? [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Profile Edits (${widget.profileEdits.length})',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: _activeSubTab == 1
                            ? const Color(0xFF0F172A)
                            : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Active Sub-tab View
        Expanded(
          child: _activeSubTab == 0
              ? _StudentList(
                  students: widget.pendingRegistrations,
                  showActions: true,
                  onAccept: widget.onAcceptRegistration,
                  onReject: widget.onRejectRegistration,
                  emptyMsg: 'No pending registrations',
                  isSelectionMode: widget.isSelectionMode,
                  selectedStudentIds: widget.selectedStudentIds,
                  onLongPressCard: widget.onLongPressCard,
                  onTapCard: widget.onTapCard,
                )
              : _ProfileEditsList(
                  students: widget.profileEdits,
                  onResolve: widget.onResolveProfileEdit,
                ),
        ),
      ],
    );
  }
}

class _ProfileEditsList extends StatelessWidget {
  final List<StudentUser> students;
  final Function(String, bool) onResolve;

  const _ProfileEditsList({required this.students, required this.onResolve});

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
                  color: const Color(0xFF009688).withValues(alpha: 0.05),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.edit_note_rounded,
                  size: 64,
                  color: Color(0xFF009688),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'No pending profile edits',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'There are no profile modification requests waiting for teacher approval.',
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
      onRefresh: () =>
          Provider.of<AdminProvider>(context, listen: false).loadStudents(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: students.length,
        itemBuilder: (context, i) {
          return _ProfileEditCard(student: students[i], onResolve: onResolve);
        },
      ),
    );
  }
}

class _ProfileEditCard extends StatefulWidget {
  final StudentUser student;
  final Function(String, bool) onResolve;

  const _ProfileEditCard({required this.student, required this.onResolve});

  @override
  State<_ProfileEditCard> createState() => _ProfileEditCardState();
}

class _ProfileEditCardState extends State<_ProfileEditCard> {
  bool _isActing = false;

  int? _getInt(dynamic val) {
    if (val == null) return null;
    return int.tryParse(val.toString());
  }

  bool? _getBool(dynamic val) {
    if (val == null) return null;
    return val == true || val.toString() == 'true';
  }

  String _getClassDisplay(int? classNo, bool? isJoint) {
    if (classNo == null) return 'N/A';
    if (isJoint == true && (classNo == 11 || classNo == 12)) {
      return '$classNo Joint';
    }
    return classNo.toString();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.student;
    final edit = s.pendingProfileEdit!;
    final reqClass = edit['classNo'];
    final reqLang = edit['language'];
    final reqJoint = edit['isJoint'];

    final parsedReqClass = _getInt(reqClass);
    final parsedReqJoint = _getBool(reqJoint);

    final oldClassStr = _getClassDisplay(s.classNo, s.isJoint);
    final newClassStr = _getClassDisplay(
      parsedReqClass ?? s.classNo,
      parsedReqJoint ?? s.isJoint,
    );

    final classChanged = oldClassStr != newClassStr;
    final langChanged = reqLang != null && reqLang.toString() != s.language;

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
                    color: const Color(0xFFE0F2FE),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.edit_note_rounded,
                    color: Color(0xFF0284C7),
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.fullName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 17,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '📱 ${s.phone ?? 'N/A'}',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  _changeRow('Class', oldClassStr, newClassStr, classChanged),
                  const SizedBox(height: 8),
                  _changeRow(
                    'Medium',
                    s.language ?? 'N/A',
                    reqLang?.toString() ?? 'N/A',
                    langChanged,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isActing
                        ? null
                        : () async {
                            setState(() => _isActing = true);
                            await widget.onResolve(s.id, false);
                            if (mounted) setState(() => _isActing = false);
                          },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('Decline'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isActing
                        ? null
                        : () async {
                            setState(() => _isActing = true);
                            await widget.onResolve(s.id, true);
                            if (mounted) setState(() => _isActing = false);
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF009688),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: _isActing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Approve',
                            style: TextStyle(color: Colors.white),
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

  Widget _changeRow(
    String label,
    String oldValue,
    String newValue,
    bool hasChanged,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Color(0xFF64748B),
            fontSize: 13,
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  oldValue,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 13,
                    decoration: hasChanged ? TextDecoration.lineThrough : null,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (hasChanged) ...[
                const SizedBox(width: 4),
                const Icon(
                  Icons.arrow_right_alt_rounded,
                  color: Color(0xFF009688),
                  size: 16,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    newValue,
                    style: const TextStyle(
                      color: Color(0xFF009688),
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
