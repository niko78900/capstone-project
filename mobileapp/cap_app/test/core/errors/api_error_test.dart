import 'package:cap_app/core/errors/api_error.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ApiErrorPayload', () {
    test('parses top-level fields and field errors', () {
      final payload = ApiErrorPayload.fromDynamic({
        'status': 422,
        'error': 'Unprocessable Entity',
        'message': 'Validation failed',
        'path': '/api/v1/submissions/price',
        'fieldErrors': [
          {'field': 'price', 'message': 'Price must be positive'},
          {'field': 'productId', 'message': 'Product id is required'},
        ],
      });

      expect(payload.status, 422);
      expect(payload.error, 'Unprocessable Entity');
      expect(payload.fieldErrors.length, 2);
      expect(payload.fieldErrorMap['price'], 'Price must be positive');
      expect(payload.fieldErrorMap['productId'], 'Product id is required');
    });

    test('uses safe defaults for non-map payloads', () {
      final payload = ApiErrorPayload.fromDynamic('invalid');
      expect(payload.status, 500);
      expect(payload.message, 'Unexpected error');
      expect(payload.fieldErrors, isEmpty);
    });
  });
}
