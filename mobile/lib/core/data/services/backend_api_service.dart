import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/app_config.dart';

class BackendApiException implements Exception {
  final int statusCode;
  final String message;

  const BackendApiException(this.statusCode, this.message);

  @override
  String toString() => message;
}

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
  Future<Map<String, dynamic>> syncUser() async {
    if (_accessToken == null) throw Exception('Not authenticated.');
    final uri = Uri.parse('$_baseUrl/api/auth/sync/');
    final response = await http.post(uri, headers: _headers);
    if (response.statusCode != 200) {
      throw _buildApiException(
        response,
        'Could not link the authenticated account.',
      );
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return body['user'] as Map<String, dynamic>;
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
    throw _buildApiException(response, 'Could not load your profile.');
  }

  Future<Map<String, dynamic>> updateProfile({
    required String firstName,
    required String lastName,
  }) async {
    if (_accessToken == null) throw Exception('Not authenticated.');
    final uri = Uri.parse('$_baseUrl/api/auth/profile/');
    final response = await http.patch(
      uri,
      headers: _headers,
      body: jsonEncode({'first_name': firstName, 'last_name': lastName}),
    );
    if (response.statusCode != 200) {
      throw _buildApiException(response, 'Could not save your profile.');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
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

  /// Step 2: Upload bytes to the signed Supabase Storage URL issued by Django.
  ///
  /// Keeping this request on the URL returned by the backend makes the mobile
  /// flow identical to the web flow and keeps storage configuration out of the
  /// app. The app only ever receives a short-lived, single-object upload URL.
  Future<void> uploadToSignedUrl({
    required String signedUrl,
    required String contentType,
    required List<int> bytes,
  }) async {
    final response = await http.put(
      Uri.parse(signedUrl),
      headers: {'Content-Type': contentType},
      body: bytes,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Direct upload to storage failed (HTTP ${response.statusCode}).',
      );
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
    required String ghanaCardNumber,
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
        'ghana_card_number': ghanaCardNumber,
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

  // ── Guarantors ───────────────────────────────────────────────────────────

  Future<List<dynamic>> getGuarantors() async {
    if (_accessToken == null) return [];
    final uri = Uri.parse('$_baseUrl/api/auth/guarantors/');
    final response = await http.get(uri, headers: _headers);
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as List<dynamic>;
    }
    return [];
  }

  Future<Map<String, dynamic>> addGuarantor({
    required String name,
    required String phoneNumber,
  }) async {
    if (_accessToken == null) throw Exception('Not authenticated.');
    final uri = Uri.parse('$_baseUrl/api/auth/guarantors/');
    final response = await http.post(
      uri,
      headers: _headers,
      body: jsonEncode({'name': name, 'phone_number': phoneNumber}),
    );
    if (response.statusCode != 201) {
      throw _buildApiException(response, 'Failed to add guarantor.');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<List<dynamic>> bulkCreateGuarantors(
    List<Map<String, String>> guarantors,
  ) async {
    if (_accessToken == null) throw Exception('Not authenticated.');
    final uri = Uri.parse('$_baseUrl/api/auth/guarantors/bulk/');
    final response = await http.post(
      uri,
      headers: _headers,
      body: jsonEncode({'guarantors': guarantors}),
    );
    if (response.statusCode != 201) {
      throw _buildApiException(response, 'Failed to save guarantors.');
    }
    return jsonDecode(response.body) as List<dynamic>;
  }

  Future<Map<String, dynamic>> updateGuarantor(
    String id, {
    String? name,
    String? phoneNumber,
  }) async {
    if (_accessToken == null) throw Exception('Not authenticated.');
    final uri = Uri.parse('$_baseUrl/api/auth/guarantors/$id/');
    final body = <String, String>{};
    if (name != null) body['name'] = name;
    if (phoneNumber != null) body['phone_number'] = phoneNumber;
    final response = await http.put(
      uri,
      headers: _headers,
      body: jsonEncode(body),
    );
    if (response.statusCode != 200) {
      throw _buildApiException(response, 'Failed to update guarantor.');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<void> deleteGuarantor(String id) async {
    if (_accessToken == null) return;
    final uri = Uri.parse('$_baseUrl/api/auth/guarantors/$id/');
    final response = await http.delete(uri, headers: _headers);
    if (response.statusCode != 204) {
      throw _buildApiException(response, 'Cannot remove guarantor.');
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

  // ── Agents ──────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> getAgentProfile() async {
    if (_accessToken == null) return null;
    final uri = Uri.parse('$_baseUrl/api/agents/profile/');
    final response = await http.get(uri, headers: _headers);
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    return null;
  }

  Future<Map<String, dynamic>> updateAgentProfile(
    Map<String, dynamic> fields,
  ) async {
    if (_accessToken == null) throw Exception('Not authenticated.');
    final uri = Uri.parse('$_baseUrl/api/agents/profile/update/');
    final response = await http.put(
      uri,
      headers: _headers,
      body: jsonEncode(fields),
    );
    if (response.statusCode != 200) {
      throw _buildApiException(response, 'Failed to update agent profile.');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> toggleAvailability() async {
    if (_accessToken == null) throw Exception('Not authenticated.');
    final uri = Uri.parse('$_baseUrl/api/agents/profile/toggle-availability/');
    final response = await http.post(uri, headers: _headers);
    if (response.statusCode != 200) {
      throw _buildApiException(response, 'Failed to toggle availability.');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<List<dynamic>> getNearbyAgents({
    required double lat,
    required double lon,
    double radius = 10.0,
    double? minAmount,
    double? maxAmount,
    String sortBy = 'distance',
  }) async {
    if (_accessToken == null) return [];
    final params = <String, String>{
      'lat': lat.toString(),
      'lon': lon.toString(),
      'radius': radius.toString(),
      'sort_by': sortBy,
    };
    if (minAmount != null) params['min_amount'] = minAmount.toString();
    if (maxAmount != null) params['max_amount'] = maxAmount.toString();
    final uri = Uri.parse(
      '$_baseUrl/api/agents/nearby/',
    ).replace(queryParameters: params);
    final response = await http.get(uri, headers: _headers);
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as List<dynamic>;
    }
    return [];
  }

  Future<Map<String, dynamic>?> getAgentDetail(String agentId) async {
    if (_accessToken == null) return null;
    final uri = Uri.parse('$_baseUrl/api/agents/$agentId/');
    final response = await http.get(uri, headers: _headers);
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    return null;
  }

  Future<Map<String, dynamic>> getAgentRoutePreview({
    required double originLatitude,
    required double originLongitude,
    required double destinationLatitude,
    required double destinationLongitude,
  }) async {
    if (_accessToken == null) throw Exception('Not authenticated.');
    final uri = Uri.parse('$_baseUrl/api/agents/route-preview/');
    final response = await http.post(
      uri,
      headers: _headers,
      body: jsonEncode({
        'origin_latitude': originLatitude,
        'origin_longitude': originLongitude,
        'destination_latitude': destinationLatitude,
        'destination_longitude': destinationLongitude,
      }),
    );
    if (response.statusCode != 200) {
      throw _buildApiException(response, 'Failed to load route preview.');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>?> getCertificationStatus() async {
    if (_accessToken == null) return null;
    final uri = Uri.parse('$_baseUrl/api/agents/certification/');
    final response = await http.get(uri, headers: _headers);
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    return null;
  }

  Future<Map<String, dynamic>> applyCertification({
    required String agentIdNumber,
    required String agentIdPhotoId,
    required String businessLocationPhotoId,
    String businessRegistrationNumber = '',
  }) async {
    if (_accessToken == null) throw Exception('Not authenticated.');
    final uri = Uri.parse('$_baseUrl/api/agents/certification/apply/');
    final response = await http.post(
      uri,
      headers: _headers,
      body: jsonEncode({
        'agent_id_number': agentIdNumber,
        'network': 'mtn',
        'agent_id_photo_id': agentIdPhotoId,
        'business_location_photo_id': businessLocationPhotoId,
        'business_registration_number': businessRegistrationNumber,
      }),
    );
    if (response.statusCode != 201) {
      throw _buildApiException(response, 'Failed to submit certification.');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  // ── Physical Transactions ───────────────────────────────────────────────

  Future<Map<String, dynamic>> createPhysicalTransaction({
    required String agentId,
    required String transactionType,
    required String amount,
    required String network,
    required String walletId,
  }) async {
    if (_accessToken == null) throw Exception('Not authenticated.');
    final uri = Uri.parse('$_baseUrl/api/transactions/physical/create/');
    final response = await http.post(
      uri,
      headers: _headers,
      body: jsonEncode({
        'agent_id': agentId,
        'transaction_type': transactionType,
        'amount': amount,
        'network': network,
        'wallet_id': walletId,
      }),
    );
    if (response.statusCode != 201) {
      throw _buildApiException(response, 'Failed to create transaction.');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<List<dynamic>> getPhysicalTransactions({String? status}) async {
    if (_accessToken == null) throw Exception('Not authenticated.');
    final params = <String, String>{};
    if (status != null) params['status'] = status;
    final uri = Uri.parse(
      '$_baseUrl/api/transactions/physical/',
    ).replace(queryParameters: params.isNotEmpty ? params : null);
    final response = await http.get(uri, headers: _headers);
    if (response.statusCode == 200) {
      final payload = jsonDecode(response.body);
      if (payload is List<dynamic>) return payload;
      throw Exception('The server returned an invalid cash-services response.');
    }
    throw _buildApiException(response, 'Could not load cash services.');
  }

  Future<Map<String, dynamic>?> getPhysicalTransactionDetail(
    String transactionId,
  ) async {
    if (_accessToken == null) return null;
    final uri = Uri.parse(
      '$_baseUrl/api/transactions/physical/$transactionId/',
    );
    final response = await http.get(uri, headers: _headers);
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    return null;
  }

  Future<Map<String, dynamic>> acceptPhysicalTransaction(
    String transactionId, {
    required String meetingLatitude,
    required String meetingLongitude,
    String meetingDescription = '',
  }) async {
    if (_accessToken == null) throw Exception('Not authenticated.');
    final uri = Uri.parse(
      '$_baseUrl/api/transactions/physical/$transactionId/accept/',
    );
    final response = await http.post(
      uri,
      headers: _headers,
      body: jsonEncode({
        'meeting_latitude': meetingLatitude,
        'meeting_longitude': meetingLongitude,
        'meeting_description': meetingDescription,
      }),
    );
    if (response.statusCode != 200) {
      throw _buildApiException(response, 'Failed to accept transaction.');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> rejectPhysicalTransaction(
    String transactionId, {
    String reason = '',
  }) async {
    if (_accessToken == null) throw Exception('Not authenticated.');
    final uri = Uri.parse(
      '$_baseUrl/api/transactions/physical/$transactionId/reject/',
    );
    final response = await http.post(
      uri,
      headers: _headers,
      body: jsonEncode({'reason': reason}),
    );
    if (response.statusCode != 200) {
      throw _buildApiException(response, 'Failed to reject transaction.');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> confirmPhysicalTransaction(
    String transactionId, {
    String verificationCode = '',
  }) async {
    if (_accessToken == null) throw Exception('Not authenticated.');
    final uri = Uri.parse(
      '$_baseUrl/api/transactions/physical/$transactionId/confirm/',
    );
    final response = await http.post(
      uri,
      headers: _headers,
      body: jsonEncode({'verification_code': verificationCode}),
    );
    if (response.statusCode != 200) {
      throw _buildApiException(response, 'Failed to confirm transaction.');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> cancelPhysicalTransaction(
    String transactionId, {
    String reason = '',
  }) async {
    if (_accessToken == null) throw Exception('Not authenticated.');
    final uri = Uri.parse(
      '$_baseUrl/api/transactions/physical/$transactionId/cancel/',
    );
    final response = await http.post(
      uri,
      headers: _headers,
      body: jsonEncode({'reason': reason}),
    );
    if (response.statusCode != 200) {
      throw _buildApiException(response, 'Failed to cancel transaction.');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> ratePhysicalTransaction(
    String transactionId, {
    required int rating,
  }) async {
    if (_accessToken == null) throw Exception('Not authenticated.');
    final uri = Uri.parse(
      '$_baseUrl/api/transactions/physical/$transactionId/rate/',
    );
    final response = await http.post(
      uri,
      headers: _headers,
      body: jsonEncode({'rating': rating}),
    );
    if (response.statusCode != 200) {
      throw _buildApiException(response, 'Failed to submit rating.');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  // ── Loans ─────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> requestLoan({
    required String agentId,
    required String amount,
    required String walletId,
    required String network,
  }) async {
    if (_accessToken == null) throw Exception('Not authenticated.');
    final uri = Uri.parse('$_baseUrl/api/loans/request/');
    final response = await http.post(
      uri,
      headers: _headers,
      body: jsonEncode({
        'agent_id': agentId,
        'amount': amount,
        'wallet_id': walletId,
        'network': network,
      }),
    );
    if (response.statusCode != 201) {
      throw _buildApiException(response, 'Failed to request loan.');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<List<dynamic>> getLoans({String? status}) async {
    if (_accessToken == null) throw Exception('Not authenticated.');
    final params = <String, String>{};
    if (status != null) params['status'] = status;
    final uri = Uri.parse(
      '$_baseUrl/api/loans/',
    ).replace(queryParameters: params.isNotEmpty ? params : null);
    final response = await http.get(uri, headers: _headers);
    if (response.statusCode == 200) {
      final payload = jsonDecode(response.body);
      if (payload is List<dynamic>) return payload;
      throw Exception('The server returned an invalid get-funds response.');
    }
    throw _buildApiException(response, 'Could not load get-funds activity.');
  }

  Future<Map<String, dynamic>?> getAgentEarnings({
    String? period,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    if (_accessToken == null) return null;
    final params = <String, String>{};
    if (period != null && period.isNotEmpty) params['period'] = period;
    if (startDate != null) params['start_date'] = _formatQueryDate(startDate);
    if (endDate != null) params['end_date'] = _formatQueryDate(endDate);
    final uri = Uri.parse(
      '$_baseUrl/api/loans/earnings/',
    ).replace(queryParameters: params.isNotEmpty ? params : null);
    final response = await http.get(uri, headers: _headers);
    if (response.statusCode != 200) {
      throw _buildApiException(response, 'Failed to load earnings.');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  // ── Notifications ────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getNotifications() async {
    if (_accessToken == null) throw Exception('Not authenticated.');
    final uri = Uri.parse('$_baseUrl/api/notifications/');
    final response = await http.get(uri, headers: _headers);
    if (response.statusCode != 200) {
      throw _buildApiException(response, 'Could not load notifications.');
    }
    final payload = jsonDecode(response.body);
    if (payload is Map<String, dynamic> && payload['notifications'] is List) {
      return payload;
    }
    throw Exception('The server returned an invalid notifications response.');
  }

  Future<Map<String, dynamic>> setNotificationReadState(
    String notificationId, {
    required bool isRead,
  }) async {
    if (_accessToken == null) throw Exception('Not authenticated.');
    final action = isRead ? 'read' : 'unread';
    final uri = Uri.parse(
      '$_baseUrl/api/notifications/$notificationId/$action/',
    );
    final response = await http.post(uri, headers: _headers);
    if (response.statusCode != 200) {
      throw _buildApiException(response, 'Could not update notification.');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> markAllNotificationsRead() async {
    if (_accessToken == null) throw Exception('Not authenticated.');
    final uri = Uri.parse('$_baseUrl/api/notifications/read-all/');
    final response = await http.post(uri, headers: _headers);
    if (response.statusCode != 200) {
      throw _buildApiException(
        response,
        'Could not mark notifications as read.',
      );
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>?> getLoanDetail(String loanId) async {
    if (_accessToken == null) return null;
    final uri = Uri.parse('$_baseUrl/api/loans/$loanId/');
    final response = await http.get(uri, headers: _headers);
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    return null;
  }

  Future<Map<String, dynamic>> acceptLoan(
    String loanId, {
    required String agentWalletId,
  }) async {
    if (_accessToken == null) throw Exception('Not authenticated.');
    final uri = Uri.parse('$_baseUrl/api/loans/$loanId/accept/');
    final response = await http.post(
      uri,
      headers: _headers,
      body: jsonEncode({'agent_wallet_id': agentWalletId}),
    );
    if (response.statusCode != 200) {
      throw _buildApiException(response, 'Failed to accept loan.');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> rejectLoan(
    String loanId, {
    String reason = '',
  }) async {
    if (_accessToken == null) throw Exception('Not authenticated.');
    final uri = Uri.parse('$_baseUrl/api/loans/$loanId/reject/');
    final response = await http.post(
      uri,
      headers: _headers,
      body: jsonEncode({'reason': reason}),
    );
    if (response.statusCode != 200) {
      throw _buildApiException(response, 'Failed to reject loan.');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> disburseLoan(String loanId) async {
    if (_accessToken == null) throw Exception('Not authenticated.');
    final uri = Uri.parse('$_baseUrl/api/loans/$loanId/disburse/');
    final response = await http.post(uri, headers: _headers);
    if (response.statusCode != 200) {
      throw _buildApiException(response, 'Failed to initiate disbursement.');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> repayLoan(
    String loanId, {
    String? amount,
  }) async {
    if (_accessToken == null) throw Exception('Not authenticated.');
    final uri = Uri.parse('$_baseUrl/api/loans/$loanId/repay/');
    final body = <String, dynamic>{};
    if (amount != null) body['amount'] = amount;
    final response = await http.post(
      uri,
      headers: _headers,
      body: jsonEncode(body),
    );
    if (response.statusCode != 200) {
      throw _buildApiException(response, 'Failed to initiate repayment.');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> cancelLoan(
    String loanId, {
    String reason = '',
  }) async {
    if (_accessToken == null) throw Exception('Not authenticated.');
    final uri = Uri.parse('$_baseUrl/api/loans/$loanId/cancel/');
    final response = await http.post(
      uri,
      headers: _headers,
      body: jsonEncode({'reason': reason}),
    );
    if (response.statusCode != 200) {
      throw _buildApiException(response, 'Failed to cancel loan.');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  BackendApiException _buildApiException(
    http.Response response,
    String fallbackMessage,
  ) {
    try {
      final body = jsonDecode(response.body);
      if (body is Map<String, dynamic>) {
        final detail =
            body['detail'] ??
            body['message'] ??
            body['error_description'] ??
            body['error'];
        if (detail is String && detail.isNotEmpty) {
          return BackendApiException(response.statusCode, detail);
        }
      }
    } catch (_) {}
    return BackendApiException(response.statusCode, fallbackMessage);
  }

  String _formatQueryDate(DateTime value) {
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}
