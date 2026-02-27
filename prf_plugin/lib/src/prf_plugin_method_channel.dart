import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/services.dart';

import 'prf_error.dart';
import 'prf_plugin_platform_interface.dart';
import 'prf_result.dart';

/// MethodChannel-based implementation of [PrfPluginPlatform].
///
/// Communicates with native iOS/Android code via a single
/// `launchWebAuth` method that opens a browser to the WebAuthn
/// PRF page and captures the callback URL result.
class MethodChannelPrfPlugin extends PrfPluginPlatform {
  static const _channel = MethodChannel('com.example.prf_plugin/channel');

  /// Default RP ID — must match the GitHub Pages domain hosting
  /// the WebAuthn page. Changing this breaks PRF determinism
  /// for previously registered credentials.
  static const _defaultRpId = 'torok-zoltan.github.io';

  /// Base URL for the WebAuthn PRF page on GitHub Pages.
  static const _defaultWebAuthnPageBase =
      'https://torok-zoltan.github.io/prf/';

  /// Custom URL scheme for the callback from the WebAuthn page.
  static const _callbackScheme = 'prfpoc';

  @override
  Future<bool> registerPasskey({String? rpIdOverride}) async {
    final rpId = rpIdOverride ?? _defaultRpId;
    // POC: challenge is generated client-side. In production,
    // challenges MUST be server-generated and single-use.
    final challenge = _generateRandomBase64Url(32);

    final url = _buildUrl(
      action: 'register',
      rpId: rpId,
      challenge: challenge,
    );

    final result = await _channel.invokeMethod<Map>('launchWebAuth', {
      'url': url,
      'callbackScheme': _callbackScheme,
    });

    // nil/null from native = user cancelled
    if (result == null) throw PrfError.cancelled();

    final params = result.cast<String, dynamic>();
    final status = params['status'] as String?;

    if (status == 'success') {
      final prfEnabled = params['prfEnabled'] == 'true';
      return prfEnabled;
    } else {
      throw PrfError.fromCallbackParams(
          params.map((k, v) => MapEntry(k.toString(), v.toString())));
    }
  }

  @override
  Future<PrfResult> derivePrf({
    Uint8List? salt,
    String? rpIdOverride,
  }) async {
    final rpId = rpIdOverride ?? _defaultRpId;
    // POC: challenge is generated client-side.
    final challenge = _generateRandomBase64Url(32);
    final effectiveSalt = salt ?? _generateRandomBytes(32);
    final saltB64 = base64Url.encode(effectiveSalt).replaceAll('=', '');

    final url = _buildUrl(
      action: 'authenticate',
      rpId: rpId,
      challenge: challenge,
      salt: saltB64,
    );

    final result = await _channel.invokeMethod<Map>('launchWebAuth', {
      'url': url,
      'callbackScheme': _callbackScheme,
    });

    if (result == null) throw PrfError.cancelled();

    final params = result.cast<String, dynamic>();
    final status = params['status'] as String?;

    if (status == 'success') {
      final prfOutputB64 = params['prf'] as String;
      final prfOutput = base64Url.decode(_padBase64(prfOutputB64));
      final credentialId = params['credentialId'] as String?;
      return PrfResult(
        prfOutput: Uint8List.fromList(prfOutput),
        salt: effectiveSalt,
        credentialId: credentialId,
      );
    } else {
      throw PrfError.fromCallbackParams(
          params.map((k, v) => MapEntry(k.toString(), v.toString())));
    }
  }

  @override
  Future<bool> isPrfSupported() async {
    final result = await _channel.invokeMethod<bool>('isPrfSupported');
    return result ?? false;
  }

  /// Build the URL for the WebAuthn PRF page with query parameters.
  String _buildUrl({
    required String action,
    required String rpId,
    required String challenge,
    String? salt,
  }) {
    final params = <String, String>{
      'action': action,
      'rpId': rpId,
      'challenge': challenge,
      'returnScheme': _callbackScheme,
    };
    if (salt != null) params['salt'] = salt;

    final query = params.entries
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
        .join('&');
    return '$_defaultWebAuthnPageBase?$query';
  }

  /// Generate [length] cryptographically random bytes.
  static Uint8List _generateRandomBytes(int length) {
    final rng = Random.secure();
    return Uint8List.fromList(
        List.generate(length, (_) => rng.nextInt(256)));
  }

  /// Generate [byteLength] random bytes and return as base64url (no padding).
  static String _generateRandomBase64Url(int byteLength) {
    final bytes = _generateRandomBytes(byteLength);
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  /// Add base64 padding back for decoding.
  static String _padBase64(String b64) {
    final pad = (4 - b64.length % 4) % 4;
    return b64 + '=' * pad;
  }
}
