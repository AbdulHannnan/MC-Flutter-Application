// lib/src/core/widgets/category_chip.dart — a category shortcut tile. Dart port
// of the RN app's `CategoryChip.tsx`.
//
// A small, fixed-width elevated card for the horizontal "Categories" strip on the
// Home dashboard (Module 9): a cover image over a one-line name. Presentational —
// a ServiceCategory in, a tappable tile out; the parent supplies [onTap].

import 'package:flutter/widgets.dart';

import '../../models/service.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';
import 'app_card.dart';
import 'app_text.dart';

class CategoryChip extends StatelessWidget {
  final ServiceCategory category;
  final VoidCallback? onTap;

  const CategoryChip({super.key, required this.category, this.onTap});

  @override
  Widget build(BuildContext context) {
    final uri = category.image?.uri;
    return Semantics(
      button: onTap != null,
      label: category.name,
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: 150,
          child: AppCard(
            elevated: true,
            padding: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 96,
                  child: uri == null
                      ? const ColoredBox(color: AppColors.surfaceAlt)
                      : Image.network(
                          uri,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) =>
                              const ColoredBox(color: AppColors.surfaceAlt),
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: AppText(
                    category.name,
                    variant: AppTextVariant.bodyStrong,
                    maxLines: 1,
                    style: const TextStyle(height: 1),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
