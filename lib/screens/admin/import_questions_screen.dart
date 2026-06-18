import 'dart:io';
import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../providers/question_provider.dart';
import '../../services/api_service.dart';
import '../shared/latex_widget.dart';
import '../../widgets/glass_card.dart';

// ─── AMBIENT GLOW DRIFT BACKGROUND ──────────────────────────────────────────
class _DriftingGlowBackground extends StatelessWidget {
  final Animation<double> animation;
  final Widget child;

  const _DriftingGlowBackground({required this.animation, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final progress = animation.value;
        final x1 = 0.2 + 0.5 * math.sin(progress * 2 * math.pi);
        final y1 = 0.3 + 0.4 * math.cos(progress * 2 * math.pi);
        final x2 = 0.8 + 0.4 * math.cos(progress * 2 * math.pi + math.pi / 2);
        final y2 = 0.7 + 0.3 * math.sin(progress * 2 * math.pi + math.pi / 2);

        return Stack(
          children: [
            Positioned.fill(
              child: Container(color: const Color(0xFF0B0F19)),
            ),
            // Glow 1: Deep Blue
            Positioned(
              left: MediaQuery.of(context).size.width * x1 - 220,
              top: MediaQuery.of(context).size.height * y1 - 220,
              child: Container(
                width: 440,
                height: 440,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF0051D5).withValues(alpha: 0.12),
                ),
              ),
            ),
            // Glow 2: Cyan/Sky Accent
            Positioned(
              left: MediaQuery.of(context).size.width * x2 - 220,
              top: MediaQuery.of(context).size.height * y2 - 220,
              child: Container(
                width: 440,
                height: 440,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF38BDF8).withValues(alpha: 0.08),
                ),
              ),
            ),
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 70, sigmaY: 70),
                child: child,
              ),
            ),
          ],
        );
      },
      child: child,
    );
  }
}

// ─── MAIN SCREEN (UPLOAD & HISTORY) ──────────────────────────────────────────
class ImportQuestionsScreen extends StatefulWidget {
  const ImportQuestionsScreen({super.key});

  @override
  State<ImportQuestionsScreen> createState() => _ImportQuestionsScreenState();
}

