class ApiException implements Exception {
  final String code;
  final String message;
  final int? statusCode;

  const ApiException({
    required this.code,
    required this.message,
    this.statusCode,
  });

  factory ApiException.fromResponse(Map<String, dynamic> json, int? statusCode) {
    final error = json['error'] as Map<String, dynamic>?;
    return ApiException(
      code: error?['code'] ?? 'UNKNOWN',
      message: error?['message'] ?? 'An unexpected error occurred',
      statusCode: statusCode,
    );
  }

  @override
  String toString() => 'ApiException($code): $message';
}
