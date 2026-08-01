# RainFire — iOS App Store Deployment Guide

Bundle ID: `com.rainfire.app` · Team ID: `5MP2L76DV8` (Datanet LLC) · Version `1.0.0+1`

---

## PART 1 — Already done (do NOT redo)

These changes are committed in the working tree. Verified with `flutter analyze` (clean) and `plutil -lint`.

| Change | File |
|---|---|
| Privacy Manifest created + wired into Runner target's Resources build phase | `ios/Runner/PrivacyInfo.xcprivacy`, `ios/Runner.xcodeproj/project.pbxproj` |
| Removed unused "Always" location permission (app only requests when-in-use; keeping it risks rejection) | `ios/Runner/Info.plist` |
| MapTiler key moved to build-time `--dart-define=MAPTILER_KEY`, dev fallback retained | `lib/services/map_config.dart` |
| `DEVELOPMENT_TEAM = 5MP2L76DV8` + `CODE_SIGN_STYLE = Automatic` on all 3 Runner configs (Debug/Release/Profile) | `ios/Runner.xcodeproj/project.pbxproj` |
| **Swift Package Manager disabled** (see Gotcha #1) | `flutter config --no-enable-swift-package-manager` |

Also verified, no action needed:
- `GoogleService-Info.plist` is present in `ios/Runner/`
- Firestore rules only need the `devices` collection — existing `firestore.rules` is adequate
- App icons complete (all sizes incl. 1024x1024)
- iOS deployment target 13.0

---

## PART 2 — Environment state on this Mac

| Item | Status |
|---|---|
| Xcode 26.6 | ✅ installed, `xcode-select` points to it, license accepted |
| CocoaPods 1.17.0 | ✅ installed via `brew install cocoapods` |
| Apple ID in Xcode | ✅ added (Datanet LLC) |
| Pods for this project | ✅ `pod install` completed successfully |
| **iOS 26.5 platform runtime** | ❌ **NOT installed — 8.52 GB download required** |
| Disk space | ⚠️ was the limiting factor; keep ~20 GB free |

---

## PART 3 — Steps to finish

### Step 1 — Free disk space
Need roughly **20 GB free** — 8.5 GB to download plus room to expand and install.
-  → System Settings → General → Storage
- Empty Trash, clear Downloads

Already reclaimed: Homebrew cache (2.5 GB) and the partial download (2.2 GB).
To re-clear Homebrew cache later: `brew cleanup --prune=all -s && rm -rf $(brew --cache)`

### Step 2 — Install the iOS platform runtime
**Easiest (recommended):** Xcode → Settings (**⌘,**) → **Components** → find **iOS 26.5** → **Get**.
Shows a progress bar and resumes if interrupted.

**Or via terminal:**
```bash
xcodebuild -downloadPlatform iOS
```
Note: a terminal download dies if the terminal closes. The Xcode GUI route is more robust.

Verify afterwards:
```bash
xcodebuild -showsdks | grep iOS
```

### Step 3 — Get your account role upgraded  ⚠️ BLOCKER
Your role on the Datanet LLC team is **Developer**, which **cannot**:
- register App IDs
- create the Apple **Distribution** certificate
- create an App Store Connect app record
- upload builds

Ask the **Account Holder** to grant:
- **Admin** in the Apple Developer Program → developer.apple.com/account → People
- **Admin** or **App Manager** in App Store Connect → Users and Access

*(Alternatively, they perform Steps 4, 5 and 7 while you supply the archive.)*

### Step 4 — Register the App ID
Direct link: https://developer.apple.com/account/resources/identifiers/add/bundleId

**App IDs** → **Continue** → **App** → **Continue** → Description `RainFire`,
**Explicit** Bundle ID `com.rainfire.app`, tick **Push Notifications** → **Continue** → **Register**

*(May be unnecessary — Xcode's automatic signing can register it during archive, but only once you have Admin rights.)*

### Step 5 — Create the App Store Connect record
App Store Connect → **Apps** → **➕** → **New App**
- Platforms: **iOS**
- Name: `RainFire` (must be unique across the App Store)
- Primary Language: English (U.S.)
- Bundle ID: `com.rainfire.app` — only appears here **after** Step 4
- SKU: `rainfire001`

### Step 6 — Build the archive
```bash
cd "/Users/rajasaifpakhral/Desktop/DESKTOP DATA/Projects/Upwork Mobile Apps/POC/Fire_Prevention_System_App"
flutter build ipa --release --dart-define=MAPTILER_KEY=QMqCIotRfvctwuPTxjIG
```
First run takes ~10-15 min (Firebase compile). Output: `build/ios/archive/Runner.xcarchive`

To sanity-check compilation without signing:
```bash
flutter build ios --release --no-codesign --dart-define=MAPTILER_KEY=QMqCIotRfvctwuPTxjIG
```

### Step 7 — Upload
Open `build/ios/archive/Runner.xcarchive` → Xcode **Organizer** → **Distribute App** →
**App Store Connect** → **Upload**.
(Or use the standalone **Transporter** app from the Mac App Store with an exported `.ipa`.)

### Step 8 — Before submitting for review
- Screenshots (6.7" and 6.5" iPhone required)
- **Privacy policy URL** (mandatory)
- App Privacy questionnaire — declare **Email Address** and **Location** (both "App Functionality", not tracking) to match `PrivacyInfo.xcprivacy`
- Description, keywords, support URL, age rating

---

## PART 4 — Gotchas discovered (important)

### 1. Swift Package Manager breaks on this project path
The project lives under `DESKTOP DATA/…/Upwork Mobile Apps/` — **two directories with spaces**. Flutter's SPM integration double-encodes the path (`DESKTOP%2520DATA`), fails to find `pubspec.yaml`, and **hangs ~25 minutes before erroring**.

**Fix applied:** SPM disabled, project uses CocoaPods.
**Do not run `flutter config --enable-swift-package-manager`.** If SPM ever gets re-enabled, either disable it again or move the project to a path with no spaces.

### 2. "Application not configured for iOS"
Means Xcode isn't fully installed / `xcode-select` points at CommandLineTools. Fix:
```bash
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -runFirstLaunch
```

### 3. "iOS 26.5 is not installed" at the end of a build
The platform runtime is missing — that's Step 2. The SDK showing in `xcodebuild -showsdks` is not sufficient on its own.

### 4. MapTiler API key
Key `QMqCIotRfvctwuPTxjIG` is in git history in plaintext. Decision was to keep it but **restrict it to bundle ID `com.rainfire.app`** in the MapTiler dashboard. Do that before release.

### 5. Firebase not yet tested on a real device
Firebase Auth / Google Sign-In have **not** been verified on physical hardware. Test login + signup on a real iPhone before submitting — a broken sign-in is an automatic rejection.

---

## Quick reference

```bash
# project root
cd "/Users/rajasaifpakhral/Desktop/DESKTOP DATA/Projects/Upwork Mobile Apps/POC/Fire_Prevention_System_App"

flutter analyze                      # static analysis
flutter doctor                       # environment check
xcodebuild -showsdks | grep iOS      # confirm platform installed
df -h /                              # check disk space

# clean rebuild if pods misbehave
flutter clean && rm -rf ios/Pods ios/Podfile.lock && flutter pub get
```
