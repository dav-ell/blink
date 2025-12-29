import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../utils/theme.dart';

class ChatFilters {
  bool hasCode;
  bool hasTodos;
  bool hasToolCalls;
  bool includeArchived;
  String sortBy;
  DateTime? startDate;
  DateTime? endDate;

  ChatFilters({
    this.hasCode = false,
    this.hasTodos = false,
    this.hasToolCalls = false,
    this.includeArchived = false,
    this.sortBy = 'last_updated',
    this.startDate,
    this.endDate,
  });

  bool get hasActiveFilters {
    return hasCode ||
        hasTodos ||
        hasToolCalls ||
        includeArchived ||
        startDate != null ||
        endDate != null ||
        sortBy != 'last_updated';
  }

  void clear() {
    hasCode = false;
    hasTodos = false;
    hasToolCalls = false;
    includeArchived = false;
    sortBy = 'last_updated';
    startDate = null;
    endDate = null;
  }
}

class FilterSheet extends StatefulWidget {
  final ChatFilters filters;
  final Function(ChatFilters) onApply;

  const FilterSheet({
    super.key,
    required this.filters,
    required this.onApply,
  });

  @override
  State<FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<FilterSheet> {
  late ChatFilters _filters;

  @override
  void initState() {
    super.initState();
    _filters = ChatFilters(
      hasCode: widget.filters.hasCode,
      hasTodos: widget.filters.hasTodos,
      hasToolCalls: widget.filters.hasToolCalls,
      includeArchived: widget.filters.includeArchived,
      sortBy: widget.filters.sortBy,
      startDate: widget.filters.startDate,
      endDate: widget.filters.endDate,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDark : AppTheme.surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(AppTheme.radiusXLarge),
          topRight: Radius.circular(AppTheme.radiusXLarge),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.symmetric(vertical: AppTheme.spacingMedium),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: (isDark ? AppTheme.textTertiaryDark : AppTheme.textTertiary).withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacingLarge,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Filters',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimary,
                  ),
                ),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () {
                    setState(() {
                      _filters.clear();
                    });
                  },
                  child: Text(
                    'Clear All',
                    style: TextStyle(
                      color: isDark ? AppTheme.primaryLight : AppTheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppTheme.spacingMedium),

          // Filter options
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacingLarge,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Content Type Section
                  _buildSectionTitle('Content Type', isDark),
                  _buildFilterSwitch(
                    'Has Code Blocks',
                    CupertinoIcons.chevron_left_slash_chevron_right,
                    AppTheme.codeColor,
                    _filters.hasCode,
                    (value) => setState(() => _filters.hasCode = value),
                    isDark,
                  ),
                  _buildFilterSwitch(
                    'Has Todo Items',
                    CupertinoIcons.check_mark_circled,
                    AppTheme.todoColor,
                    _filters.hasTodos,
                    (value) => setState(() => _filters.hasTodos = value),
                    isDark,
                  ),
                  _buildFilterSwitch(
                    'Has Tool Calls',
                    CupertinoIcons.wrench,
                    AppTheme.toolCallColor,
                    _filters.hasToolCalls,
                    (value) => setState(() => _filters.hasToolCalls = value),
                    isDark,
                  ),

                  const SizedBox(height: AppTheme.spacingLarge),

                  // Status Section
                  _buildSectionTitle('Status', isDark),
                  _buildFilterSwitch(
                    'Include Archived',
                    CupertinoIcons.archivebox,
                    AppTheme.archivedStatus,
                    _filters.includeArchived,
                    (value) => setState(() => _filters.includeArchived = value),
                    isDark,
                  ),

                  const SizedBox(height: AppTheme.spacingLarge),

                  // Sort Section
                  _buildSectionTitle('Sort By', isDark),
                  _buildSortOption('Most Recent', 'last_updated', isDark),
                  _buildSortOption('Oldest First', 'created', isDark),
                  _buildSortOption('Name', 'name', isDark),

                  const SizedBox(height: AppTheme.spacingXLarge),
                ],
              ),
            ),
          ),

          // Apply button
          Container(
            padding: const EdgeInsets.all(AppTheme.spacingLarge),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.surfaceDark : AppTheme.surface,
              border: Border(
                top: BorderSide(
                  color: (isDark ? Colors.white : Colors.black).withOpacity(0.1),
                  width: 0.5,
                ),
              ),
            ),
            child: SafeArea(
              child: SizedBox(
                width: double.infinity,
                child: CupertinoButton.filled(
                  onPressed: () {
                    widget.onApply(_filters);
                    Navigator.pop(context);
                  },
                  child: const Text(
                    'Apply Filters',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacingSmall),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildFilterSwitch(
    String label,
    IconData icon,
    Color color,
    bool value,
    Function(bool) onChanged,
    bool isDark,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingSmall),
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingMedium,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: value
            ? color.withOpacity(0.15)
            : (isDark ? AppTheme.surfaceLightDark : AppTheme.surfaceLight),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: value ? color.withOpacity(0.3) : Colors.transparent,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: value ? color : (isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondary),
          ),
          const SizedBox(width: AppTheme.spacingMedium),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 17,
                color: value
                    ? color
                    : (isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimary),
                fontWeight: value ? FontWeight.w500 : FontWeight.normal,
              ),
            ),
          ),
          CupertinoSwitch(
            value: value,
            onChanged: onChanged,
            activeColor: color,
          ),
        ],
      ),
    );
  }

  Widget _buildSortOption(String label, String value, bool isDark) {
    final isSelected = _filters.sortBy == value;

    return GestureDetector(
      onTap: () {
        setState(() {
          _filters.sortBy = value;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: AppTheme.spacingSmall),
        padding: const EdgeInsets.all(AppTheme.spacingMedium),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primary.withOpacity(0.15)
              : (isDark ? AppTheme.surfaceLightDark : AppTheme.surfaceLight),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppTheme.primary : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? CupertinoIcons.check_mark_circled_solid : CupertinoIcons.circle,
              color: isSelected
                  ? AppTheme.primary
                  : (isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondary),
              size: 22,
            ),
            const SizedBox(width: AppTheme.spacingMedium),
            Text(
              label,
              style: TextStyle(
                fontSize: 17,
                color: isSelected
                    ? AppTheme.primary
                    : (isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimary),
                fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

