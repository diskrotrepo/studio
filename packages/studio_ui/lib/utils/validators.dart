/// Non-empty / required field.
String? requiredField(String? value, {String fieldName = 'This field'}) {
  if (value == null || value.trim().isEmpty) {
    return '$fieldName is required.';
  }
  return null;
}

/// Integer within an inclusive range.  Returns `null` for empty (optional).
String? intInRange(
  String? value, {
  required int min,
  required int max,
  String fieldName = 'Value',
}) {
  if (value == null || value.trim().isEmpty) return null;
  final n = int.tryParse(value.trim());
  if (n == null) return '$fieldName must be a whole number.';
  if (n < min || n > max) return '$fieldName must be between $min and $max.';
  return null;
}

/// Positive double (> 0).  Returns `null` for empty (optional).
String? positiveDouble(String? value, {String fieldName = 'Value'}) {
  if (value == null || value.trim().isEmpty) return null;
  final n = double.tryParse(value.trim());
  if (n == null) return '$fieldName must be a number.';
  if (n <= 0) return '$fieldName must be greater than zero.';
  return null;
}

/// Non-negative double (>= 0).  Returns `null` for empty (optional).
String? nonNegativeDouble(String? value, {String fieldName = 'Value'}) {
  if (value == null || value.trim().isEmpty) return null;
  final n = double.tryParse(value.trim());
  if (n == null) return '$fieldName must be a number.';
  if (n < 0) return '$fieldName cannot be negative.';
  return null;
}

/// Minutes field: non-negative integer 0-999.
String? minutesField(String? value) {
  return intInRange(value, min: 0, max: 999, fieldName: 'Minutes');
}

/// Seconds field: 0-59.
String? secondsField(String? value) {
  return intInRange(value, min: 0, max: 59, fieldName: 'Seconds');
}

/// Seed: non-negative integer.  Returns `null` for empty (optional).
String? seedField(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  final n = int.tryParse(value.trim());
  if (n == null) return 'Seed must be a whole number.';
  if (n < 0) return 'Seed cannot be negative.';
  return null;
}

/// BPM: 1-999.  Returns `null` for empty (optional).
String? bpmField(String? value) {
  return intInRange(value, min: 1, max: 999, fieldName: 'BPM');
}

/// URL-like host format (no schema, no path traversal).
/// Accepts `hostname`, `hostname:port`, `ip:port`.
String? hostField(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'Host is required.';
  }
  final v = value.trim();
  if (v.contains('/') || v.contains('\\') || v.contains(' ')) {
    return 'Enter a hostname (e.g. api.example.com:8080), not a full URL.';
  }
  final hostPort = RegExp(r'^[a-zA-Z0-9._-]+(:\d{1,5})?$');
  if (!hostPort.hasMatch(v)) {
    return 'Invalid host format.';
  }
  return null;
}
