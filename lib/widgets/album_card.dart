import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../models/media.dart';
import '../screens/collection_screen.dart';
import 'media_art.dart';

/// Square artwork card shown in Home / Library shelves for collections.
class AlbumCard extends StatelessWidget {
  const AlbumCard({super.key, required this.collection});

  final Collection collection;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => openCollection(context, collection),
      child: SizedBox(
        width: 148,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MediaArt(
              url: collection.imageUrl ?? '',
              size: 148,
              radius: AstraTheme.radiusM,
            ),
            const SizedBox(height: 10),
            Text(
              collection.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 2),
            Text(
              collection.subtitle ?? collection.type.name.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

/// Circular artist card (same shelf, rounded to a circle).
class ArtistCard extends StatelessWidget {
  const ArtistCard({super.key, required this.collection});

  final Collection collection;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => openCollection(context, collection),
      child: SizedBox(
        width: 128,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            MediaArt(
              url: collection.imageUrl ?? '',
              size: 128,
              radius: 64,
            ),
            const SizedBox(height: 10),
            Text(
              collection.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
