import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  // 시스템 연락처 앱의 "새 연락처" 화면을 띄우는 방식이라 별도의 권한 요청은 불필요하다.
  // (직접 insert 는 일부 OEM 에서 보이지 않는 "기기 전용" 계정에 저장되는 문제가 있어
  //  사용자가 직접 계정을 선택해 저장하는 시스템 UI 흐름이 가장 확실하다.)

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

  final error = await svc.saveToDeviceContacts(card, extraNotes: extraNotes);
  if (error != null) {
    messenger.showSnackBar(
      SnackBar(
        content: Text('${l10n.saveToContactsFailure}: $error'),
        duration: const Duration(seconds: 5),
      ),
    );
  }
  // 성공 케이스에는 별도 스낵바를 띄우지 않는다 — 시스템 연락처 앱이 이미
  // 사용자에게 시각적 확인을 제공하기 때문.
}
