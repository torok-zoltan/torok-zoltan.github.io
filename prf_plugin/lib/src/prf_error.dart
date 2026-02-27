/// Typed error for PRF plugin operations.
class PrfError implements Exception {
  final String code;
  final String message;
  final String? details;

  const PrfError({required this.code, required this.message, this.details});

  factory PrfError.cancelled() =>
      const PrfError(code: 'CANCELLED', message: 'User cancelled the operation');

  factory PrfError.prfNotSupported() => const PrfError(
      code: 'PRF_NOT_SUPPORTED',
      message: 'PRF extension is not supported by this authenticator');

  factory PrfError.noCredential() => const PrfError(
      code: 'NO_CREDENTIAL',
      message: 'No matching passkey found. Register a passkey first.');

  factory PrfError.fromCallbackParams(Map<String, String> params) => PrfError(
        code: params['errorCode'] ?? 'UNKNOWN',
        message: params['errorMessage'] ?? 'Unknown error occurred',
        details: params['errorDetails'],
      );

  @override
  String toString() => 'PrfError($code): $message';
}
