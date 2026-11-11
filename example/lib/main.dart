import 'package:flutter/material.dart';
import 'package:secure_preview/secure_preview.dart';

void main() => runApp(const MaterialApp(home: PreviewExample()));

class PreviewExample extends StatelessWidget {
  const PreviewExample({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Secure preview example')),
        body: Center(
          child: SecurePreview(
            onDetected: (status) => debugPrint('Security risks: ${status.detectedRisks}'),
            detectedBuilder: (context, status) => const Text('Preview unavailable on this device.'),
            child: const Text('Sensitive preview content'),
          ),
        ),
      );
}
