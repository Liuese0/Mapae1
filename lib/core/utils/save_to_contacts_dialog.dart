import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/shared/models/collected_card.dart';
import '../../l10n/generated/app_localizations.dart';
import '../providers/app_providers.dart';
import '../services/device_contacts_service.dart';
import 'root_messenger.dart';

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
  // 로컬 ScaffoldMessenger 는 bottom sheet / dialog 가 pop 되면 dispose 되므로
  // 글로벌 root messenger 를 사용해 어떤 경우에도 스낵바가 보이도록 한다.
  final messenger = rootScaffoldMessengerKey.currentState;

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

  // flutter_contacts 자체 API 로 READ+WRITE 권한을 함께 요청한다.
  final granted = await svc.requestPermission();
  if (!granted) {
    messenger?.showSnackBar(
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
  messenger?.showSnackBar(
    SnackBar(
      content: Text(
        error == null
            ? l10n.saveToContactsSuccess
            : '${l10n.saveToContactsFailure}: $error',
      ),
      duration: Duration(seconds: error == null ? 3 : 10),
    ),
  );
}