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
      // 1600px is still high quality for Mathpix but much safer for RAM
      final XFile? photo = await _picker.pickImage(
        source: source,
      );

      if (photo == null) return null;

      // 2. Open Crop Screen
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: photo.path,
        compressFormat: ImageCompressFormat.jpg,
        compressQuality: 80,
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
      debugPrint("ImageService Error: $e");
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
