class KycSubmission {
  final String id;
  final String status;
  final String idType;
  final String rejectionReason;
  final String? idFrontId;
  final String? idBackId;
  final String? selfieId;
  final String? proofOfAddressId;

  const KycSubmission({
    required this.id,
    required this.status,
    required this.idType,
    required this.rejectionReason,
    this.idFrontId,
    this.idBackId,
    this.selfieId,
    this.proofOfAddressId,
  });

  factory KycSubmission.fromJson(Map<String, dynamic> json) {
    return KycSubmission(
      id: json['id'] as String,
      status: json['status'] as String,
      idType: json['id_type'] as String,
      rejectionReason: json['rejection_reason'] as String? ?? '',
      idFrontId: json['id_front_id'] as String?,
      idBackId: json['id_back_id'] as String?,
      selfieId: json['selfie_id'] as String?,
      proofOfAddressId: json['proof_of_address_id'] as String?,
    );
  }
}
