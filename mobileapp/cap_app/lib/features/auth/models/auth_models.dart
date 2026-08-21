// File purpose: Defines Flutter data models for auth feature flows.
import 'dart:convert';

enum UserRole { user, admin }

UserRole parseUserRole(String? raw) {
  switch ((raw ?? '').toUpperCase()) {
    case 'ADMIN':
      return UserRole.admin;
    default:
      return UserRole.user;
  }
}

class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    required this.displayName,
    required this.role,
  });

  final int id;
  final String email;
  final String displayName;
  final UserRole role;

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: (json['id'] as num).toInt(),
      email: json['email']?.toString() ?? '',
      displayName: json['displayName']?.toString() ?? '',
      role: parseUserRole(json['role']?.toString()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'displayName': displayName,
      'role': role.name.toUpperCase(),
    };
  }
}

class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.tokenType,
    required this.expiresInMs,
    required this.user,
  });

  final String accessToken;
  final String tokenType;
  final int expiresInMs;
  final AuthUser user;

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    final rawToken =
        json['accessToken']?.toString() ?? json['token']?.toString() ?? '';
    final normalizedToken = _normalizeAccessToken(rawToken);
    return AuthSession(
      accessToken: normalizedToken,
      tokenType: json['tokenType']?.toString() ?? 'Bearer',
      expiresInMs: (json['expiresInMs'] as num?)?.toInt() ?? 0,
      user: AuthUser.fromJson((json['user'] as Map).cast<String, dynamic>()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'accessToken': accessToken,
      'tokenType': tokenType,
      'expiresInMs': expiresInMs,
      'user': user.toJson(),
    };
  }

  String encodeForStorage() => jsonEncode(toJson());

  static AuthSession? decodeFromStorage(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    final raw = jsonDecode(value);
    if (raw is! Map<String, dynamic>) {
      return null;
    }
    return AuthSession.fromJson(raw);
  }

  static String _normalizeAccessToken(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return '';
    }
    const bearerPrefix = 'bearer ';
    if (trimmed.length > bearerPrefix.length &&
        trimmed.substring(0, bearerPrefix.length).toLowerCase() ==
            bearerPrefix) {
      return trimmed.substring(bearerPrefix.length).trim();
    }
    return trimmed;
  }
}
