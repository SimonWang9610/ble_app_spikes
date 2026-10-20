import 'package:flutter/material.dart';

/// An inline progress indicator, sized to sit in a row or a list tile.
class SmallSpinner extends StatelessWidget {
  const SmallSpinner({super.key, this.size = 14});

  final double size;

  @override
  Widget build(BuildContext context) =>
      SizedBox.square(dimension: size, child: const CircularProgressIndicator(strokeWidth: 2));
}
