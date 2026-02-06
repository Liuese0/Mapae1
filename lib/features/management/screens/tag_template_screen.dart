import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../core/providers/app_providers.dart';
import '../../shared/models/context_tag.dart';

final tagTemplatesProvider =
    FutureProvider.autoDispose<List<TagTemplate>>((ref) async {
  final service = ref.read(supabaseServiceProvider);
  final user = service.currentUser;
  if (user == null) return [];
  return service.getTagTemplates(user.id);
});

class TagTemplateScreen extends ConsumerWidget {
  const TagTemplateScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final templates = ref.watch(tagTemplatesProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          onPressed: () => context.pop(),
        ),
        title: const Text('태그 템플릿'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, size: 22),
            onPressed: () => _showCreateDialog(context, ref),
          ),
        ],
      ),
      body: templates.when(
        data: (list) {
          if (list.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.label_outlined,
                    size: 48,
                    color: theme.colorScheme.onSurface.withOpacity(0.2),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '태그 템플릿이 없습니다',
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withOpacity(0.4),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '명함에 만난 상황이나 특이사항을\n기록할 형식을 만들어보세요',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.colorScheme.onSurface.withOpacity(0.3),
                    ),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () => _showCreateDialog(context, ref),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('템플릿 만들기'),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final template = list[index];
              return _TemplateTile(
                template: template,
                onDelete: () async {
                  await ref
                      .read(supabaseServiceProvider)
                      .deleteTagTemplate(template.id);
                  ref.invalidate(tagTemplatesProvider);
                },
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('오류: $e')),
      ),
    );
  }

  void _showCreateDialog(BuildContext context, WidgetRef ref) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _CreateTemplateScreen(
          onCreated: () => ref.invalidate(tagTemplatesProvider),
        ),
      ),
    );
  }
}

class _TemplateTile extends StatelessWidget {
  final TagTemplate template;
  final VoidCallback onDelete;

  const _TemplateTile({required this.template, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.label_outlined,
                size: 18,
                color: theme.colorScheme.onSurface.withOpacity(0.5),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  template.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.delete_outline,
                    size: 18, color: Colors.red.shade300),
                onPressed: onDelete,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: template.fields.map((field) {
              String typeLabel;
              switch (field.type) {
                case TagFieldType.text:
                  typeLabel = '텍스트';
                  break;
                case TagFieldType.date:
                  typeLabel = '날짜';
                  break;
                case TagFieldType.select:
                  typeLabel = '선택';
                  break;
              }
              return Chip(
                label: Text(
                  '${field.name} ($typeLabel)',
                  style: const TextStyle(fontSize: 11),
                ),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ──────────────── Create Template Screen ────────────────

class _CreateTemplateScreen extends ConsumerStatefulWidget {
  final VoidCallback onCreated;

  const _CreateTemplateScreen({required this.onCreated});

  @override
  ConsumerState<_CreateTemplateScreen> createState() =>
      _CreateTemplateScreenState();
}

class _CreateTemplateScreenState extends ConsumerState<_CreateTemplateScreen> {
  final _nameController = TextEditingController();
  final List<_FieldEntry> _fields = [];
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    for (final field in _fields) {
      field.nameController.dispose();
    }
    super.dispose();
  }

  void _addField() {
    setState(() {
      _fields.add(_FieldEntry(
        nameController: TextEditingController(),
        type: TagFieldType.text,
        options: [],
      ));
    });
  }

  void _removeField(int index) {
    setState(() {
      _fields[index].nameController.dispose();
      _fields.removeAt(index);
    });
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('템플릿 이름을 입력해주세요')),
      );
      return;
    }

    if (_fields.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('최소 1개 이상의 필드를 추가해주세요')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final service = ref.read(supabaseServiceProvider);
      final user = service.currentUser;
      if (user == null) return;

      final fields = _fields.asMap().entries.map((entry) {
        return TagTemplateField(
          id: const Uuid().v4(),
          name: entry.value.nameController.text.trim(),
          type: entry.value.type,
          options: entry.value.type == TagFieldType.select
              ? entry.value.options
              : null,
          sortOrder: entry.key,
        );
      }).toList();

      final template = TagTemplate(
        id: const Uuid().v4(),
        userId: user.id,
        name: _nameController.text.trim(),
        fields: fields,
        createdAt: DateTime.now(),
      );

      await service.createTagTemplate(template);
      widget.onCreated();

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('템플릿이 생성되었습니다')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('생성 실패: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('태그 템플릿 만들기'),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _save,
            child: _isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('저장'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Template name
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '템플릿 이름',
                hintText: '예: 컨퍼런스 명함, 미팅 기록',
              ),
            ),
            const SizedBox(height: 24),

            // Fields
            Text(
              '필드',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),

            ...List.generate(_fields.length, (index) {
              final field = _fields[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.colorScheme.outline),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: field.nameController,
                            decoration: const InputDecoration(
                              labelText: '필드 이름',
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        DropdownButton<TagFieldType>(
                          value: field.type,
                          underline: const SizedBox.shrink(),
                          items: const [
                            DropdownMenuItem(
                              value: TagFieldType.text,
                              child: Text('텍스트', style: TextStyle(fontSize: 13)),
                            ),
                            DropdownMenuItem(
                              value: TagFieldType.date,
                              child: Text('날짜', style: TextStyle(fontSize: 13)),
                            ),
                            DropdownMenuItem(
                              value: TagFieldType.select,
                              child: Text('선택', style: TextStyle(fontSize: 13)),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _fields[index].type = value);
                            }
                          },
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.close,
                            size: 18,
                            color: Colors.red.shade300,
                          ),
                          onPressed: () => _removeField(index),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                    if (field.type == TagFieldType.select) ...[
                      const SizedBox(height: 8),
                      _SelectOptionsEditor(
                        options: field.options,
                        onChanged: (options) {
                          setState(() => _fields[index].options = options);
                        },
                      ),
                    ],
                  ],
                ),
              );
            }),

