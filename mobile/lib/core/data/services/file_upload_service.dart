import 'dart:io';
import 'backend_api_service.dart';

/// Reusable 3-step file upload service.
///
/// Usage from any feature:
///   final id = await fileUploadService.upload(file: file, kind: 'ghana_card', contentType: 'image/jpeg');
///
/// Steps performed internally:
///   1. POST /api/files/ — Django creates a pending FileAsset and returns a signed Supabase URL.
///   2. PUT signed_url   — client streams bytes directly to Supabase Storage.
///   3. POST /api/files/{id}/complete/ — Django verifies the object and marks the asset ready.
class FileUploadService {
  final BackendApiService _api;

  const FileUploadService(this._api);

  /// Upload [file] and return the file asset ID once the backend confirms it is ready.
  Future<String> upload({
    required File file,
    required String kind,
    required String contentType,
  }) async {
    final bytes = await file.readAsBytes();
    final name = file.path.split('/').last;
    String? fileAssetId;

    try {
      // Step 1 — Django creates the asset and signs the Supabase upload URL.
      final initiated = await _api.initiateUpload(
        originalName: name,
        contentType: contentType,
        size: bytes.length,
        kind: kind,
      );

      fileAssetId = (initiated['file'] as Map<String, dynamic>)['id'] as String;
      final upload = initiated['upload'] as Map<String, dynamic>;
      final signedUrl = upload['signed_url'] as String?;
      if (signedUrl == null || signedUrl.isEmpty) {
        throw Exception('The storage service did not return an upload URL.');
      }

      // Step 2 — upload directly to the URL issued by Django/Supabase.
      await _api.uploadToSignedUrl(
        signedUrl: signedUrl,
        contentType: contentType,
        bytes: bytes,
      );

      // Step 3 — Django verifies the object and marks the asset ready.
      await _api.finalizeUpload(fileAssetId);

      return fileAssetId;
    } catch (error) {
      // Do not leave orphaned pending assets when an upload or finalization
      // fails. Cleanup is best-effort; the original error is more useful.
      final cleanupId = fileAssetId;
      if (cleanupId != null) {
        try {
          await _api.deleteFile(cleanupId);
        } catch (_) {}
      }
      rethrow;
    }
  }

  /// Fetch a short-lived signed URL so a private file can be displayed.
  Future<String?> getAccessUrl(String fileAssetId) =>
      _api.getFileAccessUrl(fileAssetId);

  /// Delete a file asset from storage and the backend record.
  Future<void> deleteAsset(String fileAssetId) => _api.deleteFile(fileAssetId);
}
