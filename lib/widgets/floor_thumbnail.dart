import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../config/theme.dart';
import '../models/catalog.dart';
import '../services/floor_repository.dart';

class FloorThumbnail extends StatelessWidget {
  const FloorThumbnail({super.key, required this.item, this.padding = const EdgeInsets.all(10)});

  final FloorItem item;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: KColors.paper,
      padding: padding,
      child: FutureBuilder<String>(
        future: FloorRepository.thumbnail(item),
        builder: (context, snap) {
          if (snap.hasError) {
            return const Center(child: Icon(Icons.broken_image_outlined, color: KColors.slateLight));
          }
          if (!snap.hasData) {
            return const Center(
              child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
            );
          }
          return SvgPicture.string(snap.data!, fit: BoxFit.contain);
        },
      ),
    );
  }
}
