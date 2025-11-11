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
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.only(
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
              color: AppTheme.textTertiary.withOpacity(0.3),
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
                const Text(
                  'Filters',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _filters.clear();
                    });
                  },
                  child: const Text('Clear All'),
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
                  _buildSectionTitle('Content Type'),
                  _buildFilterSwitch(
                    'Has Code Blocks',
                    Icons.code,
                    AppTheme.codeColor,
                    _filters.hasCode,
                    (value) => setState(() => _filters.hasCode = value),
                  ),
                  _buildFilterSwitch(
                    'Has Todo Items',
                    Icons.check_circle_outline,
                    AppTheme.todoColor,
                    _filters.hasTodos,
                    (value) => setState(() => _filters.hasTodos = value),
                  ),
                  _buildFilterSwitch(
                    'Has Tool Calls',
                    Icons.build_circle,
                    AppTheme.toolCallColor,
                    _filters.hasToolCalls,
                    (value) => setState(() => _filters.hasToolCalls = value),
                  ),

                  const SizedBox(height: AppTheme.spacingLarge),

                  // Status Section
                  _buildSectionTitle('Status'),
                  _buildFilterSwitch(
                    'Include Archived',
                    Icons.archive,
                    AppTheme.archivedStatus,
                    _filters.includeArchived,
                    (value) => setState(() => _filters.includeArchived = value),
                  ),

                  const SizedBox(height: AppTheme.spacingLarge),

                  // Sort Section
                  _buildSectionTitle('Sort By'),
                  _buildSortOption('Most Recent', 'last_updated'),
                  _buildSortOption('Oldest First', 'created'),
                  _buildSortOption('Name', 'name'),

                  const SizedBox(height: AppTheme.spacingXLarge),
                ],
              ),
            ),
          ),

          // Apply button
          Container(
            padding: const EdgeInsets.all(AppTheme.spacingLarge),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    widget.onApply(_filters);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      vertical: AppTheme.spacingMedium,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                    ),
                  ),
                  child: const Text(
                    'Apply Filters',
                    style: TextStyle(
                      fontSize: 16,
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

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacingSmall),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppTheme.textSecondary,
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
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingSmall),
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingMedium,
        vertical: AppTheme.spacingSmall,
      ),
      decoration: BoxDecoration(
        color: value ? color.withOpacity(0.1) : AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
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
            color: value ? color : AppTheme.textSecondary,
          ),
          const SizedBox(width: AppTheme.spacingMedium),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 15,
                color: value ? color : AppTheme.textPrimary,
                fontWeight: value ? FontWeight.w500 : FontWeight.normal,
              ),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: color,
          ),
        ],
      ),
    );
  }

  Widget _buildSortOption(String label, String value) {
    final isSelected = _filters.sortBy == value;
    
    return InkWell(
      onTap: () {
        setState(() {
          _filters.sortBy = value;
        });
      },
      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      child: Container(
        margin: const EdgeInsets.only(bottom: AppTheme.spacingSmall),
        padding: const EdgeInsets.all(AppTheme.spacingMedium),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary.withOpacity(0.1) : AppTheme.surfaceLight,
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          border: Border.all(
            color: isSelected ? AppTheme.primary : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
              size: 20,
            ),
            const SizedBox(width: AppTheme.spacingMedium),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                color: isSelected ? AppTheme.primary : AppTheme.textPrimary,
                fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

