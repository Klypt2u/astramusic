import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../core/theme.dart';

/// Rounded artwork with a graceful loading shimmer + error fallback.
class MediaArt extends StatelessWidget {
  const MediaArt({
    super.key,
    required this.url,
    this.size,
    this.width,
    this.height,
    this.radius = AstraTheme.radiusM,
    this.fit = BoxFit.cover,
  });

  final String url;
  final double? size;
  final double? width;
  final double? height;
  final double radius;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final effectiveWidth = width ?? size ?? 60;
    final effectiveHeight = height ?? size ?? 60;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: effectiveWidth,
        height: effectiveHeight,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: CachedNetworkImage(
            key: ValueKey(url),
            imageUrl: url,
            fit: fit,
            fadeInDuration: const Duration(milliseconds: 220),
            placeholder: (_, __) => const ShimmerBox(),
            errorWidget: (_, __, ___) => Container(
              color: AstraTheme.surfaceHigh,
              alignment: Alignment.center,
              child: const Icon(Icons.music_note_rounded,
                  color: AstraTheme.textSecondary),
            ),
          ),
        ),
      ),
    );
  }
}

/// Minimal blocky shimmer used by every loading placeholder.
class ShimmerBox extends StatelessWidget {
  const ShimmerBox({
    super.key,
    this.width,
    this.height,
    this.radius = 12,
  });

  final double? width;
  final double? height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AstraTheme.surfaceHigh,
      highlightColor: AstraTheme.surfaceHigh.withOpacity(0.45),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: AstraTheme.surfaceHigh,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}
