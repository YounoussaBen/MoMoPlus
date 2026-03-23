class PhysicalTransaction {
  final String id;
  final String transactionType;
  final double amount;
  final String network;
  final String status;
  final String? verificationCode;
  final double? meetingLatitude;
  final double? meetingLongitude;
  final String? meetingDescription;
  final bool userConfirmed;
  final bool agentConfirmed;
  final String userName;
  final String agentName;
  final String agentId;
  final String walletPhoneNumber;
  final String walletNetwork;
  final String? cancellationReason;
  final DateTime createdAt;
  final DateTime? completedAt;
  final DateTime expiresAt;

  const PhysicalTransaction({
    required this.id,
    required this.transactionType,
    required this.amount,
    required this.network,
    required this.status,
    this.verificationCode,
    this.meetingLatitude,
    this.meetingLongitude,
    this.meetingDescription,
    required this.userConfirmed,
    required this.agentConfirmed,
    required this.userName,
    required this.agentName,
    required this.agentId,
    required this.walletPhoneNumber,
    required this.walletNetwork,
    this.cancellationReason,
    required this.createdAt,
    this.completedAt,
    required this.expiresAt,
  });

  bool get isPending => status == 'pending';
  bool get isAccepted => status == 'accepted';
  bool get isCompleted => status == 'completed';
  bool get isCancelled => status == 'cancelled';
  bool get isRejected => status == 'rejected';
  bool get isActive => isPending || isAccepted;
  bool get isCashOut => transactionType == 'cash_out';

  String get typeLabel => isCashOut ? 'Cash Out' : 'Deposit';

  String get statusLabel => switch (status) {
    'pending' => 'Pending',
    'accepted' => 'Accepted',
    'completed' => 'Completed',
    'cancelled' => 'Cancelled',
    'rejected' => 'Rejected',
    'expired' => 'Expired',
    _ => status,
  };

  String get networkLabel => switch (network) {
    'mtn' => 'MTN',
    'vodafone' => 'Vodafone',
    'airteltigo' => 'AirtelTigo',
    _ => network,
  };

  factory PhysicalTransaction.fromJson(Map<String, dynamic> json) {
    return PhysicalTransaction(
      id: json['id'] as String,
      transactionType: json['transaction_type'] as String,
      amount: _toDouble(json['amount']) ?? 0,
      network: json['network'] as String,
      status: json['status'] as String,
      verificationCode: json['verification_code'] as String?,
      meetingLatitude: _toDouble(json['meeting_latitude']),
      meetingLongitude: _toDouble(json['meeting_longitude']),
      meetingDescription: json['meeting_description'] as String?,
      userConfirmed: json['user_confirmed'] as bool? ?? false,
      agentConfirmed: json['agent_confirmed'] as bool? ?? false,
      userName: json['user_name'] as String? ?? '',
      agentName: json['agent_name'] as String? ?? '',
      agentId: json['agent_id'] as String? ?? '',
      walletPhoneNumber: json['wallet_phone_number'] as String? ?? '',
      walletNetwork: json['wallet_network'] as String? ?? '',
      cancellationReason: json['cancellation_reason'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
      expiresAt: DateTime.parse(json['expires_at'] as String),
    );
  }

  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }
}
