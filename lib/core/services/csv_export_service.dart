import 'dart:io';
import 'package:csv/csv.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../features/shared/models/business_card.dart';
import '../../features/shared/models/crm_contact.dart';

/// 명함 및 CRM 연락처를 CSV로 내보내는 서비스.
///
/// - UTF-8 BOM 포함 (Excel 한글 호환)
/// - 임시 파일 생성 후 share_plus로 공유
class CsvExportService {
  /// 명함 리스트를 CSV로 내보냅니다.
  static Future<void> exportBusinessCards(List<BusinessCard> cards) async {
    if (cards.isEmpty) return;

    const headers = [
      '이름',
      '회사',
      '직책',
      '부서',
      '이메일',
      '전화',
      '모바일',
      '팩스',
      '주소',
      '웹사이트',
      'SNS',
      '메모',
      '등록일',
    ];

    final rows = <List<String>>[
      headers,
      for (final card in cards)
        [
          card.name ?? '',
          card.company ?? '',
          card.position ?? '',
          card.department ?? '',
          card.email ?? '',
          card.phone ?? '',
          card.mobile ?? '',
          card.fax ?? '',
          card.address ?? '',
          card.website ?? '',
          card.snsUrl ?? '',
          card.memo ?? '',
          DateFormat('yyyy-MM-dd').format(card.createdAt),
        ],
    ];

    final date = DateFormat('yyyyMMdd').format(DateTime.now());
    await _exportCsv(rows, 'mapae_cards_$date.csv');
  }

  /// CRM 연락처 리스트를 CSV로 내보냅니다.
  static Future<void> exportCrmContacts(List<CrmContact> contacts) async {
    if (contacts.isEmpty) return;

    const headers = [
      '이름',
      '회사',
      '직책',
      '부서',
      '이메일',
      '전화',
      '모바일',
      '상태',
      '메모',
      '등록일',
    ];

    final rows = <List<String>>[
      headers,
      for (final contact in contacts)
        [
          contact.name ?? '',
          contact.company ?? '',
          contact.position ?? '',
          contact.department ?? '',
          contact.email ?? '',
          contact.phone ?? '',
          contact.mobile ?? '',
          contact.status.label,
          contact.memo ?? '',
          DateFormat('yyyy-MM-dd').format(contact.createdAt),
        ],
    ];

    final date = DateFormat('yyyyMMdd').format(DateTime.now());
    await _exportCsv(rows, 'mapae_crm_$date.csv');
  }

  /// CSV 데이터를 임시 파일로 저장하고 공유합니다.
  static Future<void> _exportCsv(
      List<List<String>> rows,
      String fileName,
      ) async {
    try {
      final csvData = const ListToCsvConverter().convert(rows);
      // UTF-8 BOM 추가 (Excel에서 한글 깨짐 방지)
      final bom = '\uFEFF';
      final content = '$bom$csvData';

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$fileName');
      await file.writeAsString(content, flush: true);

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'text/csv')],
        subject: fileName,
      );
    } catch (e) {
      debugPrint('[CsvExportService] Export error: $e');
      rethrow;
    }
  }
}