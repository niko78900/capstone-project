import 'package:cap_app/shared/widgets/android_back_scope.dart';
import 'package:flutter/material.dart';

class GuidedProductSubmissionScreen extends StatelessWidget {
  const GuidedProductSubmissionScreen({this.prefillBarcode, super.key});

  final String? prefillBarcode;

  @override
  Widget build(BuildContext context) {
    return BackToHomeScope(
      child: Scaffold(
        appBar: AppBar(title: const Text('Guided Product Submission')),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Guided product submission will start with barcode scanning.',
              ),
              if ((prefillBarcode ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Prefilled barcode',
                    border: OutlineInputBorder(),
                  ),
                  child: Text(prefillBarcode!.trim()),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