class _ImportQuestionsScreenState extends State<ImportQuestionsScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  late TabController _tabController;
  late AnimationController _bgAnimationController;

  List<dynamic> _jobs = [];
  bool _isLoadingJobs = false;

  final Map<String, File?> _selectedFiles = {};
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _markdownController = TextEditingController();
  final TextEditingController _csvController = TextEditingController();

  bool _isUploading = false;
  double _uploadProgress = 0.0;
  String? _uploadError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _bgAnimationController = AnimationController(
      duration: const Duration(seconds: 25),
      vsync: this,
    )..repeat(reverse: true);
    
    _loadJobs();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<QuestionProvider>(context, listen: false).syncChapters();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _bgAnimationController.dispose();
    _urlController.dispose();
    _markdownController.dispose();
    _csvController.dispose();
    super.dispose();
  }

  Future<void> _loadJobs() async {
    if (_isLoadingJobs) return;
    setState(() => _isLoadingJobs = true);
    try {
      final jobs = await _apiService.getImportJobs();
      setState(() {
        _jobs = jobs;
      });
      _checkAndStartPolling();
    } catch (e) {
      _showSnackBar('Failed to load import jobs: $e', isError: true);
    } finally {
      setState(() => _isLoadingJobs = false);
    }
  }

  void _checkAndStartPolling() {
    final activeJobs = _jobs.where((job) =>
        job['status'] == 'queued' || job['status'] == 'parsing');
    
    if (activeJobs.isNotEmpty) {
      Future.delayed(const Duration(seconds: 4), () {
        if (mounted) _loadJobs();
      });
    }
  }

  Future<void> _pickPDF() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
      if (result != null && result.files.isNotEmpty && result.files.first.path != null) {
        setState(() {
          _selectedFiles['pdf'] = File(result.files.first.path!);
          _uploadError = null;
        });
      }
    } catch (e) {
      _showSnackBar('Error picking PDF file: $e', isError: true);
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    if (source == ImageSource.camera) {
      final status = await Permission.camera.request();
      if (!status.isGranted) return;
    }

    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: source);
      if (picked != null) {
        setState(() {
          _selectedFiles['image'] = File(picked.path);
          _uploadError = null;
        });
      }
    } catch (e) {
      _showSnackBar('Error picking image: $e', isError: true);
    }
  }

  Future<void> _submitImport(String type) async {
    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
      _uploadError = null;
    });

    try {
      File? file;
      String? url;
      String? text;

      if (type == 'pdf') {
        file = _selectedFiles['pdf'];
        if (file == null) throw Exception('Please select a PDF file first.');
      } else if (type == 'image') {
        file = _selectedFiles['image'];
        if (file == null) throw Exception('Please select or take an image first.');
      } else if (type == 'url') {
        url = _urlController.text.trim();
        if (url.isEmpty || !url.startsWith('http')) {
          throw Exception('Please enter a valid HTTP/HTTPS URL.');
        }
      } else if (type == 'markdown') {
        text = _markdownController.text.trim();
        if (text.isEmpty) throw Exception('Markdown text content is empty.');
      } else if (type == 'csv') {
        text = _csvController.text.trim();
        if (text.isEmpty) throw Exception('CSV content is empty.');
      }

      final response = await _apiService.uploadImportSource(
        importType: type,
        file: file,
        url: url,
        text: text,
        onProgress: (p) {
          setState(() {
            _uploadProgress = p;
          });
        },
      );

      if (response['success'] == true) {
        _showSnackBar('Import job queued successfully!');
        _selectedFiles.remove(type);
        _urlController.clear();
        _markdownController.clear();
        _csvController.clear();

        await _loadJobs();
        
        final newJobId = response['data']['jobId'];
        final jobDetails = _jobs.firstWhere((j) => j['_id'] == newJobId, orElse: () => response['data']);
        
        // Navigate directly to details view for this job
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ImportJobDetailsScreen(jobId: newJobId, job: jobDetails),
            ),
          ).then((_) => _loadJobs());
        }
      } else {
        throw Exception(response['message'] ?? 'Upload failed.');
      }
    } catch (e) {
      setState(() {
        _uploadError = e.toString().replaceFirst('Exception: ', '');
      });
      _showSnackBar(_uploadError!, isError: true);
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: isError ? const Color(0xFFBA1A1A) : const Color(0xFF43A047),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.all(20),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 850;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Import Dashboard',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 24),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 28),
            onPressed: _loadJobs,
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: _DriftingGlowBackground(
        animation: _bgAnimationController,
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (isDesktop) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 4,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: _buildUploadContainer(),
                      ),
                    ),
                    Expanded(
                      flex: 5,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: _buildHistoryListSection(),
                      ),
                    ),
                  ],
                );
              } else {
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      _buildUploadContainer(),
                      const SizedBox(height: 24),
                      _buildHistoryListSection(),
                    ],
                  ),
                );
              }
            },
          ),
        ),
      ),
    );
  }

  Widget _buildUploadContainer() {
    return GlassCard(
      borderRadius: 24,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'New Import Source',
            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          TabBar(
            controller: _tabController,
            isScrollable: true,
            labelColor: const Color(0xFF38BDF8),
            unselectedLabelColor: const Color(0xFF94A3B8),
            indicatorColor: const Color(0xFF38BDF8),
            indicatorSize: TabBarIndicatorSize.label,
            dividerColor: Colors.transparent,
            tabAlignment: TabAlignment.start,
            tabs: const [
              Tab(text: 'PDF', icon: Icon(Icons.picture_as_pdf_rounded)),
              Tab(text: 'Image', icon: Icon(Icons.image_rounded)),
              Tab(text: 'URL', icon: Icon(Icons.link_rounded)),
              Tab(text: 'Markdown', icon: Icon(Icons.code_rounded)),
              Tab(text: 'CSV', icon: Icon(Icons.table_chart_rounded)),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 280,
            child: TabBarView(
              controller: _tabController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildPDFTab(),
                _buildImageTab(),
                _buildURLTab(),
                _buildMarkdownTab(),
                _buildCSVTab(),
              ],
            ),
          ),
          if (_isUploading) ...[
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: _uploadProgress,
                      minHeight: 8,
                      backgroundColor: Colors.white.withOpacity(0.08),
                      valueColor: const AlwaysStoppedAnimation(Color(0xFF38BDF8)),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  '${(_uploadProgress * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPDFTab() {
    final pdf = _selectedFiles['pdf'];
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (pdf == null) ...[
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: IconButton(
              icon: const Icon(Icons.cloud_upload_rounded, size: 48, color: Color(0xFF38BDF8)),
              onPressed: _pickPDF,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Select a PDF question paper to process',
            style: TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
          ),
        ] else ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Row(
              children: [
                const Icon(Icons.picture_as_pdf_rounded, color: Colors.redAccent, size: 32),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    pdf.path.split('/').last,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.cached_rounded, color: Color(0xFF38BDF8)),
                  onPressed: _pickPDF,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _isUploading ? null : () => _submitImport('pdf'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0051D5),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 4,
            ),
            child: const Text('Process PDF', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          ),
        ]
      ],
    );
  }

  Widget _buildImageTab() {
    final img = _selectedFiles['image'];
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (img == null) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.camera_alt_rounded),
                label: const Text('Camera'),
                onPressed: () => _pickImage(ImageSource.camera),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.06),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  side: BorderSide(color: Colors.white.withOpacity(0.08)),
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.photo_library_rounded),
                label: const Text('Gallery'),
                onPressed: () => _pickImage(ImageSource.gallery),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.06),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  side: BorderSide(color: Colors.white.withOpacity(0.08)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Snap or select question images for OCR extraction',
            style: TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
          ),
        ] else ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Row(
              children: [
                const Icon(Icons.image_rounded, color: Colors.greenAccent, size: 32),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    img.path.split('/').last,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.cached_rounded, color: Color(0xFF38BDF8)),
                  onPressed: () => _pickImage(ImageSource.gallery),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _isUploading ? null : () => _submitImport('image'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0051D5),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('Process Image', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          ),
        ]
      ],
    );
  }

  Widget _buildURLTab() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        TextField(
          controller: _urlController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Website URL',
            labelStyle: const TextStyle(color: Color(0xFF64748B)),
            hintText: 'https://example.com/mcq-questions',
            hintStyle: const TextStyle(color: Color(0xFF475569)),
            prefixIcon: const Icon(Icons.link_rounded, color: Color(0xFF38BDF8)),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
              borderRadius: BorderRadius.circular(14),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: Color(0xFF38BDF8)),
              borderRadius: BorderRadius.circular(14),
            ),
            filled: true,
            fillColor: Colors.white.withOpacity(0.02),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Extract questions from public online resources',
          style: TextStyle(color: Color(0xFF64748B), fontSize: 13, fontWeight: FontWeight.w500),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _isUploading ? null : () => _submitImport('url'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0051D5),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: const Text('Import from URL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        ),
      ],
    );
  }

  Widget _buildMarkdownTab() {
    return Column(
      children: [
        Expanded(
          child: TextField(
            controller: _markdownController,
            style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 13),
            maxLines: null,
            decoration: InputDecoration(
              labelText: 'Paste Markdown Content',
              labelStyle: const TextStyle(color: Color(0xFF64748B)),
              hintText: r'''### Question 1
What is $2+2$? 
A) 3
B) 4
Answer: B
Class: 12
Chapter: General''',
              hintStyle: const TextStyle(color: Color(0xFF475569)),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
                borderRadius: BorderRadius.circular(14),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: Color(0xFF38BDF8)),
                borderRadius: BorderRadius.circular(14),
              ),
              filled: true,
              fillColor: Colors.white.withOpacity(0.02),
            ),
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: _isUploading ? null : () => _submitImport('markdown'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0051D5),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: const Text('Parse Markdown', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        ),
      ],
    );
  }

  Widget _buildCSVTab() {
    return Column(
      children: [
        Expanded(
          child: TextField(
            controller: _csvController,
            style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 13),
            maxLines: null,
            decoration: InputDecoration(
              labelText: 'Paste CSV Data (Comma separated)',
              labelStyle: const TextStyle(color: Color(0xFF64748B)),
              hintText: r'''QuestionText,Option A,Option B,Option C,Option D,CorrectAnswer,ClassNo,ChapterName,Language,Explanation
"What is $1+1$?",1,2,3,4,B,12,General,English,"1+1 is 2"''',
              hintStyle: const TextStyle(color: Color(0xFF475569)),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
                borderRadius: BorderRadius.circular(14),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: Color(0xFF38BDF8)),
                borderRadius: BorderRadius.circular(14),
              ),
              filled: true,
              fillColor: Colors.white.withOpacity(0.02),
            ),
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: _isUploading ? null : () => _submitImport('csv'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0051D5),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: const Text('Parse CSV Data', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        ),
      ],
    );
  }

  Widget _buildHistoryListSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Import History & Jobs',
          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 16),
        if (_isLoadingJobs && _jobs.isEmpty)
          const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
        else if (_jobs.isEmpty)
          const Text('No recent import jobs found.', style: TextStyle(color: Color(0xFF64748B)))
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _jobs.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final job = _jobs[index];
              final jobId = job['_id'];
              final status = job['status'];
              final type = job['importType'].toString().toUpperCase();
              final date = DateTime.parse(job['createdAt']).toLocal();

              Color statusColor = Colors.grey;
              if (status == 'queued') statusColor = Colors.orange;
              if (status == 'parsing') statusColor = Colors.blue;
              if (status == 'preview_ready') statusColor = Colors.green;
              if (status == 'partially_saved') statusColor = Colors.teal;
              if (status == 'saved') statusColor = Colors.indigo;
              if (status == 'failed') statusColor = Colors.red;

              return InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ImportJobDetailsScreen(jobId: jobId, job: job),
                    ),
                  ).then((_) => _loadJobs());
                },
                borderRadius: BorderRadius.circular(16),
                child: GlassCard(
                  borderRadius: 16,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              status.toString().toUpperCase(),
                              style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.w800),
                            ),
                          ),
                          Text(
                            '${date.day}/${date.month} ${date.hour}:${date.minute.toString().padLeft(2, '0')}',
                            style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        job['sourceFileName'] ?? 'Source Data',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.label_outline, color: const Color(0xFF38BDF8).withValues(alpha: 0.7), size: 16),
                          const SizedBox(width: 6),
                          Text(
                            'Type: $type',
                            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                          ),
                          const Spacer(),
                          if (job['totalItems'] > 0)
                            Text(
                              'Verified: ${job['savedItems'] ?? 0}/${job['totalItems']}',
                              style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}

