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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadQuestions();
    });
  }

  void _loadQuestions() {
    Provider.of<QuestionProvider>(context, listen: false).loadQuestions(
      classNo: _filterClass,
      language: _filterLanguage,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FB),
      appBar: AppBar(
        title: const Text('Question Bank'),
        actions: [
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
                  return const Center(child: CircularProgressIndicator());
                }
                if (provider.loadState == QuestionLoadState.error) {
                  return Center(child: Text(provider.error ?? 'Error loading questions'));
                }
                if (provider.questions.isEmpty) {
                  return const Center(child: Text('No questions found matching filters.'));
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: provider.questions.length,
                  itemBuilder: (context, index) {
                    return _QuestionCard(question: provider.questions[index]);
                  },
                );
              },
            ),
          ),
        ],
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
  const _QuestionCard({required this.question});

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
          // Header info
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                _badge('Class ${question.classNo}', const Color(0xFFE0F7FA), const Color(0xFF006064)),
                const SizedBox(width: 8),
                _badge(question.language, const Color(0xFFF3E5F5), const Color(0xFF4A148C)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 20, color: Colors.blue),
                  onPressed: () => _editQuestion(context),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                  onPressed: () => _confirmDelete(context),
                ),
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
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Text('${String.fromCharCode(65 + i)}) ', style: const TextStyle(fontWeight: FontWeight.bold)),
                        Expanded(child: Text(question.options[i])),
                        if (isCorrect) const Icon(Icons.check_circle, color: Colors.green, size: 16),
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
      builder: (context) => AlertDialog(
        title: const Text('Delete Question?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Provider.of<QuestionProvider>(context, listen: false).deleteQuestion(question.id!);
              Navigator.pop(context);
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
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Question'),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('SAVE', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
             TextFormField(
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
                    onChanged: (v) => setState(() {
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
                    onChanged: (v) => setState(() => _selectedLanguage = v!),
                    items: ['English', 'Bengali', 'Both'].map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
                    decoration: const InputDecoration(labelText: 'Language'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedChapter,
              onChanged: (v) => setState(() => _selectedChapter = v),
              items: chapters.map((ch) => DropdownMenuItem(value: ch, child: Text(ch))).toList(),
              decoration: const InputDecoration(labelText: 'Chapter'),
            ),
            const SizedBox(height: 24),
            ...List.generate(4, (i) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: TextFormField(
                controller: _optCtrls[i],
                decoration: InputDecoration(labelText: 'Option ${String.fromCharCode(65 + i)}'),
              ),
            )),
            const SizedBox(height: 12),
            TextFormField(
              controller: _correctCtrl,
              decoration: const InputDecoration(labelText: 'Correct Answer (Exact Text)'),
            ),
          ],
        ),
      ),
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
