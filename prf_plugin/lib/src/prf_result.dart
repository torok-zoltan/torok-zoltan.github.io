import 'dart:convert';
import 'dart:typed_data';

/// Immutable result of a PRF derivation.
class PrfResult {
  /// 32 bytes of PRF output (HMAC-secret derived).
  final Uint8List prfOutput;

  /// The salt that was used for this derivation.
  final Uint8List salt;

  /// Base64url-encoded credential ID (optional).
  final String? credentialId;

  const PrfResult({
    required this.prfOutput,
    required this.salt,
    this.credentialId,
  });

  /// PRF output as a base64url string (no padding).
  String get prfOutputBase64Url =>
      base64Url.encode(prfOutput).replaceAll('=', '');

  /// PRF output as a lowercase hex string.
  String get prfOutputHex =>
      prfOutput.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  /// First 16 bytes of PRF output as hex (preview).
  String get prfOutputHexPreview {
    final preview = prfOutput.length > 16 ? prfOutput.sublist(0, 16) : prfOutput;
    return preview.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Salt as a base64url string (no padding).
  String get saltBase64Url =>
      base64Url.encode(salt).replaceAll('=', '');

  @override
  String toString() =>
      'PrfResult(length=${prfOutput.length}, hex=$prfOutputHexPreview...)';
}
