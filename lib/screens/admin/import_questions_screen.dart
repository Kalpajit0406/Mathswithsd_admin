import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../providers/question_provider.dart';
import '../../services/api_service.dart';
import '../shared/latex_widget.dart';
import '../../widgets/glass_card.dart';

class ImportQuestionsScreen extends StatefulWidget {
  const ImportQuestionsScreen({super.key});

  @override
  State<ImportQuestionsScreen> createState() => _ImportQuestionsScreenState();
}

class _ImportQuestionsScreenState extends State<ImportQuestionsScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  late TabController _tabController;

  // Recent jobs list
  List<dynamic> _jobs = [];
  bool _isLoadingJobs = false;

  // Selected job for preview
  String? _selectedJobId;
  Map<String, dynamic>? _selectedJob;
  List<dynamic> _jobItems = [];
  bool _isLoadingItems = false;
  
  // Track status polling
  Map<String, File?> _selectedFiles = {}; // 'pdf' -> File, 'image' -> File
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _markdownController = TextEditingController();
  final TextEditingController _csvController = TextEditingController();

  bool _isUploading = false;
  double _uploadProgress = 0.0;
  String? _uploadError;

  // Verification selection states
  final Set<String> _selectedItemIdsForBatch = {};
  final Map<String, Map<String, dynamic>> _editedItems = {}; // itemId -> fields map

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadJobs();
    
    // Auto-sync chapters in the provider on screen load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<QuestionProvider>(context, listen: false).syncChapters();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
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
      
      // If we have an active job, we will start a periodic check
      _checkAndStartPolling();
    } catch (e) {
      _showSnackBar('Failed to load import jobs: $e', isError: true);
    } finally {
      setState(() => _isLoadingJobs = false);
    }
  }

  void _checkAndStartPolling() {
    // Check if any job is queued or parsing, and trigger status updates
    final activeJobs = _jobs.where((job) =>
        job['status'] == 'queued' || job['status'] == 'parsing');
    
    if (activeJobs.isNotEmpty) {
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          _loadJobs();
          if (_selectedJobId != null) {
            _loadJobStatusAndItems(_selectedJobId!);
          }
        }
      });
    }
  }

  Future<void> _loadJobStatusAndItems(String jobId) async {
    setState(() => _isLoadingItems = true);
    try {
      final jobStatus = await _apiService.getImportJobStatus(jobId);
      final items = await _apiService.getImportJobItems(jobId);
      setState(() {
        _selectedJob = jobStatus;
        _jobItems = items;
        
        // Auto-select all items that are pending_verification for batch operations
        _selectedItemIdsForBatch.clear();
        for (var item in items) {
          if (item['status'] == 'pending_verification') {
            _selectedItemIdsForBatch.add(item['_id']);
          }
        }
      });
    } catch (e) {
      _showSnackBar('Failed to load preview items: $e', isError: true);
    } finally {
      setState(() => _isLoadingItems = false);
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
        final jobId = response['data']['jobId'];
        _showSnackBar('Job queued successfully!');
        
        // Reset inputs
        _selectedFiles.remove(type);
        _urlController.clear();
        _markdownController.clear();
        _csvController.clear();

        // Select the newly created job and refresh
        setState(() {
          _selectedJobId = jobId;
        });
        await _loadJobs();
        if (_selectedJobId != null) {
          _loadJobStatusAndItems(_selectedJobId!);
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

  Future<void> _saveItemChanges(String itemId) async {
    final updates = _editedItems[itemId];
    if (updates == null || updates.isEmpty) return;

    try {
      final response = await _apiService.updateImportItem(itemId, updates);
      if (response['success'] == true) {
        _showSnackBar('Item updated.');
        setState(() {
          // Remove from edited state to reset indicator
          _editedItems.remove(itemId);
          
          // Update the local item object in list
          final index = _jobItems.indexWhere((it) => it['_id'] == itemId);
          if (index != -1) {
            _jobItems[index] = response['data'];
          }
        });
      } else {
        _showSnackBar(response['message'] ?? 'Failed to update item.', isError: true);
      }
    } catch (e) {
      _showSnackBar('Error updating item: $e', isError: true);
    }
  }

  Future<void> _processBatchVerification() async {
    if (_selectedJobId == null) return;

    // Save any pending unsaved inline edits first
    if (_editedItems.isNotEmpty) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Unsaved Edits'),
          content: const Text('You have unsaved changes in some questions. Do you want to save them before proceeding?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Discard Edits')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save & Continue')),
          ],
        ),
      );

      if (confirm == true) {
        // Sequentially save all edited items
        final itemIds = List<String>.from(_editedItems.keys);
        for (final id in itemIds) {
          await _saveItemChanges(id);
        }
      }
    }

    final confirmIds = _selectedItemIdsForBatch.toList();
    final rejectIds = _jobItems
        .where((it) => it['status'] == 'pending_verification' && !_selectedItemIdsForBatch.contains(it['_id']))
        .map((it) => it['_id'].toString())
        .toList();

    if (confirmIds.isEmpty && rejectIds.isEmpty) {
      _showSnackBar('No pending items to process.', isError: true);
      return;
    }

    setState(() => _isLoadingItems = true);

    try {
      final response = await _apiService.confirmImportItems(
        _selectedJobId!,
        confirmItemIds: confirmIds,
        rejectItemIds: rejectIds,
      );

      if (response['success'] == true) {
        final data = response['data'];
        _showSnackBar(
          'Batch completed. Confirmed: ${data['saved']}, Rejected: ${data['rejected']}, Failed: ${data['failed']}',
        );
        // Reload job and items to sync status
        await _loadJobs();
        await _loadJobStatusAndItems(_selectedJobId!);
      } else {
        _showSnackBar(response['message'] ?? 'Verification failed.', isError: true);
      }
    } catch (e) {
      _showSnackBar('Error confirming items: $e', isError: true);
    } finally {
      setState(() => _isLoadingItems = false);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? const Color(0xFFBA1A1A) : const Color(0xFF43A047),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Premium Dark Mode Base
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Import Questions',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: () {
              _loadJobs();
              if (_selectedJobId != null) {
                _loadJobStatusAndItems(_selectedJobId!);
              }
            },
          )
        ],
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left panel: Import Panel & History List
          Expanded(
            flex: 2,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 8, 12, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildUploadContainer(),
                  const SizedBox(height: 24),
                  _buildHistoryList(),
                ],
              ),
            ),
          ),
          // Right panel: Preview & Editing Table/Form
          Expanded(
            flex: 3,
            child: Container(
              decoration: const BoxDecoration(
                border: Border(left: BorderSide(color: Color(0xFF1E293B), width: 1)),
              ),
              child: _selectedJobId == null
                  ? const Center(
                      child: Text(
                        'Select an import job from the history list to preview and verify questions.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xFF64748B), fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                    )
                  : _buildPreviewPanel(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadContainer() {
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'New Import Source',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TabBar(
              controller: _tabController,
              isScrollable: true,
              labelColor: const Color(0xFF38BDF8),
              unselectedLabelColor: const Color(0xFF64748B),
              indicatorColor: const Color(0xFF38BDF8),
              tabs: const [
                Tab(text: 'PDF', icon: Icon(Icons.picture_as_pdf_rounded)),
                Tab(text: 'Image', icon: Icon(Icons.image_rounded)),
                Tab(text: 'URL', icon: Icon(Icons.link_rounded)),
                Tab(text: 'Markdown', icon: Icon(Icons.code_rounded)),
                Tab(text: 'CSV', icon: Icon(Icons.table_chart_rounded)),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 260,
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
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: LinearProgressIndicator(
                      value: _uploadProgress,
                      backgroundColor: const Color(0xFF1E293B),
                      valueColor: const AlwaysStoppedAnimation(Color(0xFF38BDF8)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${(_uploadProgress * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPDFTab() {
    final pdf = _selectedFiles['pdf'];
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (pdf == null) ...[
          IconButton(
            icon: const Icon(Icons.cloud_upload_rounded, size: 60, color: Color(0xFF64748B)),
            onPressed: _pickPDF,
          ),
          const SizedBox(height: 10),
          const Text('Select PDF file to upload and parse', style: TextStyle(color: Color(0xFF94A3B8))),
        ] else ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.picture_as_pdf_rounded, color: Colors.red, size: 28),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  pdf.path.split('/').last,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _pickPDF,
            child: const Text('Change File', style: TextStyle(color: Color(0xFF38BDF8))),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _isUploading ? null : () => _submitImport('pdf'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0051D5),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Process PDF', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E293B)),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.photo_library_rounded),
                label: const Text('Gallery'),
                onPressed: () => _pickImage(ImageSource.gallery),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E293B)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text('Upload question images for OCR extraction', style: TextStyle(color: Color(0xFF94A3B8))),
        ] else ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.image_rounded, color: Colors.green, size: 28),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  img.path.split('/').last,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: () => _pickImage(ImageSource.camera),
                child: const Text('Retake Camera', style: TextStyle(color: Color(0xFF38BDF8))),
              ),
              TextButton(
                onPressed: () => _pickImage(ImageSource.gallery),
                child: const Text('Browse Gallery', style: TextStyle(color: Color(0xFF38BDF8))),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _isUploading ? null : () => _submitImport('image'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0051D5),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Process Image', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
            prefixIcon: const Icon(Icons.link_rounded, color: Color(0xFF64748B)),
            enabledBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: Color(0xFF1E293B)),
              borderRadius: BorderRadius.circular(12),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: Color(0xFF38BDF8)),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Extract questions from public online resources',
          style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: _isUploading ? null : () => _submitImport('url'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0051D5),
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('Import from URL', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
            minLines: 6,
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
                borderSide: const BorderSide(color: Color(0xFF1E293B)),
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: Color(0xFF38BDF8)),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: _isUploading ? null : () => _submitImport('markdown'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0051D5),
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('Parse Markdown', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
            minLines: 6,
            decoration: InputDecoration(
              labelText: 'Paste CSV Data (Comma separated)',
              labelStyle: const TextStyle(color: Color(0xFF64748B)),
              hintText: r'''QuestionText,Option A,Option B,Option C,Option D,CorrectAnswer,ClassNo,ChapterName,Language,Explanation
"What is $1+1$?",1,2,3,4,B,12,General,English,"1+1 is 2"''',
              hintStyle: const TextStyle(color: Color(0xFF475569)),
              enabledBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: Color(0xFF1E293B)),
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: Color(0xFF38BDF8)),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: _isUploading ? null : () => _submitImport('csv'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0051D5),
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('Parse CSV Data', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildHistoryList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Import History / Jobs',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        if (_isLoadingJobs && _jobs.isEmpty)
          const Center(child: CircularProgressIndicator())
        else if (_jobs.isEmpty)
          const Text('No recent import jobs found.', style: TextStyle(color: Color(0xFF64748B)))
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _jobs.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final job = _jobs[index];
              final jobId = job['_id'];
              final status = job['status'];
              final type = job['importType'].toString().toUpperCase();
              final date = DateTime.parse(job['createdAt']).toLocal();
              final isSelected = _selectedJobId == jobId;

              Color statusColor = Colors.grey;
              if (status == 'queued') statusColor = Colors.orange;
              if (status == 'parsing') statusColor = Colors.blue;
              if (status == 'preview_ready') statusColor = Colors.green;
              if (status == 'partially_saved') statusColor = Colors.teal;
              if (status == 'saved') statusColor = Colors.indigo;
              if (status == 'failed') statusColor = Colors.red;

              return InkWell(
                onTap: () {
                  setState(() {
                    _selectedJobId = jobId;
                    _selectedJob = job;
                    _editedItems.clear();
                  });
                  _loadJobStatusAndItems(jobId);
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF1E293B) : const Color(0xFF131C2E),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? const Color(0xFF38BDF8) : const Color(0xFF1E293B),
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
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
                              style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                          Text(
                            '${date.day}/${date.month} ${date.hour}:${date.minute.toString().padLeft(2, '0')}',
                            style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        job['sourceFileName'] ?? 'Source Data',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.label_outline, color: const Color(0xFF38BDF8).withValues(alpha: 0.7), size: 14),
                          const SizedBox(width: 4),
                          Text(
                            'Type: $type',
                            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                          ),
                          const Spacer(),
                          if (job['totalItems'] > 0)
                            Text(
                              'Items: ${job['savedItems'] ?? 0}/${job['totalItems']}',
                              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.w600),
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

  Widget _buildPreviewPanel() {
    if (_selectedJob == null) return const SizedBox();

    final status = _selectedJob!['status'];
    final error = _selectedJob!['errorMessage'];

    return Column(
      children: [
        // Job Overview Header
        Container(
          padding: const EdgeInsets.all(24),
          color: const Color(0xFF131C2E),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _selectedJob!['sourceFileName'] ?? 'Job Preview',
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                  _buildStatusBadge(status),
                ],
              ),
              if (error != null) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Error: $error',
                          style: const TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Text(
                    'Extracted Questions count: ${_jobItems.length}',
                    style: const TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
                  ),
                  const Spacer(),
                  if (['preview_ready', 'partially_saved'].contains(status)) ...[
                    ElevatedButton.icon(
                      icon: const Icon(Icons.done_all_rounded, color: Colors.white),
                      label: const Text('Apply Batch Actions', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF38BDF8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _isLoadingItems ? null : _processBatchVerification,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),

        // Items List
        Expanded(
          child: _isLoadingItems
              ? const Center(child: CircularProgressIndicator())
              : _jobItems.isEmpty
                  ? const Center(
                      child: Text(
                        'No questions parsed from this source yet.',
                        style: TextStyle(color: Color(0xFF64748B), fontSize: 15),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(24),
                      itemCount: _jobItems.length,
                      itemBuilder: (context, index) {
                        final item = _jobItems[index];
                        return _buildItemCard(item, index + 1);
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color = Colors.grey;
    if (status == 'preview_ready') color = Colors.green;
    if (status == 'partially_saved') color = Colors.teal;
    if (status == 'saved') color = Colors.indigo;
    if (status == 'failed') color = Colors.red;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11),
      ),
    );
  }

  Widget _buildItemCard(dynamic item, int displayNum) {
    final itemId = item['_id'];
    final status = item['status'];
    
    // Check if item has edits
    final hasUnsavedEdits = _editedItems.containsKey(itemId);

    // Initial values or current edited values
    final questionText = _editedItems[itemId]?['questionText'] ?? item['questionText'] ?? '';
    final List<dynamic> options = _editedItems[itemId]?['options'] ?? item['options'] ?? ['', '', '', ''];
    final correctAnswer = _editedItems[itemId]?['correctAnswer'] ?? item['correctAnswer'] ?? 'A';
    final classNo = _editedItems[itemId]?['classNo'] ?? item['classNo'] ?? 12;
    final chapterName = _editedItems[itemId]?['chapterName'] ?? item['chapterName'] ?? 'General';
    final language = _editedItems[itemId]?['language'] ?? item['language'] ?? 'English';
    final explanation = _editedItems[itemId]?['explanation'] ?? item['explanation'] ?? '';

    final isPending = status == 'pending_verification';
    final isSaved = status == 'saved';
    final isRejected = status == 'rejected';

    final dupInfo = item['duplicateInfo'] ?? {};
    final isDuplicate = dupInfo['detected'] == true;
    final similarity = dupInfo['similarity'] != null ? (dupInfo['similarity'] * 100).toStringAsFixed(0) : '0';

    return Card(
      color: const Color(0xFF131C2E),
      margin: const EdgeInsets.only(bottom: 20),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isSaved
              ? Colors.indigo.withValues(alpha: 0.4)
              : isRejected
                  ? Colors.red.withValues(alpha: 0.4)
                  : hasUnsavedEdits
                      ? const Color(0xFF38BDF8)
                      : const Color(0xFF1E293B),
          width: hasUnsavedEdits ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
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
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(width: 12),
                _buildItemStatusIndicator(status),
                const Spacer(),
                if (hasUnsavedEdits) ...[
                  TextButton.icon(
                    icon: const Icon(Icons.save_rounded, size: 16, color: Color(0xFF38BDF8)),
                    label: const Text('Save Edits', style: TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold)),
                    onPressed: () => _saveItemChanges(itemId),
                  ),
                ],
              ],
            ),
            const Divider(color: Color(0xFF1E293B), height: 24),

            // Duplicate warning banner
            if (isDuplicate) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.amber),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Warning: Duplicate Detected ($similarity% similarity to existing question). Check carefully before verifying.',
                        style: const TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Question Text Input
            const Text('Question Text', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            TextField(
              controller: TextEditingController(text: questionText)
                ..selection = TextSelection.fromPosition(TextPosition(offset: questionText.length)),
              enabled: isPending,
              style: const TextStyle(color: Colors.white),
              maxLines: null,
              onChanged: (val) {
                _updateEditState(itemId, 'questionText', val);
              },
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF0F172A),
                enabledBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Color(0xFF1E293B)),
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Color(0xFF38BDF8)),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // LaTeX live rendering preview
            if (questionText.toString().contains('\$') || questionText.toString().contains('\\')) ...[
              const Text('LaTeX Live Render Preview:', style: TextStyle(color: Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF1E293B)),
                ),
                child: LaTeXWidget(text: questionText),
              ),
              const SizedBox(height: 16),
            ],

            // Options Inputs
            const Text('Options', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            for (int i = 0; i < 4; i++) ...[
              Row(
                children: [
                  Radio<String>(
                    value: String.fromCharCode(65 + i),
                    groupValue: correctAnswer,
                    activeColor: const Color(0xFF38BDF8),
                    onChanged: isPending
                        ? (val) {
                            setState(() {
                              _updateEditState(itemId, 'correctAnswer', val);
                            });
                          }
                        : null,
                  ),
                  Text(
                    '${String.fromCharCode(65 + i)})',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: TextEditingController(text: options[i])
                        ..selection = TextSelection.fromPosition(TextPosition(offset: options[i].toString().length)),
                      enabled: isPending,
                      style: const TextStyle(color: Colors.white),
                      onChanged: (val) {
                        final list = List<String>.from(options);
                        list[i] = val;
                        _updateEditState(itemId, 'options', list);
                      },
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFF0F172A),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        enabledBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: Color(0xFF1E293B)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: Color(0xFF38BDF8)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 12),

            // Metadata row
            Row(
              children: [
                Expanded(
                  child: _buildClassDropdown(
                    selectedClass: classNo,
                    enabled: isPending,
                    onChanged: (val) {
                      setState(() {
                        _updateEditState(itemId, 'classNo', val);
                        
                        // Pick default chapter for new class
                        final provider = Provider.of<QuestionProvider>(context, listen: false);
                        final chaps = provider.getChaptersForClass(val!);
                        final defaultChap = chaps.isNotEmpty ? chaps.first : 'General';
                        _updateEditState(itemId, 'chapterName', defaultChap);
                      });
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
            const Text('Explanation', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            TextField(
              controller: TextEditingController(text: explanation)
                ..selection = TextSelection.fromPosition(TextPosition(offset: explanation.toString().length)),
              enabled: isPending,
              style: const TextStyle(color: Colors.white),
              onChanged: (val) {
                _updateEditState(itemId, 'explanation', val);
              },
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF0F172A),
                enabledBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Color(0xFF1E293B)),
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Color(0xFF38BDF8)),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            
            // Error Message (If database validation failed during confirmation)
            if (item['errorMessage'] != null) ...[
              const SizedBox(height: 12),
              Text(
                'Verification Error: ${item['errorMessage']}',
                style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildItemStatusIndicator(String status) {
    Color color = Colors.grey;
    IconData icon = Icons.pending_rounded;

    if (status == 'saved') {
      color = Colors.indigo;
      icon = Icons.check_circle_rounded;
    } else if (status == 'rejected') {
      color = Colors.red;
      icon = Icons.cancel_rounded;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 4),
        Text(
          status.toUpperCase(),
          style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11),
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
        const SizedBox(height: 4),
        DropdownButtonFormField<int>(
          value: selectedClass,
          onChanged: enabled ? onChanged : null,
          dropdownColor: const Color(0xFF131C2E),
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFF0F172A),
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            enabledBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: Color(0xFF1E293B)),
              borderRadius: BorderRadius.circular(8),
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
        const SizedBox(height: 4),
        DropdownButtonFormField<String>(
          value: selectedChapter,
          isExpanded: true,
          onChanged: enabled ? onChanged : null,
          dropdownColor: const Color(0xFF131C2E),
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFF0F172A),
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            enabledBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: Color(0xFF1E293B)),
              borderRadius: BorderRadius.circular(8),
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
        const SizedBox(height: 4),
        DropdownButtonFormField<String>(
          value: selectedLanguage,
          onChanged: enabled ? onChanged : null,
          dropdownColor: const Color(0xFF131C2E),
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFF0F172A),
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            enabledBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: Color(0xFF1E293B)),
              borderRadius: BorderRadius.circular(8),
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

  void _updateEditState(String itemId, String fieldName, dynamic value) {
    if (!_editedItems.containsKey(itemId)) {
      _editedItems[itemId] = {};
    }
    setState(() {
      _editedItems[itemId]![fieldName] = value;
    });
  }
}
