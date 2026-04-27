import 'package:flutter/material.dart';

class BarcodeAssetIcon extends StatelessWidget {
  const BarcodeAssetIcon({this.size = 26, super.key});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/icons/barcode_icon.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
    );
  }
}
