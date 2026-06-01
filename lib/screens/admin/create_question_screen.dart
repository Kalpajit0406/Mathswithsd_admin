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
import '../shared/latex_widget.dart';
import '../../widgets/animations.dart';
import '../../widgets/confidence_badge.dart';
import '../../widgets/question_queue_status_widget.dart';
import '../../widgets/pdf_picker_widget.dart';

class CreateQuestionTab extends StatefulWidget {
  /// Optional image file to process immediately after mounting (used by lost-data recovery)
  final File? initialScanFile;

  const CreateQuestionTab({super.key, this.initialScanFile});

  @override
  State<CreateQuestionTab> createState() => _CreateQuestionTabState();
}

class _CreateQuestionTabState extends State<CreateQuestionTab> {
  // ... rest of the implementation

  // Form Controllers
  final _questionCtrl = TextEditingController();
  final List<TextEditingController> _optCtrls = List.generate(
    4,
    (_) => TextEditingController(),
  );
  final _correctCtrl = TextEditingController();

  // Selection state
  int _selectedClass = 9;
  String _selectedLanguage = 'English';
  String? _selectedChapter;
  File? _diagramFile;
  File? _selectedGalleryFile;
  int? _selectedCorrectOptionIndex;
  bool _useLaTeXPreview = true;
  bool _isManualInput = false;
  bool _showPdfPicker = false;

  final _imageService = ImageService();
  QuestionProvider? _subscribedProvider;

