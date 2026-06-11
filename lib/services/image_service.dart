import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class ImageService {
  final ImagePicker _picker = ImagePicker();

  /// Copies [source] into the app's own temp dir so the file is guaranteed
  /// to survive until the upload completes. Android can evict ImageCropper's
  /// cache files at any time, producing a 0-byte read.
  Future<File> _safeCopyToAppTemp(File source) async {
    final tmpDir = await getTemporaryDirectory();
    final destDir = Directory(p.join(tmpDir.path, 'ocr_uploads'));
    if (!destDir.existsSync()) destDir.createSync(recursive: true);

    final ext = p.extension(source.path).isNotEmpty
        ? p.extension(source.path)
        : '.jpg';
    final dest = File(
      p.join(destDir.path, 'img_${DateTime.now().millisecondsSinceEpoch}$ext'),
    );
    await source.copy(dest.path);
    return dest;
  }

  /// Writes raw [bytes] to a stable file in the app's temp dir.
  /// Used for content:// URIs (Android 10+) where File() gives 0 bytes.
  Future<File> _writeBytesToAppTemp(List<int> bytes,
      {String ext = '.jpg'}) async {
    final tmpDir = await getTemporaryDirectory();
    final destDir = Directory(p.join(tmpDir.path, 'ocr_uploads'));
    if (!destDir.existsSync()) destDir.createSync(recursive: true);

    final dest = File(
      p.join(destDir.path, 'img_${DateTime.now().millisecondsSinceEpoch}$ext'),
    );
    await dest.writeAsBytes(bytes, flush: true);
    return dest;
  }

  Future<File?> pickAndCropImage(
    BuildContext context, {
    ImageSource source = ImageSource.camera,
  }) async {
    final primaryColor = Theme.of(context).primaryColor;
    try {
      // 1. Pick image — resolution constraints keep memory safe on 4 GB devices
      final XFile? photo = await _picker.pickImage(
        source: source,
        maxWidth: 3000,
        maxHeight: 3000,
        imageQuality: 95,
      );

      if (photo == null) return null;

      // 2. Read bytes via XFile (handles content:// URIs on Android 10+)
      final photoBytes = await photo.readAsBytes();
      if (photoBytes.isEmpty) {
        if (kDebugMode) {
          debugPrint('[ImageService] pickImage returned 0-byte file. Aborting.');
        }
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Camera returned an empty image. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return null;
      }

      // 3. Write to stable path so ImageCropper gets a reliable file
      final stablePhoto = await _writeBytesToAppTemp(photoBytes);
      if (kDebugMode) {
        debugPrint('[ImageService] Stable photo size: ${photoBytes.length} bytes');
      }

      // 4. Open crop screen
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: stablePhoto.path,
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

      // 5. Copy cropped result to stable dir (cropper also uses cache)
      final file = await _safeCopyToAppTemp(File(croppedFile.path));
      final length = await file.length();
      if (kDebugMode) {
        debugPrint('[ImageService] Cropped file size: $length bytes');
      }

      if (length == 0) {
        if (kDebugMode) {
          debugPrint('[ImageService] WARNING: cropped file is 0 bytes!');
        }
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
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: const [
                  Icon(Icons.warning_amber_rounded,
                      color: Colors.orange, size: 28),
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
                  child: const Text('OK',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0051D5))),
                ),
              ],
            ),
          );
        }
        return null;
      }

      return file;
    } catch (e) {
      if (kDebugMode) {
        debugPrint("ImageService Error: $e");
      }
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

      // Copy to stable location so the file survives until upload
      final file = await _safeCopyToAppTemp(File(croppedFile.path));
      final length = await file.length();
      if (kDebugMode) {
        debugPrint(
            '[ImageService] cropExistingImage: ($length bytes)');
      }
      return length > 0 ? file : null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint("cropExistingImage Error: $e");
      }
      return null;
    }
  }

  /// Recovers the photo file after Android process-death during camera capture.
  ///
  /// Returns a stable [File] with valid bytes, or null if nothing to recover.
  /// Uses [XFile.readAsBytes()] to properly handle content:// URIs
  /// (Android 10+), which [File(path).readAsBytes()] cannot handle.
  Future<File?> getLostData() async {
    if (!Platform.isAndroid) return null;

    final LostDataResponse response = await _picker.retrieveLostData();
    if (response.isEmpty || response.file == null) return null;

    final xFile = response.file!;
    if (kDebugMode) {
      debugPrint('[ImageService] getLostData: recovering lost image data');
    }

    // XFile.readAsBytes() resolves content:// URIs — File() alone gives 0 bytes
    final bytes = await xFile.readAsBytes();
    if (bytes.isEmpty) {
      if (kDebugMode) {
        debugPrint('[ImageService] getLostData: recovered file is empty!');
      }
      return null;
    }

    final ext = p.extension(xFile.path).isNotEmpty
        ? p.extension(xFile.path)
        : '.jpg';
    final stableFile = await _writeBytesToAppTemp(bytes, ext: ext);
    if (kDebugMode) {
      debugPrint(
          '[ImageService] getLostData: saved ${bytes.length} bytes');
    }
    return stableFile;
  }
}
