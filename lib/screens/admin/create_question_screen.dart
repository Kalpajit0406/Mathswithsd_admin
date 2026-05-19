import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../providers/question_provider.dart';
import '../../models/question_model.dart';
import '../../services/image_service.dart';
import '../../utils/constants.dart';
import '../../utils/latex_converter.dart';
import '../shared/katex_widget.dart';
import '../../widgets/animations.dart';

class CreateQuestionTab extends StatefulWidget {
  const CreateQuestionTab({super.key});

  @override
  State<CreateQuestionTab> createState() => _CreateQuestionTabState();
}

class _CreateQuestionTabState extends State<CreateQuestionTab> {
  // ... rest of the implementation

  // Form Controllers
  final _questionCtrl = TextEditingController();
  final List<TextEditingController> _optCtrls = List.generate(4, (_) => TextEditingController());
  final _correctCtrl = TextEditingController();

  // Selection state
  int _selectedClass = 9;
  String _selectedLanguage = 'English';
  String? _selectedChapter;
  File? _diagramFile;
  bool _useKaTeXPreview = true;

  final _imageService = ImageService();

  @override
  void initState() {
    super.initState();
    _selectedChapter = AppConstants.classChapters[_selectedClass]?.first;
    _handleLostData();
    
    // Auto-sync when queue changes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncFromQueue();
    });
  }

  Future<void> _handleLostData() async {
    final lostFile = await _imageService.getLostData();
    if (lostFile != null && mounted) {
      _processScannedFile(File(lostFile.path));
    }
  }

  void _syncFromQueue() {
    final provider = Provider.of<QuestionProvider>(context, listen: false);
    if (provider.questionQueue.isNotEmpty) {
      final scan = provider.questionQueue.first;
      _questionCtrl.text = scan.questionText;
      for (int i = 0; i < 4; i++) {
        if (scan.options.length > i) {
          _optCtrls[i].text = scan.options[i];
        } else {
          _optCtrls[i].clear();
        }
      }
      if (scan.correctAnswer != null) _correctCtrl.text = scan.correctAnswer!;
      setState(() {});
    }
  }

  void _clearForm() {
    _questionCtrl.clear();
    for (var ctrl in _optCtrls) {
      ctrl.clear();
    }
    _correctCtrl.clear();
    setState(() {
      _diagramFile = null;
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    // Check permissions
    if (source == ImageSource.camera) {
      final status = await Permission.camera.request();
      if (status.isPermanentlyDenied) {
        _showPermissionDialog('Camera');
        return;
      }
      if (!status.isGranted) return;
    } else {
      PermissionStatus status;
      if (Platform.isAndroid) {
        // Safe permissions checking across all Android versions (Android 13+ vs older)
        int sdkInt = 0;
        try {
          final apiMatch = RegExp(r'API\s+(\d+)').firstMatch(Platform.operatingSystemVersion);
          if (apiMatch != null) {
            sdkInt = int.parse(apiMatch.group(1)!);
          } else {
            final androidMatch = RegExp(r'Android\s+(\d+)').firstMatch(Platform.operatingSystemVersion);
            if (androidMatch != null) {
              final ver = int.parse(androidMatch.group(1)!);
              if (ver >= 13) sdkInt = 33;
            }
          }
        } catch (_) {}

        if (sdkInt >= 33) {
          status = await Permission.photos.request();
        } else {
          status = await Permission.storage.request();
        }
      } else {
        status = await Permission.photos.request();
      }
      if (status.isPermanentlyDenied) {
        _showPermissionDialog('Gallery');
        return;
      }
      if (!status.isGranted) return;
    }

    try {
      final file = await _imageService.pickAndCropImage(context, source: source);
      if (!mounted || file == null) return;
      _processScannedFile(file);
    } catch (e) {
      if (mounted) {
        _showSnack('Image selection failed: $e');
      }
    }
  }

  void _showPermissionDialog(String type) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$type Permission Required'),
        content: Text('Please enable $type access in settings to scan questions.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(onPressed: () => openAppSettings(), child: const Text('Open Settings')),
        ],
      ),
    );
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _processScannedFile(File file) async {
    final provider = Provider.of<QuestionProvider>(context, listen: false);
    await provider.scanImage(file);

    if (!mounted) return;
    if (provider.creationError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.creationError!),
          backgroundColor: const Color(0xFFBA1A1A),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } else if (provider.questionQueue.isNotEmpty) {
      _syncFromQueue();
    }
  }

  Future<void> _pickDiagram() async {
    final file = await _imageService.pickAndCropImage(context, source: ImageSource.gallery);
    if (file != null) {
      setState(() => _diagramFile = file);
    }
  }

  Future<void> _saveQuestion() async {
    if (_questionCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Question text is required'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    final provider = Provider.of<QuestionProvider>(context, listen: false);
    final q = Question(
      questionText: _questionCtrl.text.trim(),
      options: _optCtrls.map((c) => c.text.trim()).toList(),
      correctAnswer: _correctCtrl.text.trim(),
      classNo: _selectedClass,
      language: _selectedLanguage,
      chapter: _selectedChapter ?? '',
    );

    final success = await provider.saveQuestion(q, diagramFile: _diagramFile);
    if (!mounted) return;

    if (success) {
      _clearForm();
      if (provider.questionQueue.isNotEmpty) {
        provider.popQuestionFromQueue();
        _syncFromQueue();
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Question saved successfully!'),
          backgroundColor: const Color(0xFF4CAF50),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.creationError ?? 'Failed to save'),
          backgroundColor: const Color(0xFFBA1A1A),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  @override
  void dispose() {
    _questionCtrl.dispose();
    for (var c in _optCtrls) {
      c.dispose();
    }
    _correctCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<QuestionProvider>(
      builder: (context, provider, _) {
        final chapters = AppConstants.classChapters[_selectedClass] ?? [];
        final bool hasQueue = provider.questionQueue.isNotEmpty;

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FadeInSlide(
                duration: const Duration(milliseconds: 500),
                child: _buildHeader(provider),
              ),
              const SizedBox(height: 24),
              
              if (!hasQueue && !provider.isScanning) 
                FadeInSlide(
                  duration: const Duration(milliseconds: 550),
                  delay: const Duration(milliseconds: 100),
                  child: _buildInitialScanView(),
                )
              else ...[
                FadeInSlide(
                  duration: const Duration(milliseconds: 500),
                  child: _buildQuestionQueueStatus(provider),
                ),
                const SizedBox(height: 24),
                
                FadeInSlide(
                  duration: const Duration(milliseconds: 550),
                  delay: const Duration(milliseconds: 100),
                  child: _buildFormSection('Question Content', [
                    _label('Question Text (KaTeX Preview)'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _questionCtrl,
                      minLines: 3,
                      maxLines: 8,
                      decoration: _inputDec('Type or scan question...'),
                      onChanged: (_) => setState(() {}),
                    ),
                    if (_questionCtrl.text.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _label('Live Preview'),
                          Row(
                            children: [
                              ChoiceChip(
                                label: const Text(
                                  'KaTeX Render',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                                selected: _useKaTeXPreview,
                                selectedColor: const Color(0x200051D5),
                                labelStyle: TextStyle(
                                  color: _useKaTeXPreview ? const Color(0xAA0051D5) : Colors.black54,
                                ),
                                onSelected: (selected) {
                                  if (selected) setState(() => _useKaTeXPreview = true);
                                },
                              ),
                              const SizedBox(width: 8),
                              ChoiceChip(
                                label: const Text(
                                  'Readable Text',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                                selected: !_useKaTeXPreview,
                                selectedColor: const Color(0x200051D5),
                                labelStyle: TextStyle(
                                  color: !_useKaTeXPreview ? const Color(0xAA0051D5) : Colors.black54,
                                ),
                                onSelected: (selected) {
                                  if (selected) setState(() => _useKaTeXPreview = false);
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _buildPreviewBox(
                        _useKaTeXPreview
                            ? KaTeXWidget(text: _questionCtrl.text)
                            : Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8F9FA),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Text(
                                  LatexToReadableConverter.convert(_questionCtrl.text),
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                    height: 1.5,
                                    color: Color(0xFF1E293B),
                                  ),
                                ),
                              ),
                      ),
                    ],
                  ]),
                ),
                
                const SizedBox(height: 20),
                FadeInSlide(
                  duration: const Duration(milliseconds: 550),
                  delay: const Duration(milliseconds: 150),
                  child: _buildFormSection('Diagram', [
                    _buildDiagramPicker(),
                  ]),
                ),

                const SizedBox(height: 20),
                FadeInSlide(
                  duration: const Duration(milliseconds: 550),
                  delay: const Duration(milliseconds: 200),
                  child: _buildFormSection('Options', [
                    for (int i = 0; i < 4; i++) ...[
                      _label('Option ${String.fromCharCode(65 + i)}'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _optCtrls[i],
                        decoration: _inputDec('Enter option ${i+1}...'),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 12),
                    ],
                    _label('Correct Answer'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _correctCtrl,
                      decoration: _inputDec('Exact text of correct option'),
                    ),
                  ]),
                ),

                const SizedBox(height: 20),
                FadeInSlide(
                  duration: const Duration(milliseconds: 550),
                  delay: const Duration(milliseconds: 250),
                  child: _buildFormSection('Metadata', [
                     Row(
                      children: [
                        Expanded(
                          child: _buildDropdown<int>(
                            label: 'Class',
                            value: _selectedClass,
                            items: [9, 10, 11, 12].map((c) => DropdownMenuItem(value: c, child: Text('Class $c'))).toList(),
                            onChanged: (val) {
                              setState(() {
                                _selectedClass = val!;
                                _selectedChapter = AppConstants.classChapters[_selectedClass]?.first;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildDropdown<String>(
                            label: 'Language',
                            value: _selectedLanguage,
                            items: ['Bengali', 'English', 'Both'].map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
                            onChanged: (val) => setState(() => _selectedLanguage = val!),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildDropdown<String>(
                      label: 'Chapter',
                      value: _selectedChapter,
                      isExpanded: true,
                      items: chapters.map((ch) => DropdownMenuItem(value: ch, child: Text(ch, overflow: TextOverflow.ellipsis))).toList(),
                      onChanged: (val) => setState(() => _selectedChapter = val),
                    ),
                  ]),
                ),

                const SizedBox(height: 36),
                FadeInSlide(
                  duration: const Duration(milliseconds: 550),
                  delay: const Duration(milliseconds: 300),
                  child: _buildActionButtons(provider),
                ),
                const SizedBox(height: 40),
              ]
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(QuestionProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Create Question',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: Color(0xFF0F172A),
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          provider.isScanning ? 'Processing scanned image with AI OCR...' : 'Scan physical papers or input equations manually',
          style: const TextStyle(
            color: Color(0xFF75859D),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildInitialScanView() {
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 60),
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: const Color(0xFFECEEF0), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                )
              ],
            ),
            child: const Icon(Icons.document_scanner_outlined, size: 76, color: Color(0xFF0051D5)),
          ),
          const SizedBox(height: 28),
          const Text(
            'No Scan Loaded Yet',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 18,
              color: Color(0xFF0F172A),
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Scan or select an image to parse math symbols automatically.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF75859D),
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 36),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: BounceOnTap(
                  onTap: () => _pickImage(ImageSource.camera),
                  child: _scanActionCard('Camera Capture', Icons.camera_alt_rounded, const Color(0xFF0051D5)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: BounceOnTap(
                  onTap: () => _pickImage(ImageSource.gallery),
                  child: _scanActionCard('Choose Gallery', Icons.photo_library_rounded, const Color(0xFF316BF3)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _scanActionCard(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFECEEF0), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 14,
              color: Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionQueueStatus(QuestionProvider provider) {
    if (provider.questionQueue.length <= 1) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF0051D5).withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF0051D5).withOpacity(0.12), width: 1),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome_motion_rounded, color: Color(0xFF0051D5)),
          const SizedBox(width: 14),
          Text(
            'Batch Scan: ${provider.questionQueue.length} questions remaining in queue',
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: Color(0xFF0051D5),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 16,
            color: Color(0xFF0F172A),
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFECEEF0), width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildDiagramPicker() {
    return Column(
      children: [
        if (_diagramFile != null) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(_diagramFile!, height: 160, width: double.infinity, fit: BoxFit.contain),
          ),
          const SizedBox(height: 12),
        ],
        OutlinedButton.icon(
          onPressed: _pickDiagram,
          icon: Icon(_diagramFile == null ? Icons.add_photo_alternate_rounded : Icons.edit_rounded, size: 20),
          label: Text(_diagramFile == null ? 'Add Optional Diagram' : 'Replace Question Diagram'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 50),
            side: const BorderSide(color: Color(0xFFECEEF0), width: 1),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(QuestionProvider provider) {
    return Row(
      children: [
        if (provider.questionQueue.isNotEmpty)
          Expanded(
            child: OutlinedButton(
              onPressed: () => provider.clearQueue(),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: const BorderSide(color: Color(0xFFBA1A1A)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text(
                'Discard Queue',
                style: TextStyle(color: Color(0xFFBA1A1A), fontWeight: FontWeight.w800),
              ),
            ),
          ),
        if (provider.questionQueue.isNotEmpty) const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: ElevatedButton(
            onPressed: provider.isSaving ? null : _saveQuestion,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0051D5),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
            child: provider.isSaving
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text(
                    provider.questionQueue.length > 1 ? 'Save & Next Question' : 'Save Form Question',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewBox(Widget child) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFECEEF0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'LIVE LATEX RENDERED PREVIEW:',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF75859D), letterSpacing: 0.5),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  Widget _label(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFF75859D),
        fontWeight: FontWeight.w700,
        fontSize: 13,
      ),
    );
  }

  InputDecoration _inputDec(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: const Color(0xFFF7F9FB),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFECEEF0))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFECEEF0))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF0051D5), width: 1.5)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  Widget _buildDropdown<T>({required String label, required T? value, required List<DropdownMenuItem<T>> items, required ValueChanged<T?> onChanged, bool isExpanded = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(label),
        const SizedBox(height: 8),
        DropdownButtonFormField<T>(
          value: value,
          onChanged: onChanged,
          isExpanded: isExpanded,
          decoration: _inputDec(label),
          items: items,
        ),
      ],
    );
  }
}
