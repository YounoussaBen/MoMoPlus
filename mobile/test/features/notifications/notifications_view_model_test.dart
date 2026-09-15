import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momoplus/core/data/services/backend_api_service.dart';
import 'package:momoplus/features/notifications/presentation/notifications_view_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  setUpAll(() {
    dotenv.testLoad(fileInput: 'BACKEND_URL=http://localhost:8000');
  });

  test('loads notifications and keeps unread count in sync', () async {
    final api = _FakeNotificationsApi();
    final viewModel = NotificationsViewModel(api, autoStart: false);
    addTearDown(viewModel.dispose);

    viewModel.setSession('user-a');
    await pumpEventQueue();

    expect(viewModel.notifications, hasLength(2));
    expect(viewModel.unreadCount, 2);

    expect(
      await viewModel.setReadState('notification-1', isRead: true),
      isTrue,
    );
    expect(viewModel.unreadCount, 1);
    expect(viewModel.notifications.first.isRead, isTrue);

    expect(await viewModel.markAllAsRead(), isTrue);
    expect(viewModel.unreadCount, 0);
    expect(viewModel.notifications.every((item) => item.isRead), isTrue);
    expect(api.markAllCalls, 1);
  });

  test('clears notifications when the authenticated session ends', () async {
    final api = _FakeNotificationsApi();
    final viewModel = NotificationsViewModel(api, autoStart: false);
    addTearDown(viewModel.dispose);

    viewModel.setSession('user-a');
    await pumpEventQueue();
    expect(viewModel.notifications, isNotEmpty);

    viewModel.clearSession();

    expect(viewModel.isSessionActive, isFalse);
    expect(viewModel.notifications, isEmpty);
    expect(viewModel.unreadCount, 0);
  });
}

class _FakeNotificationsApi extends BackendApiService {
  _FakeNotificationsApi()
    : super(SupabaseClient('https://example.supabase.co', 'test-anon-key'));

  int markAllCalls = 0;
  final _notifications = <Map<String, dynamic>>[
    {
      'id': 'notification-1',
      'kind': 'loan_request',
      'title': 'New Get Funds request',
      'message': 'A user requested funds.',
      'is_read': false,
      'read_at': null,
      'resource_type': 'loan',
      'resource_id': 'loan-1',
      'created_at': '2026-09-15T10:00:00Z',
    },
    {
      'id': 'notification-2',
      'kind': 'transaction_status',
      'title': 'Cash Service completed',
      'message': 'The cash service is complete.',
      'is_read': false,
      'read_at': null,
      'resource_type': 'transaction',
      'resource_id': 'transaction-1',
      'created_at': '2026-09-15T09:00:00Z',
    },
  ];

  @override
  Future<Map<String, dynamic>> getNotifications() async => {
    'notifications': _notifications,
    'unread_count': _notifications
        .where((item) => item['is_read'] == false)
        .length,
  };

  @override
  Future<Map<String, dynamic>> setNotificationReadState(
    String notificationId, {
    required bool isRead,
  }) async {
    final notification = _notifications.firstWhere(
      (item) => item['id'] == notificationId,
    );
    notification['is_read'] = isRead;
    notification['read_at'] = isRead ? '2026-09-15T11:00:00Z' : null;
    return notification;
  }

  @override
  Future<Map<String, dynamic>> markAllNotificationsRead() async {
    markAllCalls++;
    for (final notification in _notifications) {
      notification['is_read'] = true;
      notification['read_at'] = '2026-09-15T11:00:00Z';
    }
    return {'updated': _notifications.length, 'unread_count': 0};
  }
}
