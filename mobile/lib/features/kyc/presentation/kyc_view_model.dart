import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../auth/presentation/auth_view_model.dart';
import '../../../core/utils/error_helpers.dart';
import '../data/kyc_repository.dart';
import '../data/kyc_submission_model.dart';

enum KycScreenState { loading, wizard, pending, rejected, approved, error }

class FileUploadState {
  /// Either a local file path (just picked) or a signed https URL (restored from server).
  final String displayPath;
  final String? assetId;
  final bool uploading;
  final String? error;

  const FileUploadState({
    required this.displayPath,
    this.assetId,
    this.uploading = false,
    this.error,
  });

  FileUploadState copyWith({String? assetId, bool? uploading, String? error}) =>
      FileUploadState(
        displayPath: displayPath,
        assetId: assetId ?? this.assetId,
        uploading: uploading ?? this.uploading,
        error: error,
      );

  bool get isReady => assetId != null && !uploading;
}

class KycViewModel extends ChangeNotifier {
  final KycRepositoryContract _repository;
  final AuthViewModel _authViewModel;
  final ImagePicker _picker = ImagePicker();

  KycScreenState _screenState = KycScreenState.loading;
  KycSubmission? _submission;
  String? _errorMessage;
  bool _isSubmitting = false;
  bool _isGoingHome = false;
  bool _isRefreshing = false;
  Timer? _draftSaveTimer;

  int _step = 0;
  String _ghanaCardNumber = '';
  FileUploadState? _idFront;
  FileUploadState? _idBack;
  FileUploadState? _selfie;
  FileUploadState? _proofOfAddress;

  KycViewModel({
    required KycRepositoryContract repository,
    required AuthViewModel authViewModel,
    bool autoLoad = true,
  }) : _repository = repository,
       _authViewModel = authViewModel {
    if (autoLoad) unawaited(refreshStatus(showLoading: true));
  }

  KycScreenState get screenState => _screenState;
  KycSubmission? get submission => _submission;
  String? get errorMessage => _errorMessage;
  bool get isSubmitting => _isSubmitting;
  bool get isGoingHome => _isGoingHome;
  bool get isRefreshing => _isRefreshing;
  int get step => _step;
  String get ghanaCardNumber => _ghanaCardNumber;
  bool get isGhanaCardNumberValid => RegExp(
    r'^GHA(?:[\s-]?\d){10}$',
    caseSensitive: false,
  ).hasMatch(_ghanaCardNumber.trim());

  FileUploadState? get idFront => _idFront;
  FileUploadState? get idBack => _idBack;
  FileUploadState? get selfie => _selfie;
  FileUploadState? get proofOfAddress => _proofOfAddress;

  bool get canAdvanceStep1 =>
      isGhanaCardNumberValid &&
      (_idFront?.isReady ?? false) &&
      (_idBack?.isReady ?? false);
  bool get canAdvanceStep2 => _selfie?.isReady ?? false;
  bool get canSubmit => _proofOfAddress?.isReady ?? false;

  // ─── Lifecycle ────────────────────────────────────────────────────────────

  Future<void> refreshStatus({bool showLoading = false}) async {
    if (_isRefreshing) return;

    final previousState = _screenState;
    _isRefreshing = true;
    _errorMessage = null;
    if (showLoading) _screenState = KycScreenState.loading;
    notifyListeners();

    try {
      final submission = await _repository.getStatus();
      if (submission == null) {
        await _loadDraft();
        _submission = null;
        _screenState = KycScreenState.wizard;
      } else {
        _submission = submission;
        _screenState = _parseState(submission.status);
        await _authViewModel.refreshProfile();
      }
    } catch (error) {
      _errorMessage = friendlyErrorMessage(error);
      _screenState = !showLoading && previousState == KycScreenState.pending
          ? KycScreenState.pending
          : KycScreenState.error;
    } finally {
      _isRefreshing = false;
      notifyListeners();
    }
  }

