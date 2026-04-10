class FieldValidationError {
  const FieldValidationError({
    required this.field,
    required this.message,
  });

  final String field;
  final String message;

  factory FieldValidationError.fromJson(Map<String, dynamic> json) {
    return FieldValidationError(
      field: json['field']?.toString() ?? '',
      message: json['message']?.toString() ?? 'Invalid value',
    );
  }
}

class ApiErrorPayload {
  const ApiErrorPayload({
    required this.status,
    required this.error,
    required this.message,
    required this.path,
    required this.fieldErrors,
  });

  final int status;
  final String error;
  final String message;
  final String path;
  final List<FieldValidationError> fieldErrors;

  Map<String, String> get fieldErrorMap => {
    for (final item in fieldErrors) item.field: item.message,
  };

  factory ApiErrorPayload.fromDynamic(dynamic raw) {
    final map = raw is Map ? raw.cast<String, dynamic>() : <String, dynamic>{};
    final fieldsRaw = map['fieldErrors'];
    final fieldErrors = fieldsRaw is List
        ? fieldsRaw
            .whereType<Map>()
            .map((item) => FieldValidationError.fromJson(item.cast<String, dynamic>()))
            .toList()
        : <FieldValidationError>[];

    return ApiErrorPayload(
      status: map['status'] is int ? map['status'] as int : 500,
      error: map['error']?.toString() ?? 'Error',
      message: map['message']?.toString() ?? 'Unexpected error',
      path: map['path']?.toString() ?? '',
      fieldErrors: fieldErrors,
    );
  }
}
