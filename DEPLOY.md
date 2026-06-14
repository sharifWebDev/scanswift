Preparing a signed Android App Bundle (.aab) for Google Play

Prerequisites

- Flutter SDK installed and available on PATH
- Java JDK 17 (as project uses Java 17 compatibility)
- Your Android keystore file (e.g., `upload-keystore.jks`)

Steps

1. Create a signing properties file

Copy `android/key.properties.example` to `android/key.properties` and update values:

storePassword=...
keyPassword=...
keyAlias=...
storeFile=/absolute/path/to/your/upload-keystore.jks

Keep `android/key.properties` out of version control.

2. Build a release Android App Bundle

From project root run:

```bash
flutter clean
flutter pub get
flutter build appbundle --release
```

The generated `.aab` will be in `build/app/outputs/flutter-apk/app-release.aab`.

3. Verify and upload

- Test your release build on a device or internal test track.
- Create a Play Console app and upload the `.aab`.
- Provide required Play Store assets (icons, screenshots, privacy policy).

Notes

- Ensure `applicationId` in `android/app/build.gradle.kts` is set to your app's package name.
- Update `versionName` and `versionCode` as appropriate before releasing.

4. for apk build
- flutter clean
- flutter build apk --release