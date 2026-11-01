import 'package:flutter/material.dart';

import 'media_art.dart';

/// One horizontal, scrollable shelf of square artwork cards (Home tab).
class ArtworkShelf extends StatelessWidget {
  const ArtworkShelf({
    super.key,
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        SizedBox(
          height: 190,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: children.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (_, i) => children[i],
          ),
        ),
      ],
    );
  }
}

/// Full-width shimmer placeholders shown while a shelf loads.
class PlaceholderShelf extends StatelessWidget {
  const PlaceholderShelf({super.key, required this.titlePlaceholderCount});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: ShimmerBox(width: 140, height: 16),
        ),
        SizedBox(
          height: 190,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: titlePlaceholderCount,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (_, __) => const SizedBox(
              width: 148,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShimmerBox(width: 148, height: 148, radius: 14),
                  SizedBox(height: 8),
                  ShimmerBox(width: 120, height: 12),
                  SizedBox(height: 6),
                  ShimmerBox(width: 80, height: 10),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
