import 'package:flutter/material.dart';

import '../screens/home_screen.dart';
import '../theme/app_theme.dart';

class CodeAtlasAppBar extends StatelessWidget implements PreferredSizeWidget {
  final List<Widget>? actions;

  const CodeAtlasAppBar({
    super.key,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      toolbarHeight: 88,
      backgroundColor: AppColors.navy,
      elevation: 0,
      titleSpacing: 12,
      title: const Row(
        children: [
          AnimatedLogo(),
          SizedBox(width: 16),
          Expanded(
            child: AnimatedBrandText(),
          ),
        ],
      ),
      actions: actions,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(88);
}