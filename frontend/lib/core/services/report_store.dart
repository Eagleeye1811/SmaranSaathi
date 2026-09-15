import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// One document the caregiver picked, already copied into app storage.
@immutable
class PickedReport {
  const PickedReport({
    required this.fileName,
    required this.filePath,
    required this.sizeBytes,
  });

  final String fileName;
  final String filePath;
  final int sizeBytes;
}

/// Medical documents the caregiver attaches — an MRI, an EEG trace, a lab
/// result, a discharge summary.
///
/// The sibling of [PhotoStore], and it exists for the same reason: a document
/// picker hands back a path into a cache directory (on Android, often a
/// temporary copy made for the content URI it was given), and the OS is free
/// to empty that whenever it likes. Referencing it would mean a report
/// attached today is a dead link next week, so every pick is copied into the
/// app's own documents directory and only that copy's path is stored.
///
/// Paths, not bytes: a scanned PDF runs to several megabytes, and a Hive box
/// holding them inline would be read into memory in full on every launch.
class ReportStore {
  const ReportStore._();

  static const String _folder = 'medical_reports';

  /// What a medical report actually arrives as. PDFs are the common case —
  /// labs and imaging centres email them — with photographs second, for a
  /// caregiver holding a paper result and no scanner.
  static const List<String> allowedExtensions = <String>[
    'pdf',
    'jpg',
    'jpeg',
    'png',
    'heic',
    'webp',
  ];

  /// Opens the system document picker and stores the chosen file.
  ///
  /// Null on every ordinary non-outcome — the picker dismissed, a permission
  /// declined, nothing chosen — because none of those are errors a caregiver
  /// needs a red banner about. They simply did not attach anything.
  static Future<PickedReport?> pick() async {
    try {
      final FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: allowedExtensions,
        // The bytes are read from disk during the copy below rather than
        // loaded into the result, so a large scan never sits in memory twice.
        withData: false,
        allowMultiple: false,
      );

      final PlatformFile? picked =
          result != null && result.files.isNotEmpty ? result.files.first : null;
      if (picked == null || picked.path == null) return null;

      return await _copyIn(File(picked.path!), picked.name);
    } catch (error) {
      debugPrint('ReportStore: picking a document failed ($error)');
      return null;
    }
  }

  static Future<PickedReport?> _copyIn(File source, String originalName) async {
    try {
      final Directory docs = await getApplicationDocumentsDirectory();
      final Directory dir = Directory('${docs.path}/$_folder');
      if (!dir.existsSync()) await dir.create(recursive: true);

      // Timestamped so attaching two results with the same name from the same
      // lab — "report.pdf" twice — cannot overwrite the first one.
      final String stamp = DateTime.now().millisecondsSinceEpoch.toString();
      final String safeName = _sanitise(originalName);
      final File target = File('${dir.path}/${stamp}_$safeName');

      await source.copy(target.path);
      return PickedReport(
        fileName: originalName,
        filePath: target.path,
        sizeBytes: await target.length(),
      );
    } catch (error) {
      debugPrint('ReportStore: storing a document failed ($error)');
      return null;
    }
  }

  /// Strips anything that could walk out of the folder or upset the file
  /// system. The caregiver-facing name is kept separately on the record, so
  /// this only has to be safe, not pretty.
  static String _sanitise(String name) {
    final String cleaned =
        name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_').replaceAll('..', '_');
    return cleaned.isEmpty ? 'report' : cleaned;
  }

  /// Removes a stored copy. Best effort: a file that is already gone is the
  /// outcome we wanted anyway.
  static Future<void> delete(String? path) async {
    if (path == null || path.isEmpty) return;
    try {
      final File file = File(path);
      if (file.existsSync()) await file.delete();
    } catch (error) {
      debugPrint('ReportStore: deleting a document failed ($error)');
    }
  }

  /// True when the file is still where the record says it is.
  ///
  /// Checked before offering to open one, because a record can outlive its
  /// file: a backup restored onto a new phone brings the list but not the
  /// documents, and a viewer opening nothing explains itself badly.
  static bool exists(String? path) {
    if (path == null || path.isEmpty) return false;
    try {
      return File(path).existsSync();
    } catch (_) {
      return false;
    }
  }
}
