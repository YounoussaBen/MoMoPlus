import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/app_config.dart';

/// Thin HTTP client for Django backend endpoints.
///
/// Auth flow: the frontend obtains a Supabase access token and sends it as
/// `Authorization: Bearer <token>`. Django verifies the token, syncs the local
/// user row automatically on every protected request, and returns data.
/// [syncUser] is an explicit call right after sign-in to hydrate the backend
/// profile in one predictable round-trip; it is not strictly required since any
/// protected endpoint triggers the same sync.
class BackendApiService {
  final String _baseUrl = AppConfig.backendUrl;
  final SupabaseClient _supabaseClient;

  BackendApiService(this._supabaseClient);

  String? get _accessToken => _supabaseClient.auth.currentSession?.accessToken;

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    if (_accessToken != null) 'Authorization': 'Bearer $_accessToken',
  };

  /// Explicitly hydrate the backend Django user row after sign-in.
  Future<void> syncUser() async {
    if (_accessToken == null) return;
    final uri = Uri.parse('$_baseUrl/api/auth/sync/');
    await http.post(uri, headers: _headers);
  }

  /// Inform the backend of logout (backend is stateless; client discards the token).
  Future<void> logout() async {
    if (_accessToken == null) return;
    final uri = Uri.parse('$_baseUrl/api/auth/logout/');
    await http.post(uri, headers: _headers);
  }

  /// Fetch the backend profile for the authenticated user.
  Future<Map<String, dynamic>?> getProfile() async {
    if (_accessToken == null) return null;
    final uri = Uri.parse('$_baseUrl/api/auth/profile/');
    final response = await http.get(uri, headers: _headers);
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    return null;
  }

  /// Fetch the current user's KYC submission status.
  Future<Map<String, dynamic>?> getKycStatus() async {
    if (_accessToken == null) return null;
    final uri = Uri.parse('$_baseUrl/api/kyc/status/');
    final response = await http.get(uri, headers: _headers);
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    return null;
  }

  /// Step 1: Ask Django to create a pending FileAsset and return a signed Supabase upload URL.
  Future<Map<String, dynamic>> initiateUpload({
    required String originalName,
    required String contentType,
    required int size,
    required String kind,
  }) async {
    if (_accessToken == null) throw Exception('Not authenticated.');
    final uri = Uri.parse('$_baseUrl/api/files/');
    final response = await http.post(
      uri,
      headers: _headers,
      body: jsonEncode({
        'original_name': originalName,
        'content_type': contentType,
        'size': size,
        'kind': kind,
        'visibility': 'private',
      }),
    );
    if (response.statusCode != 201) {
      throw _buildApiException(response, 'Failed to initiate file upload.');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Step 2: Upload bytes using Supabase's signed upload API.
  Future<void> uploadToSignedUrl({
    required String bucket,
    required String path,
    required String token,
    required String contentType,
    required List<int> bytes,
  }) async {
    try {
      await _supabaseClient.storage
          .from(bucket)
          .uploadBinaryToSignedUrl(
            path,
            token,
            Uint8List.fromList(bytes),
            FileOptions(contentType: contentType),
          );
    } on StorageException catch (error) {
      throw Exception('Direct upload to storage failed: ${error.message}');
    }
  }

  /// Step 3: Tell Django the upload is done; it verifies the object and marks the file ready.
  Future<void> finalizeUpload(String fileAssetId) async {
    if (_accessToken == null) throw Exception('Not authenticated.');
    final uri = Uri.parse('$_baseUrl/api/files/$fileAssetId/complete/');
    final response = await http.post(uri, headers: _headers);
    if (response.statusCode != 200) {
      throw _buildApiException(response, 'Failed to finalize file upload.');
    }
  }

  /// Submit KYC using pre-uploaded file asset IDs (JSON, no multipart).
  Future<void> submitKyc({
    required String idType,
    required String idFrontId,
    required String idBackId,
    required String selfieId,
    required String proofOfAddressId,
  }) async {
    if (_accessToken == null) throw Exception('Not authenticated.');
    final uri = Uri.parse('$_baseUrl/api/kyc/submit/');
    final response = await http.post(
      uri,
      headers: _headers,
      body: jsonEncode({
        'id_type': idType,
        'id_front_id': idFrontId,
        'id_back_id': idBackId,
        'selfie_id': selfieId,
        'proof_of_address_id': proofOfAddressId,
      }),
    );
    if (response.statusCode != 200) {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      throw Exception(decoded['detail'] ?? 'KYC submission failed.');
    }
  }

  /// Fetch a short-lived signed URL to read a private file asset.
  Future<String?> getFileAccessUrl(String fileAssetId) async {
    if (_accessToken == null) return null;
    final uri = Uri.parse('$_baseUrl/api/files/$fileAssetId/access-url/');
    final response = await http.post(uri, headers: _headers);
    if (response.statusCode != 200) return null;
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return body['url'] as String?;
  }

  /// Permanently delete a file asset.
  Future<void> deleteFile(String fileAssetId) async {
    if (_accessToken == null) return;
    final uri = Uri.parse('$_baseUrl/api/files/$fileAssetId/');
    await http.delete(uri, headers: _headers);
  }

  /// Fetch the in-progress KYC wizard draft from the server.
  Future<Map<String, dynamic>> getKycDraft() async {
    if (_accessToken == null) return {};
    final uri = Uri.parse('$_baseUrl/api/kyc/draft/');
    final response = await http.get(uri, headers: _headers);
    if (response.statusCode != 200) return {};
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Persist the in-progress KYC wizard draft to the server.
  Future<void> saveKycDraft(Map<String, dynamic> draft) async {
    if (_accessToken == null) return;
    final uri = Uri.parse('$_baseUrl/api/kyc/draft/save/');
    await http.put(uri, headers: _headers, body: jsonEncode(draft));
  }

  /// Submit an application to become an agent.
  Future<void> requestAgent() async {
    if (_accessToken == null) return;
    final uri = Uri.parse('$_baseUrl/api/auth/request-agent/');
    final response = await http.post(uri, headers: _headers);
    if (response.statusCode != 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      throw Exception(body['detail'] ?? 'Failed to submit agent application.');
    }
  }

  // ── Wallets ──────────────────────────────────────────────────────────────

  Future<List<dynamic>> getWallets() async {
    if (_accessToken == null) return [];
    final uri = Uri.parse('$_baseUrl/api/wallets/');
    final response = await http.get(uri, headers: _headers);
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as List<dynamic>;
    }
    return [];
  }

  Future<Map<String, dynamic>> addWallet({
    required String phoneNumber,
    required String network,
  }) async {
    if (_accessToken == null) throw Exception('Not authenticated.');
    final uri = Uri.parse('$_baseUrl/api/wallets/add/');
    final response = await http.post(
      uri,
      headers: _headers,
      body: jsonEncode({'phone_number': phoneNumber, 'network': network}),
    );
    if (response.statusCode != 201) {
      throw _buildApiException(response, 'Failed to add wallet.');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> verifyWalletOtp({
    required String walletId,
    required String code,
  }) async {
    if (_accessToken == null) throw Exception('Not authenticated.');
    final uri = Uri.parse('$_baseUrl/api/wallets/$walletId/verify/');
    final response = await http.post(
      uri,
      headers: _headers,
      body: jsonEncode({'code': code}),
    );
    if (response.statusCode != 200) {
      throw _buildApiException(response, 'OTP verification failed.');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<void> resendWalletOtp(String walletId) async {
    if (_accessToken == null) return;
    final uri = Uri.parse('$_baseUrl/api/wallets/$walletId/resend-otp/');
    final response = await http.post(uri, headers: _headers);
    if (response.statusCode != 200) {
      throw _buildApiException(response, 'Failed to resend OTP.');
    }
  }

  Future<Map<String, dynamic>> setDefaultWallet(String walletId) async {
    if (_accessToken == null) throw Exception('Not authenticated.');
    final uri = Uri.parse('$_baseUrl/api/wallets/$walletId/set-default/');
    final response = await http.post(uri, headers: _headers);
    if (response.statusCode != 200) {
      throw _buildApiException(response, 'Failed to set default wallet.');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<void> deleteWallet(String walletId) async {
    if (_accessToken == null) return;
    final uri = Uri.parse('$_baseUrl/api/wallets/$walletId/');
    final response = await http.delete(uri, headers: _headers);
    if (response.statusCode != 204) {
      throw _buildApiException(response, 'Failed to delete wallet.');
    }
  }

  Exception _buildApiException(http.Response response, String fallbackMessage) {
    try {
      final body = jsonDecode(response.body);
      if (body is Map<String, dynamic>) {
        final detail =
            body['detail'] ??
            body['message'] ??
            body['error_description'] ??
            body['error'];
        if (detail is String && detail.isNotEmpty) {
          return Exception(detail);
        }
      }
    } catch (_) {}
    return Exception(fallbackMessage);
  }
}
