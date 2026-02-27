import 'dart:typed_data';

import 'src/prf_plugin_platform_interface.dart';
import 'src/prf_result.dart';

export 'src/prf_error.dart';
export 'src/prf_plugin_method_channel.dart';
export 'src/prf_plugin_platform_interface.dart';
export 'src/prf_result.dart';

/// Flutter plugin for deriving WebAuthn PRF output using passkeys.
///
/// Usage:
/// 1. Call [registerPasskey] once to create a passkey with PRF enabled.
/// 2. Call [derivePrf] to derive a deterministic 32-byte secret.
///
/// Security notes (POC):
/// - Challenge is generated client-side. Production MUST use server-generated nonces.
/// - PRF output is raw key material. Use HKDF before using as an encryption key.
/// - Passkey deletion = permanent key loss (PRF output is unrecoverable).
/// - Custom URL scheme callback is interceptable. Production needs Universal/App Links.
class PrfPlugin {
  /// Register a new passkey with PRF extension enabled.
  ///
  /// Returns `true` if the authenticator reports PRF support,
  /// `false` if the passkey was created but PRF is not supported.
  /// Throws [PrfError] on failure or cancellation.
  static Future<bool> registerPasskey({String? rpIdOverride}) {
    return PrfPluginPlatform.instance.registerPasskey(
      rpIdOverride: rpIdOverride,
    );
  }

  /// Derive PRF output using a previously registered passkey.
  ///
  /// If [salt] is null, generates a random 32-byte salt.
  /// The salt used is included in the returned [PrfResult]
  /// so callers can verify determinism.
  ///
  /// Returns [PrfResult] with the 32-byte PRF output.
  /// Throws [PrfError] on failure or cancellation.
  static Future<PrfResult> derivePrf({
    Uint8List? salt,
    String? rpIdOverride,
  }) {
    return PrfPluginPlatform.instance.derivePrf(
      salt: salt,
      rpIdOverride: rpIdOverride,
    );
  }

  /// Best-effort check for PRF support on this platform.
  ///
  /// Returns `true` on iOS 18+ and Android 14+ (API 34+).
  /// Android requires Chrome 130+ with Google Password Manager.
  ///
  /// Actual support depends on the browser and authenticator at
  /// ceremony time. Use this for pre-flight UI hints only.
  static Future<bool> isPrfSupported() {
    return PrfPluginPlatform.instance.isPrfSupported();
  }
}
