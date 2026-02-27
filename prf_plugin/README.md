# prf_plugin

A Flutter plugin POC for deriving WebAuthn PRF output using passkeys.

## What this does

This plugin uses the [WebAuthn PRF extension](https://w3c.github.io/webauthn/#prf-extension)
to derive a deterministic 32-byte secret from a passkey. The PRF output is
determined by (credential, RP ID, salt) and is suitable as raw key material
for HKDF.

The WebAuthn ceremony runs in a browser context:
- **iOS**: ASWebAuthenticationSession (iOS 18+ for PRF support)
- **Android**: Chrome Custom Tabs (Android 14+ with Chrome 130+ and Google Password Manager)

The WebAuthn page is hosted on GitHub Pages and performs the actual
`navigator.credentials.create()` / `navigator.credentials.get()` calls.

## Architecture

```
Flutter App  <-->  MethodChannel  <-->  Native (Swift/Kotlin)
                                            |
                                    ASWebAuthenticationSession (iOS)
                                    Chrome Custom Tabs (Android)
                                            |
                                    GitHub Pages (WebAuthn PRF page)
                                            |
                                    prfpoc:// callback with results
```

## Setup

### 1. Host the WebAuthn page

Copy `docs/index.html` to your GitHub Pages repo under a `/prf/` path:

```
your-username.github.io/prf/index.html
```

Update the RP ID and page URL in `lib/src/prf_plugin_method_channel.dart`:

```dart
static const _defaultRpId = 'your-username.github.io';
static const _defaultWebAuthnPageBase = 'https://your-username.github.io/prf/';
```

### 2. iOS setup

**Minimum deployment target**: iOS 16.0 (PRF requires iOS 18+ at runtime)

In your app's `ios/Runner/Info.plist`, add the URL scheme:

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>prfpoc</string>
        </array>
        <key>CFBundleURLName</key>
        <string>com.example.yourapp</string>
    </dict>
</array>
```

Set the iOS deployment target in `ios/Podfile`:

```ruby
platform :ios, '16.0'
```

### 3. Android setup

In your app's `android/app/src/main/AndroidManifest.xml`:

1. Set `launchMode="singleTop"` on your main activity
2. Add an intent-filter for the `prfpoc` scheme
3. Add a `<queries>` block for Custom Tabs

```xml
<activity
    android:name=".MainActivity"
    android:launchMode="singleTop"
    ...>

    <!-- Existing launcher intent-filter -->

    <intent-filter>
        <action android:name="android.intent.action.VIEW" />
        <category android:name="android.intent.category.DEFAULT" />
        <category android:name="android.intent.category.BROWSABLE" />
        <data android:scheme="prfpoc" />
    </intent-filter>
</activity>

<!-- Outside <application> -->
<queries>
    <intent>
        <action android:name="android.support.customtabs.action.CustomTabsService" />
    </intent>
</queries>
```

Use `FlutterFragmentActivity` in your `MainActivity.kt`:

```kotlin
class MainActivity : FlutterFragmentActivity()
```

## Usage

```dart
import 'package:prf_plugin/prf_plugin.dart';

// Step 1: Register a passkey (once)
final prfEnabled = await PrfPlugin.registerPasskey();
print('PRF supported: $prfEnabled');

// Step 2: Derive PRF output
final result = await PrfPlugin.derivePrf(
  salt: myFixedSalt, // or null for random salt
);
print('PRF output: ${result.prfOutputBase64Url}');
print('Length: ${result.prfOutput.length} bytes');
print('Hex: ${result.prfOutputHex}');
print('Salt used: ${result.saltBase64Url}');
```

## API

### `PrfPlugin.registerPasskey({String? rpIdOverride})`

Creates a new passkey with PRF extension enabled. Returns `true` if the
authenticator reports PRF support.

### `PrfPlugin.derivePrf({Uint8List? salt, String? rpIdOverride})`

Derives PRF output using a previously registered passkey. If `salt` is null,
generates a random 32-byte salt. Returns a `PrfResult` containing:
- `prfOutput` — 32 bytes of PRF output
- `salt` — the salt that was used
- `credentialId` — base64url credential ID

### `PrfPlugin.isPrfSupported()`

Best-effort platform check. Returns `true` on iOS 18+ and Android 14+ (API 34+).

## Platform support

| Platform | Status |
|----------|--------|
| iOS 18+  | Working (iCloud Keychain passkeys only) |
| iOS < 18 | Passkey creation works, PRF not available |
| Android 14+ | Working (Chrome 130+ with Google Password Manager) |
| Android < 14 | Passkey creation works, PRF not available |

## Security notes (POC only)

- **Static challenge**: The challenge is generated client-side. Production MUST
  use server-generated, single-use nonces.
- **No attestation verification**: The registration response is not verified.
- **PRF = raw key material**: Use HKDF before using as an encryption key.
- **Custom URL scheme**: The `prfpoc://` scheme is interceptable by other apps.
  Production should use Universal Links (iOS) / App Links (Android).
- **Passkey deletion = key loss**: If the passkey is deleted from iCloud Keychain
  or Google Password Manager, the PRF output is permanently lost.

## Known limitations

1. Firefox on Android does not support PRF (use Chrome or Edge)
2. Only iCloud Keychain passkeys support PRF on iOS (not YubiKey/external keys)
3. Android back-button dismissal from Custom Tabs causes the Dart Future to hang
4. No credential ID storage — uses discoverable credentials only
5. Single pending operation — concurrent calls are not supported