// ─── DETAILS SCREEN (PREVIEW & VERIFICATION) ──────────────────────────────────
class ImportJobDetailsScreen extends StatefulWidget {
  final String jobId;
  final Map<String, dynamic> job;

  const ImportJobDetailsScreen({super.key, required this.jobId, required this.job});

  @override
  State<ImportJobDetailsScreen> createState() => _ImportJobDetailsScreenState();
}

class _ImportJobDetailsScreenState extends State<ImportJobDetailsScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  late AnimationController _bgAnimationController;

  Map<String, dynamic>? _job;
  List<dynamic> _jobItems = [];
  bool _isLoading = false;

  // Controller maps to prevent cursor jumping
  final Map<String, TextEditingController> _questionControllers = {};
  final Map<String, List<TextEditingController>> _optionControllers = {};
  final Map<String, TextEditingController> _explanationControllers = {};

  final Map<String, Map<String, dynamic>> _editedItems = {};
  final Set<String> _selectedItemIdsForBatch = {};

  @override
  void initState() {
    super.initState();
    _bgAnimationController = AnimationController(
      duration: const Duration(seconds: 25),
      vsync: this,
    )..repeat(reverse: true);
    
    _loadItems();
  }

  @override
  void dispose() {
    _bgAnimationController.dispose();
    _clearControllers();
    super.dispose();
  }

  void _clearControllers() {
    for (var ctrl in _questionControllers.values) {
      ctrl.dispose();
    }
    _questionControllers.clear();
    for (var ctrls in _optionControllers.values) {
      for (var ctrl in ctrls) {
        ctrl.dispose();
      }
    }
    _optionControllers.clear();
    for (var ctrl in _explanationControllers.values) {
      ctrl.dispose();
    }
    _explanationControllers.clear();
  }

  Future<void> _loadItems() async {
    setState(() => _isLoading = true);
    try {
      final jobStatus = await _apiService.getImportJobStatus(widget.jobId);
      final items = await _apiService.getImportJobItems(widget.jobId);
      
      _clearControllers();

      setState(() {
        _job = jobStatus;
        _jobItems = items;
        
        // Initialize controllers map
        for (var item in items) {
          final itemId = item['_id'];
          
          _questionControllers[itemId] = TextEditingController(text: item['questionText'] ?? '');
          _explanationControllers[itemId] = TextEditingController(text: item['explanation'] ?? '');
          
          final List<dynamic> opts = item['options'] ?? ['', '', '', ''];
          _optionControllers[itemId] = List.generate(
            4,
            (i) => TextEditingController(text: i < opts.length ? opts[i].toString() : ''),
          );

          if (item['status'] == 'pending_verification') {
            _selectedItemIdsForBatch.add(itemId);
          }
        }
      });
    } catch (e) {
      _showSnackBar('Failed to load items: $e', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveItemChanges(String itemId) async {
    // Gather updates from controller text or dropdown states
    final questionText = _questionControllers[itemId]?.text.trim() ?? '';
    final options = _optionControllers[itemId]?.map((c) => c.text.trim()).toList() ?? ['', '', '', ''];
    final explanation = _explanationControllers[itemId]?.text.trim() ?? '';
    
    final updates = _editedItems[itemId] ?? {};
    final body = {
      'questionText': questionText,
      'options': options,
      'explanation': explanation,
      if (updates.containsKey('correctAnswer')) 'correctAnswer': updates['correctAnswer'],
      if (updates.containsKey('classNo')) 'classNo': updates['classNo'],
      if (updates.containsKey('chapterName')) 'chapterName': updates['chapterName'],
      if (updates.containsKey('language')) 'language': updates['language'],
    };

    try {
      final response = await _apiService.updateImportItem(itemId, body);
      if (response['success'] == true) {
        _showSnackBar('Changes saved for question.');
        setState(() {
          _editedItems.remove(itemId);
          final index = _jobItems.indexWhere((it) => it['_id'] == itemId);
          if (index != -1) {
            _jobItems[index] = response['data'];
          }
        });
      } else {
        _showSnackBar(response['message'] ?? 'Failed to save changes.', isError: true);
      }
    } catch (e) {
      _showSnackBar('Error updating item: $e', isError: true);
    }
  }

  Future<void> _processBatchVerification() async {
    if (_job == null) return;

    final confirmIds = _selectedItemIdsForBatch.toList();
    final rejectIds = _jobItems
        .where((it) => it['status'] == 'pending_verification' && !_selectedItemIdsForBatch.contains(it['_id']))
        .map((it) => it['_id'].toString())
        .toList();

    if (confirmIds.isEmpty && rejectIds.isEmpty) {
      _showSnackBar('No pending items to process.', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await _apiService.confirmImportItems(
        widget.jobId,
        confirmItemIds: confirmIds,
        rejectItemIds: rejectIds,
      );

      if (response['success'] == true) {
        final data = response['data'];
        _showSnackBar(
          'Batch complete. Saved: ${data['saved']}, Rejected: ${data['rejected']}, Failed: ${data['failed']}',
        );
        await _loadItems();
      } else {
        _showSnackBar(response['message'] ?? 'Verification failed.', isError: true);
      }
    } catch (e) {
      _showSnackBar('Error confirming items: $e', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _updateEditState(String itemId, String fieldName, dynamic value) {
    if (!_editedItems.containsKey(itemId)) {
      _editedItems[itemId] = {};
    }
    setState(() {
      _editedItems[itemId]![fieldName] = value;
    });
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: isError ? const Color(0xFFBA1A1A) : const Color(0xFF43A047),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.all(20),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = _job?['status'] ?? widget.job['status'];
    final fileName = _job?['sourceFileName'] ?? widget.job['sourceFileName'];
    final error = _job?['errorMessage'];

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          fileName ?? 'Job Preview',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 20),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (['preview_ready', 'partially_saved'].contains(status))
            ElevatedButton.icon(
              icon: const Icon(Icons.verified_user_rounded, color: Colors.white, size: 18),
              label: const Text('Verify Batch', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF38BDF8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              onPressed: _isLoading ? null : _processBatchVerification,
            ),
          const SizedBox(width: 16),
        ],
      ),
      body: _DriftingGlowBackground(
        animation: _bgAnimationController,
        child: SafeArea(
          child: Column(
            children: [
              // Job Header Info Card
              if (error != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded, color: Colors.redAccent),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Parsing Failure: $error',
                            style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Items list view
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _jobItems.isEmpty
                        ? const Center(
                            child: Text(
                              'No questions parsed from this job yet.',
                              style: TextStyle(color: Color(0xFF64748B), fontSize: 16),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(20),
                            itemCount: _jobItems.length,
                            itemBuilder: (context, index) {
                              final item = _jobItems[index];
                              return _buildItemCard(item, index + 1);
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildItemCard(dynamic item, int displayNum) {
    final itemId = item['_id'];
    final status = item['status'];
    final hasUnsavedEdits = _editedItems.containsKey(itemId) || 
        _questionControllers[itemId]?.text != (item['questionText'] ?? '') ||
        _explanationControllers[itemId]?.text != (item['explanation'] ?? '');

    final correctAnswer = _editedItems[itemId]?['correctAnswer'] ?? item['correctAnswer'] ?? 'A';
    final classNo = _editedItems[itemId]?['classNo'] ?? item['classNo'] ?? 12;
    final chapterName = _editedItems[itemId]?['chapterName'] ?? item['chapterName'] ?? 'General';
    final language = _editedItems[itemId]?['language'] ?? item['language'] ?? 'English';

    final isPending = status == 'pending_verification';
    final isSaved = status == 'saved';
    final isRejected = status == 'rejected';

    final dupInfo = item['duplicateInfo'] ?? {};
    final isDuplicate = dupInfo['detected'] == true;
    final similarity = dupInfo['similarity'] != null ? (dupInfo['similarity'] * 100).toStringAsFixed(0) : '0';

    return GlassCard(
      borderRadius: 20,
      padding: const EdgeInsets.all(20),
      color: isSaved
          ? Colors.indigo.withValues(alpha: 0.15)
          : isRejected
              ? Colors.red.withValues(alpha: 0.1)
              : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (isPending)
                Checkbox(
                  value: _selectedItemIdsForBatch.contains(itemId),
                  activeColor: const Color(0xFF38BDF8),
                  onChanged: (val) {
                    setState(() {
                      if (val == true) {
                        _selectedItemIdsForBatch.add(itemId);
                      } else {
                        _selectedItemIdsForBatch.remove(itemId);
                      }
                    });
                  },
                ),
              Text(
                'Question $displayNum',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
              ),
              const SizedBox(width: 12),
              _buildItemStatusIndicator(status),
              const Spacer(),
              if (isPending) ...[
                TextButton.icon(
                  icon: Icon(
                    Icons.save_rounded, 
                    size: 18, 
                    color: hasUnsavedEdits ? const Color(0xFF38BDF8) : Colors.white24
                  ),
                  label: Text(
                    'Save changes', 
                    style: TextStyle(
                      color: hasUnsavedEdits ? const Color(0xFF38BDF8) : Colors.white24,
                      fontWeight: FontWeight.bold
                    )
                  ),
                  onPressed: () => _saveItemChanges(itemId),
                ),
              ]
            ],
          ),
          const Divider(color: Colors.white10, height: 24),

          if (isDuplicate) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Warning: Duplicate Detected ($similarity% similarity to existing question). Check carefully before verifying.',
                      style: const TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Question Input
          const Text('Question Text', style: TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextField(
            controller: _questionControllers[itemId],
            enabled: isPending,
            style: const TextStyle(color: Colors.white),
            maxLines: null,
            onChanged: (val) {
              _updateEditState(itemId, 'questionText', val);
            },
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white.withOpacity(0.02),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
                borderRadius: BorderRadius.circular(10),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: Color(0xFF38BDF8)),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // LaTeX render
          if (_questionControllers[itemId]?.text.contains('\$') == true || _questionControllers[itemId]?.text.contains('\\') == true) ...[
            const Text('LaTeX Live Render Preview:', style: TextStyle(color: Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.02),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withOpacity(0.06)),
              ),
              child: LaTeXWidget(text: _questionControllers[itemId]!.text),
            ),
            const SizedBox(height: 16),
          ],

          // Option Inputs
          const Text('Options', style: TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          for (int i = 0; i < 4; i++) ...[
            Row(
              children: [
                Radio<String>(
                  value: String.fromCharCode(65 + i),
                  groupValue: correctAnswer,
                  activeColor: const Color(0xFF38BDF8),
                  onChanged: isPending
                      ? (val) {
                          _updateEditState(itemId, 'correctAnswer', val);
                        }
                      : null,
                ),
                Text(
                  '${String.fromCharCode(65 + i)})',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _optionControllers[itemId]?[i],
                    enabled: isPending,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.02),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Color(0xFF38BDF8)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 16),

          // Metadata drop selectors
          Row(
            children: [
              Expanded(
                child: _buildClassDropdown(
                  selectedClass: classNo,
                  enabled: isPending,
                  onChanged: (val) {
                    _updateEditState(itemId, 'classNo', val);
                    final provider = Provider.of<QuestionProvider>(context, listen: false);
                    final chaps = provider.getChaptersForClass(val!);
                    final defaultChap = chaps.isNotEmpty ? chaps.first : 'General';
                    _updateEditState(itemId, 'chapterName', defaultChap);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildChapterDropdown(
                  selectedClass: classNo,
                  selectedChapter: chapterName,
                  enabled: isPending,
                  onChanged: (val) {
                    _updateEditState(itemId, 'chapterName', val);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildLanguageDropdown(
                  selectedLanguage: language,
                  enabled: isPending,
                  onChanged: (val) {
                    _updateEditState(itemId, 'language', val);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Explanation Input
          const Text('Explanation', style: TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextField(
            controller: _explanationControllers[itemId],
            enabled: isPending,
            style: const TextStyle(color: Colors.white),
            onChanged: (val) {
              _updateEditState(itemId, 'explanation', val);
            },
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white.withOpacity(0.02),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
                borderRadius: BorderRadius.circular(10),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: Color(0xFF38BDF8)),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),

          if (item['errorMessage'] != null) ...[
            const SizedBox(height: 12),
            Text(
              'Save Error: ${item['errorMessage']}',
              style: const TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildItemStatusIndicator(String status) {
    Color color = Colors.grey;
    IconData icon = Icons.pending_rounded;

    if (status == 'saved') {
      color = Colors.indigoAccent;
      icon = Icons.check_circle_rounded;
    } else if (status == 'rejected') {
      color = Colors.redAccent;
      icon = Icons.cancel_rounded;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 6),
        Text(
          status.toUpperCase(),
          style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildClassDropdown({
    required int selectedClass,
    required bool enabled,
    required ValueChanged<int?> onChanged,
  }) {
    final list = [9, 10, 11, 12, 13];
    if (!list.contains(selectedClass)) {
      list.add(selectedClass);
      list.sort();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Class', style: TextStyle(color: Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        DropdownButtonFormField<int>(
          value: selectedClass,
          onChanged: enabled ? onChanged : null,
          dropdownColor: const Color(0xFF0F172A),
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white.withOpacity(0.02),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          items: list
              .map((c) => DropdownMenuItem(
                    value: c,
                    child: Text(c == 13 ? 'Joint Entrance' : 'Class $c'),
                  ))
              .toList(),
        ),
      ],
    );
  }

  Widget _buildChapterDropdown({
    required int selectedClass,
    required String selectedChapter,
    required bool enabled,
    required ValueChanged<String?> onChanged,
  }) {
    final provider = Provider.of<QuestionProvider>(context, listen: false);
    final chapters = provider.getChaptersForClass(selectedClass);
    
    final uniqueChapters = List<String>.from(chapters);
    if (!uniqueChapters.contains(selectedChapter)) {
      uniqueChapters.insert(0, selectedChapter);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Chapter', style: TextStyle(color: Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: selectedChapter,
          isExpanded: true,
          onChanged: enabled ? onChanged : null,
          dropdownColor: const Color(0xFF0F172A),
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white.withOpacity(0.02),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          items: uniqueChapters
              .map((ch) => DropdownMenuItem(
                    value: ch,
                    child: Text(ch, overflow: TextOverflow.ellipsis),
                  ))
              .toList(),
        ),
      ],
    );
  }

  Widget _buildLanguageDropdown({
    required String selectedLanguage,
    required bool enabled,
    required ValueChanged<String?> onChanged,
  }) {
    final list = ['English', 'Bengali', 'Both'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Language', style: TextStyle(color: Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: selectedLanguage,
          onChanged: enabled ? onChanged : null,
          dropdownColor: const Color(0xFF0F172A),
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white.withOpacity(0.02),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          items: list
              .map((l) => DropdownMenuItem(
                    value: l,
                    child: Text(l),
                  ))
              .toList(),
        ),
      ],
    );
  }
}
