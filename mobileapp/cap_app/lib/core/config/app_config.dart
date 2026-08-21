// File purpose: Defines Flutter runtime configuration values.
class AppConfig {
  const AppConfig._();

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://sectora.ddns.net',
  );
}
