import 'package:cap_app/core/config/app_config.dart';
import 'package:cap_app/core/errors/api_error.dart';
import 'package:cap_app/core/errors/app_exception.dart';
import 'package:cap_app/core/network/auth_token_storage.dart';
import 'package:dio/dio.dart';

class ApiClient {
  ApiClient(this._tokenStorage)
    : _dio = Dio(
        BaseOptions(
          baseUrl: AppConfig.apiBaseUrl,
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
          sendTimeout: const Duration(seconds: 15),
          headers: const {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _tokenStorage.readToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) {
          handler.reject(_mapError(error));
        },
      ),
    );
  }

  final Dio _dio;
  final AuthTokenStorage _tokenStorage;

  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final response = await _dio.get<dynamic>(
        path,
        queryParameters: queryParameters,
      );
      return response.data;
    } on DioException catch (error) {
      throw _extractException(error);
    } catch (_) {
      throw const AppException(message: 'Unexpected network error');
    }
  }

  Future<dynamic> post(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final response = await _dio.post<dynamic>(
        path,
        data: data,
        queryParameters: queryParameters,
      );
      return response.data;
    } on DioException catch (error) {
      throw _extractException(error);
    } catch (_) {
      throw const AppException(message: 'Unexpected network error');
    }
  }

  DioException _mapError(DioException error) {
    final response = error.response;
    late final AppException mapped;

    if (response != null) {
      final payload = ApiErrorPayload.fromDynamic(response.data);
      final fallback = response.statusMessage?.trim();
      mapped = AppException(
        message: payload.message.isNotEmpty
            ? payload.message
            : (fallback?.isNotEmpty == true ? fallback! : 'Request failed'),
        statusCode: response.statusCode ?? payload.status,
        fieldErrors: payload.fieldErrorMap,
      );
    } else {
      mapped = AppException(message: _transportErrorMessage(error));
    }

    return DioException(
      requestOptions: error.requestOptions,
      response: response,
      type: error.type,
      error: mapped,
      stackTrace: error.stackTrace,
      message: error.message,
    );
  }

  String _transportErrorMessage(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
        return 'Could not connect to the server. Please try again.';
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'The request timed out. Please try again.';
      case DioExceptionType.connectionError:
        return 'Cannot reach server at ${AppConfig.apiBaseUrl}. Check that the backend is running.';
      case DioExceptionType.badCertificate:
        return 'Secure connection failed.';
      case DioExceptionType.cancel:
        return 'Request was cancelled.';
      case DioExceptionType.badResponse:
      case DioExceptionType.unknown:
        return 'Request failed. Please try again.';
    }
  }

  AppException _extractException(DioException error) {
    final wrapped = error.error;
    if (wrapped is AppException) {
      return wrapped;
    }
    return AppException(
      message: error.message ?? 'Request failed',
      statusCode: error.response?.statusCode,
    );
  }
}
