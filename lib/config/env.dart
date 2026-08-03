class Env {
  static const String appName = String.fromEnvironment(
    'APP_NAME',
    defaultValue: 'MurihSpace',
  );

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost/api/v1',
  );

  static const String reverbHost = String.fromEnvironment(
    'REVERB_HOST',
    defaultValue: 'localhost',
  );

  static const int reverbPort = int.fromEnvironment(
    'REVERB_PORT',
    defaultValue: 8080,
  );

  static const String reverbScheme = String.fromEnvironment(
    'REVERB_SCHEME',
    defaultValue: 'ws',
  );

  static const String reverbAppKey = String.fromEnvironment(
    'REVERB_APP_KEY',
    defaultValue: 'murihspace',
  );
}
