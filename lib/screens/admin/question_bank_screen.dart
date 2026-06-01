import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/question_provider.dart';
import '../../models/question_model.dart';
import '../../utils/constants.dart';
import '../shared/latex_widget.dart';
import '../../services/image_service.dart';
import 'package:image_picker/image_picker.dart';

class QuestionBankScreen extends StatefulWidget {
  const QuestionBankScreen({super.key});

  @override
  State<QuestionBankScreen> createState() => _QuestionBankScreenState();
}

class _QuestionBankScreenState extends State<QuestionBankScreen> {
  int? _filterClass;
  String? _filterLanguage;
  String? _filterChapter;
  bool _isSelectionMode = false;
  final Set<String> _selectedQuestionIds = {};

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadQuestions();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      final provider = Provider.of<QuestionProvider>(context, listen: false);
      provider.loadMoreQuestions(classNo: _filterClass, language: _filterLanguage);
    }
  }

  void _loadQuestions() {
    Provider.of<QuestionProvider>(context, listen: false).loadQuestions(
      classNo: _filterClass,
      language: _filterLanguage,
    );
  }

  Future<void> _bulkDelete(BuildContext context) async {
    final ids = _selectedQuestionIds.toList();
    if (ids.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Bulk Delete', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to permanently delete these ${ids.length} question(s) from the database? This is irreversible.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(20.0),
            child: CircularProgressIndicator(color: Color(0xFF0051D5)),
          ),
        ),
      ),
    );

    final provider = Provider.of<QuestionProvider>(context, listen: false);
    final success = await provider.bulkDeleteQuestions(ids);

    if (context.mounted) Navigator.pop(context); // Close loading dialog

    if (success) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully deleted ${ids.length} question(s)'),
            backgroundColor: Colors.green,
          ),
        );
      }
      setState(() {
        _isSelectionMode = false;
        _selectedQuestionIds.clear();
      });
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Some questions could not be deleted. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: _isSelectionMode ? const Color(0xFF0051D5) : Colors.transparent,
        leading: _isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () {
                  setState(() {
                    _isSelectionMode = false;
                    _selectedQuestionIds.clear();
                  });
                },
              )
            : (Navigator.canPop(context)
                ? IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF0F172A), size: 20),
                    onPressed: () => Navigator.pop(context),
                  )
                : null),
        title: _isSelectionMode
            ? Text('${_selectedQuestionIds.length} Selected', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))
            : const Text('Question Bank', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w800, fontSize: 22, letterSpacing: -0.5)),
        actions: _isSelectionMode
            ? [
                IconButton(
                  icon: const Icon(Icons.select_all, color: Colors.white),
                  tooltip: 'Select All',
                  onPressed: () {
                    final provider = Provider.of<QuestionProvider>(context, listen: false);
                    final visibleIds = provider.questions.map((q) => q.id!).toList();
                    setState(() {
                      final allSelected = visibleIds.every((id) => _selectedQuestionIds.contains(id));
                      if (allSelected) {
                        _selectedQuestionIds.removeAll(visibleIds);
                        _isSelectionMode = false;
                      } else {
                        _selectedQuestionIds.addAll(visibleIds);
                      }
                    });
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.white),
                  tooltip: 'Delete Selected',
                  onPressed: () => _bulkDelete(context),
                ),
              ]
            : [
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadQuestions,
                ),
              ],
      ),
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(
            child: Consumer<QuestionProvider>(
              builder: (context, provider, _) {
                if (provider.loadState == QuestionLoadState.loading) {
                  return const _SkeletonLoaderList();
                }
                if (provider.loadState == QuestionLoadState.error) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Text(
                        provider.error ?? 'Error loading questions',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                      ),
                    ),
                  );
                }
                if (provider.questions.isEmpty) {
                  return _buildEmptyState();
                }

                return RefreshIndicator(
                  color: const Color(0xFF0051D5),
                  onRefresh: () async {
                    _loadQuestions();
                  },
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: provider.questions.length + (provider.hasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == provider.questions.length) {
                        return const Padding(
                          padding: EdgeInsets.only(top: 8.0),
                          child: _PulsingShimmer(
                            child: Column(
                              children: [
                                _SkeletonQuestionCard(),
                                _SkeletonQuestionCard(),
                              ],
                            ),
                          ),
                        );
                      }
                      final q = provider.questions[index];
                      return GestureDetector(
                        onLongPress: () {
                          setState(() {
                            _isSelectionMode = true;
                            _selectedQuestionIds.add(q.id!);
                          });
                        },
                        onTap: () {
                          if (_isSelectionMode) {
                            setState(() {
                              if (_selectedQuestionIds.contains(q.id!)) {
                                _selectedQuestionIds.remove(q.id!);
                                if (_selectedQuestionIds.isEmpty) {
                                  _isSelectionMode = false;
                                }
                              } else {
                                _selectedQuestionIds.add(q.id!);
                              }
                            });
                          }
                        },
                        child: _QuestionCard(
                          question: q,
                          isSelectionMode: _isSelectionMode,
                          isSelected: _selectedQuestionIds.contains(q.id!),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
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
                Icons.quiz_outlined,
                size: 64,
                color: Color(0xFF0051D5),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No Questions Found',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'There are no questions matching your selected filters. Try changing your class or language criteria, or clear filters to view all questions.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF64748B),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _filterClass = null;
                  _filterLanguage = null;
                  _filterChapter = null;
                });
                _loadQuestions();
              },
              icon: const Icon(Icons.filter_alt_off_outlined),
              label: const Text('Clear Filters'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0051D5),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.white,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _filterChip<int>(
              label: _filterClass == null ? 'All Classes' : 'Class $_filterClass',
              onTap: _showClassPicker,
            ),
            const SizedBox(width: 8),
            _filterChip<String>(
              label: _filterLanguage ?? 'All Languages',
              onTap: _showLanguagePicker,
            ),
            const SizedBox(width: 8),
            if (_filterClass != null)
              _filterChip<String>(
                label: _filterChapter ?? 'All Chapters',
                onTap: _showChapterPicker,
              ),
          ],
        ),
      ),
    );
  }

  Widget _filterChip<T>({required String label, required VoidCallback onTap}) {
    return ActionChip(
      label: Text(label),
      onPressed: onTap,
      backgroundColor: const Color(0xFFE0F7FA),
      labelStyle: const TextStyle(color: Color(0xFF006064), fontWeight: FontWeight.bold),
    );
  }

  void _showClassPicker() {
    showModalBottomSheet(
      context: context,
      builder: (context) => ListView(
        shrinkWrap: true,
        children: [
          ListTile(title: const Text('All Classes'), onTap: () => _updateFilter(null, null, null)),
          ...[9, 10, 11, 12].map((c) => ListTile(
            title: Text('Class $c'),
            onTap: () => _updateFilter(c, null, null),
          )),
        ],
      ),
    );
  }

  void _showLanguagePicker() {
    showModalBottomSheet(
      context: context,
      builder: (context) => ListView(
        shrinkWrap: true,
        children: [
          ListTile(title: const Text('All Languages'), onTap: () => _updateFilter(_filterClass, null, _filterChapter)),
          ...['English', 'Bengali', 'Both'].map((l) => ListTile(
            title: Text(l),
            onTap: () => _updateFilter(_filterClass, l, _filterChapter),
          )),
        ],
      ),
    );
  }

  void _showChapterPicker() {
    final chapters = AppConstants.classChapters[_filterClass] ?? [];
    showModalBottomSheet(
      context: context,
      builder: (context) => ListView(
        shrinkWrap: true,
        children: [
          ListTile(title: const Text('All Chapters'), onTap: () => _updateFilter(_filterClass, _filterLanguage, null)),
          ...chapters.map((ch) => ListTile(
            title: Text(ch),
            onTap: () => _updateFilter(_filterClass, _filterLanguage, ch),
          )),
        ],
      ),
    );
  }

  void _updateFilter(int? c, String? l, String? ch) {
    setState(() {
      _filterClass = c;
      _filterLanguage = l;
      _filterChapter = ch;
    });
    Navigator.pop(context);
    _loadQuestions();
  }
}

