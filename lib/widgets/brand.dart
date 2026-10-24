import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../config/theme.dart';

/// Logo mark + "KREEDUM / CONSTRUCTION" wordmark.
class BrandLockup extends StatelessWidget {
  const BrandLockup({super.key, this.onDark = true, this.markSize = 34});

  final bool onDark;
  final double markSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          onDark ? 'assets/brand/logo_mark_white.png' : 'assets/brand/logo_mark.png',
          width: markSize,
          height: markSize,
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              AppConfig.brandWord,
              style: KText.display(
                markSize * 0.56,
                color: onDark ? KColors.white : KColors.navy,
              ).copyWith(letterSpacing: 0.6, height: 1),
            ),
            const SizedBox(height: 3),
            Text(
              AppConfig.brandSub,
              style: KText.eyebrow(color: onDark ? KColors.accentLight : KColors.blue)
                  .copyWith(fontSize: markSize * 0.25, letterSpacing: 2.6, height: 1),
            ),
          ],
        ),
      ],
    );
  }
}
