class ApiConfig {
  static String baseUrl = 'http://localhost:8000';

  static Uri uri(String path) => Uri.parse('$baseUrl$path');

  static String fullUrl(String path) => '$baseUrl$path';

  static Uri wsUri(String path) {
    final wsBase = baseUrl.replaceFirst('http', 'ws');
    return Uri.parse('$wsBase$path');
  }
}