class _QuestionCard extends StatelessWidget {
  final Question question;
  final bool isSelectionMode;
  final bool isSelected;

  const _QuestionCard({
    required this.question,
    required this.isSelectionMode,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFFF0F5FF) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? const Color(0xFF0051D5) : Colors.grey.shade200,
          width: isSelected ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header info
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                if (isSelectionMode) ...[
                  Checkbox(
                    value: isSelected,
                    activeColor: const Color(0xFF0051D5),
                    onChanged: (_) {}, // Handled by GestureDetector at parent level
                  ),
                  const SizedBox(width: 8),
                ],
                _badge('Class ${question.classNo}', const Color(0xFFE0F7FA), const Color(0xFF006064)),
                const SizedBox(width: 8),
                _badge(question.language, const Color(0xFFF3E5F5), const Color(0xFF4A148C)),
                const Spacer(),
                if (!isSelectionMode) ...[
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 20, color: Colors.blue),
                    onPressed: () => _editQuestion(context),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                    onPressed: () => _confirmDelete(context),
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1),
          // Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Chapter: ${question.chapter}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                LaTeXWidget(text: question.questionText),
                if (question.diagram != null) ...[
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      question.diagram!,
                      height: 120,
                      width: double.infinity,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                const Text('Options:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 8),
                ...List.generate(question.options.length, (i) {
                  final isCorrect = question.options[i] == question.correctAnswer;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isCorrect
                          ? const Color(0xFFE8F5E9)
                          : const Color(0xFFF8F9FA),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isCorrect
                            ? const Color(0xFF43A047)
                            : Colors.grey.shade200,
                        width: isCorrect ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${String.fromCharCode(65 + i)}) ',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isCorrect
                                ? const Color(0xFF2E7D32)
                                : const Color(0xFF0F172A),
                          ),
                        ),
                        Expanded(child: LaTeXWidget(text: question.options[i])),
                        if (isCorrect)
                          const Padding(
                            padding: EdgeInsets.only(left: 6, top: 2),
                            child: Icon(Icons.check_circle, color: Color(0xFF43A047), size: 16),
                          ),
                      ],
                    ),
                  );
                }),

              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _badge(String label, Color bg, Color text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: TextStyle(color: text, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  void _editQuestion(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _EditQuestionSheet(question: question),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Question?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext); // close confirmation dialog
              
              // show loading dialog
              BuildContext? loadingContext;
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (ctx) {
                  loadingContext = ctx;
                  return const Center(child: CircularProgressIndicator());
                },
              );

              final success = await Provider.of<QuestionProvider>(context, listen: false).deleteQuestion(question.id!);
              
              if (loadingContext != null && loadingContext!.mounted) {
                Navigator.pop(loadingContext!); // close loading dialog
              }

              if (context.mounted) {
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Question deleted successfully.')),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Failed to delete question.')),
                  );
                }
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _EditQuestionSheet extends StatefulWidget {
  final Question question;
  const _EditQuestionSheet({required this.question});

  @override
  State<_EditQuestionSheet> createState() => _EditQuestionSheetState();
}

