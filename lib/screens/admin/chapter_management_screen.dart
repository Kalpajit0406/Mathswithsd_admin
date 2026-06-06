import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../utils/constants.dart' hide AppColors;
import '../../widgets/fade_in_slide.dart';
import '../../widgets/glass_card.dart';

class AppColors {
  static const Color error = Color(0xFFBA1A1A);
  static const Color success = Color(0xFF43A047);
  static const Color warning = Color(0xFFE65100);
}


class ChapterManagementScreen extends StatefulWidget {
  const ChapterManagementScreen({super.key});

  @override
  State<ChapterManagementScreen> createState() => _ChapterManagementScreenState();
}

class _ChapterManagementScreenState extends State<ChapterManagementScreen> with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  late TabController _tabController;
  
  List<Map<String, dynamic>> _allChapters = [];
  List<Map<String, dynamic>> _filteredChapters = [];
  bool _isLoading = false;
  String _searchQuery = '';
  String _sortBy = 'name'; // 'name' or 'date'
  int _selectedClass = 9;

  final List<int> _classes = [9, 10, 11, 12, 13];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _classes.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _selectedClass = _classes[_tabController.index];
          _applyFilters();
        });
      }
    });
    _fetchChapters();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchChapters() async {
    setState(() => _isLoading = true);
    try {
      final chapters = await _apiService.getChapters();
      setState(() {
        _allChapters = chapters;
        _applyFilters();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load chapters: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _applyFilters() {
    List<Map<String, dynamic>> temp = _allChapters.where((ch) {
      final matchesClass = ch['classId'] == _selectedClass;
      final matchesSearch = ch['chapterName']
          .toString()
          .toLowerCase()
          .contains(_searchQuery.toLowerCase());
      return matchesClass && matchesSearch;
    }).toList();

    if (_sortBy == 'name') {
      temp.sort((a, b) => a['chapterName'].toString().compareTo(b['chapterName'].toString()));
    } else {
      // Sort by date created (newest first)
      temp.sort((a, b) {
        final aDate = DateTime.tryParse(a['createdAt'] ?? '') ?? DateTime.now();
        final bDate = DateTime.tryParse(b['createdAt'] ?? '') ?? DateTime.now();
        return bDate.compareTo(aDate);
      });
    }

    setState(() {
      _filteredChapters = temp;
    });
  }

  void _showAddChapterDialog() {
    final textController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFFF7F9FB),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: const [
                  Icon(Icons.add_circle_outline, color: Color(0xFF0051D5)),
                  SizedBox(width: 8),
                  Text(
                    'Add New Chapter',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ],
              ),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Class: ${_selectedClass == 13 ? "Joint Entrance" : "Class $_selectedClass"}',
                      style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF75859D)),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: textController,
                      autofocus: true,
                      enabled: !isSaving,
                      decoration: InputDecoration(
                        labelText: 'Chapter Name',
                        hintText: 'e.g. Differential Equations',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF0051D5), width: 2),
                        ),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Please enter a chapter name';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: Color(0xFF75859D))),
                ),
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (formKey.currentState!.validate()) {
                            setDialogState(() => isSaving = true);
                            try {
                              await _apiService.addChapter(_selectedClass, textController.text.trim());
                              if (mounted) {
                                Navigator.pop(context);
                                _fetchChapters();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Chapter added successfully!'),
                                    backgroundColor: AppColors.success,
                                  ),
                                );
                              }
                            } catch (e) {
                              setDialogState(() => isSaving = false);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Error adding chapter: $e'),
                                    backgroundColor: AppColors.error,
                                  ),
                                );
                              }
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0051D5),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: isSaving
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEditChapterDialog(Map<String, dynamic> chapter) {
    final chapterId = chapter['_id'] ?? chapter['id'];
    final chapterName = chapter['chapterName'];
    final textController = TextEditingController(text: chapterName);
    final formKey = GlobalKey<FormState>();
    
    bool isFetchingUsage = true;
    bool isSaving = false;
    int usageCount = 0;
    String? fetchError;

    // Load usage count on dialog open
    Future.microtask(() async {
      try {
        final count = await _apiService.getChapterUsage(chapterId);
        if (mounted) {
          setState(() {
            isFetchingUsage = false;
            usageCount = count;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            isFetchingUsage = false;
            fetchError = e.toString();
          });
        }
      }
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            // Keep dialog state synced with outer async task
            if (isFetchingUsage) {
              return const AlertDialog(
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Analyzing chapter questions...', style: TextStyle(fontWeight: FontWeight.w500)),
                  ],
                ),
              );
            }

            if (fetchError != null) {
              return AlertDialog(
                title: const Text('Error'),
                content: Text('Failed to check chapter usage: $fetchError'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ],
              );
            }

            final showDestructiveOption = usageCount > 0;

            return AlertDialog(
              backgroundColor: const Color(0xFFF7F9FB),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: const [
                  Icon(Icons.edit, color: Color(0xFF0051D5)),
                  SizedBox(width: 8),
                  Text(
                    'Edit Chapter',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ],
              ),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Contains: $usageCount linked questions.',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: showDestructiveOption ? AppColors.warning : const Color(0xFF75859D),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: textController,
                      enabled: !isSaving,
                      decoration: InputDecoration(
                        labelText: 'Chapter Name',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Chapter name cannot be empty';
                        }
                        return null;
                      },
                    ),
                    if (showDestructiveOption) ...[
                      const SizedBox(height: 16),
                      const Text(
                        'This chapter contains active questions. Choose an action:',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: Color(0xFF75859D))),
                ),
                
                // If there are questions, offer the destructive delete option
                if (showDestructiveOption)
                  ElevatedButton(
                    onPressed: isSaving
                        ? null
                        : () => _confirmDestructiveEdit(chapterId, chapterName, setDialogState),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Delete Questions & Chapter'),
                  ),

                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (formKey.currentState!.validate()) {
                            setDialogState(() => isSaving = true);
                            try {
                              await _apiService.editChapter(
                                chapterId,
                                'rename',
                                chapterName: textController.text.trim(),
                              );
                              if (mounted) {
                                Navigator.pop(context);
                                _fetchChapters();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Chapter renamed everywhere successfully!'),
                                    backgroundColor: AppColors.success,
                                  ),
                                );
                              }
                            } catch (e) {
                              setDialogState(() => isSaving = false);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Failed to rename chapter: $e'),
                                    backgroundColor: AppColors.error,
                                  ),
                                );
                              }
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0051D5),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: isSaving
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(showDestructiveOption ? 'Rename Everywhere' : 'Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmDestructiveEdit(String chapterId, String chapterName, StateSetter setDialogState) {
    final confirmationController = TextEditingController();
    bool isVerifying = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSubstate) {
            return AlertDialog(
              title: const Text('⚠️ DANGER ZONE', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'This action permanently deletes all questions linked to "$chapterName" and removes the chapter from all exams.',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 16),
                  const Text('To confirm, type "DELETE" in the box below:'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: confirmationController,
                    autofocus: true,
                    enabled: !isVerifying,
                    decoration: const InputDecoration(
                      hintText: 'DELETE',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isVerifying ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isVerifying
                      ? null
                      : () async {
                          if (confirmationController.text.trim() != 'DELETE') {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Text does not match "DELETE"'), backgroundColor: AppColors.error),
                            );
                            return;
                          }
                          setSubstate(() => isVerifying = true);
                          try {
                            await _apiService.editChapter(chapterId, 'delete_questions');
                            if (mounted) {
                              Navigator.pop(context); // Close sub-dialog
                              Navigator.pop(context); // Close edit dialog
                              _fetchChapters();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Chapter and questions deleted successfully.'),
                                  backgroundColor: AppColors.success,
                                ),
                              );
                            }
                          } catch (e) {
                            setSubstate(() => isVerifying = false);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Delete failed: $e'), backgroundColor: AppColors.error),
                              );
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: isVerifying
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Permanently Delete Everything'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showDeleteChapterDialog(Map<String, dynamic> chapter) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _DeleteChapterDialog(
        chapterId: chapter['_id'] ?? chapter['id'] ?? '',
        chapterName: chapter['chapterName'] ?? '',
        onDeleted: _fetchChapters,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Chapter Manager',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF0051D5)),
            onPressed: _fetchChapters,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF0051D5),
          unselectedLabelColor: const Color(0xFF75859D),
          indicatorColor: const Color(0xFF0051D5),
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(text: 'Class 9'),
            Tab(text: 'Class 10'),
            Tab(text: 'Class 11'),
            Tab(text: 'Class 12'),
            Tab(text: 'Joint'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddChapterDialog,
        backgroundColor: const Color(0xFF0051D5),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Add Chapter', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
      ),
      body: Column(
        children: [
          // Filter & Search Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: TextField(
                      onChanged: (val) {
                        setState(() {
                          _searchQuery = val;
                          _applyFilters();
                        });
                      },
                      decoration: const InputDecoration(
                        hintText: 'Search chapters...',
                        prefixIcon: Icon(Icons.search_rounded, color: Color(0xFF75859D)),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: PopupMenuButton<String>(
                    icon: const Icon(Icons.sort_rounded, color: Color(0xFF0051D5)),
                    onSelected: (val) {
                      setState(() {
                        _sortBy = val;
                        _applyFilters();
                      });
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'name',
                        child: Text('Sort Alphabetically'),
                      ),
                      const PopupMenuItem(
                        value: 'date',
                        child: Text('Sort by Recency'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Main List View
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _fetchChapters,
                    child: _filteredChapters.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              SizedBox(height: MediaQuery.of(context).size.height * 0.25),
                              Center(
                                child: Column(
                                  children: [
                                    Icon(Icons.menu_book_rounded, size: 72, color: const Color(0xFF75859D).withValues(alpha: 0.3)),
                                    const SizedBox(height: 16),
                                    Text(
                                      _searchQuery.isEmpty ? 'No Chapters Found' : 'No matches for "$_searchQuery"',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF75859D),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      'Add a chapter using the button below.',
                                      style: TextStyle(color: Color(0xFF75859D)),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          )
                        : ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            itemCount: _filteredChapters.length,
                            itemBuilder: (context, index) {
                              final ch = _filteredChapters[index];
                              return FadeInSlide(
                                duration: const Duration(milliseconds: 400),
                                slideOffset: 16,
                                child: Padding(
                                  padding: const EdgeInsets.only(bottom: 12.0),
                                  child: GlassCard(
                                    borderRadius: 16,
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    child: Row(
                                      children: [
                                        const CircleAvatar(
                                          backgroundColor: Color(0xFFE0EAFD),
                                          radius: 20,
                                          child: Icon(Icons.bookmark_outline_rounded, color: Color(0xFF0051D5), size: 20),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Text(
                                            ch['chapterName'] ?? '',
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF0F172A),
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.edit_outlined, color: Color(0xFF316BF3)),
                                          onPressed: () => _showEditChapterDialog(ch),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFBA1A1A)),
                                          onPressed: () => _showDeleteChapterDialog(ch),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _DeleteChapterDialog extends StatefulWidget {
  final String chapterId;
  final String chapterName;
  final VoidCallback onDeleted;

  const _DeleteChapterDialog({
    required this.chapterId,
    required this.chapterName,
    required this.onDeleted,
  });

  @override
  State<_DeleteChapterDialog> createState() => _DeleteChapterDialogState();
}

class _DeleteChapterDialogState extends State<_DeleteChapterDialog> {
  final ApiService _apiService = ApiService();
  final TextEditingController _confirmationController = TextEditingController();
  bool _isFetchingUsage = true;
  bool _isDeleting = false;
  int _usageCount = 0;
  String? _fetchError;

  @override
  void initState() {
    super.initState();
    _fetchUsage();
  }

  @override
  void dispose() {
    _confirmationController.dispose();
    super.dispose();
  }

  Future<void> _fetchUsage() async {
    try {
      final count = await _apiService.getChapterUsage(widget.chapterId);
      if (mounted) {
        setState(() {
          _isFetchingUsage = false;
          _usageCount = count;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isFetchingUsage = false;
          _fetchError = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isFetchingUsage) {
      return const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Analyzing chapter references...', style: TextStyle(fontWeight: FontWeight.w500)),
          ],
        ),
      );
    }

    if (_fetchError != null) {
      return AlertDialog(
        title: const Text('Error'),
        content: Text('Failed to check chapter usage: $_fetchError'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      );
    }

    final hasLinkedQuestions = _usageCount > 0;

    return AlertDialog(
      backgroundColor: const Color(0xFFF7F9FB),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Icon(Icons.warning_rounded, color: AppColors.error),
          SizedBox(width: 8),
          Text(
            'Delete Chapter',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Are you sure you want to delete "${widget.chapterName}"?',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 12),
          if (hasLinkedQuestions) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFEAEA),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.error),
              ),
              child: Text(
                'WARNING: This chapter contains $_usageCount active questions. Deleting this chapter will CASCADE and permanently delete all these questions and references. This action is irreversible!',
                style: const TextStyle(color: Color(0xFF7A1C1C), fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Type "DELETE" to confirm cascade delete:'),
            const SizedBox(height: 8),
            TextField(
              controller: _confirmationController,
              enabled: !_isDeleting,
              decoration: const InputDecoration(
                hintText: 'DELETE',
                border: OutlineInputBorder(),
              ),
            ),
          ] else ...[
            const Text('This chapter is empty and has no linked questions. Deleting it is safe.'),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isDeleting ? null : () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: Color(0xFF75859D))),
        ),
        ElevatedButton(
          onPressed: _isDeleting
              ? null
              : () async {
                  if (hasLinkedQuestions && _confirmationController.text.trim() != 'DELETE') {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please type "DELETE" to confirm'), backgroundColor: AppColors.error),
                    );
                    return;
                  }

                  setState(() => _isDeleting = true);
                  try {
                    await _apiService.deleteChapter(widget.chapterId);
                    if (mounted) {
                      Navigator.pop(context);
                      widget.onDeleted();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Chapter deleted successfully.'),
                          backgroundColor: AppColors.success,
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      setState(() => _isDeleting = false);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error deleting chapter: $e'),
                          backgroundColor: AppColors.error,
                        ),
                      );
                    }
                  }
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.error,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: _isDeleting
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Delete'),
        ),
      ],
    );
  }
}

