# RainFire

Fire prevention and sprinkler monitoring app. Monitors fire risk per zone using
live weather (NOAA/NWS, Open-Meteo) and active-fire data (NASA FIRMS, NIFC),
and controls sprinkler valves on Digital Matter devices via the TG platform.

## Development

```sh
flutter pub get
flutter run
```

Web is a design-preview target only — Firebase is skipped there.

## Release builds

### Android (Play Store)

Application ID: `com.rainfire.app`.

1. Generate a release keystore (one time):
   ```sh
   keytool -genkey -v -keystore android/rainfire-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias rainfire
   ```
2. Copy `android/key.properties.example` to `android/key.properties` and fill
   in the passwords. Both the keystore and `key.properties` are git-ignored.
3. Register the release key's SHA-1 in Firebase (required for Google Sign-In):
   ```sh
   keytool -list -v -keystore android/rainfire-release.jks -alias rainfire
   firebase apps:android:sha:create 1:699348421681:android:b9f4d03f2f553529629910 <SHA1-without-colons>
   ```
   Then re-download `google-services.json` into `android/app/`.
4. Build the upload bundle:
   ```sh
   flutter build appbundle --release
   ```

### iOS (App Store)

Bundle ID: `com.rainfire.app`. Requires a Mac with Xcode and an Apple
Developer account.

1. Open `ios/Runner.xcworkspace`, set your Team under Signing & Capabilities.
2. `flutter build ipa --release`, then upload via Xcode Organizer or Transporter.

## Store checklist

- [ ] Replace the default Flutter launcher icon (all platforms) — e.g. with
      `flutter_launcher_icons` from a 1024x1024 source image.
- [ ] Play Console: privacy policy URL, data-safety form (location, email).
- [ ] App Store Connect: privacy nutrition labels (location, email).
- [ ] Screenshots for both stores.
