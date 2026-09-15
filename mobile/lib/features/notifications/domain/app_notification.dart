class AppNotification {
  final String id;
  final String kind;
  final String title;
  final String message;
  final bool isRead;
  final DateTime? readAt;
  final String resourceType;
  final String resourceId;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.kind,
    required this.title,
    required this.message,
    required this.isRead,
    required this.readAt,
    required this.resourceType,
    required this.resourceId,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    final createdAt = DateTime.tryParse(json['created_at'] as String? ?? '');
    final readAt = DateTime.tryParse(json['read_at'] as String? ?? '');
    return AppNotification(
      id: json['id'] as String,
      kind: json['kind'] as String? ?? '',
      title: json['title'] as String? ?? '',
      message: json['message'] as String? ?? '',
      isRead: json['is_read'] as bool? ?? false,
      readAt: readAt?.toLocal(),
      resourceType: json['resource_type'] as String? ?? '',
      resourceId: json['resource_id'] as String? ?? '',
      createdAt: (createdAt ?? DateTime.now()).toLocal(),
    );
  }
}
