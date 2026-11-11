import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'secure_preview_detector.dart';
import 'security_status.dart';

/// Displays [child] only while no configured security risk is detected.
///
/// The child is hidden during the initial check. If [recheck] is true,
/// rechecks happen when the app resumes and every [recheckInterval]; if false,
/// only the first check is performed. Use [detectedBuilder] to customize the
/// blocked UI; by default an empty box is rendered.
///
/// On unsupported platforms (web, macOS, Linux) or when [enabled] is false, the
/// widget is inert: it renders [child] directly and performs no checks, starts
/// no timers, and does not touch the native side.
class SecurePreview extends StatefulWidget {
  const SecurePreview({
    required this.child,
    this.detectedBuilder,
    this.checks = const {
      SecurityRisk.rooted,
      SecurityRisk.emulator,
      SecurityRisk.developerOptions,
      SecurityRisk.usbDebugging,
      SecurityRisk.screenMirroring,
      SecurityRisk.screenRecording,
      SecurityRisk.externalDisplay,
    },
    this.recheck = true,
    this.recheckInterval = const Duration(seconds: 3),
    this.onDetected,
    this.preventScreenshots = true,
    this.blurWhenBackgrounded = true,
    this.enabled = true,
    super.key,
  });

  final Widget child;
  final Widget Function(BuildContext context, SecurityStatus status)?
      detectedBuilder;
  final Set<SecurityRisk> checks;

  /// When true (default), risks are rechecked on app resume and every
  /// [recheckInterval]. When false, only the first check runs (plus a recheck
  /// if [checks] changes); the result is kept for the widget's lifetime.
  final bool recheck;

  /// Interval between periodic rechecks. Ignored when [recheck] is false.
  final Duration recheckInterval;
  final ValueChanged<SecurityStatus>? onDetected;

  /// Blocks ordinary screenshots and non-secure capture on Android, and
  /// excludes the window from screen capture on Windows.
  /// iOS does not expose a public API to prevent screenshots.
  final bool preventScreenshots;

  /// Blurs this widget while the app is inactive or backgrounded.
  final bool blurWhenBackgrounded;

  /// When false, the widget renders [child] with no checks or protection.
  final bool enabled;

  @override
  State<SecurePreview> createState() => _SecurePreviewState();
}

class _SecurePreviewState extends State<SecurePreview>
    with WidgetsBindingObserver {
  SecurityStatus? _status;
  Timer? _timer;
  bool _checking = false;
  bool _isForeground = true;
  bool _protectionApplied = false;

  /// Platforms with a native detector implementation (Android, iOS, Windows).
  /// Web, macOS and Linux are never "active".
  /// Uses [defaultTargetPlatform] (not dart:io) so it is safe on web and can
  /// be overridden in widget tests.
  static bool get _isSupportedPlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.windows);

  static bool _isActive(SecurePreview w) => w.enabled && _isSupportedPlatform;

  bool get _active => _isActive(widget);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (_active) _start();
  }

  void _start() {
    _protectionApplied = true;
    SecurePreviewDetector.setScreenshotProtection(widget.preventScreenshots);
    _refresh();
    _restartTimer();
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
    if (_protectionApplied) {
      _protectionApplied = false;
      SecurePreviewDetector.setScreenshotProtection(false);
    }
    // Forget stale results so a later re-enable starts hidden until checked.
    _status = null;
  }

  void _restartTimer() {
    _timer?.cancel();
    _timer = widget.recheck
        ? Timer.periodic(widget.recheckInterval, (_) => _refresh())
        : null;
  }

  @override
  void didUpdateWidget(covariant SecurePreview oldWidget) {
    super.didUpdateWidget(oldWidget);

    final wasActive = _isActive(oldWidget);
    if (wasActive != _active) {
      _active ? _start() : _stop();
      return;
    }
    if (!_active) return;

    if (oldWidget.recheckInterval != widget.recheckInterval ||
        oldWidget.recheck != widget.recheck) {
      _restartTimer();
    }
    // Turning rechecks back on: refresh now rather than wait for the timer.
    if (!oldWidget.recheck && widget.recheck) _refresh();
    if (!setEquals(oldWidget.checks, widget.checks)) _refresh();
    if (oldWidget.preventScreenshots != widget.preventScreenshots) {
      SecurePreviewDetector.setScreenshotProtection(widget.preventScreenshots);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final foreground = state == AppLifecycleState.resumed;

    // Track foreground state even while inactive so it is correct if the
    // widget is enabled later.
    if (!_active) {
      _isForeground = foreground;
      return;
    }

    if (mounted && _isForeground != foreground) {
      setState(() => _isForeground = foreground);
    }
    if (foreground && widget.recheck) _refresh();
  }

  Future<void> _refresh() async {
    if (_checking || !mounted || !_active) return;
    _checking = true;
    try {
      final raw = await SecurePreviewDetector.check();
      final filtered = SecurityStatus(
        detectedRisks: raw.detectedRisks.where(widget.checks.contains).toSet(),
      );
      // The widget may have been disabled or disposed while awaiting.
      if (!mounted || !_active) return;
      final previous = _status;
      setState(() => _status = filtered);
      if (filtered.isCompromised &&
          (previous == null ||
              previous.isSafe ||
              !setEquals(previous.detectedRisks, filtered.detectedRisks))) {
        widget.onDetected?.call(filtered);
      }
    } catch (error, stack) {
      // Fail closed: with no status the child stays hidden.
      FlutterError.reportError(FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'secure_preview',
        context: ErrorDescription('while checking device security'),
      ));
    } finally {
      _checking = false;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    if (_protectionApplied) {
      SecurePreviewDetector.setScreenshotProtection(false);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_active) return widget.child;

    final status = _status;
    final Widget content;
    if (status == null) {
      content = const SizedBox.shrink();
    } else if (status.isCompromised) {
      content = widget.detectedBuilder?.call(context, status) ??
          const SizedBox.shrink();
    } else {
      content = widget.child;
    }

    // The child always sits in the same slot and the blur is only laid over
    // it, so going inactive (notification shade, an incoming call banner …)
    // does not rebuild the child from scratch; a video player would restart.
    return Stack(
      fit: StackFit.passthrough,
      children: [
        content,
        if (!_isForeground && widget.blurWhenBackgrounded)
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: const ColoredBox(color: Color(0xCCFFFFFF)),
            ),
          ),
      ],
    );
  }
}
