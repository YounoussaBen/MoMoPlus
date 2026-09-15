import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/data/services/backend_api_service.dart';
import '../../../core/utils/error_helpers.dart';
import '../domain/app_notification.dart';

const _notificationsRefreshInterval = Duration(seconds: 10);

class NotificationsViewModel extends ChangeNotifier {
  final BackendApiService _api;

  List<AppNotification> _notifications = [];
  String? _sessionId;
  bool _isSessionActive = false;
  bool _isLoading = false;
  bool _isUpdating = false;
  String? _errorMessage;
  int _unreadCount = 0;
  int _sessionGeneration = 0;
  bool _isDisposed = false;
  Timer? _refreshTimer;
  Future<void>? _loadFuture;

  NotificationsViewModel(this._api, {bool autoStart = true}) {
    if (autoStart) _startSession();
  }

  List<AppNotification> get notifications => List.unmodifiable(_notifications);
  int get unreadCount => _unreadCount;
  bool get isLoading => _isLoading;
  bool get isUpdating => _isUpdating;
  String? get errorMessage => _errorMessage;
  bool get isSessionActive => _isSessionActive;

  void setSession(String? sessionId) {
    if (sessionId == null) {
      clearSession();
      return;
    }
    if (_isSessionActive && _sessionId == sessionId) return;
    _startSession(sessionId: sessionId);
  }

  Future<void> load() async {
    if (!_isSessionActive || _isDisposed) return;
    final inFlight = _loadFuture;
    if (inFlight != null) return inFlight;

    final generation = _sessionGeneration;
    final future = _loadInternal(generation);
    _loadFuture = future;
    unawaited(
      future.whenComplete(() {
        if (identical(_loadFuture, future)) _loadFuture = null;
      }),
    );
    return future;
  }

  Future<void> _loadInternal(int generation) async {
    _isLoading = _notifications.isEmpty;
    _errorMessage = null;
    _notifyListeners();
    try {
      final payload = await _api.getNotifications();
      if (!_isCurrentSession(generation)) return;
      final rawNotifications = payload['notifications'];
      if (rawNotifications is! List) {
        throw Exception(
          'The server returned an invalid notifications response.',
        );
      }
      _notifications = rawNotifications
          .whereType<Map<String, dynamic>>()
          .map(AppNotification.fromJson)
          .toList();
      final serverUnread = payload['unread_count'];
      _unreadCount = serverUnread is int
          ? serverUnread
          : _notifications.where((notification) => !notification.isRead).length;
    } catch (error) {
      if (!_isCurrentSession(generation)) return;
      _errorMessage = friendlyErrorMessage(error);
    } finally {
      if (_isCurrentSession(generation)) {
        _isLoading = false;
        _notifyListeners();
      }
    }
  }

  Future<bool> setReadState(
    String notificationId, {
    required bool isRead,
  }) async {
    if (!_isSessionActive || _isDisposed || _isUpdating) return false;
    final generation = _sessionGeneration;
    _isUpdating = true;
    _errorMessage = null;
    _notifyListeners();
    try {
      final data = await _api.setNotificationReadState(
        notificationId,
        isRead: isRead,
      );
      if (!_isCurrentSession(generation)) return false;
      final updated = AppNotification.fromJson(data);
      final index = _notifications.indexWhere(
        (item) => item.id == notificationId,
      );
      if (index >= 0) {
        _notifications[index] = updated;
      }
      _unreadCount = _notifications.where((item) => !item.isRead).length;
      _notifyListeners();
      return true;
    } catch (error) {
      if (!_isCurrentSession(generation)) return false;
      _errorMessage = friendlyErrorMessage(error);
      return false;
    } finally {
      if (_isCurrentSession(generation)) {
        _isUpdating = false;
        _notifyListeners();
      }
    }
  }

  Future<bool> markAllAsRead() async {
    if (!_isSessionActive || _isDisposed || _isUpdating || _unreadCount == 0) {
      return false;
    }
    final generation = _sessionGeneration;
    _isUpdating = true;
    _errorMessage = null;
    _notifyListeners();
    try {
      await _api.markAllNotificationsRead();
      if (!_isCurrentSession(generation)) return false;
      final now = DateTime.now();
      _notifications = _notifications
          .map(
            (item) => item.isRead
                ? item
                : AppNotification(
                    id: item.id,
                    kind: item.kind,
                    title: item.title,
                    message: item.message,
                    isRead: true,
                    readAt: now,
                    resourceType: item.resourceType,
                    resourceId: item.resourceId,
                    createdAt: item.createdAt,
                  ),
          )
          .toList();
      _unreadCount = 0;
      _notifyListeners();
      return true;
    } catch (error) {
      if (!_isCurrentSession(generation)) return false;
      _errorMessage = friendlyErrorMessage(error);
      return false;
    } finally {
      if (_isCurrentSession(generation)) {
        _isUpdating = false;
        _notifyListeners();
      }
    }
  }

  void startAutoRefresh() {
    if (!_isSessionActive || _refreshTimer != null || _isDisposed) return;
    _refreshTimer = Timer.periodic(
      _notificationsRefreshInterval,
      (_) => unawaited(load()),
    );
  }

  void stopAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  void clearSession() {
    if (_isDisposed) return;
    stopAutoRefresh();
    _sessionGeneration++;
    _sessionId = null;
    _isSessionActive = false;
    _loadFuture = null;
    _notifications = [];
    _unreadCount = 0;
    _isLoading = false;
    _isUpdating = false;
    _errorMessage = null;
    _notifyListeners();
  }

  void _startSession({String? sessionId}) {
    clearSession();
    _sessionId = sessionId;
    _isSessionActive = true;
    startAutoRefresh();
    unawaited(load());
  }

  bool _isCurrentSession(int generation) =>
      !_isDisposed && _isSessionActive && generation == _sessionGeneration;

  void _notifyListeners() {
    if (!_isDisposed) notifyListeners();
  }

  @override
  void dispose() {
    if (_isDisposed) return;
    stopAutoRefresh();
    _isSessionActive = false;
    _loadFuture = null;
    _isDisposed = true;
    super.dispose();
  }
}
