import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../core/providers/app_providers.dart';
import '../../../l10n/generated/app_localizations.dart';
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
        title: Text(AppLocalizations.of(context).tagTemplate),
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
                    AppLocalizations.of(context).noTagTemplates,
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withOpacity(0.4),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppLocalizations.of(context).tagTemplateHint,
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
                    label: Text(AppLocalizations.of(context).createTemplate),
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
        error: (e, _) => Center(child: Text(AppLocalizations.of(context).errorMsg(e.toString()))),
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
                  typeLabel = AppLocalizations.of(context).textField;
                  break;
                case TagFieldType.date:
                  typeLabel = AppLocalizations.of(context).dateField;
                  break;
                case TagFieldType.check:
                  typeLabel = AppLocalizations.of(context).selectField;
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
    final l10n = AppLocalizations.of(context);
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.enterName)),
      );
      return;
    }

    if (_fields.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.addField)),
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
          SnackBar(content: Text(AppLocalizations.of(context).saved)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).saveFailed(e.toString()))),
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
        title: Text(AppLocalizations.of(context).createTagTemplate),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _save,
            child: _isLoading
                ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
                : Text(AppLocalizations.of(context).save),
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
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context).templateName,
              ),
            ),
            const SizedBox(height: 24),

            // Fields
            Text(
              AppLocalizations.of(context).addField,
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
                child: Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: field.nameController,
                        decoration: const InputDecoration(
                          labelText: AppLocalizations.of(context).fieldName,
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    DropdownButton<TagFieldType>(
                      value: field.type,
                      underline: const SizedBox.shrink(),
                      items: [
                        DropdownMenuItem(
                          value: TagFieldType.text,
                          child:
                          Text(AppLocalizations.of(context).textField, style: const TextStyle(fontSize: 13)),
                        ),
                        DropdownMenuItem(
                          value: TagFieldType.date,
                          child: Text(AppLocalizations.of(context).dateField, style: const TextStyle(fontSize: 13)),
                        ),
                        DropdownMenuItem(
                          value: TagFieldType.check,
                          child: Text(AppLocalizations.of(context).selectField, style: const TextStyle(fontSize: 13)),
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
              );
            }),

            // Add field button
            Center(
              child: OutlinedButton.icon(
                onPressed: _addField,
                icon: const Icon(Icons.add, size: 16),
                label: Text(AppLocalizations.of(context).addField),
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
                          if (field.type == TagFieldType.check)
                            Icon(
                              Icons.check_box_outline_blank,
                              size: 20,
                              color: theme.colorScheme.onSurface
                                  .withOpacity(0.3),
                            )
                          else
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

  _FieldEntry({
    required this.nameController,
    required this.type,
  });
}