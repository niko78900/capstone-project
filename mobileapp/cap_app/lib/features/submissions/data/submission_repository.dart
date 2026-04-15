import 'package:cap_app/core/errors/app_exception.dart';
import 'package:cap_app/core/network/api_client.dart';
import 'package:cap_app/features/submissions/models/submission_models.dart';
import 'package:dio/dio.dart';

class SubmissionRepository {
  SubmissionRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<SubmissionResponse> submitProduct(
    ProductSubmissionRequestDto request,
  ) async {
    final raw = await _apiClient.post(
      '/api/v1/submissions/product',
      data: request.toJson(),
    );
    return SubmissionResponse.fromJson((raw as Map).cast<String, dynamic>());
  }

  Future<SubmissionResponse> submitPrice(
    PriceSubmissionRequestDto request,
  ) async {
    final raw = await _apiClient.post(
      '/api/v1/submissions/price',
      data: request.toJson(),
    );
    return SubmissionResponse.fromJson((raw as Map).cast<String, dynamic>());
  }

  Future<List<SubmissionResponse>> getMySubmissions() async {
    final raw = await _apiClient.get('/api/v1/submissions/me');
    if (raw is! List) {
      return const [];
    }
    return raw
        .whereType<Map>()
        .map(
          (item) => SubmissionResponse.fromJson(item.cast<String, dynamic>()),
        )
        .toList();
  }

  Future<String> uploadProductImage(String filePath) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath),
    });
    final raw = await _apiClient.postMultipart(
      '/api/v1/submissions/images',
      formData: formData,
    );
    if (raw is! Map) {
      throw const AppException(message: 'Image upload failed');
    }
    final imageUrl = raw['imageUrl']?.toString().trim() ?? '';
    if (imageUrl.isEmpty) {
      throw const AppException(message: 'Image upload failed');
    }
    return imageUrl;
  }
}
