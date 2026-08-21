// File purpose: Normalizes and presents Flutter error behavior.
import 'dart:async';
import 'dart:io';

import 'package:cap_app/core/errors/app_exception.dart';

String humanizeErrorMessage(Object error) {
  if (error is AppException) {
    final message = error.message.trim();
    final lower = message.toLowerCase();

    if (error.statusCode == 401) {
      return 'Your session expired. Please log in again.';
    }
    if (error.statusCode == 403) {
      return 'You do not have permission for this action.';
    }
    if (error.statusCode != null && error.statusCode! >= 500) {
      return 'Server error. Please try again.';
    }
    if (_looksLikeConnectivityIssue(lower)) {
      return 'No connection.';
    }
    if (_looksLikeTimeoutIssue(lower)) {
      return 'Request timed out. Please try again.';
    }
    if (lower.contains('validation failed')) {
      return 'Some input is invalid. Please review and try again.';
    }
    if (message.isNotEmpty) {
      return message;
    }
  }

  if (error is SocketException) {
    return 'No connection.';
  }
  if (error is TimeoutException) {
    return 'Request timed out. Please try again.';
  }

  return 'Something went wrong. Please try again.';
}

String formatErrorMessageForUi(Object error, {required bool debugModeEnabled}) {
  final humanized = humanizeErrorMessage(error);
  if (!debugModeEnabled) {
    return humanized;
  }

  final details = error.toString().trim();
  if (details.isEmpty || details == humanized) {
    return humanized;
  }
  return '$humanized\n\nDetails:\n$details';
}

bool _looksLikeConnectivityIssue(String lower) {
  return lower.contains('cannot reach server') ||
      lower.contains('connection error') ||
      lower.contains('failed host lookup') ||
      lower.contains('connection refused') ||
      lower.contains('network is unreachable') ||
      lower.contains('socketexception') ||
      lower.contains('no address associated with hostname') ||
      lower.contains('network');
}

bool _looksLikeTimeoutIssue(String lower) {
  return lower.contains('timeout') || lower.contains('timed out');
}
