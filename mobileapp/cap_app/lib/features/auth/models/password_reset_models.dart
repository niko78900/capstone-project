enum PasswordResetStatus {
  pending,
  approved,
  denied,
  completed,
  expired,
  unknown,
}

PasswordResetStatus parsePasswordResetStatus(String? value) {
  return switch ((value ?? '').toUpperCase()) {
    'PENDING' => PasswordResetStatus.pending,
    'APPROVED' => PasswordResetStatus.approved,
    'DENIED' => PasswordResetStatus.denied,
    'COMPLETED' => PasswordResetStatus.completed,
    'EXPIRED' => PasswordResetStatus.expired,
    _ => PasswordResetStatus.unknown,
  };
}

class PasswordResetRequestResponse {
  const PasswordResetRequestResponse({
    required this.requestToken,
    required this.status,
    required this.expiresAt,
  });

  final String requestToken;
  final PasswordResetStatus status;
  final DateTime? expiresAt;

  factory PasswordResetRequestResponse.fromJson(Map<String, dynamic> json) {
    return PasswordResetRequestResponse(
      requestToken: json['requestToken']?.toString() ?? '',
      status: parsePasswordResetStatus(json['status']?.toString()),
      expiresAt: DateTime.tryParse(json['expiresAt']?.toString() ?? ''),
    );
  }
}

class PasswordResetStatusResponse {
  const PasswordResetStatusResponse({
    required this.status,
    required this.email,
    required this.expiresAt,
    required this.updatedAt,
  });

  final PasswordResetStatus status;
  final String email;
  final DateTime? expiresAt;
  final DateTime? updatedAt;

  factory PasswordResetStatusResponse.fromJson(Map<String, dynamic> json) {
    return PasswordResetStatusResponse(
      status: parsePasswordResetStatus(json['status']?.toString()),
      email: json['email']?.toString() ?? '',
      expiresAt: DateTime.tryParse(json['expiresAt']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? ''),
    );
  }
}

class PasswordResetCompleteResponse {
  const PasswordResetCompleteResponse({
    required this.status,
    required this.message,
  });

  final PasswordResetStatus status;
  final String message;

  factory PasswordResetCompleteResponse.fromJson(Map<String, dynamic> json) {
    return PasswordResetCompleteResponse(
      status: parsePasswordResetStatus(json['status']?.toString()),
      message: json['message']?.toString() ?? 'Password reset completed',
    );
  }
}
