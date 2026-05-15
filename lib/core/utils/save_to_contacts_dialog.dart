import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../features/shared/models/collected_card.dart';
import '../../l10n/generated/app_localizations.dart';
import '../providers/app_providers.dart';
import '../services/device_contacts_service.dart';

/// 명함이 저장된 직후, 휴대폰 네이티브 연락처에도 같이 저장할지 묻는 1번의
/// Yes/No 다이얼로그. 같은 카드 ID 에 대해서는 한 번만 묻고 다시 묻지 않는다.
Future<void> promptSaveToContacts(
    BuildContext context,
    WidgetRef ref,
    CollectedCard card,
    ) async {
  final svc = ref.read(deviceContactsServiceProvider);
  if (await svc.hasBeenOffered(card.id)) return;
  if (!context.mounted) return;

  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);

  final yes = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.saveToContactsTitle),
      content: Text(l10n.saveToContactsBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(l10n.saveToContactsNo),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(l10n.saveToContactsYes),
        ),
      ],
    ),
  );

  // 사용자가 어느 쪽을 눌렀든 (또는 dismiss 했든) 같은 카드에 대해선 다시 묻지 않는다.
  await svc.markOffered(card.id);

  if (yes != true) return;

  final status = await Permission.contacts.request();
  if (!status.isGranted) {
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.saveToContactsFailure)),
    );
    return;
  }

  // ContextTag 의 비표준 커스텀 필드를 "필드명: 값\n…" 으로 직렬화.
  // 표준 필드명은 CollectedCard 에 이미 반영되어 있으므로 제외.
  final supabase = ref.read(supabaseServiceProvider);
  final extraLines = <String>[];
  try {
    final tags = await supabase.getCardTags(card.id);
    for (final tag in tags) {
      tag.values.forEach((fieldName, value) {
        if (standardCardFieldNames.contains(fieldName)) return;
        if (value == null) return;
        if (value is String && value.trim().isEmpty) return;
        extraLines.add('$fieldName: $value');
      });
    }
  } catch (_) {
    // ContextTag 조회 실패는 무시 — 표준 필드만이라도 저장한다.
  }
  final extraNotes = extraLines.join('\n');

  final ok = await svc.saveToDeviceContacts(card, extraNotes: extraNotes);
  messenger.showSnackBar(
    SnackBar(
      content: Text(
        ok ? l10n.saveToContactsSuccess : l10n.saveToContactsFailure,
      ),
    ),
  );
}
