import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/services/image_vault.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/motion.dart';

/// Displays an encrypted vault image: decrypts in memory and fades in.
/// Shows a soft placeholder while loading or when the file is missing.
class VaultImage extends StatelessWidget {
  final String fileName;
  final BoxFit fit;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;

  const VaultImage({
    super.key,
    required this.fileName,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(12);
    return ClipRRect(
      borderRadius: radius,
      child: SizedBox(
        width: width,
        height: height,
        child: fileName.isEmpty
            ? const _Placeholder()
            : FutureBuilder<Uint8List?>(
                future: ImageVault.instance.read(fileName),
                builder: (context, snapshot) {
                  final bytes = snapshot.data;
                  if (bytes == null) return const _Placeholder();
                  return AnimatedSwitcher(
                    duration: AppMotion.base,
                    child: Image.memory(
                      bytes,
                      key: ValueKey(fileName),
                      fit: fit,
                      width: width,
                      height: height,
                      gaplessPlayback: true,
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.bgSunken,
      child: const Center(
        child: Icon(
          Icons.description_outlined,
          color: AppColors.textTertiary,
          size: 28,
        ),
      ),
    );
  }
}
