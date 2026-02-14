import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/app_providers.dart';
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
      isScrollControlled: true,
      builder: (context) {
        return _CategorySelectionSheet(
          categories: widget.categories,
          selectedCategoryId: selectedCategory,
          onSelected: (categoryId) {
            ref.read(walletCategoryProvider.notifier).state = categoryId;
            ref.invalidate(categoriesProvider);
            Navigator.pop(context);
          },
          onCategoriesChanged: () {
            ref.invalidate(categoriesProvider);
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

/// Bottom sheet for category selection with create/delete
class _CategorySelectionSheet extends ConsumerStatefulWidget {
  final List<CardCategory> categories;
  final String? selectedCategoryId;
  final Function(String?) onSelected;
  final VoidCallback onCategoriesChanged;

  const _CategorySelectionSheet({
    required this.categories,
    required this.selectedCategoryId,
    required this.onSelected,
    required this.onCategoriesChanged,
  });

  @override
  ConsumerState<_CategorySelectionSheet> createState() =>
      _CategorySelectionSheetState();
}

class _CategorySelectionSheetState
    extends ConsumerState<_CategorySelectionSheet> {
  final _newCategoryController = TextEditingController();
  final _newCategoryFocus = FocusNode();
  bool _isAddingCategory = false;
  bool _isCreating = false;
  late List<CardCategory> _categories;

  @override
  void initState() {
    super.initState();
    _categories = List.from(widget.categories);
  }

  @override
  void dispose() {
    _newCategoryController.dispose();
    _newCategoryFocus.dispose();
    super.dispose();
  }

  Future<void> _createCategory() async {
    final name = _newCategoryController.text.trim();
    if (name.isEmpty) return;

    final service = ref.read(supabaseServiceProvider);
    final user = service.currentUser;
    if (user == null) return;

    setState(() => _isCreating = true);

    try {
      final newCategory = await service.createCategory(
        CardCategory(
          id: '',
          userId: user.id,
          name: name,
          createdAt: DateTime.now(),
        ),
      );

      _newCategoryController.clear();
      setState(() {
        _categories.add(newCategory);
        _isAddingCategory = false;
        _isCreating = false;
      });

      widget.onCategoriesChanged();

      // Auto-select the newly created category
      widget.onSelected(newCategory.id);
    } catch (e) {
      setState(() => _isCreating = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('카테고리 생성 실패: $e')),
        );
      }
    }
  }

  Future<void> _deleteCategory(CardCategory category) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('카테고리 삭제'),
        content: Text("'${category.name}' 카테고리를 삭제하시겠습니까?\n해당 카테고리의 명함은 삭제되지 않습니다."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final service = ref.read(supabaseServiceProvider);
      await service.deleteCategory(category.id);

      setState(() {
        _categories.removeWhere((c) => c.id == category.id);
      });

      widget.onCategoriesChanged();

      // If the deleted category was selected, reset filter
      if (widget.selectedCategoryId == category.id) {
        widget.onSelected(null);
        return;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('카테고리 삭제 실패: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius:
          const BorderRadius.vertical(top: Radius.circular(20)),
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

            // Title + Add button
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 8, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '카테고리 선택',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  IconButton(
                    icon: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        _isAddingCategory ? Icons.close : Icons.add,
                        key: ValueKey(_isAddingCategory),
                        size: 22,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    onPressed: () {
                      setState(() {
                        _isAddingCategory = !_isAddingCategory;
                        if (_isAddingCategory) {
                          Future.delayed(const Duration(milliseconds: 100),
                                  () => _newCategoryFocus.requestFocus());
                        } else {
                          _newCategoryController.clear();
                        }
                      });
                    },
                  ),
                ],
              ),
            ),

            // New category input
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              child: _isAddingCategory
                  ? Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _newCategoryController,
                        focusNode: _newCategoryFocus,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _createCategory(),
                        decoration: InputDecoration(
                          hintText: '새 카테고리 이름',
                          hintStyle: TextStyle(
                            color: theme.colorScheme.onSurface
                                .withOpacity(0.4),
                          ),
                          filled: true,
                          fillColor: theme
                              .colorScheme.surfaceContainerHighest
                              .withOpacity(0.5),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(
                              color: theme.colorScheme.primary
                                  .withOpacity(0.5),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 42,
                      child: FilledButton(
                        onPressed: _isCreating ? null : _createCategory,
                        style: FilledButton.styleFrom(
                          padding:
                          const EdgeInsets.symmetric(horizontal: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: _isCreating
                            ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                            : const Text('추가'),
                      ),
                    ),
                  ],
                ),
              )
                  : const SizedBox.shrink(),
            ),

            const Divider(height: 1),

            // Scrollable category list
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.45,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // "All" option
                    ListTile(
                      leading: Icon(
                        Icons.grid_view_rounded,
                        color: widget.selectedCategoryId == null
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurface.withOpacity(0.5),
                      ),
                      title: Text(
                        '전체',
                        style: TextStyle(
                          fontWeight: widget.selectedCategoryId == null
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: widget.selectedCategoryId == null
                              ? theme.colorScheme.primary
                              : null,
                        ),
                      ),
                      trailing: widget.selectedCategoryId == null
                          ? Icon(Icons.check,
                          color: theme.colorScheme.primary, size: 20)
                          : null,
                      onTap: () => widget.onSelected(null),
                    ),

                    // Category items
                    if (_categories.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          '카테고리가 없습니다\n위의 + 버튼으로 추가해 보세요',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color:
                            theme.colorScheme.onSurface.withOpacity(0.4),
                            height: 1.5,
                          ),
                        ),
                      )
                    else
                      ..._categories.map((category) {
                        final isSelected =
                            category.id == widget.selectedCategoryId;
                        return ListTile(
                          leading: Icon(
                            Icons.label_outline,
                            color: isSelected
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurface
                                .withOpacity(0.5),
                          ),
                          title: Text(
                            category.name,
                            style: TextStyle(
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              color: isSelected
                                  ? theme.colorScheme.primary
                                  : null,
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isSelected)
                                Icon(Icons.check,
                                    color: theme.colorScheme.primary,
                                    size: 20),
                              const SizedBox(width: 4),
                              GestureDetector(
                                onTap: () => _deleteCategory(category),
                                child: Padding(
                                  padding: const EdgeInsets.all(4),
                                  child: Icon(
                                    Icons.delete_outline,
                                    size: 18,
                                    color: theme.colorScheme.onSurface
                                        .withOpacity(0.3),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          onTap: () => widget.onSelected(category.id),
                        );
                      }),
                  ],
                ),
              ),
            ),

            SizedBox(
                height: MediaQuery.of(context).padding.bottom + 16),
          ],
        ),
      ),
    );
  }
}