  Future<void> _saveDraft() async {
    try {
      final draft = <String, dynamic>{
        'step': _step,
        if (_ghanaCardNumber.isNotEmpty) 'ghana_card_number': _ghanaCardNumber,
        if (_idFront?.assetId != null) 'id_front_id': _idFront!.assetId,
        if (_idBack?.assetId != null) 'id_back_id': _idBack!.assetId,
        if (_selfie?.assetId != null) 'selfie_id': _selfie!.assetId,
        if (_proofOfAddress?.assetId != null)
          'proof_of_address_id': _proofOfAddress!.assetId,
      };
      await _repository.saveDraft(draft);
    } catch (_) {}
  }

  Future<void> _loadDraft() async {
    try {
      final draft = await _repository.getDraft();
      if (draft.isEmpty) return;
      _step = (draft['step'] as int?) ?? 0;
      _ghanaCardNumber = draft['ghana_card_number'] as String? ?? '';
      await Future.wait([
        if (draft['id_front_id'] != null)
          _restoreSlot(draft['id_front_id'] as String, (s) => _idFront = s),
        if (draft['id_back_id'] != null)
          _restoreSlot(draft['id_back_id'] as String, (s) => _idBack = s),
        if (draft['selfie_id'] != null)
          _restoreSlot(draft['selfie_id'] as String, (s) => _selfie = s),
        if (draft['proof_of_address_id'] != null)
          _restoreSlot(
            draft['proof_of_address_id'] as String,
            (s) => _proofOfAddress = s,
          ),
      ]);
    } catch (_) {}
  }

  Future<void> _clearDraft() async {
    try {
      await _repository.saveDraft({});
    } catch (_) {}
  }

  KycScreenState _parseState(String status) => switch (status) {
    'pending' => KycScreenState.pending,
    'approved' => KycScreenState.approved,
    'rejected' => KycScreenState.rejected,
    _ => KycScreenState.wizard,
  };

  // ─── Restore files from a saved submission ────────────────────────────────

  /// Fetch signed URLs for each file in the submission and populate the wizard slots.
  /// Called when entering the resubmit wizard so existing uploads are visible.
  Future<void> _restoreFromSubmission(KycSubmission submission) async {
    _ghanaCardNumber = submission.ghanaCardNumber;
    await Future.wait([
      if (submission.idFrontId != null)
        _restoreSlot(submission.idFrontId!, (s) => _idFront = s),
      if (submission.idBackId != null)
        _restoreSlot(submission.idBackId!, (s) => _idBack = s),
      if (submission.selfieId != null)
        _restoreSlot(submission.selfieId!, (s) => _selfie = s),
      if (submission.proofOfAddressId != null)
        _restoreSlot(submission.proofOfAddressId!, (s) => _proofOfAddress = s),
    ]);
  }

  Future<void> _restoreSlot(
    String assetId,
    void Function(FileUploadState) setter,
  ) async {
    try {
      final url = await _repository.getFileAccessUrl(assetId);
      if (url != null) {
        setter(FileUploadState(displayPath: url, assetId: assetId));
      }
    } catch (_) {
      // Non-critical — the slot stays empty and the user can re-upload.
    }
  }

  // ─── Navigation ───────────────────────────────────────────────────────────

  void setGhanaCardNumber(String value) {
    _ghanaCardNumber = value.toUpperCase();
    _draftSaveTimer?.cancel();
    _draftSaveTimer = Timer(const Duration(milliseconds: 400), _saveDraft);
    notifyListeners();
  }

  void nextStep() {
    if (_step < 2) {
      _step++;
      _saveDraft();
      notifyListeners();
    }
  }

  void prevStep() {
    if (_step > 0) {
      _step--;
      _saveDraft();
      notifyListeners();
    }
  }

  // ─── Upload ───────────────────────────────────────────────────────────────