class _EditQuestionSheetState extends State<_EditQuestionSheet> {
  late TextEditingController _questionCtrl;
  late List<TextEditingController> _optCtrls;
  late TextEditingController _correctCtrl;
  late int _selectedClass;
  late String _selectedLanguage;
  String? _selectedChapter;
  File? _newDiagramFile;

  @override
  void initState() {
    super.initState();
    _questionCtrl = TextEditingController(text: widget.question.questionText);
    _optCtrls = widget.question.options.map((o) => TextEditingController(text: o)).toList();
    // Pad to 4 options if needed
    while (_optCtrls.length < 4) {
      _optCtrls.add(TextEditingController());
    }
    _correctCtrl = TextEditingController(text: widget.question.correctAnswer);
    _selectedClass = widget.question.classNo;
    _selectedLanguage = widget.question.language;
    _selectedChapter = widget.question.chapter;
  }

  @override
  Widget build(BuildContext context) {
    final chapters = AppConstants.classChapters[_selectedClass] ?? [];
    
    return Consumer<QuestionProvider>(
      builder: (context, provider, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Edit Question'),
            actions: [
              provider.isSaving
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16.0),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        ),
                      ),
                    )
                  : TextButton(
                      onPressed: _save,
                      child: const Text('SAVE', style: TextStyle(color: Colors.white)),
                    ),
            ],
          ),
          body: Column(
            children: [
              if (provider.isSaving) const LinearProgressIndicator(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      TextFormField(
                        enabled: !provider.isSaving,
                        controller: _questionCtrl,
                        maxLines: 5,
                        decoration: const InputDecoration(labelText: 'Question Text', border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              value: _selectedClass,
                              onChanged: provider.isSaving ? null : (v) => setState(() {
                                _selectedClass = v!;
                                _selectedChapter = AppConstants.classChapters[v]?.first;
                              }),
                              items: [9,10,11,12].map((c) => DropdownMenuItem(value: c, child: Text('Class $c'))).toList(),
                              decoration: const InputDecoration(labelText: 'Class'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _selectedLanguage,
                              onChanged: provider.isSaving ? null : (v) => setState(() => _selectedLanguage = v!),
                              items: ['English', 'Bengali', 'Both'].map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
                              decoration: const InputDecoration(labelText: 'Language'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _selectedChapter,
                        onChanged: provider.isSaving ? null : (v) => setState(() => _selectedChapter = v),
                        items: chapters.map((ch) => DropdownMenuItem(value: ch, child: Text(ch))).toList(),
                        decoration: const InputDecoration(labelText: 'Chapter'),
                      ),
                      const SizedBox(height: 24),
                      ...List.generate(4, (i) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: TextFormField(
                          enabled: !provider.isSaving,
                          controller: _optCtrls[i],
                          decoration: InputDecoration(labelText: 'Option ${String.fromCharCode(65 + i)}'),
                        ),
                      )),
                      const SizedBox(height: 12),
                      TextFormField(
                        enabled: !provider.isSaving,
                        controller: _correctCtrl,
                        decoration: const InputDecoration(labelText: 'Correct Answer (Exact Text)'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _save() async {
    final provider = Provider.of<QuestionProvider>(context, listen: false);
    final data = {
      'question': _questionCtrl.text.trim(),
      'classNo': _selectedClass,
      'language': _selectedLanguage,
      'chapter': _selectedChapter,
      'options': _optCtrls.map((c) => c.text.trim()).toList(),
      'correctAnswer': _correctCtrl.text.trim(),
    };

    final success = await provider.updateQuestion(widget.question.id!, data);
    if (success && mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Question updated!')));
    }
  }
}

class _PulsingShimmer extends StatefulWidget {
  final Widget child;
  const _PulsingShimmer({required this.child});

  @override
  State<_PulsingShimmer> createState() => _PulsingShimmerState();
}

class _PulsingShimmerState extends State<_PulsingShimmer> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.35, end: 0.85).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Opacity(
          opacity: _animation.value,
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class _SkeletonLoaderList extends StatelessWidget {
  const _SkeletonLoaderList();

  @override
  Widget build(BuildContext context) {
    return _PulsingShimmer(
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 3,
        itemBuilder: (context, index) => const _SkeletonQuestionCard(),
      ),
    );
  }
}

class _SkeletonQuestionCard extends StatelessWidget {
  const _SkeletonQuestionCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header info skeleton
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                _skeletonBox(width: 60, height: 20, borderRadius: 6),
                const SizedBox(width: 8),
                _skeletonBox(width: 80, height: 20, borderRadius: 6),
                const Spacer(),
                _skeletonBox(width: 24, height: 24, borderRadius: 12),
                const SizedBox(width: 8),
                _skeletonBox(width: 24, height: 24, borderRadius: 12),
              ],
            ),
          ),
          const Divider(height: 1),
          // Content skeleton
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _skeletonBox(width: 120, height: 14),
                const SizedBox(height: 16),
                _skeletonBox(width: double.infinity, height: 16),
                const SizedBox(height: 8),
                _skeletonBox(width: double.infinity, height: 16),
                const SizedBox(height: 8),
                _skeletonBox(width: 200, height: 16),
                const SizedBox(height: 24),
                const Text('Options:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
                const SizedBox(height: 12),
                ...List.generate(4, (i) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      _skeletonBox(width: 24, height: 24, borderRadius: 12),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _skeletonBox(width: double.infinity, height: 20, borderRadius: 8),
                      ),
                    ],
                  ),
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _skeletonBox({required double width, required double height, double borderRadius = 4}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}
