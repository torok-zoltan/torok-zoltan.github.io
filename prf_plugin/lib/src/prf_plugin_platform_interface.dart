import 'dart:typed_data';

import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'prf_plugin_method_channel.dart';
import 'prf_result.dart';

/// Platform interface for the PRF plugin.
///
/// Platform implementations should extend this class rather than
/// implement it, to ensure forward compatibility.
abstract class PrfPluginPlatform extends PlatformInterface {
  PrfPluginPlatform() : super(token: _token);

  static final Object _token = Object();

  static PrfPluginPlatform _instance = MethodChannelPrfPlugin();

  static PrfPluginPlatform get instance => _instance;

  static set instance(PrfPluginPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Register a new passkey with PRF extension enabled.
  /// Returns true if the authenticator supports PRF.
  Future<bool> registerPasskey({String? rpIdOverride});

  /// Derive PRF output using a previously registered passkey.
  /// If [salt] is null, a random 32-byte salt is generated.
  Future<PrfResult> derivePrf({Uint8List? salt, String? rpIdOverride});

  /// Best-effort check for PRF support on this platform.
  /// Actual support depends on browser and authenticator at ceremony time.
  Future<bool> isPrfSupported();
}
