import 'dart:io';
import '../../../core/data/repositories/auth_repository.dart';
import '../../../core/data/services/file_upload_service.dart';
import 'kyc_submission_model.dart';

class KycRepository {
  final AuthRepository _authRepository;
  final FileUploadService _uploadService;

  const KycRepository({
    required AuthRepository authRepository,
    required FileUploadService uploadService,
  }) : _authRepository = authRepository,
       _uploadService = uploadService;

  Future<KycSubmission?> getStatus() async {
    final data = await _authRepository.getKycStatus();
    if (data == null) return null;
    return KycSubmission.fromJson(data);
  }

  /// Upload [file] and return its file asset ID. Delegates to the shared [FileUploadService].
  Future<String> uploadFile(File file, String kind, String contentType) =>
      _uploadService.upload(file: file, kind: kind, contentType: contentType);

  /// Fetch a signed URL to display a private file asset.
  Future<String?> getFileAccessUrl(String assetId) =>
      _uploadService.getAccessUrl(assetId);

  Future<Map<String, dynamic>> getDraft() => _authRepository.getKycDraft();
  Future<void> saveDraft(Map<String, dynamic> draft) =>
      _authRepository.saveKycDraft(draft);

  /// Delete an uploaded file asset (e.g. when the user replaces a document).
  Future<void> deleteFile(String assetId) =>
      _uploadService.deleteAsset(assetId);

  Future<void> submit({
    required String idType,
    required String idFrontId,
    required String idBackId,
    required String selfieId,
    required String proofOfAddressId,
  }) => _authRepository.submitKyc(
    idType: idType,
    idFrontId: idFrontId,
    idBackId: idBackId,
    selfieId: selfieId,
    proofOfAddressId: proofOfAddressId,
  );
}
