import 'package:flutter/material.dart';
import 'package:ell_tall_market/widgets/custom_search_bar.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final bool showBackButton;
  final Widget? leading;
  final Color? backgroundColor;
  final double elevation;
  final bool centerTitle;
  final Widget? flexibleSpace;
  final double? titleSpacing;
  final TextStyle? titleStyle;
  final IconThemeData? iconTheme;
  final ShapeBorder? shape;

  const CustomAppBar({
    super.key,
    required this.title,
    this.actions,
    this.showBackButton = true,
    this.leading,
    this.backgroundColor,
    this.elevation = 0,
    this.centerTitle = true,
    this.flexibleSpace,
    this.titleSpacing,
    this.titleStyle,
    this.iconTheme,
    this.shape,
  });

  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(
        title,
        style:
            titleStyle ??
            TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
      ),
      actions: actions,
      automaticallyImplyLeading: showBackButton,
      leading: leading,
      backgroundColor: backgroundColor ?? Colors.white,
      elevation: elevation,
      centerTitle: centerTitle,
      flexibleSpace: flexibleSpace,
      titleSpacing: titleSpacing,
      iconTheme: iconTheme ?? IconThemeData(color: Colors.black),
      shape: shape,
    );
  }
}

class SearchAppBar extends StatelessWidget implements PreferredSizeWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onCancel;
  final String hintText;

  const SearchAppBar({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.onCancel,
    this.hintText = 'ابحث عن منتج...',
  });

  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 1,
      automaticallyImplyLeading: false,
      title: CompactSearchBar(
        controller: controller,
        hintText: hintText,
        onChanged: onChanged,
        onClear: () => onChanged(''),
      ),
      actions: [
        TextButton(
          onPressed: onCancel,
          child: Text('إلغاء', style: TextStyle(color: Colors.black)),
        ),
      ],
    );
  }
}

class TransparentAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final Color? textColor;
  final Color? iconColor;

  const TransparentAppBar({
    super.key,
    required this.title,
    this.actions,
    this.textColor = Colors.white,
    this.iconColor = Colors.white,
  });

  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(
        title,
        style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
      ),
      actions: actions,
      backgroundColor: Colors.transparent,
      elevation: 0,
      iconTheme: IconThemeData(color: iconColor),
    );
  }
}

class SliverAppBarWithTabs extends StatelessWidget {
  final String title;
  final List<Tab> tabs;
  final TabController? tabController;

  const SliverAppBarWithTabs({
    super.key,
    required this.title,
    required this.tabs,
    this.tabController,
  });

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      title: Text(title),
      pinned: true,
      floating: true,
      snap: true,
      bottom: TabBar(
        controller: tabController,
        tabs: tabs,
        indicatorColor: Theme.of(context).primaryColor,
        labelColor: Theme.of(context).primaryColor,
        unselectedLabelColor: Colors.grey,
      ),
    );
  }
}
