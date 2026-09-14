class KycSubmission {
  final String id;
  final String status;
  final String idType;
  final String ghanaCardNumber;
  final String verificationMethod;
  final String rejectionReason;
  final String? idFrontId;
  final String? idBackId;
  final String? selfieId;
  final String? proofOfAddressId;

  const KycSubmission({
    required this.id,
    required this.status,
    required this.idType,
    this.ghanaCardNumber = '',
    this.verificationMethod = 'manual_review',
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
      idType: json['id_type'] as String? ?? 'national_id',
      ghanaCardNumber: json['ghana_card_number'] as String? ?? '',
      verificationMethod:
          json['verification_method'] as String? ?? 'manual_review',
      rejectionReason: json['rejection_reason'] as String? ?? '',
      idFrontId: json['id_front_id'] as String?,
      idBackId: json['id_back_id'] as String?,
      selfieId: json['selfie_id'] as String?,
      proofOfAddressId: json['proof_of_address_id'] as String?,
    );
  }
}