  @override
  void initState() {
    super.initState();
    _selectedChapter = AppConstants.classChapters[_selectedClass]?.first;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<QuestionProvider>(context, listen: false);
      provider.restoreQueueState().then((_) {
        if (!mounted) return;
        _syncFromQueue();
      });

      // If AdminDashboard passed a file (lost-data recovery path), scan it now
      if (widget.initialScanFile != null) {
        _processScannedFile(widget.initialScanFile!);
      } else if (provider.questionQueue.isNotEmpty) {
        // Normal launch: sync if there's already something in the queue
        _syncFromQueue();
      }

      // Listen for future queue changes (e.g., triggered externally by AdminDashboard)
      _subscribedProvider = provider;
      _lastQueueLength = provider.questionQueue.length;
      _lastIsScanning = provider.isScanning;
      provider.addListener(_onProviderChange);
    });
  }

  int _lastQueueIndex = -1;
  int _lastQueueLength = 0;
  bool _lastIsScanning = false; // Corrected type to bool

  void _onProviderChange() {
    if (!mounted) return;
    final provider = Provider.of<QuestionProvider>(context, listen: false);

    // Detect when scanning just finished and queue has items
    final scanningJustFinished = _lastIsScanning && !provider.isScanning;
    final indexChanged = provider.currentQueueIndex != _lastQueueIndex;

    _lastIsScanning = provider.isScanning;
    _lastQueueIndex = provider.currentQueueIndex;

    if (scanningJustFinished && provider.isQueueActive) {
      _syncFromQueue();
      final current = provider.currentQueueItem;
      if (current?.confidence != null) {
        _showOCRConfidenceFeedback(current!.confidence!);
      }
    } else if (indexChanged && provider.isQueueActive) {
      _syncFromQueue();
    } else if (scanningJustFinished && provider.creationError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.creationError!),
          backgroundColor: const Color(0xFFBA1A1A),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  void _syncFromQueue() {
    final provider = Provider.of<QuestionProvider>(context, listen: false);
    final current = provider.currentQueueItem;

    if (current != null) {
      // Always reset correct-answer state first so stale selection never persists
      // across question navigation (Bug 3 fix).
      _correctCtrl.clear();

      // Wrap ALL field assignments in setState so the LaTeX preview widgets
      // re-render immediately and option radio buttons become selectable.
      setState(() {
        _questionCtrl.text = current.questionText;

        for (int i = 0; i < 4; i++) {
          _optCtrls[i].text = (current.options.length > i)
              ? current.options[i]
              : '';
        }

        // Re-compute correct-answer checkbox from stored correctAnswer field
        int? foundIndex;
        if (current.correctAnswer != null &&
            current.correctAnswer!.isNotEmpty) {
          _correctCtrl.text = current.correctAnswer!;
          for (int i = 0; i < 4; i++) {
            if (_optCtrls[i].text.trim().toLowerCase() ==
                current.correctAnswer!.trim().toLowerCase()) {
              foundIndex = i;
              break;
            }
          }
        }

        _selectedCorrectOptionIndex = foundIndex;
        _isManualInput = false; // keep form section visible via hasQueue flag
        _diagramFile = null; // clear old diagram so it doesn't carry over
      });
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
      _selectedCorrectOptionIndex = null;
      _selectedGalleryFile = null;
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    // Request permission only for camera, as gallery uses system Photo Picker on Android 13+ without permissions
    if (source == ImageSource.camera) {
      final status = await Permission.camera.request();
      if (status.isPermanentlyDenied) {
        _showPermissionDialog('Camera');
        return;
      }
      if (!status.isGranted) return;
    }

    try {
      final file = await _imageService.pickAndCropImage(
        context,
        source: source,
      );
      if (!mounted || file == null) return;
      if (source == ImageSource.gallery) {
        setState(() {
          _selectedGalleryFile = file;
        });
      } else {
        _processScannedFile(file);
      }
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
        content: Text(
          'Please enable $type access in settings to scan questions.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => openAppSettings(),
            child: const Text('Open Settings'),
          ),
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } else if (provider.questionQueue.isNotEmpty) {
      setState(() {
        _selectedGalleryFile = null;
      });
      _syncFromQueue();

      // Show OCR confidence feedback
      final ocr = provider.questionQueue.first;
      if (ocr.confidence != null) {
        _showOCRConfidenceFeedback(ocr.confidence!);
      }
    }
  }

  void _showOCRConfidenceFeedback(double confidence) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'OCR Quality Assessment',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 24),
            Center(child: ConfidenceBadge(confidence: confidence)),
            const SizedBox(height: 24),
            // Show recommendation based on confidence
            _buildConfidenceRecommendation(confidence),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(
                        color: Color(0xFF4A148C),
                        width: 2,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Re-crop Image',
                      style: TextStyle(
                        color: Color(0xFF4A148C),
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('OCR results accepted ✓'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4A148C),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Accept',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
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

  Widget _buildConfidenceRecommendation(double confidence) {
    String recommendation;
    Color bgColor;
    Color textColor;
    IconData icon;

    if (confidence >= 90) {
      recommendation = '✓ Ready to use\nOCR results are excellent quality';
      bgColor = const Color(0xFF4CAF50).withValues(alpha: 0.1);
      textColor = const Color(0xFF4CAF50);
      icon = Icons.check_circle;
    } else if (confidence >= 80) {
      recommendation = '→ Review recommended\nDouble-check complex sections';
      bgColor = const Color(0xFF2196F3).withValues(alpha: 0.1);
      textColor = const Color(0xFF2196F3);
      icon = Icons.info;
    } else if (confidence >= 70) {
      recommendation = '⚠ Please review carefully\nCheck mathematical notation';
      bgColor = const Color(0xFFFFC107).withValues(alpha: 0.1);
      textColor = const Color(0xFFFFC107);
      icon = Icons.warning;
    } else if (confidence >= 60) {
      recommendation = '⚠ Manual correction needed\nSome errors may be present';
      bgColor = const Color(0xFFFF9800).withValues(alpha: 0.1);
      textColor = const Color(0xFFFF9800);
      icon = Icons.warning_amber;
    } else {
      recommendation =
          '✕ Re-crop or re-upload recommended\nQuality too low for reliable OCR';
      bgColor = const Color(0xFFBA1A1A).withValues(alpha: 0.1);
      textColor = const Color(0xFFBA1A1A);
      icon = Icons.error;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: textColor.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        children: [
          Icon(icon, color: textColor, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              recommendation,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w600,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDiagram() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Select Diagram Source',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              leading: const Icon(
                Icons.camera_alt_outlined,
                color: Color(0xFF0051D5),
              ),
              title: const Text('Take a Photo (Camera)'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(
                Icons.photo_library_outlined,
                color: Color(0xFF0051D5),
              ),
              title: const Text('Choose from Gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (source == null) return;

    final file = await _imageService.pickAndCropImage(context, source: source);
    if (file != null) {
      setState(() => _diagramFile = file);
    }
  }

  Future<void> _saveQuestion() async {
    if (_questionCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Question text is required'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }

    for (int i = 0; i < 4; i++) {
      if (_optCtrls[i].text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Option ${String.fromCharCode(65 + i)} is required'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
        return;
      }
    }

    final String correctAnswer = _correctCtrl.text.trim();
    if (correctAnswer.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Correct answer is required'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }

    final List<String> options = _optCtrls.map((c) => c.text.trim()).toList();
    if (!options.any((o) => o.toLowerCase() == correctAnswer.toLowerCase())) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Correct answer must match one of the 4 options exactly',
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }

    final provider = Provider.of<QuestionProvider>(context, listen: false);
    final bool isQueueFlow = provider.questionQueue.isNotEmpty;
    final bool wasLastQuestion = isQueueFlow && !provider.hasNextQuestion;

    final q = Question(
      questionText: _questionCtrl.text.trim(),
      options: options,
      correctAnswer: correctAnswer,
      classNo: _selectedClass,
      language: _selectedLanguage,
      chapter: _selectedChapter ?? '',
    );

    final success = await provider.saveQuestion(q, diagramFile: _diagramFile);
    if (!mounted) return;

    if (success) {
      _clearForm();

      if (isQueueFlow && wasLastQuestion) {
        // Show completion dialog and redirect
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: const [
                Icon(Icons.check_circle, color: Color(0xFF4CAF50), size: 28),
                SizedBox(width: 8),
                Text('All Questions Saved'),
              ],
            ),
            content: const Text(
              'All questions in this scan session have been successfully verified and saved to the database.',
              style: TextStyle(fontSize: 15),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                },
                child: const Text(
                  'OK',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0051D5),
                  ),
                ),
              ),
            ],
          ),
        ).then((_) {
          provider.clearQueue();
          if (mounted) {
            setState(() {
              _isManualInput = false;
            });
            _clearForm();
            Navigator.pop(context); // Close the Create Question screen
          }
        });
      } else if (provider.questionQueue.isNotEmpty) {
        _syncFromQueue();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('✓ Question saved! Loading next...'),
            backgroundColor: const Color(0xFF4CAF50),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      } else {
        // Manual input flow: question saved and reset form
        setState(() {
          _isManualInput = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('✓ Question saved successfully!'),
            backgroundColor: const Color(0xFF4CAF50),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } else {
      final errorText = provider.creationError ?? 'Failed to save';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorText),
          backgroundColor: const Color(0xFFBA1A1A),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );

      if (errorText.toLowerCase().contains('session expired')) {
        await Future.delayed(const Duration(milliseconds: 250));
        if (!mounted) return;
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil('/login', (route) => false);
      }
    }
  }

  @override
  void dispose() {
    _subscribedProvider?.removeListener(_onProviderChange);
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

        // Show PDF picker if requested
        if (_showPdfPicker) {
          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () {
                        setState(() {
                          _showPdfPicker = false;
                        });
                      },
                    ),
                    const Text(
                      'PDF/Document Upload',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                PdfPickerWidget(
                  enableDirectExtraction: true,
                  onQuestionsExtracted: (questions, sessionId) {
                    setState(() {
                      _showPdfPicker = false;
                    });
                    _syncFromQueue();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Extracted ${questions.length} questions!',
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        }

        // Show Gallery Image preview/upload if requested
        if (_selectedGalleryFile != null) {
          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () {
                        setState(() {
                          _selectedGalleryFile = null;
                        });
                      },
                    ),
                    const Text(
                      'Gallery Image Preview',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        constraints: const BoxConstraints(maxHeight: 350),
                        color: const Color(0xFFF1F5F9),
                        child: Image.file(
                          _selectedGalleryFile!,
                          fit: BoxFit.contain,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Selected Image ready for OCR',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'File path: ${_selectedGalleryFile!.path.split('/').last}',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(height: 20),
                            if (provider.isScanning) ...[
                              const Center(
                                child: Column(
                                  children: [
                                    CircularProgressIndicator(
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Color(0xFF0051D5),
                                      ),
                                    ),
                                    SizedBox(height: 12),
                                    Text(
                                      'Processing image with Mathpix OCR...',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF0051D5),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ] else ...[
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () {
                                        setState(() {
                                          _selectedGalleryFile = null;
                                        });
                                      },
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 16,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                      ),
                                      child: const Text('Cancel'),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: () => _processScannedFile(
                                        _selectedGalleryFile!,
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFF0051D5,
                                        ),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 16,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        elevation: 0,
                                      ),
                                      child: const Text(
                                        'Extract Questions',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

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

              if (!hasQueue && !provider.isScanning && !_isManualInput)
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
                    _label('Question Text (LaTeX Preview)'),
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
                                  'LaTeX Render',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                selected: _useLaTeXPreview,
                                selectedColor: const Color(0x200051D5),
                                labelStyle: TextStyle(
                                  color: _useLaTeXPreview
                                      ? const Color(0xAA0051D5)
                                      : Colors.black54,
                                ),
                                onSelected: (selected) {
                                  if (selected)
                                    setState(() => _useLaTeXPreview = true);
                                },
                              ),
                              const SizedBox(width: 8),
                              ChoiceChip(
                                label: const Text(
                                  'Readable Text',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                selected: !_useLaTeXPreview,
                                selectedColor: const Color(0x200051D5),
                                labelStyle: TextStyle(
                                  color: !_useLaTeXPreview
                                      ? const Color(0xAA0051D5)
                                      : Colors.black54,
                                ),
                                onSelected: (selected) {
                                  if (selected)
                                    setState(() => _useLaTeXPreview = false);
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _buildPreviewBox(
                        _useLaTeXPreview
                            ? LaTeXWidget(text: _questionCtrl.text)
                            : Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8F9FA),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(0xFFE2E8F0),
                                  ),
                                ),
                                child: Text(
                                  LatexToReadableConverter.convert(
                                    _questionCtrl.text,
                                  ),
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
                  child: _buildFormSection('Diagram', [_buildDiagramPicker()]),
                ),

                const SizedBox(height: 20),
                FadeInSlide(
                  duration: const Duration(milliseconds: 550),
                  delay: const Duration(milliseconds: 200),
                  child: _buildFormSection('Options', [
                    const Text(
                      'Check the box next to the correct answer:',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 14),
                    for (int i = 0; i < 4; i++) ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(
                              top: 24.0,
                              right: 8.0,
                            ),
                            child: Tooltip(
                              message:
                                  'Mark Option ${String.fromCharCode(65 + i)} as correct',
                              child: Transform.scale(
                                scale: 1.1,
                                child: Checkbox(
                                  value: _selectedCorrectOptionIndex == i,
                                  activeColor: const Color(0xFF0051D5),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  onChanged: (bool? val) {
                                    setState(() {
                                      if (val == true) {
                                        _selectedCorrectOptionIndex = i;
                                        _correctCtrl.text = _optCtrls[i].text
                                            .trim();
                                      } else {
                                        if (_selectedCorrectOptionIndex == i) {
                                          _selectedCorrectOptionIndex = null;
                                          _correctCtrl.clear();
                                        }
                                      }
                                    });
                                  },
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _label('Option ${String.fromCharCode(65 + i)}'),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: _optCtrls[i],
                                  decoration: _inputDec(
                                    'Enter option ${i + 1}...',
                                  ),
                                  onChanged: (val) {
                                    setState(() {
                                      if (_selectedCorrectOptionIndex == i) {
                                        _correctCtrl.text = val.trim();
                                      }
                                    });
                                  },
                                ),
                                if (_optCtrls[i].text.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  _buildOptionPreviewBox(
                                    LaTeXWidget(text: _optCtrls[i].text),
                                  ),
                                ],
                                const SizedBox(height: 16),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
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
                            items: [9, 10, 11, 12, 13]
                                .map(
                                  (c) => DropdownMenuItem(
                                    value: c,
                                    child: Text(
                                      c == 13 ? 'Joint Entrance' : 'Class $c',
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (val) {
                              setState(() {
                                _selectedClass = val!;
                                _selectedChapter = AppConstants
                                    .classChapters[_selectedClass]
                                    ?.first;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildDropdown<String>(
                            label: 'Language',
                            value: _selectedLanguage,
                            items: ['Bengali', 'English', 'Both']
                                .map(
                                  (l) => DropdownMenuItem(
                                    value: l,
                                    child: Text(l),
                                  ),
                                )
                                .toList(),
                            onChanged: (val) =>
                                setState(() => _selectedLanguage = val!),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildDropdown<String>(
                      label: 'Chapter',
                      value: _selectedChapter,
                      isExpanded: true,
                      items: chapters
                          .map(
                            (ch) => DropdownMenuItem(
                              value: ch,
                              child: Text(ch, overflow: TextOverflow.ellipsis),
                            ),
                          )
                          .toList(),
                      onChanged: (val) =>
                          setState(() => _selectedChapter = val),
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
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(QuestionProvider provider) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
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
                provider.isScanning
                    ? 'Processing scanned image with AI OCR...'
                    : 'Scan physical papers or input equations manually',
                style: const TextStyle(
                  color: Color(0xFF75859D),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        if (provider.questionQueue.isNotEmpty)
          TextButton.icon(
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Discard Scan Session'),
                  content: const Text(
                    'Are you sure you want to discard all remaining scanned questions?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _clearForm();
                        provider.clearQueue();
                        setState(() {
                          _isManualInput = false;
                        });
                      },
                      child: const Text(
                        'Discard',
                        style: TextStyle(color: Color(0xFFBA1A1A)),
                      ),
                    ),
                  ],
                ),
              );
            },
            icon: const Icon(
              Icons.delete_sweep_rounded,
              color: Color(0xFFBA1A1A),
            ),
            label: const Text(
              'Discard Scan',
              style: TextStyle(
                color: Color(0xFFBA1A1A),
                fontWeight: FontWeight.bold,
              ),
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
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(
              Icons.document_scanner_outlined,
              size: 76,
              color: Color(0xFF0051D5),
            ),
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
                  child: _scanActionCard(
                    'Camera Capture',
                    Icons.camera_alt_rounded,
                    const Color(0xFF0051D5),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: BounceOnTap(
                  onTap: () => _pickImage(ImageSource.gallery),
                  child: _scanActionCard(
                    'Choose Gallery',
                    Icons.photo_library_rounded,
                    const Color(0xFF316BF3),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          BounceOnTap(
            onTap: () {
              setState(() {
                _isManualInput = true;
              });
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFECEEF0), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(
                    Icons.edit_note_rounded,
                    color: Color(0xFF4A148C),
                    size: 28,
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Input Manually',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          BounceOnTap(
            onTap: () {
              setState(() {
                _showPdfPicker = true;
              });
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 18),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE5E7EB), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(
                    Icons.description_outlined,
                    color: Color(0xFF2563EB),
                    size: 28,
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Upload PDF/Document',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                ],
              ),
            ),
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
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
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
    if (provider.questionQueue.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        // Use the new comprehensive queue status widget
        QuestionQueueStatusWidget(
          onPrevious: () {
            if (provider.previousQuestion()) {
              _syncFromQueue();
            }
          },
          onNext: () {
            if (provider.nextQuestion()) {
              _syncFromQueue();
            }
          },
          onSkip: () {
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Skip Question'),
                content: const Text('Skip this question without saving?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      if (provider.nextQuestion()) {
                        _syncFromQueue();
                      }
                    },
                    child: const Text('Skip'),
                  ),
                ],
              ),
            );
          },
          onDelete: () {
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Delete Question'),
                content: const Text('Remove this question from the queue?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      provider.removeCurrentQuestion();
                      if (provider.isQueueActive) {
                        _syncFromQueue();
                      } else {
                        _clearForm();
                        setState(() {
                          _isManualInput = false;
                        });
                      }
                    },
                    child: const Text(
                      'Delete',
                      style: TextStyle(color: Color(0xFFBA1A1A)),
                    ),
                  ),
                ],
              ),
            );
          },
          showNavigationButtons: true,
        ),
      ],
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
            child: Image.file(
              _diagramFile!,
              height: 160,
              width: double.infinity,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: 12),
        ],
        OutlinedButton.icon(
          onPressed: _pickDiagram,
          icon: Icon(
            _diagramFile == null
                ? Icons.add_photo_alternate_rounded
                : Icons.edit_rounded,
            size: 20,
          ),
          label: Text(
            _diagramFile == null
                ? 'Add Optional Diagram'
                : 'Replace Question Diagram',
          ),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 50),
            side: const BorderSide(color: Color(0xFFECEEF0), width: 1),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
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
              onPressed: () {
                _clearForm();
                provider.popQuestionFromQueue();
                if (provider.questionQueue.isNotEmpty) {
                  _syncFromQueue();
                } else {
                  setState(() => _isManualInput = false);
                }
              },
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: const BorderSide(color: Color(0xFFBA1A1A)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'Skip',
                style: TextStyle(
                  color: Color(0xFFBA1A1A),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        if (provider.questionQueue.isEmpty && _isManualInput)
          Expanded(
            child: OutlinedButton(
              onPressed: () {
                _clearForm();
                setState(() {
                  _isManualInput = false;
                });
              },
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: const BorderSide(color: Color(0xFF75859D)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: Color(0xFF75859D),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        if (provider.questionQueue.isNotEmpty || _isManualInput)
          const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: ElevatedButton(
            onPressed: provider.isSaving ? null : _saveQuestion,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0051D5),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
            child: provider.isSaving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Text(
                    provider.questionQueue.isNotEmpty
                        ? (provider.hasNextQuestion
                              ? 'Save & Next Question'
                              : 'Save & Finish')
                        : 'Save Question',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
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
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: Color(0xFF75859D),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  Widget _buildOptionPreviewBox(Widget child) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFECEEF0)),
      ),
      child: child,
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
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFECEEF0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFECEEF0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF0051D5), width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  Widget _buildDropdown<T>({
    required String label,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
    bool isExpanded = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(label),
        const SizedBox(height: 8),
        DropdownButtonFormField<T>(
          initialValue: value,
          onChanged: onChanged,
          isExpanded: isExpanded,
          decoration: _inputDec(label),
          items: items,
        ),
      ],
    );
  }
}
