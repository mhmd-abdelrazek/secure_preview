# secure_preview

A Flutter plugin/widget for hiding sensitive UI when configured device/display risks are detected and reducing ordinary screen capture.

## Install

```yaml
dependencies:
  secure_preview:
    path: ../secure_preview
```

The package's own `pubspec.yaml` includes the Flutter SDK dependency:

```yaml
dependencies:
  flutter:
    sdk: flutter
```

## Usage

```dart
import 'package:secure_preview/secure_preview.dart';

SecurePreview(
  preventScreenshots: true,
  blurWhenBackgrounded: true,
  child: const YourSensitiveWidget(),
  detectedBuilder: (context, status) => const SizedBox.shrink(),
  onDetected: (status) => debugPrint('Blocked: ${status.detectedRisks}'),
)
```

## Capture protection and limitations

- **Android:** `preventScreenshots: true` enables `WindowManager.LayoutParams.FLAG_SECURE` for the host Activity while the widget is mounted. This blocks ordinary screenshots and most non-secure screen capture/recording of the app window. It is not a guarantee against a compromised/rooted device, external camera, or every OEM/remote-display implementation.
- **Windows:** `preventScreenshots: true` calls `SetWindowDisplayAffinity` with `WDA_EXCLUDEFROMCAPTURE` on the app's top-level window (Windows 10 version 2004+; older builds fall back to `WDA_MONITOR`, which captures a black window). Software capture such as Snipping Tool, Game Bar, OBS and screen sharing no longer shows the window. It does not stop a phone camera, an HDMI capture card, kernel-level malware, or a host capturing a VM's display. Native checks on Windows: `emulator` = virtual machine heuristics (CPUID vendor + BIOS strings), `usbDebugging` = a native debugger is attached, `screenMirroring` = Remote Desktop session, `screenRecording` = a known recorder process (OBS, ShareX, etc.) is running, `externalDisplay` = more than one monitor. `rooted` and `developerOptions` always report false. Because multi-monitor desktops are common, remove `SecurityRisk.externalDisplay` from `checks` if you don't want it to block there.
- **iOS:** Apple does not provide a public API for apps to prevent screenshots. The package cannot guarantee screenshot blocking. It masks the widget with a blur when Flutter reports the app is inactive/backgrounded, and its native checks can report some screen recording/mirroring states. Screenshot notifications happen after the screenshot and cannot prevent it.
- **Background blur:** The Flutter blur overlay is best-effort. Android's secure window flag protects the Android app-switcher snapshot. iOS app-switcher snapshots may be taken before Flutter redraws, so this overlay is not a guaranteed privacy screen on every iOS version/device.
- **Detection:** Root/jailbreak and emulator checks are heuristic. Android has no dependable public API to detect every screen recording or wireless mirroring session. Developer Options and USB debugging checks are Android-only (on Windows, USB debugging maps to an attached debugger). Recorder detection on Windows is a process-name list and is easy to evade.
- **Windows focus:** Flutter reports the app as inactive when its window loses focus, so `blurWhenBackgrounded` blurs the content whenever the user clicks another window. Set it to `false` on desktop if that is too aggressive.
- **Lifecycle:** The screenshot flag is enabled while `SecurePreview` is mounted and is cleared when it is disposed. If multiple widgets need protection, avoid disposing one while another protected surface is visible; a production app may prefer app-wide protection management.

This package is a defense-in-depth helper, not a complete anti-capture or DRM solution. For valuable video, use platform DRM and server-side authorization as appropriate.
