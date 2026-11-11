import 'package:flutter/services.dart';

import 'security_status.dart';

/// Reads best-effort security signals from the native platform.
/// These checks are signals, not tamper-proof security guarantees.
class SecurePreviewDetector {
  SecurePreviewDetector._();

  static const MethodChannel _channel = MethodChannel('secure_preview');

  /// Enables platform screenshot protection where supported.
  /// Returns false on platforms (such as iOS) that cannot block screenshots.
  static Future<bool> setScreenshotProtection(bool enabled) async {
    try {
      return await _channel.invokeMethod<bool>('setScreenshotProtection', enabled) ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  static Future<SecurityStatus> check() async {
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>('checkSecurity');
      final risks = <SecurityRisk>{};
      if (result == null) return SecurityStatus(detectedRisks: risks);

      void add(String key, SecurityRisk risk) {
        if (result[key] == true) risks.add(risk);
      }

      add('rooted', SecurityRisk.rooted);
      add('emulator', SecurityRisk.emulator);
      add('developerOptions', SecurityRisk.developerOptions);
      add('usbDebugging', SecurityRisk.usbDebugging);
      add('screenMirroring', SecurityRisk.screenMirroring);
      add('screenRecording', SecurityRisk.screenRecording);
      add('externalDisplay', SecurityRisk.externalDisplay);
      return SecurityStatus(detectedRisks: risks);
    } on MissingPluginException {
      return const SecurityStatus(detectedRisks: {});
    } on PlatformException {
      return const SecurityStatus(detectedRisks: {});
    }
  }
}
