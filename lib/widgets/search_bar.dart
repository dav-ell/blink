import 'dart:async';
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
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingMedium,
        vertical: AppTheme.spacingSmall,
      ),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.surfaceLight,
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              ),
              child: TextField(
                controller: _controller,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: 'Search chats...',
                  hintStyle: TextStyle(
                    color: AppTheme.textTertiary,
                    fontSize: 15,
                  ),
                  prefixIcon: const Icon(
                    Icons.search,
                    color: AppTheme.textTertiary,
                    size: 22,
                  ),
                  suffixIcon: _controller.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(
                            Icons.clear,
                            color: AppTheme.textTertiary,
                            size: 20,
                          ),
                          onPressed: () {
                            _controller.clear();
                            widget.onSearch('');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacingMedium,
                    vertical: AppTheme.spacingMedium,
                  ),
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
                        ? AppTheme.primary.withOpacity(0.1)
                        : AppTheme.surfaceLight,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  ),
                  child: IconButton(
                    icon: Icon(
                      Icons.filter_list,
                      color: widget.hasActiveFilters
                          ? AppTheme.primary
                          : AppTheme.textSecondary,
                    ),
                    onPressed: widget.onFilterTap,
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

