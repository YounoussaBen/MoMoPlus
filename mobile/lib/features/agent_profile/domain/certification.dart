class CertificationApplication {
  final String id;
  final String agentIdNumber;
  final String network;
  final String status;
  final String rejectionReason;
  final DateTime createdAt;

  const CertificationApplication({
    required this.id,
    required this.agentIdNumber,
    required this.network,
    required this.status,
    required this.rejectionReason,
    required this.createdAt,
  });

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';

  factory CertificationApplication.fromJson(Map<String, dynamic> json) {
    return CertificationApplication(
      id: json['id'] as String,
      agentIdNumber: json['agent_id_number'] as String,
      network: json['network'] as String? ?? 'mtn',
      status: json['status'] as String,
      rejectionReason: json['rejection_reason'] as String? ?? '',
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
