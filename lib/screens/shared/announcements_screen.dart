import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/exam_provider.dart';
import '../../models/test_model.dart';
import 'create_announcement_screen.dart';

class AnnouncementsScreen extends StatefulWidget {
  final bool isAdmin;
  final String? studentClass; // for filtering

  const AnnouncementsScreen({
    super.key,
    required this.isAdmin,
    this.studentClass,
  });

  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen> {
  bool _isSelectionMode = false;
  final Set<String> _selectedAnnouncementIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ExamProvider>(context, listen: false).loadAnnouncements(
        targetClass: widget.isAdmin ? null : widget.studentClass,
      );
    });
  }

  void _toggleSelection(String announcementId) {
    setState(() {
      if (_selectedAnnouncementIds.contains(announcementId)) {
        _selectedAnnouncementIds.remove(announcementId);
        if (_selectedAnnouncementIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedAnnouncementIds.add(announcementId);
        _isSelectionMode = true;
      }
    });
  }

  void _enterSelectionMode(String announcementId) {
    if (!widget.isAdmin) return;
    setState(() {
      _isSelectionMode = true;
      _selectedAnnouncementIds.clear();
      _selectedAnnouncementIds.add(announcementId);
    });
  }

  Future<void> _handleBulkDelete(BuildContext context) async {
    final ids = _selectedAnnouncementIds.toList();
    if (ids.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Bulk Delete',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to permanently delete ${ids.length} announcement(s)? This action is irreversible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
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
            child: CircularProgressIndicator(color: Color(0xFF1565C0)),
          ),
        ),
      ),
    );

    final provider = Provider.of<ExamProvider>(context, listen: false);
    final success = await provider.bulkDeleteAnnouncements(
      ids,
      targetClass: widget.studentClass,
    );

    if (context.mounted) Navigator.pop(context);

    if (success) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully deleted ${ids.length} announcement(s)'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
      setState(() {
        _isSelectionMode = false;
        _selectedAnnouncementIds.clear();
      });
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to delete announcements. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget? _buildBottomSelectionBar() {
    if (!_isSelectionMode || _selectedAnnouncementIds.isEmpty) return null;

    final count = _selectedAnnouncementIds.length;

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
                '$count announcement(s) selected',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                  fontSize: 13,
                ),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () => _handleBulkDelete(context),
              icon: const Icon(
                Icons.delete_outline,
                color: Colors.white,
                size: 20,
              ),
              label: const Text(
                'Delete Selected',
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
          ],
        ),
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
                    _selectedAnnouncementIds.clear();
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
                '${_selectedAnnouncementIds.length} Selected',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              )
            : const Text(
                'Announcements',
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
                  onPressed: () {
                    final provider = Provider.of<ExamProvider>(
                      context,
                      listen: false,
                    );
                    final visibleIds = provider.announcements
                        .map((a) => a.id)
                        .toList();
                    setState(() {
                      final allSelected = visibleIds.every(
                        (id) => _selectedAnnouncementIds.contains(id),
                      );
                      if (allSelected) {
                        _selectedAnnouncementIds.removeAll(visibleIds);
                        if (_selectedAnnouncementIds.isEmpty) {
                          _isSelectionMode = false;
                        }
                      } else {
                        _selectedAnnouncementIds.addAll(visibleIds);
                        _isSelectionMode = true;
                      }
                    });
                  },
                ),
              ]
            : (widget.isAdmin
                  ? [
                      IconButton(
                        icon: const Icon(
                          Icons.playlist_add_check_rounded,
                          color: Color(0xFF0F172A),
                          size: 28,
                        ),
                        tooltip: 'Select Announcements',
                        onPressed: () {
                          setState(() {
                            _isSelectionMode = true;
                            _selectedAnnouncementIds.clear();
                          });
                        },
                      ),
                    ]
                  : null),
        elevation: 0,
      ),
      body: Consumer<ExamProvider>(
        builder: (context, provider, _) {
          if (provider.announcementsState == LoadState.loading) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF1565C0)),
            );
          }
          if (provider.announcementsState == LoadState.error) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.cloud_off, size: 72, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    provider.announcementsError ?? 'Failed to load',
                    style: const TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => provider.loadAnnouncements(
                      targetClass: widget.studentClass,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1565C0),
                    ),
                    child: const Text(
                      'Retry',
                      style: TextStyle(color: Colors.white),
                    ),
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
                  Icon(
                    Icons.notifications_none,
                    size: 80,
                    color: Colors.grey.shade200,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No announcements yet.',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            color: const Color(0xFF1565C0),
            onRefresh: () =>
                provider.loadAnnouncements(targetClass: widget.studentClass),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: provider.announcements.length,
              itemBuilder: (context, i) {
                final ann = provider.announcements[i];
                return _AnnouncementCard(
                  ann: ann,
                  isSelectionMode: _isSelectionMode,
                  isSelected: _selectedAnnouncementIds.contains(ann.id),
                  onLongPress: () => _enterSelectionMode(ann.id),
                  onTap: () => _toggleSelection(ann.id),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: widget.isAdmin && !_isSelectionMode
          ? FloatingActionButton(
              backgroundColor: const Color(0xFF1565C0),
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CreateAnnouncementScreen(),
                  ),
                );
                if (result == true && mounted) {
                  // Reload announcements after creating new one
                  Provider.of<ExamProvider>(
                    context,
                    listen: false,
                  ).loadAnnouncements();
                }
              },
              tooltip: 'Create Announcement',
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
      bottomNavigationBar: _buildBottomSelectionBar(),
    );
  }
}

class _AnnouncementCard extends StatelessWidget {
  final Announcement ann;
  final bool isSelectionMode;
  final bool isSelected;
  final VoidCallback? onLongPress;
  final VoidCallback? onTap;

  const _AnnouncementCard({
    required this.ann,
    required this.isSelectionMode,
    required this.isSelected,
    this.onLongPress,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: isSelectionMode ? onTap : null,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isSelectionMode) ...[
              Padding(
                padding: const EdgeInsets.only(
                  left: 16,
                  top: 12,
                  right: 16,
                  bottom: 8,
                ),
                child: Row(
                  children: [
                    Checkbox(
                      value: isSelected,
                      activeColor: const Color(0xFF1565C0),
                      onChanged: (_) => onTap?.call(),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Select Announcement',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
            ],
            // Image if available
            if (ann.image != null && ann.image!.isNotEmpty)
              ClipRRect(
                borderRadius: isSelectionMode
                    ? BorderRadius.zero
                    : const BorderRadius.vertical(top: Radius.circular(16)),
                child: Image.network(
                  ann.image!,
                  width: double.infinity,
                  height: 180,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE3F2FD),
                          borderRadius: BorderRadius.circular(50),
                        ),
                        child: Text(
                          ann.targetClass == 'all'
                              ? 'All Classes'
                              : 'Class ${ann.targetClass}',
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
                      Text(
                        ann.formattedDate,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    ann.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                      color: Color(0xFF1A237E),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    ann.message,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF424242),
                      height: 1.5,
                    ),
                    maxLines: 5,
                    overflow: TextOverflow.ellipsis,
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
