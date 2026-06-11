import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class ImageService {
  final ImagePicker _picker = ImagePicker();

  /// Copies [source] into the app's temporary directory so the file is
  /// guaranteed to survive until the upload completes (Android can evict
  /// ImageCropper's cache files at any time, producing a 0-byte read).
  Future<File> _safeCopyToAppTemp(File source) async {
    final tmpDir = await getTemporaryDirectory();
    final destDir = Directory(p.join(tmpDir.path, 'ocr_uploads'));
    if (!destDir.existsSync()) destDir.createSync(recursive: true);

    // Use timestamp so concurrent picks never collide
    final ext = p.extension(source.path).isNotEmpty ? p.extension(source.path) : '.jpg';
    final dest = File(p.join(destDir.path, 'img_${DateTime.now().millisecondsSinceEpoch}$ext'));
    await source.copy(dest.path);
    return dest;
  }

  Future<File?> pickAndCropImage(BuildContext context, {ImageSource source = ImageSource.camera}) async {
    final primaryColor = Theme.of(context).primaryColor;
    try {
      // 1. Pick Image with resolution constraints to save memory
      // 3000px provides ultra high quality for OCR formulas while being safe on 4GB RAM devices
      final XFile? photo = await _picker.pickImage(
        source: source,
        maxWidth: 3000,
        maxHeight: 3000,
        imageQuality: 95,
      );

      if (photo == null) return null;

      // 2. Open Crop Screen
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: photo.path,
        compressFormat: ImageCompressFormat.jpg,
        compressQuality: 90,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Question',
            toolbarColor: primaryColor,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.original,
            lockAspectRatio: false,
            aspectRatioPresets: [
              CropAspectRatioPreset.original,
              CropAspectRatioPreset.square,
              CropAspectRatioPreset.ratio3x2,
              CropAspectRatioPreset.ratio4x3,
              CropAspectRatioPreset.ratio16x9,
            ],
          ),
          IOSUiSettings(
            title: 'Crop Question',
            aspectRatioPresets: [
              CropAspectRatioPreset.original,
              CropAspectRatioPreset.square,
              CropAspectRatioPreset.ratio3x2,
              CropAspectRatioPreset.ratio4x3,
              CropAspectRatioPreset.ratio16x9,
            ],
          ),
        ],
      );

      if (croppedFile == null) return null;

      // 3. Copy to stable app temp dir — prevents 0-byte reads caused by
      //    Android evicting ImageCropper's cache between crop and upload.
      final file = await _safeCopyToAppTemp(File(croppedFile.path));

      final length = await file.length();
      debugPrint('[ImageService] Copied cropped file: ${file.path} ($length bytes)');

      if (length == 0) {
        debugPrint('[ImageService] WARNING: copied file is still 0 bytes!');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Image could not be read. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return null;
      }

      if (length > 2 * 1024 * 1024) {
        if (context.mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: const [
                  Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
                  SizedBox(width: 8),
                  Text('Photo Too Large'),
                ],
              ),
              content: const Text(
                'The selected image exceeds the maximum allowed size of 2 MB.\n\n'
                'Please crop the image more closely or reduce the image size/quality and try again.',
                style: TextStyle(fontSize: 14),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0051D5))),
                ),
              ],
            ),
          );
        }
        return null;
      }

      return file;
    } catch (e) {
      debugPrint("ImageService Error: $e");
      return null;
    }
  }

  Future<File?> cropExistingImage(BuildContext context, File imageFile) async {
    final primaryColor = Theme.of(context).primaryColor;
    try {
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: imageFile.path,
        compressFormat: ImageCompressFormat.jpg,
        compressQuality: 90,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Question',
            toolbarColor: primaryColor,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.original,
            lockAspectRatio: false,
            aspectRatioPresets: [
              CropAspectRatioPreset.original,
              CropAspectRatioPreset.square,
              CropAspectRatioPreset.ratio3x2,
              CropAspectRatioPreset.ratio4x3,
              CropAspectRatioPreset.ratio16x9,
            ],
          ),
          IOSUiSettings(
            title: 'Crop Question',
            aspectRatioPresets: [
              CropAspectRatioPreset.original,
              CropAspectRatioPreset.square,
              CropAspectRatioPreset.ratio3x2,
              CropAspectRatioPreset.ratio4x3,
              CropAspectRatioPreset.ratio16x9,
            ],
          ),
        ],
      );

      if (croppedFile == null) return null;

      // Copy to stable location so the file survives until it's uploaded
      final file = await _safeCopyToAppTemp(File(croppedFile.path));
      final length = await file.length();
      debugPrint('[ImageService] cropExistingImage copied: ${file.path} ($length bytes)');
      return length > 0 ? file : null;
    } catch (e) {
      debugPrint("cropExistingImage Error: $e");
      return null;
    }
  }

  /// Handles Android specific process death when camera is launched
  Future<XFile?> getLostData() async {
    if (Platform.isAndroid) {
      final LostDataResponse response = await _picker.retrieveLostData();
      if (response.isEmpty) return null;
      return response.file;
    }
    return null;
  }
}