  /// Shared upload logic for gallery selections and the dedicated selfie camera screen.
  ///
  /// [getState] / [setState] address the specific slot so there is no ambiguity
  /// when two slots share the same [kind] (both Ghana Card sides use 'ghana_card').
  Future<void> _uploadFile({
    required File file,
    required String kind,
    required String contentType,
    required FileUploadState? Function() getState,
    required void Function(FileUploadState?) setState,
  }) async {
    // Remember the previous asset so we can delete it after the new one is confirmed.
    final previousAssetId = getState()?.assetId;

    setState(FileUploadState(displayPath: file.path, uploading: true));
    notifyListeners();

    try {
      final assetId = await _repository.uploadFile(file, kind, contentType);
      setState(getState()!.copyWith(assetId: assetId, uploading: false));
      unawaited(_saveDraft());

      // Delete the replaced asset — fire-and-forget, failure is non-critical.
      if (previousAssetId != null) {
        _repository.deleteFile(previousAssetId).catchError((_) {});
      }
    } catch (e) {
      setState(
        getState()!.copyWith(uploading: false, error: friendlyErrorMessage(e)),
      );
    }
    notifyListeners();
  }

  Future<void> _pickAndUpload({
    required ImageSource source,
    required String kind,
    required String contentType,
    required FileUploadState? Function() getState,
    required void Function(FileUploadState?) setState,
  }) async {
    XFile? pickedFile;
    try {
      pickedFile = await _picker.pickImage(source: source, imageQuality: 90);
    } catch (e) {
      _errorMessage = 'Could not open image picker: ${friendlyErrorMessage(e)}';
      notifyListeners();
      return;
    }
    if (pickedFile == null) return;

    await _uploadFile(
      file: File(pickedFile.path),
      kind: kind,
      contentType: contentType,
      getState: getState,
      setState: setState,
    );
  }

  Future<void> pickIdFront() async {
    await _pickAndUpload(
      source: ImageSource.gallery,
      kind: 'ghana_card',
      contentType: 'image/jpeg',
      getState: () => _idFront,
      setState: (s) => _idFront = s,
    );
  }

  Future<void> pickIdBack() async {
    await _pickAndUpload(
      source: ImageSource.gallery,
      kind: 'ghana_card',
      contentType: 'image/jpeg',
      getState: () => _idBack,
      setState: (s) => _idBack = s,
    );
  }

  Future<void> uploadSelfieFile(File file) async {
    await _uploadFile(
      file: file,
      kind: 'selfie',
      contentType: 'image/jpeg',
      getState: () => _selfie,
      setState: (s) => _selfie = s,
    );
  }

  Future<void> pickProofOfAddress() async {
    await _pickAndUpload(
      source: ImageSource.gallery,
      kind: 'document',
      contentType: 'image/jpeg',
      getState: () => _proofOfAddress,
      setState: (s) => _proofOfAddress = s,
    );
  }

  // ─── Submit ───────────────────────────────────────────────────────────────

  Future<void> submit() async {
    if (!canAdvanceStep1 || !canAdvanceStep2 || !canSubmit) return;
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _repository.submit(
        ghanaCardNumber: _ghanaCardNumber.trim(),
        idFrontId: _idFront!.assetId!,
        idBackId: _idBack!.assetId!,
        selfieId: _selfie!.assetId!,
        proofOfAddressId: _proofOfAddress!.assetId!,
      );
      await _authViewModel.refreshProfile();
      await _clearDraft();
      final submission = await _repository.getStatus();
      if (submission != null) {
        _submission = submission;
        _screenState = _parseState(submission.status);
      } else {
        _screenState = KycScreenState.pending;
      }
    } catch (e) {
      _errorMessage = friendlyErrorMessage(e);
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  /// Enter the resubmit wizard, pre-populated with files from the rejected submission.
  Future<void> startResubmit() async {
    await _clearDraft();
    _step = 0;
    _ghanaCardNumber = '';
    _idFront = null;
    _idBack = null;
    _selfie = null;
    _proofOfAddress = null;
    _errorMessage = null;
    _screenState = KycScreenState.wizard;
    notifyListeners();

    if (_submission != null) {
      await _restoreFromSubmission(_submission!);
      notifyListeners();
    }
  }

  Future<void> goHome() async {
    if (_isGoingHome) return;

    _isGoingHome = true;
    notifyListeners();

    try {
      await _authViewModel.refreshProfile();
      await _authViewModel.acknowledgeKycApproval();
    } finally {
      _isGoingHome = false;
      notifyListeners();
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _draftSaveTimer?.cancel();
    super.dispose();
  }
}
