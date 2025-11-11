import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../utils/theme.dart';

class ChatSearchBar extends StatefulWidget {
  final Function(String) onSearch;
  final VoidCallback? onFilterTap;
  final bool hasActiveFilters;

  const ChatSearchBar({
    super.key,
    required this.onSearch,
    this.onFilterTap,
    this.hasActiveFilters = false,
  });

  @override
  State<ChatSearchBar> createState() => _ChatSearchBarState();
}

class _ChatSearchBarState extends State<ChatSearchBar> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    _debounce = Timer(const Duration(milliseconds: 300), () {
      widget.onSearch(query);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingMedium,
        vertical: AppTheme.spacingSmall,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDark : AppTheme.surface,
        border: Border(
          bottom: BorderSide(
            color: (isDark ? Colors.white : Colors.black).withOpacity(0.1),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? AppTheme.surfaceLightDark : AppTheme.surfaceLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: CupertinoTextField(
                controller: _controller,
                onChanged: _onSearchChanged,
                placeholder: 'Search chats...',
                placeholderStyle: TextStyle(
                  color: isDark ? AppTheme.textTertiaryDark : AppTheme.textTertiary,
                  fontSize: 17,
                ),
                style: TextStyle(
                  color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimary,
                  fontSize: 17,
                ),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.surfaceLightDark : AppTheme.surfaceLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                prefix: Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Icon(
                    CupertinoIcons.search,
                    color: isDark ? AppTheme.textTertiaryDark : AppTheme.textTertiary,
                    size: 20,
                  ),
                ),
                suffix: _controller.text.isNotEmpty
                    ? CupertinoButton(
                        padding: const EdgeInsets.only(right: 8),
                        minSize: 0,
                        onPressed: () {
                          _controller.clear();
                          widget.onSearch('');
                          setState(() {});
                        },
                        child: Icon(
                          CupertinoIcons.clear_circled_solid,
                          color: isDark ? AppTheme.textTertiaryDark : AppTheme.textTertiary,
                          size: 18,
                        ),
                      )
                    : null,
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 12,
                ),
              ),
            ),
          ),
          if (widget.onFilterTap != null) ...[
            const SizedBox(width: AppTheme.spacingSmall),
            Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: widget.hasActiveFilters
                        ? AppTheme.primary.withOpacity(0.15)
                        : (isDark ? AppTheme.surfaceLightDark : AppTheme.surfaceLight),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: CupertinoButton(
                    padding: const EdgeInsets.all(12),
                    onPressed: widget.onFilterTap,
                    child: Icon(
                      CupertinoIcons.slider_horizontal_3,
                      color: widget.hasActiveFilters
                          ? AppTheme.primary
                          : (isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondary),
                      size: 22,
                    ),
                  ),
                ),
                if (widget.hasActiveFilters)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppTheme.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

