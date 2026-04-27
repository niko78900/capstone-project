import 'package:cap_app/features/catalog/utils/barcode_resolution.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

Future<String?> scanBarcodeWithDevice(BuildContext context) async {
  if (defaultTargetPlatform != TargetPlatform.android) {
    if (!context.mounted) {
      return null;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Barcode scanning is currently enabled on Android in this build.',
        ),
      ),
    );
    return null;
  }

  return Navigator.of(context, rootNavigator: true).push<String>(
    MaterialPageRoute<String>(builder: (_) => const BarcodeScannerScreen()),
  );
}

class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen>
    with WidgetsBindingObserver {
  final MobileScannerController _controller = MobileScannerController(
    cameraResolution: const Size(1280, 720),
    detectionSpeed: DetectionSpeed.noDuplicates,
    useNewCameraSelector: true,
  );
  final ImagePicker _imagePicker = ImagePicker();
  bool _handled = false;
  bool _scanFromPhotoBusy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted || _handled) {
      return;
    }
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _controller.stop();
      return;
    }
    if (state == AppLifecycleState.resumed) {
      _restartCamera();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan barcode'),
        actions: [
          IconButton(
            tooltip: 'Retry camera',
            onPressed: _restartCamera,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: MobileScanner(
                    controller: _controller,
                    errorBuilder: (context, error, child) {
                      return _ScannerStatusOverlay(
                        title: 'Camera unavailable',
                        message: _cameraErrorMessage(error),
                      );
                    },
                    onDetect: (capture) {
                      if (_handled) {
                        return;
                      }
                      final code = capture.barcodes
                          .map((item) => item.rawValue)
                          .whereType<String>()
                          .map(normalizeBarcodeInput)
                          .firstWhere(
                            (value) => value.isNotEmpty,
                            orElse: () => '',
                          );
                      if (code.isEmpty) {
                        return;
                      }
                      _handled = true;
                      Navigator.of(context).pop(code);
                    },
                  ),
                ),
                Positioned(
                  left: 24,
                  right: 24,
                  top: 24,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.surface.withValues(alpha: 0.82),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        'Align the barcode inside the frame. If preview stays blank on emulator, use Scan from photo.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ),
                ),
                Align(
                  child: IgnorePointer(
                    child: Container(
                      width: 240,
                      height: 140,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.primary,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 24,
                  right: 24,
                  bottom: 24,
                  child: ValueListenableBuilder<MobileScannerState>(
                    valueListenable: _controller,
                    builder: (context, state, child) {
                      final hasFeed =
                          state.isInitialized &&
                          state.error == null &&
                          state.size.width > 0 &&
                          state.size.height > 0;
                      if (hasFeed) {
                        return const SizedBox.shrink();
                      }
                      return DecoratedBox(
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.surface.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(
                            'Camera feed is unavailable. Retry or scan from a photo.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _openManualCodeEntry,
                    icon: const Icon(Icons.numbers_outlined),
                    label: const Text('Enter code manually'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: _scanFromPhotoBusy
                        ? null
                        : _scanBarcodeFromPhoto,
                    icon: _scanFromPhotoBusy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.photo_library_outlined),
                    label: const Text('Scan from photo'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _restartCamera() async {
    try {
      await _controller.stop();
      await _controller.start();
    } on MobileScannerException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_cameraErrorMessage(error))));
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not restart the camera preview. Enter code manually if needed.',
          ),
        ),
      );
    }
  }

  Future<void> _scanBarcodeFromPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (modalContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Take photo'),
                onTap: () => Navigator.of(modalContext).pop(ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Choose from gallery'),
                onTap: () =>
                    Navigator.of(modalContext).pop(ImageSource.gallery),
              ),
            ],
          ),
        );
      },
    );
    if (!mounted || source == null) {
      return;
    }

    setState(() {
      _scanFromPhotoBusy = true;
    });
    try {
      final picked = await _imagePicker.pickImage(source: source);
      if (!mounted || picked == null) {
        return;
      }
      final capture = await _controller.analyzeImage(picked.path);
      if (!mounted) {
        return;
      }
      final code =
          capture?.barcodes
              .map((item) => item.rawValue)
              .whereType<String>()
              .map(normalizeBarcodeInput)
              .firstWhere((value) => value.isNotEmpty, orElse: () => '') ??
          '';
      if (code.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No barcode was detected in the selected image.'),
          ),
        );
        return;
      }
      _handled = true;
      Navigator.of(context).pop(code);
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not analyze image. Please try another photo.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _scanFromPhotoBusy = false;
        });
      }
    }
  }

  String _cameraErrorMessage(MobileScannerException error) {
    switch (error.errorCode) {
      case MobileScannerErrorCode.permissionDenied:
        return 'Camera permission was denied. Enable it in app settings and retry.';
      case MobileScannerErrorCode.unsupported:
        return 'Barcode scanning is not supported on this device/emulator.';
      case MobileScannerErrorCode.controllerDisposed:
      case MobileScannerErrorCode.controllerUninitialized:
      case MobileScannerErrorCode.controllerAlreadyInitialized:
      case MobileScannerErrorCode.genericError:
        final details = error.errorDetails?.message?.trim();
        if (details != null && details.isNotEmpty) {
          return details;
        }
        return 'Scanner failed to initialize. Retry or enter code manually.';
    }
  }

  Future<void> _openManualCodeEntry() async {
    final controller = TextEditingController();
    final entered = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Enter barcode manually'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Barcode or product code',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(controller.text.trim()),
              child: const Text('Use code'),
            ),
          ],
        );
      },
    );
    if (!mounted) {
      return;
    }
    final normalized = normalizeBarcodeInput(entered ?? '');
    if (normalized.isEmpty) {
      return;
    }
    _handled = true;
    Navigator.of(context).pop(normalized);
  }
}

class _ScannerStatusOverlay extends StatelessWidget {
  const _ScannerStatusOverlay({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      message,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
