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

    // Step 1 — initiate
    final initiated = await _api.initiateUpload(
      originalName: name,
      contentType: contentType,
      size: bytes.length,
      kind: kind,
    );

    final fileAssetId =
        (initiated['file'] as Map<String, dynamic>)['id'] as String;
    final upload = initiated['upload'] as Map<String, dynamic>;
    final bucket = upload['bucket'] as String;
    final path = upload['path'] as String;
    final token = upload['token'] as String;

    // Step 2 — direct upload to Supabase
    await _api.uploadToSignedUrl(
      bucket: bucket,
      path: path,
      token: token,
      contentType: contentType,
      bytes: bytes,
    );

    // Step 3 — finalize
    await _api.finalizeUpload(fileAssetId);

    return fileAssetId;
  }

  /// Fetch a short-lived signed URL so a private file can be displayed.
  Future<String?> getAccessUrl(String fileAssetId) =>
      _api.getFileAccessUrl(fileAssetId);

  /// Delete a file asset from storage and the backend record.
  Future<void> deleteAsset(String fileAssetId) => _api.deleteFile(fileAssetId);
}
