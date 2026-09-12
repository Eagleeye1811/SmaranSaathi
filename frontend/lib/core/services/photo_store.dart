import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

/// Real photographs the caregiver adds — family faces, places, occasions.
///
/// The picker hands back a file in a cache directory the OS is free to empty,
/// so nothing is ever referenced there: every picked image is copied into the
/// app's own documents directory first, and only that copy's path is stored.
/// A photograph of someone's mother should not disappear because Android
/// reclaimed some space.
///
/// Paths, not bytes: family photographs run to several megabytes each, and a
/// Hive box holding a dozen of them would be read into memory in full every
/// time the profile loads.
class PhotoStore {
  const PhotoStore._();

  static const String _folder = 'memory_photos';

  static final ImagePicker _picker = ImagePicker();

  /// Picks from the gallery or the camera and returns the stored copy's path.
  ///
  /// Null on every ordinary non-outcome — the picker dismissed, no camera, a
  /// permission declined — because none of those are errors a caregiver needs
  /// a red banner about. They simply did not add a photo.
  static Future<String?> pick({required bool fromCamera, required String id}) async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: fromCamera ? ImageSource.camera : ImageSource.gallery,
        // Generous enough for a face on a large phone, small enough that a
        // dozen of them do not fill a cheap device. The originals stay in the
        // gallery untouched.
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );
      if (picked == null) return null;
      return await _copyIn(picked, id);
    } catch (error) {
      debugPrint('PhotoStore: picking a photo failed ($error)');
      return null;
    }
  }

  static Future<String?> _copyIn(XFile picked, String id) async {
    try {
      final Directory docs = await getApplicationDocumentsDirectory();
      final Directory dir = Directory('${docs.path}/$_folder');
      if (!dir.existsSync()) await dir.create(recursive: true);

      // The id plus a timestamp: re-picking a photo for the same record has
      // to land on a new file, or the old image stays in the widget cache and
      // the caregiver sees the picture they just replaced.
      final String name = '${id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final File file = File('${dir.path}/$name');
      await file.writeAsBytes(await picked.readAsBytes(), flush: true);
      return file.path;
    } catch (error) {
      debugPrint('PhotoStore: storing a photo failed ($error)');
      return null;
    }
  }

  /// Removes a stored copy. Best effort: a photo that is already gone is the
  /// outcome we wanted anyway.
  static Future<void> delete(String? path) async {
    if (path == null || path.isEmpty) return;
    try {
      final File file = File(path);
      if (file.existsSync()) await file.delete();
    } catch (error) {
      debugPrint('PhotoStore: deleting a photo failed ($error)');
    }
  }

  /// True when the file is still where the record says it is.
  ///
  /// Checked before rendering, because a record can outlive its file: a
  /// backup restored onto a new phone brings the profile but not the
  /// pictures, and a broken `Image.file` is a grey box with no explanation.
  static bool exists(String? path) {
    if (path == null || path.isEmpty) return false;
    try {
      return File(path).existsSync();
    } catch (_) {
      return false;
    }
  }
}
