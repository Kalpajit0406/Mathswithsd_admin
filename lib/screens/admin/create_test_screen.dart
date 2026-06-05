import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/admin_provider.dart';
import '../../providers/question_provider.dart';
import '../../utils/constants.dart';

class CreateTestScreen extends StatefulWidget {
  const CreateTestScreen({super.key});

  @override
  State<CreateTestScreen> createState() => _CreateTestScreenState();
}

class _CreateTestScreenState extends State<CreateTestScreen> {
  String _selectedDate = '';
  String _selectedTime = '';
  String _selectedClass = '10';
  String _selectedMedium = 'English';
  String _selectedQuestions = '20';
  String _totalTime = '30';

  // Advanced Config
  double _negativeMarking = 0.0;
  double _marksPerQuestion = 1.0;
  List<String> _selectedChapters = [];

  final _classes = ['9', '10', '11', '12', '13'];
  final _mediums = ['Bengali', 'English', 'Both'];
  final _questionOptions = ['10', '20', '30', '40', '50', '80', '100'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<QuestionProvider>(context, listen: false).syncChapters();
      _checkAndLoadDraft();
    });
  }

  Future<void> _saveDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('test_draft_date', _selectedDate);
      await prefs.setString('test_draft_time', _selectedTime);
      await prefs.setString('test_draft_class', _selectedClass);
      await prefs.setString('test_draft_medium', _selectedMedium);
      await prefs.setString('test_draft_questions', _selectedQuestions);
      await prefs.setString('test_draft_duration', _totalTime);
      await prefs.setDouble('test_draft_negative_marking', _negativeMarking);
      await prefs.setDouble('test_draft_marks_per_question', _marksPerQuestion);
      await prefs.setStringList('test_draft_chapters', _selectedChapters);
    } catch (e) {
      debugPrint('Failed to save test draft: $e');
    }
  }

  Future<void> _clearDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('test_draft_date');
      await prefs.remove('test_draft_time');
      await prefs.remove('test_draft_class');
      await prefs.remove('test_draft_medium');
      await prefs.remove('test_draft_questions');
      await prefs.remove('test_draft_duration');
      await prefs.remove('test_draft_negative_marking');
      await prefs.remove('test_draft_marks_per_question');
      await prefs.remove('test_draft_chapters');
    } catch (e) {
      debugPrint('Failed to clear test draft: $e');
    }
  }

  Future<void> _checkAndLoadDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hasDraft =
          prefs.containsKey('test_draft_date') ||
          prefs.containsKey('test_draft_chapters');
      if (!hasDraft) return;

      final date = prefs.getString('test_draft_date') ?? '';
      final time = prefs.getString('test_draft_time') ?? '';
      final classNo = prefs.getString('test_draft_class') ?? '10';
      final medium = prefs.getString('test_draft_medium') ?? 'English';
      final questions = prefs.getString('test_draft_questions') ?? '20';
      final duration = prefs.getString('test_draft_duration') ?? '30';
      final negativeMarking =
          prefs.getDouble('test_draft_negative_marking') ?? 0.0;
      final marksPerQuestion =
          prefs.getDouble('test_draft_marks_per_question') ?? 1.0;
      final chapters = prefs.getStringList('test_draft_chapters') ?? [];

      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Resume Draft?',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: const Text(
            'You have an unsaved draft from a previous session. Would you like to resume editing?',
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await _clearDraft();
                if (mounted) Navigator.pop(context);
              },
              child: const Text('Discard', style: TextStyle(color: Colors.red)),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _selectedDate = date;
                  _selectedTime = time;
                  _selectedClass = classNo;
                  _selectedMedium = medium;
                  _selectedQuestions = questions;
                  _totalTime = duration;
                  _negativeMarking = negativeMarking;
                  _marksPerQuestion = marksPerQuestion;
                  _selectedChapters = List<String>.from(chapters);
                });
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0051D5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Resume',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      debugPrint('Failed to check and load draft: $e');
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: Color(0xFF0051D5)),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _selectedDate =
            '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';
      });
      _saveDraft();
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: Color(0xFF0051D5)),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      final h = picked.hourOfPeriod.toString().padLeft(2, '0');
      final m = picked.minute.toString().padLeft(2, '0');
      final period = picked.period == DayPeriod.am ? 'AM' : 'PM';
      setState(() => _selectedTime = '$h:$m $period');
      _saveDraft();
    }
  }

  void _toggleChapter(String ch) {
    setState(() {
      if (_selectedChapters.contains(ch)) {
        _selectedChapters.remove(ch);
      } else {
        _selectedChapters.add(ch);
      }
    });
    _saveDraft();
  }

  Future<void> _publishTest() async {
    if (_selectedDate.isEmpty) {
      _showSnack('Please select a date');
      return;
    }
    if (_selectedTime.isEmpty) {
      _showSnack('Please select a time');
      return;
    }
    if (_selectedChapters.isEmpty) {
      _showSnack('Please select at least one chapter');
      return;
    }
    final duration = int.tryParse(_totalTime) ?? 0;
    if (duration <= 0) {
      _showSnack('Please enter a valid duration greater than 0');
      return;
    }
    final qCount = int.tryParse(_selectedQuestions) ?? 0;
    if (qCount <= 0) {
      _showSnack('Please select a valid question count');
      return;
    }
    if (_marksPerQuestion <= 0) {
      _showSnack('Marks per question must be greater than 0');
      return;
    }

    final provider = Provider.of<AdminProvider>(context, listen: false);
    final success = await provider.createTest(
      date: _selectedDate,
      time: _selectedTime,
      classNo: int.parse(_selectedClass),
      language: _selectedMedium,
      totalQuestions: int.parse(_selectedQuestions),
      totalTime: int.tryParse(_totalTime) ?? 30,
      negativeMarking: _negativeMarking,
      marksPerQuestion: _marksPerQuestion,
      chapters: _selectedChapters,
    );

    if (!mounted) return;
    if (success) {
      await _clearDraft();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Test published successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } else {
      _showSnack(provider.createTestError ?? 'Failed to create test');
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final questionProvider = Provider.of<QuestionProvider>(context);
    final chapters = List<String>.from(questionProvider.getChaptersForClass(int.parse(_selectedClass)));
    if (chapters.isEmpty) {
      chapters.addAll(AppConstants.classChapters[int.parse(_selectedClass)] ?? []);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FB),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Color(0xFF0F172A),
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'New Assessment',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w800,
            fontSize: 22,
            letterSpacing: -0.5,
          ),
        ),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionCard('Schedule', [
              Row(
                children: [
                  Expanded(
                    child: _dateTimeCard(
                      label: 'Date',
                      value: _selectedDate.isEmpty
                          ? 'Select Date'
                          : _selectedDate,
                      icon: Icons.calendar_today,
                      onTap: _pickDate,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _dateTimeCard(
                      label: 'Time',
                      value: _selectedTime.isEmpty
                          ? 'Select Time'
                          : _selectedTime,
                      icon: Icons.schedule,
                      onTap: _pickTime,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildTextField(
                label: 'Duration (Minutes)',
                initialValue: _totalTime,
                onChanged: (v) {
                  _totalTime = v;
                  _saveDraft();
                },
                icon: Icons.timer_outlined,
              ),
            ]),
            const SizedBox(height: 20),

            _sectionCard('Target & Language', [
              _buildDropdown(
                'Target Class',
                _selectedClass,
                _classes
                    .map((c) => c == '13' ? 'Joint Entrance' : 'Class $c')
                    .toList(),
                _classes,
                (val) => setState(() {
                  _selectedClass = val!;
                  _selectedChapters.clear();
                  _saveDraft();
                }),
                Icons.class_,
              ),
              const SizedBox(height: 16),
              _buildDropdown(
                'Language',
                _selectedMedium,
                _mediums,
                _mediums,
                (val) => setState(() {
                  _selectedMedium = val!;
                  _saveDraft();
                }),
                Icons.translate,
              ),
            ]),
            const SizedBox(height: 20),

            _sectionCard('Grading & Scope', [
              _buildDropdown(
                'Questions Count',
                _selectedQuestions,
                _questionOptions,
                _questionOptions,
                (val) => setState(() {
                  _selectedQuestions = val!;
                  _saveDraft();
                }),
                Icons.help_outline,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      label: 'Marks/Q',
                      initialValue: _marksPerQuestion.toString(),
                      onChanged: (v) {
                        _marksPerQuestion = double.tryParse(v) ?? 1.0;
                        _saveDraft();
                      },
                      icon: Icons.add_circle_outline,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTextField(
                      label: 'Negative/Q',
                      initialValue: _negativeMarking.toString(),
                      onChanged: (v) {
                        _negativeMarking = double.tryParse(v) ?? 0.0;
                        _saveDraft();
                      },
                      icon: Icons.remove_circle_outline,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text(
                'Select Chapters',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 0,
                children: chapters.map((ch) {
                  final isSelected = _selectedChapters.contains(ch);
                  return FilterChip(
                    label: Text(
                      ch,
                      style: TextStyle(
                        fontSize: 11,
                        color: isSelected ? Colors.white : Colors.black87,
                      ),
                    ),
                    selected: isSelected,
                    onSelected: (_) => _toggleChapter(ch),
                    selectedColor: const Color(0xFF0051D5),
                    checkmarkColor: Colors.white,
                  );
                }).toList(),
              ),
            ]),
            const SizedBox(height: 32),

            Consumer<AdminProvider>(
              builder: (context, provider, _) => SizedBox(
                width: double.infinity,
                height: 56,
                child: provider.isCreatingTest
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton(
                        onPressed: _publishTest,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0051D5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Publish Assessment',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _sectionCard(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0051D5),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE0E3E5)),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _dateTimeCard({
    required String label,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF0F4FF),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: const Color(0xFF0051D5), size: 16),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF0051D5),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required String initialValue,
    required ValueChanged<String> onChanged,
    required IconData icon,
  }) {
    return TextFormField(
      initialValue: initialValue,
      keyboardType: TextInputType.number,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
      ),
    );
  }

  Widget _buildDropdown(
    String label,
    String value,
    List<String> displayOptions,
    List<String> values,
    ValueChanged<String?> onChanged,
    IconData icon,
  ) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      items: List.generate(
        values.length,
        (i) =>
            DropdownMenuItem(value: values[i], child: Text(displayOptions[i])),
      ),
    );
  }
}
