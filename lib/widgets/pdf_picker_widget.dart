import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';

import '../providers/question_provider.dart';

/// PDF Document Picker Widget
///
/// Features:
/// - Select PDF, DOCX, PPTX, EPUB files
/// - Show file preview with size
/// - Progress indication during upload
/// - Error handling with retry
/// - Extraction progress with polling
class PdfPickerWidget extends StatefulWidget {
  final Function(String pdfId)? onPdfSelected;
  final Function(List<dynamic> questions, String sessionId)?
  onQuestionsExtracted;
  final bool enableDirectExtraction;

  const PdfPickerWidget({
    super.key,
    this.onPdfSelected,
    this.onQuestionsExtracted,
    this.enableDirectExtraction = true,
  });

  @override
  State<PdfPickerWidget> createState() => _PdfPickerWidgetState();
}

class _PdfPickerWidgetState extends State<PdfPickerWidget> {
  File? _selectedFile;
  final bool _isUploading = false;
  bool _isExtracting = false;
  double _uploadProgress = 0.0;
  String? _errorMessage;
  String? _statusMessage;

  final List<String> _supportedFormats = [
    'pdf',
    'docx',
    'pptx',
    'epub',
    'doc',
    'pages',
  ];

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            SizedBox(height: 12),
            if (_selectedFile != null) ...[
              _buildFilePreview(),
              SizedBox(height: 16),
            ],
            if (_errorMessage != null) ...[
              _buildErrorBanner(),
              SizedBox(height: 12),
            ],
            if (_statusMessage != null) ...[
              _buildStatusBanner(),
              SizedBox(height: 12),
            ],
            if (_isUploading || _isExtracting) ...[
              _buildProgressIndicator(),
              SizedBox(height: 12),
            ],
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Icon(Icons.description_outlined, color: Colors.blue, size: 28),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Upload PDF or Document',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              Text(
                'PDF, DOCX, PPTX, EPUB supported',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFilePreview() {
    final fileSize = _selectedFile!.lengthSync();
    final fileSizeMB = (fileSize / (1024 * 1024)).toStringAsFixed(2);
    final fileName = _selectedFile!.path.split('/').last;
    final fileExtension = fileName.split('.').last.toUpperCase();

    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.insert_drive_file, color: Colors.blue, size: 32),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        fileExtension,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    Text(
                      '$fileSizeMB MB',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (!_isUploading && !_isExtracting)
            IconButton(
              icon: Icon(Icons.close),
              onPressed: () {
                setState(() {
                  _selectedFile = null;
                  _errorMessage = null;
                });
              },
            ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              _errorMessage ?? 'Unknown error',
              style: TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBanner() {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.orange),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              _statusMessage ?? '',
              style: TextStyle(color: Colors.orange[700], fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_isUploading) ...[
          Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(Colors.blue),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  _isExtracting ? 'Processing document...' : 'Uploading...',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _uploadProgress,
              minHeight: 6,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation(Colors.blue),
            ),
          ),
          SizedBox(height: 8),
          Text(
            '${(_uploadProgress * 100).toStringAsFixed(1)}%',
            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
          ),
        ] else if (_isExtracting) ...[
          Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(Colors.purple),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Extracting questions...',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _isUploading || _isExtracting ? null : _pickFile,
            icon: Icon(Icons.folder_open),
            label: Text('Choose File'),
          ),
        ),
        SizedBox(width: 12),
        if (_selectedFile != null && widget.enableDirectExtraction)
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _isUploading || _isExtracting
                  ? null
                  : _extractQuestions,
              icon: Icon(Icons.cloud_upload),
              label: Text('Upload & Extract'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            ),
          ),
      ],
    );
  }

  Future<void> _pickFile() async {
    try {
      // Request file picker permissions
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: _supportedFormats,
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _selectedFile = File(result.files.first.path!);
          _errorMessage = null;
          _statusMessage = null;
        });

        // Auto-extract if enabled
        if (widget.enableDirectExtraction && mounted) {
          _extractQuestions();
        }
      }
    } catch (error) {
      setState(() {
        _errorMessage = 'Failed to pick file: $error';
      });
    }
  }

  Future<void> _extractQuestions() async {
    if (_selectedFile == null) {
      setState(() {
        _errorMessage = 'No file selected';
      });
      return;
    }

    setState(() {
      _isExtracting = true;
      _uploadProgress = 0.0;
      _errorMessage = null;
      _statusMessage = 'Uploading document...';
    });

    try {
      final provider = Provider.of<QuestionProvider>(context, listen: false);

      // Upload and extract questions
      final result = await provider.uploadPdfAndExtractQuestions(
        _selectedFile!,
        onProgress: (progress) {
          if (mounted) {
            setState(() {
              _uploadProgress = progress;
              _statusMessage =
                  'Uploading... ${(progress * 100).toStringAsFixed(1)}%';
            });
          }
        },
      );

      if (result != null && mounted) {
        setState(() {
          _isExtracting = false;
          _statusMessage = 'Extracted ${result['totalQuestions']} questions!';
        });

        // Notify parent
        if (result['pdfId'] != null) {
          widget.onPdfSelected?.call(result['pdfId']);
        }

        if (result['questions'] != null && result['sessionId'] != null) {
          widget.onQuestionsExtracted?.call(
            result['questions'],
            result['sessionId'],
          );
        }

        // Auto-dismiss message after 2 seconds
        await Future.delayed(Duration(seconds: 2));
        if (mounted) {
          setState(() {
            _statusMessage = null;
          });
        }
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _isExtracting = false;
          _errorMessage = 'Error: $error';
          _statusMessage = null;
        });
      }
    }
  }
}

/// PDF Extraction Status Widget
/// Shows polling status and progress for PDF processing
class PdfExtractionStatusWidget extends StatefulWidget {
  final String pdfId;
  final Function(Map<String, dynamic>)? onComplete;

  const PdfExtractionStatusWidget({
    super.key,
    required this.pdfId,
    this.onComplete,
  });

  @override
  State<PdfExtractionStatusWidget> createState() =>
      _PdfExtractionStatusWidgetState();
}

class _PdfExtractionStatusWidgetState extends State<PdfExtractionStatusWidget> {
  late Future<void> _statusFuture;

  @override
  void initState() {
    super.initState();
    _statusFuture = _pollStatus();
  }

  Future<void> _pollStatus() async {
    final provider = Provider.of<QuestionProvider>(context, listen: false);

    while (mounted) {
      try {
        final status = await provider.getPdfStatus(widget.pdfId);

        if (status['status'] == 'completed') {
          widget.onComplete?.call(status);
          break;
        }

        await Future.delayed(Duration(seconds: 2));
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error checking status: $error')),
          );
        }
        break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _statusFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Processing document...'),
              ],
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48, color: Colors.red),
                SizedBox(height: 16),
                Text('Error: ${snapshot.error}'),
              ],
            ),
          );
        }

        return SizedBox.shrink();
      },
    );
  }
}
