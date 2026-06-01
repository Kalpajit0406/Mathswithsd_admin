import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';

class ImageService {
  final ImagePicker _picker = ImagePicker();

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

      final file = File(croppedFile.path);
      final length = await file.length();
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
      return File(croppedFile.path);
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
