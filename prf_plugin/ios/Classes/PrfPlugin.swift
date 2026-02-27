import Flutter
import UIKit
import AuthenticationServices

/// iOS native plugin for WebAuthn PRF derivation.
///
/// Uses ASWebAuthenticationSession to open the WebAuthn PRF page
/// hosted on GitHub Pages. The page performs the WebAuthn ceremony
/// and redirects back via a custom URL scheme with results.
///
/// Requirements:
/// - iOS 16.0+ (runtime PRF check requires iOS 18+)
/// - prefersEphemeralWebBrowserSession = false (needed for iCloud Keychain passkey access)
public class PrfPlugin: NSObject, FlutterPlugin,
                         ASWebAuthenticationPresentationContextProviding {

    private var pendingResult: FlutterResult?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "com.example.prf_plugin/channel",
            binaryMessenger: registrar.messenger()
        )
        let instance = PrfPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "launchWebAuth":
            guard let args = call.arguments as? [String: Any],
                  let urlString = args["url"] as? String,
                  let callbackScheme = args["callbackScheme"] as? String,
                  let url = URL(string: urlString) else {
                result(FlutterError(code: "INVALID_ARGS",
                                    message: "Missing url or callbackScheme",
                                    details: nil))
                return
            }
            launchWebAuth(url: url, callbackScheme: callbackScheme, result: result)

        case "isPrfSupported":
            // PRF is supported on iOS 18+ with iCloud Keychain passkeys.
            // External security keys (YubiKey, etc.) do NOT support PRF on iOS.
            if #available(iOS 18.0, *) {
                result(true)
            } else {
                result(false)
            }

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func launchWebAuth(url: URL, callbackScheme: String,
                                result: @escaping FlutterResult) {
        self.pendingResult = result

        let session = ASWebAuthenticationSession(
            url: url,
            callbackURLScheme: callbackScheme
        ) { [weak self] callbackURL, error in
            guard let self = self else { return }

            if let error = error {
                let nsError = error as NSError
                if nsError.domain == ASWebAuthenticationSessionErrorDomain,
                   nsError.code == ASWebAuthenticationSessionError
                       .canceledLogin.rawValue {
                    // User cancelled — return nil so Dart can distinguish
                    // cancellation from actual errors.
                    self.pendingResult?(nil)
                } else {
                    self.pendingResult?(FlutterError(
                        code: "AUTH_SESSION_ERROR",
                        message: error.localizedDescription,
                        details: nil
                    ))
                }
                self.pendingResult = nil
                return
            }

            guard let callbackURL = callbackURL else {
                self.pendingResult?(FlutterError(
                    code: "NO_CALLBACK",
                    message: "No callback URL received",
                    details: nil
                ))
                self.pendingResult = nil
                return
            }

            // Parse query parameters from the callback URL and return
            // them as a [String: String] dictionary to Dart.
            let params = self.parseQueryParams(from: callbackURL)
            self.pendingResult?(params)
            self.pendingResult = nil
        }

        // CRITICAL: Do NOT use ephemeral session. We need access to
        // iCloud Keychain passkeys. An ephemeral session isolates
        // from Safari and prevents the system passkey sheet from
        // showing the user's existing passkeys.
        session.prefersEphemeralWebBrowserSession = false

        session.presentationContextProvider = self
        session.start()
    }

    private func parseQueryParams(from url: URL) -> [String: String] {
        guard let components = URLComponents(
            url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            return [:]
        }
        var params: [String: String] = [:]
        for item in queryItems {
            params[item.name] = item.value ?? ""
        }
        return params
    }

    // MARK: - ASWebAuthenticationPresentationContextProviding

    public func presentationAnchor(
        for session: ASWebAuthenticationSession
    ) -> ASPresentationAnchor {
        // Use the modern UIWindowScene API (iOS 13+).
        guard let scene = UIApplication.shared.connectedScenes
                .first as? UIWindowScene,
              let window = scene.windows.first else {
            return UIWindow()
        }
        return window
    }
}
