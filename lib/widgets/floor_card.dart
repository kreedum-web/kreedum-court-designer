import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../models/catalog.dart';
import '../screens/editor_screen.dart';
import 'floor_thumbnail.dart';

/// Grid tile for one floor design. Tapping it opens the colour editor.
class FloorCard extends StatelessWidget {
  const FloorCard({super.key, required this.item});

  final FloorItem item;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Material(
      color: KColors.white,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          FocusScope.of(context).unfocus(); // close the keyboard if search was open
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => EditorScreen(item: item)));
        },
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: KColors.paperDim),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: FloorThumbnail(item: item)),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.titleSmall),
                    const SizedBox(height: 2),
                    Text(item.category.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.bodySmall),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
