import 'package:flutter/foundation.dart';
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
  debugPrint('[promptSaveToContacts] called for card=${card.id} name=${card.name}');
  if (await svc.hasBeenOffered(card.id)) {
    debugPrint('[promptSaveToContacts] already offered for ${card.id}, skip');
    return;
  }
  if (!context.mounted) {
    debugPrint('[promptSaveToContacts] context unmounted, skip');
    return;
  }

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
  debugPrint('[promptSaveToContacts] user answer: $yes');

  if (yes != true) {
    // No 나 dismiss 의 경우엔 다시 물어볼 수 있게 markOffered 하지 않는다.
    return;
  }

  // Yes 누른 시점에만 "이 카드는 이미 다뤘다" 로 기록 — 저장 실패해도 다시 묻지 않음
  // (다시 묻고 또 실패하면 짜증나니까).
  await svc.markOffered(card.id);

  // flutter_contacts 자체 API 로 READ+WRITE 권한을 함께 요청한다.
  final granted = await svc.requestPermission();
  if (!granted) {
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.saveToContactsFailure)),
    );
    return;
  }

  // ContextTag 의 비표준 커스텀 필드를 "필드명: 값\n…" 으로 직렬화.
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
  messenger.showSnackBar(
    SnackBar(
      content: Text(
        error == null
            ? l10n.saveToContactsSuccess
            : '${l10n.saveToContactsFailure}: $error',
      ),
      duration: Duration(seconds: error == null ? 3 : 5),
    ),
  );
}