            // Add field button
            Center(
              child: OutlinedButton.icon(
                onPressed: _addField,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('필드 추가'),
              ),
            ),

            const SizedBox(height: 40),

            // Preview
            if (_fields.isNotEmpty) ...[
              Text(
                '미리보기',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: theme.colorScheme.surfaceContainerHighest,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _fields.map((field) {
                    final name = field.nameController.text.isNotEmpty
                        ? field.nameController.text
                        : '필드 이름';
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 80,
                            child: Text(
                              name,
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.onSurface
                                    .withOpacity(0.5),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Container(
                              height: 28,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: theme.colorScheme.outline
                                      .withOpacity(0.5),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FieldEntry {
  final TextEditingController nameController;
  TagFieldType type;
  List<String> options;

  _FieldEntry({
    required this.nameController,
    required this.type,
    required this.options,
  });
}

class _SelectOptionsEditor extends StatefulWidget {
  final List<String> options;
  final Function(List<String>) onChanged;

  const _SelectOptionsEditor({
    required this.options,
    required this.onChanged,
  });

  @override
  State<_SelectOptionsEditor> createState() => _SelectOptionsEditorState();
}

class _SelectOptionsEditorState extends State<_SelectOptionsEditor> {
  final _controller = TextEditingController();

  void _addOption() {
    if (_controller.text.trim().isNotEmpty) {
      final updated = [...widget.options, _controller.text.trim()];
      widget.onChanged(updated);
      _controller.clear();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 4,
          children: widget.options.asMap().entries.map((entry) {
            return Chip(
              label: Text(entry.value, style: const TextStyle(fontSize: 11)),
              onDeleted: () {
                final updated = [...widget.options]..removeAt(entry.key);
                widget.onChanged(updated);
              },
              deleteIconColor: Colors.red.shade300,
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
            );
          }).toList(),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _controller,
                decoration: const InputDecoration(
                  hintText: '선택 옵션 추가',
                  isDense: true,
                ),
                onFieldSubmitted: (_) => _addOption(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.add_circle_outline, size: 20),
              onPressed: _addOption,
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ],
    );
  }
}
