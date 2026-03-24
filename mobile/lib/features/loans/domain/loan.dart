class LoanPayment {
  final String id;
  final String paymentType;
  final double amount;
  final String status;
  final String reference;
  final String payerPhone;
  final String payerNetwork;
  final DateTime? completedAt;
  final DateTime createdAt;

  const LoanPayment({
    required this.id,
    required this.paymentType,
    required this.amount,
    required this.status,
    required this.reference,
    required this.payerPhone,
    required this.payerNetwork,
    this.completedAt,
    required this.createdAt,
  });

  factory LoanPayment.fromJson(Map<String, dynamic> json) {
    return LoanPayment(
      id: json['id'] as String,
      paymentType: json['payment_type'] as String,
      amount: double.parse(json['amount'].toString()),
      status: json['status'] as String,
      reference: json['reference'] as String,
      payerPhone: json['payer_phone'] as String,
      payerNetwork: json['payer_network'] as String,
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  bool get isSuccess => status == 'success';
  bool get isPending => status == 'pending';
  bool get isFailed => status == 'failed';
  bool get isDisbursement => paymentType == 'disbursement';
  bool get isRepayment => paymentType == 'repayment';
}

class Loan {
  final String id;
  final String borrowerName;
  final String borrowerEmail;
  final String agentName;
  final String agentId;
  final double amount;
  final double interestRate;
  final double totalRepayment;
  final double penaltyAmount;
  final double outstandingBalance;
  final String status;
  final String network;
  final String borrowerWalletPhone;
  final String borrowerWalletNetwork;
  final String agentWalletPhone;
  final String rejectionReason;
  final DateTime? approvedAt;
  final DateTime? disbursedAt;
  final DateTime? deadlineAt;
  final DateTime? completedAt;
  final DateTime? defaultedAt;
  final DateTime createdAt;
  final List<LoanPayment> payments;

  const Loan({
    required this.id,
    required this.borrowerName,
    required this.borrowerEmail,
    required this.agentName,
    required this.agentId,
    required this.amount,
    required this.interestRate,
    required this.totalRepayment,
    required this.penaltyAmount,
    required this.outstandingBalance,
    required this.status,
    required this.network,
    required this.borrowerWalletPhone,
    required this.borrowerWalletNetwork,
    required this.agentWalletPhone,
    required this.rejectionReason,
    this.approvedAt,
    this.disbursedAt,
    this.deadlineAt,
    this.completedAt,
    this.defaultedAt,
    required this.createdAt,
    this.payments = const [],
  });

  factory Loan.fromJson(Map<String, dynamic> json) {
    return Loan(
      id: json['id'] as String,
      borrowerName: json['borrower_name'] as String? ?? '',
      borrowerEmail: json['borrower_email'] as String? ?? '',
      agentName: json['agent_name'] as String? ?? '',
      agentId: json['agent_id'] as String? ?? '',
      amount: double.parse(json['amount'].toString()),
      interestRate: double.parse(json['interest_rate'].toString()),
      totalRepayment: double.parse(json['total_repayment'].toString()),
      penaltyAmount: double.parse(json['penalty_amount'].toString()),
      outstandingBalance: double.parse(json['outstanding_balance'].toString()),
      status: json['status'] as String,
      network: json['network'] as String? ?? '',
      borrowerWalletPhone: json['borrower_wallet_phone'] as String? ?? '',
      borrowerWalletNetwork: json['borrower_wallet_network'] as String? ?? '',
      agentWalletPhone: json['agent_wallet_phone'] as String? ?? '',
      rejectionReason: json['rejection_reason'] as String? ?? '',
      approvedAt: json['approved_at'] != null
          ? DateTime.parse(json['approved_at'] as String)
          : null,
      disbursedAt: json['disbursed_at'] != null
          ? DateTime.parse(json['disbursed_at'] as String)
          : null,
      deadlineAt: json['deadline_at'] != null
          ? DateTime.parse(json['deadline_at'] as String)
          : null,
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
      defaultedAt: json['defaulted_at'] != null
          ? DateTime.parse(json['defaulted_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      payments:
          (json['payments'] as List<dynamic>?)
              ?.map((p) => LoanPayment.fromJson(p as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  // Status helpers
  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isDisbursing => status == 'disbursing';
  bool get isActive => status == 'active';
  bool get isRepaying => status == 'repaying';
  bool get isCompleted => status == 'completed';
  bool get isDefaulted => status == 'defaulted';
  bool get isRejected => status == 'rejected';
  bool get isCancelled => status == 'cancelled';
  bool get isFailed => status == 'failed';

  bool get isOngoing =>
      isPending || isApproved || isDisbursing || isActive || isRepaying;

  bool get isOverdue =>
      isActive && deadlineAt != null && DateTime.now().isAfter(deadlineAt!);

  String get statusLabel => switch (status) {
    'pending' => 'Pending',
    'approved' => 'Approved',
    'disbursing' => 'Sending Funds',
    'active' => 'Active',
    'repaying' => 'Repaying',
    'completed' => 'Completed',
    'defaulted' => 'Defaulted',
    'rejected' => 'Rejected',
    'cancelled' => 'Cancelled',
    'failed' => 'Failed',
    _ => status,
  };

  String get networkLabel => switch (network) {
    'mtn' => 'MTN',
    'vodafone' => 'Telecel',
    'airteltigo' => 'AirtelTigo',
    _ => network,
  };

  Duration? get timeRemaining {
    if (deadlineAt == null || !isActive) return null;
    final remaining = deadlineAt!.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }
}
