import 'dart:io';
import '../../../core/data/repositories/auth_repository.dart';
import '../../../core/data/services/file_upload_service.dart';
import 'kyc_submission_model.dart';

abstract interface class KycRepositoryContract {
  Future<KycSubmission?> getStatus();
  Future<String> uploadFile(File file, String kind, String contentType);
  Future<String?> getFileAccessUrl(String assetId);
  Future<Map<String, dynamic>> getDraft();
  Future<void> saveDraft(Map<String, dynamic> draft);
  Future<void> deleteFile(String assetId);
  Future<void> submit({
    required String ghanaCardNumber,
    required String idFrontId,
    required String idBackId,
    required String selfieId,
    required String proofOfAddressId,
  });
}

class KycRepository implements KycRepositoryContract {
  final AuthRepository _authRepository;
  final FileUploadService _uploadService;

  const KycRepository({
    required AuthRepository authRepository,
    required FileUploadService uploadService,
  }) : _authRepository = authRepository,
       _uploadService = uploadService;

  @override
  Future<KycSubmission?> getStatus() async {
    final data = await _authRepository.getKycStatus();
    if (data == null) return null;
    return KycSubmission.fromJson(data);
  }

  /// Upload [file] and return its file asset ID. Delegates to the shared [FileUploadService].
  @override
  Future<String> uploadFile(File file, String kind, String contentType) =>
      _uploadService.upload(file: file, kind: kind, contentType: contentType);

  /// Fetch a signed URL to display a private file asset.
  @override
  Future<String?> getFileAccessUrl(String assetId) =>
      _uploadService.getAccessUrl(assetId);

  @override
  Future<Map<String, dynamic>> getDraft() => _authRepository.getKycDraft();

  @override
  Future<void> saveDraft(Map<String, dynamic> draft) =>
      _authRepository.saveKycDraft(draft);

  /// Delete an uploaded file asset (e.g. when the user replaces a document).
  @override
  Future<void> deleteFile(String assetId) =>
      _uploadService.deleteAsset(assetId);

  @override
  Future<void> submit({
    required String ghanaCardNumber,
    required String idFrontId,
    required String idBackId,
    required String selfieId,
    required String proofOfAddressId,
  }) => _authRepository.submitKyc(
    ghanaCardNumber: ghanaCardNumber,
    idFrontId: idFrontId,
    idBackId: idBackId,
    selfieId: selfieId,
    proofOfAddressId: proofOfAddressId,
  );
}
