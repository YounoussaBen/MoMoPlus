import 'dart:convert';
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
}
