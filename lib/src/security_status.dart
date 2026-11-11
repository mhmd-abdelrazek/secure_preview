enum SecurityRisk {
  rooted,
  emulator,
  developerOptions,
  usbDebugging,
  screenMirroring,
  screenRecording,
  externalDisplay,
}

class SecurityStatus {
  const SecurityStatus({required this.detectedRisks});

  final Set<SecurityRisk> detectedRisks;

  bool get isSafe => detectedRisks.isEmpty;
  bool get isCompromised => !isSafe;

  bool contains(SecurityRisk risk) => detectedRisks.contains(risk);

  @override
  String toString() => 'SecurityStatus(detectedRisks: $detectedRisks)';
}
