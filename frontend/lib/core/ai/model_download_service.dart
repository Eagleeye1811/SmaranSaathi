import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Fetches the fine-tuned Mitra GGUF model onto this device, once, so
/// [LlamaOnDeviceAiService] can run it with no network afterward.
///
/// Deliberately NOT automatic: this is a caregiver-triggered, explicit
/// download (an "Enable offline AI" toggle) rather than something that starts
/// silently in the background — the file is ~800MB, and this app's users are
/// assumed to be on limited/metered rural connections. See
/// `core/ai/gemini_ai_service.dart` for the online counterpart; this is the
/// offline half of the same `AiService` contract.
class ModelDownloadService {
  ModelDownloadService({
    // Filled in once the GGUF is pushed to Hugging Face Hub — see the
    // "Optional: upload to Hugging Face Hub" cell in backend/SmaranSaathi.ipynb.
    // A resolve URL looks like:
    //   https://huggingface.co/<user>/<repo>/resolve/main/<file>.gguf
    this.downloadUrl = '',
    // Fill in once the final GGUF is hashed (`sha256sum` on the exported
    // file) — this catches a truncated/corrupted download before the app
    // ever tries to load it.
    this.expectedSha256,
    this.fileName = 'mitra-llama3.2-1b-q4km.gguf',
  });

  /// Reads `MITRA_MODEL_URL` / `MITRA_MODEL_SHA256` the same way [AiConfig]
  /// reads its own settings: `--dart-define` first, falling back to whatever
  /// `main.dart` loaded from `.env`. Empty/unset until the trained GGUF is
  /// actually pushed to Hugging Face Hub and those values are filled in.
  factory ModelDownloadService.fromEnvironment() {
    const String defineUrl = String.fromEnvironment('MITRA_MODEL_URL');
    const String defineSha = String.fromEnvironment('MITRA_MODEL_SHA256');

    String fromDotenv(String key) =>
        dotenv.isInitialized ? (dotenv.env[key]?.trim() ?? '') : '';

    String envOr(String defineValue, String dotenvKey) =>
        defineValue.isNotEmpty ? defineValue : fromDotenv(dotenvKey);

    final String url = envOr(defineUrl, 'MITRA_MODEL_URL');
    final String sha = envOr(defineSha, 'MITRA_MODEL_SHA256');

    return ModelDownloadService(downloadUrl: url, expectedSha256: sha.isEmpty ? null : sha);
  }

  final String downloadUrl;
  final String? expectedSha256;
  final String fileName;

  bool get isConfigured => downloadUrl.isNotEmpty;

  Future<File> _targetFile() async {
    final Directory dir = await getApplicationSupportDirectory();
    return File('${dir.path}/$fileName');
  }

  /// The path to hand to `fllama` once the model is on disk, or null if it
  /// isn't downloaded (or verified) yet.
  Future<String?> readyModelPath() async {
    final File file = await _targetFile();
    if (!await file.exists()) return null;
    if (await file.length() == 0) return null;
    return file.path;
  }

  Future<bool> get isDownloaded async => (await readyModelPath()) != null;

  /// Downloads the model, emitting progress in `[0.0, 1.0]`. Throws if
  /// [downloadUrl] is unset, the request fails, or the checksum (when
  /// [expectedSha256] is set) doesn't match — the caller is expected to
  /// delete the partial file on error, which this does automatically.
  Stream<double> download() async* {
    if (!isConfigured) {
      throw StateError('ModelDownloadService: no downloadUrl configured yet.');
    }

    final File target = await _targetFile();
    final File partial = File('${target.path}.part');
    final http.Client client = http.Client();

    try {
      final http.StreamedResponse response =
          await client.send(http.Request('GET', Uri.parse(downloadUrl)));
      if (response.statusCode != 200) {
        throw HttpException('Model download failed: HTTP ${response.statusCode}');
      }

      final int? total = response.contentLength;
      final IOSink sink = partial.openWrite();
      int received = 0;

      await for (final List<int> chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (total != null && total > 0) {
          yield received / total;
        }
      }
      await sink.flush();
      await sink.close();

      if (expectedSha256 != null) {
        final Digest digest = sha256.convert(await partial.readAsBytes());
        if (digest.toString() != expectedSha256) {
          await partial.delete();
          throw const FormatException(
              'Downloaded model failed checksum verification — deleted, please retry.');
        }
      }

      if (await target.exists()) await target.delete();
      await partial.rename(target.path);
      yield 1.0;
    } catch (_) {
      if (await partial.exists()) await partial.delete();
      rethrow;
    } finally {
      client.close();
    }
  }

  Future<void> deleteDownloadedModel() async {
    final File file = await _targetFile();
    if (await file.exists()) await file.delete();
  }
}

/// Thrown by [ModelDownloadService.download] when the HTTP response itself
/// signals failure. Kept tiny and local rather than pulling in a whole
/// exceptions module for one type.
class HttpException implements Exception {
  const HttpException(this.message);
  final String message;
  @override
  String toString() => message;
}
