// File purpose: Normalizes and presents Flutter error behavior.
class AppException implements Exception {
  const AppException({
    required this.message,
    this.statusCode,
    this.fieldErrors = const {},
  });

  final String message;
  final int? statusCode;
  final Map<String, String> fieldErrors;

  bool get isUnauthorized => statusCode == 401;

  @override
  String toString() =>
      'AppException(statusCode: $statusCode, message: $message)';
}
