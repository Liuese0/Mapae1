import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/models/category.dart';
import '../screens/wallet_screen.dart';

class SearchFilterBar extends ConsumerStatefulWidget {
  final List<CardCategory> categories;

  const SearchFilterBar({
    super.key,
    required this.categories,
  });

  @override
  ConsumerState<SearchFilterBar> createState() => _SearchFilterBarState();
}

class _SearchFilterBarState extends ConsumerState<SearchFilterBar> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _showCategorySheet() {
    final selectedCategory = ref.read(walletCategoryProvider);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _CategorySelectionSheet(
          categories: widget.categories,
          selectedCategoryId: selectedCategory,
          onSelected: (categoryId) {
            ref.read(walletCategoryProvider.notifier).state = categoryId;
            Navigator.pop(context);
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedCategory = ref.watch(walletCategoryProvider);
    final sortMode = ref.watch(walletSortProvider);
    final searchQuery = ref.watch(walletSearchQueryProvider);

    // Find selected category name
    String categoryLabel = '전체';
    if (selectedCategory != null) {
      final match = widget.categories
          .where((c) => c.id == selectedCategory)
          .toList();
      if (match.isNotEmpty) {
        categoryLabel = match.first.name;
      }
    }

    final bool hasCategoryFilter = selectedCategory != null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: TextField(
            controller: _searchController,
            focusNode: _focusNode,
            onChanged: (value) {
              ref.read(walletSearchQueryProvider.notifier).state = value;
            },
            style: theme.textTheme.bodyMedium,
            decoration: InputDecoration(
              hintText: '이름, 회사, 직함으로 검색',
              hintStyle: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.4),
              ),
              prefixIcon: Icon(
                Icons.search,
                size: 20,
                color: theme.colorScheme.onSurface.withOpacity(0.4),
              ),
              suffixIcon: searchQuery.isNotEmpty
                  ? IconButton(
                      icon: Icon(
                        Icons.close,
                        size: 18,
                        color: theme.colorScheme.onSurface.withOpacity(0.5),
                      ),
                      onPressed: () {
                        _searchController.clear();
                        ref.read(walletSearchQueryProvider.notifier).state = '';
                        _focusNode.unfocus();
                      },
                    )
                  : null,
              filled: true,
              fillColor: theme.colorScheme.surfaceContainerHighest
                  .withOpacity(0.5),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: theme.colorScheme.primary.withOpacity(0.5),
                  width: 1.5,
                ),
              ),
            ),
          ),
        ),

        // Filter chips row
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              // Category chip
              _FilterChip(
                label: categoryLabel,
                icon: Icons.category_outlined,
                isActive: hasCategoryFilter,
                hasDropdown: true,
                onTap: _showCategorySheet,
                onClear: hasCategoryFilter
                    ? () {
                        ref.read(walletCategoryProvider.notifier).state = null;
                      }
                    : null,
              ),
              const SizedBox(width: 8),

              // Sort chip
              _FilterChip(
                label: sortMode == SortMode.byDate ? '등록순' : '이름순',
                icon: Icons.sort,
                isActive: sortMode != SortMode.byDate,
                onTap: () {
                  ref.read(walletSortProvider.notifier).state =
                      sortMode == SortMode.byDate
                          ? SortMode.byName
                          : SortMode.byDate;
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),
      ],
    );
  }
}

/// Individual filter chip widget
class _FilterChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isActive;
  final bool hasDropdown;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  const _FilterChip({
    required this.label,
    required this.icon,
    this.isActive = false,
    this.hasDropdown = false,
    required this.onTap,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeBg = theme.colorScheme.primary.withOpacity(0.12);
    final activeFg = theme.colorScheme.primary;
    final inactiveFg = theme.colorScheme.onSurface.withOpacity(0.6);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.only(
            left: 10,
            right: onClear != null ? 4 : 10,
            top: 6,
            bottom: 6,
          ),
          decoration: BoxDecoration(
            color: isActive ? activeBg : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isActive
                  ? activeFg.withOpacity(0.4)
                  : theme.colorScheme.outline.withOpacity(0.5),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 14,
                color: isActive ? activeFg : inactiveFg,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                  color: isActive ? activeFg : inactiveFg,
                ),
              ),
              if (hasDropdown) ...[
                const SizedBox(width: 2),
                Icon(
                  Icons.arrow_drop_down,
                  size: 16,
                  color: isActive ? activeFg : inactiveFg,
                ),
              ],
              if (onClear != null) ...[
                const SizedBox(width: 2),
                GestureDetector(
                  onTap: onClear,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: activeFg.withOpacity(0.15),
                    ),
                    child: Icon(
                      Icons.close,
                      size: 12,
                      color: activeFg,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet for category selection
class _CategorySelectionSheet extends StatelessWidget {
  final List<CardCategory> categories;
  final String? selectedCategoryId;
  final Function(String?) onSelected;

  const _CategorySelectionSheet({
    required this.categories,
    required this.selectedCategoryId,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurface.withOpacity(0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Title
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              '카테고리 선택',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          const Divider(height: 1),

          // "All" option
          ListTile(
            leading: Icon(
              Icons.grid_view_rounded,
              color: selectedCategoryId == null
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface.withOpacity(0.5),
            ),
            title: Text(
              '전체',
              style: TextStyle(
                fontWeight: selectedCategoryId == null
                    ? FontWeight.w600
                    : FontWeight.w400,
                color: selectedCategoryId == null
                    ? theme.colorScheme.primary
                    : null,
              ),
            ),
            trailing: selectedCategoryId == null
                ? Icon(Icons.check, color: theme.colorScheme.primary, size: 20)
                : null,
            onTap: () => onSelected(null),
          ),

          // Category items
          if (categories.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                '카테고리가 없습니다',
                style: TextStyle(
                  color: theme.colorScheme.onSurface.withOpacity(0.4),
                ),
              ),
            )
          else
            ...categories.map((category) {
              final isSelected = category.id == selectedCategoryId;
              return ListTile(
                leading: Icon(
                  Icons.label_outline,
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface.withOpacity(0.5),
                ),
                title: Text(
                  category.name,
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected ? theme.colorScheme.primary : null,
                  ),
                ),
                trailing: isSelected
                    ? Icon(Icons.check,
                        color: theme.colorScheme.primary, size: 20)
                    : null,
                onTap: () => onSelected(category.id),
              );
            }),

          SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
        ],
      ),
    );
  }
}
