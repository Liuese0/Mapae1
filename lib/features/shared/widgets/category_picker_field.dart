import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/app_providers.dart';
import '../../shared/models/category.dart';

/// Reusable category picker field for card forms.
/// Shows current category and opens a selection/creation sheet on tap.
class CategoryPickerField extends ConsumerWidget {
  final String? categoryId;
  final String? categoryName;
  final ValueChanged<({String? id, String? name})> onChanged;

  const CategoryPickerField({
    super.key,
    this.categoryId,
    this.categoryName,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final hasCategory = categoryId != null && categoryId!.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showCategorySheet(context, ref),
        borderRadius: BorderRadius.circular(4),
        child: InputDecorator(
          decoration: const InputDecoration(
            labelText: '카테고리',
            labelStyle: TextStyle(fontSize: 13),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  hasCategory ? (categoryName ?? '') : '선택 안함',
                  style: TextStyle(
                    color: hasCategory
                        ? theme.textTheme.bodyLarge?.color
                        : theme.colorScheme.onSurface.withOpacity(0.4),
                  ),
                ),
              ),
              if (hasCategory)
                GestureDetector(
                  onTap: () => onChanged((id: null, name: null)),
                  child: Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Icon(
                      Icons.close,
                      size: 18,
                      color: theme.colorScheme.onSurface.withOpacity(0.4),
                    ),
                  ),
                )
              else
                Icon(
                  Icons.arrow_drop_down,
                  color: theme.colorScheme.onSurface.withOpacity(0.4),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCategorySheet(BuildContext context, WidgetRef ref) {
    final service = ref.read(supabaseServiceProvider);
    final user = service.currentUser;
    if (user == null) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return _FormCategorySheet(
          userId: user.id,
          selectedCategoryId: categoryId,
          onSelected: (id, name) {
            onChanged((id: id, name: name));
            Navigator.pop(sheetContext);
          },
        );
      },
    );
  }
}

/// Bottom sheet with category list + inline creation
class _FormCategorySheet extends ConsumerStatefulWidget {
  final String userId;
  final String? selectedCategoryId;
  final void Function(String? id, String? name) onSelected;

  const _FormCategorySheet({
    required this.userId,
    required this.selectedCategoryId,
    required this.onSelected,
  });

  @override
  ConsumerState<_FormCategorySheet> createState() => _FormCategorySheetState();
}

class _FormCategorySheetState extends ConsumerState<_FormCategorySheet> {
  final _newCatController = TextEditingController();
  final _newCatFocus = FocusNode();
  bool _isAdding = false;
  bool _isCreating = false;
  List<CardCategory> _categories = [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void dispose() {
    _newCatController.dispose();
    _newCatFocus.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    final service = ref.read(supabaseServiceProvider);
    final cats = await service.getCategories(widget.userId);
    if (mounted) setState(() { _categories = cats; _loaded = true; });
  }

  Future<void> _createCategory() async {
    final name = _newCatController.text.trim();
    if (name.isEmpty) return;

    setState(() => _isCreating = true);
    try {
      final service = ref.read(supabaseServiceProvider);
      final created = await service.createCategory(
        CardCategory(
          id: '',
          userId: widget.userId,
          name: name,
          createdAt: DateTime.now(),
        ),
      );
      _newCatController.clear();
      setState(() {
        _categories.add(created);
        _isAdding = false;
        _isCreating = false;
      });
      ref.invalidate(categoriesProvider);
      // Auto-select newly created
      widget.onSelected(created.id, created.name);
    } catch (e) {
      setState(() => _isCreating = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('카테고리 생성 실패: $e')),
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
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Title + add button
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 8, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('카테고리 선택',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      )),
                  IconButton(
                    icon: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        _isAdding ? Icons.close : Icons.add,
                        key: ValueKey(_isAdding),
                        size: 22,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    onPressed: () {
                      setState(() {
                        _isAdding = !_isAdding;
                        if (_isAdding) {
                          Future.delayed(const Duration(milliseconds: 100),
                                  () => _newCatFocus.requestFocus());
                        } else {
                          _newCatController.clear();
                        }
                      });
                    },
                  ),
                ],
              ),
            ),

            // Inline new category input
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              child: _isAdding
                  ? Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _newCatController,
                        focusNode: _newCatFocus,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _createCategory(),
                        decoration: InputDecoration(
                          hintText: '새 카테고리 이름',
                          hintStyle: TextStyle(
                            color: theme.colorScheme.onSurface.withOpacity(0.4),
                          ),
                          filled: true,
                          fillColor: theme.colorScheme.surfaceContainerHighest
                              .withOpacity(0.5),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(
                              color: theme.colorScheme.primary.withOpacity(0.5),
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
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: _isCreating
                            ? const SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
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

            // List
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.4,
              ),
              child: !_loaded
                  ? const Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: SizedBox(
                    width: 24, height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
                  : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // None option
                    ListTile(
                      leading: Icon(Icons.label_off_outlined,
                          color: widget.selectedCategoryId == null
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurface.withOpacity(0.5)),
                      title: Text('선택 안함',
                          style: TextStyle(
                            fontWeight: widget.selectedCategoryId == null
                                ? FontWeight.w600 : FontWeight.w400,
                            color: widget.selectedCategoryId == null
                                ? theme.colorScheme.primary : null,
                          )),
                      trailing: widget.selectedCategoryId == null
                          ? Icon(Icons.check,
                          color: theme.colorScheme.primary, size: 20)
                          : null,
                      onTap: () => widget.onSelected(null, null),
                    ),

                    if (_categories.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          '카테고리가 없습니다\n위의 + 버튼으로 추가해 보세요',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: theme.colorScheme.onSurface.withOpacity(0.4),
                            height: 1.5,
                          ),
                        ),
                      )
                    else
                      ..._categories.map((cat) {
                        final selected = cat.id == widget.selectedCategoryId;
                        return ListTile(
                          leading: Icon(Icons.label_outline,
                              color: selected
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurface.withOpacity(0.5)),
                          title: Text(cat.name,
                              style: TextStyle(
                                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                                color: selected ? theme.colorScheme.primary : null,
                              )),
                          trailing: selected
                              ? Icon(Icons.check,
                              color: theme.colorScheme.primary, size: 20)
                              : null,
                          onTap: () => widget.onSelected(cat.id, cat.name),
                        );
                      }),
                  ],
                ),
              ),
            ),

            SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
          ],
        ),
      ),
    );
  }
}