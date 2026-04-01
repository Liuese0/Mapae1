import 'dart:io';
import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../features/shared/models/business_card.dart';
import '../../features/shared/models/crm_contact.dart';

/// 명함 및 CRM 연락처를 Excel(.xlsx)로 내보내는 서비스.
class ExcelExportService {
  /// 명함 리스트를 Excel로 내보냅니다.
  static Future<void> exportBusinessCards(List<BusinessCard> cards) async {
    if (cards.isEmpty) return;

    final headers = [
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
    await _exportExcel(headers, rows, '명함', 'mapae_cards_$date.xlsx');
  }

  /// CRM 연락처 리스트를 Excel로 내보냅니다.
  static Future<void> exportCrmContacts(List<CrmContact> contacts) async {
    if (contacts.isEmpty) return;

    final headers = [
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
    await _exportExcel(headers, rows, 'CRM', 'mapae_crm_$date.xlsx');
  }

  /// Excel 파일을 생성하고 공유합니다.
  static Future<void> _exportExcel(
      List<String> headers,
      List<List<String>> rows,
      String sheetName,
      String fileName,
      ) async {
    try {
      final excel = Excel.createExcel();

      // 기본 시트 이름을 변경
      final defaultSheet = excel.getDefaultSheet();
      if (defaultSheet != null) {
        excel.rename(defaultSheet, sheetName);
      }
      final sheet = excel[sheetName];

      // 헤더 스타일 (볼드 + 배경색)
      final headerStyle = CellStyle(
        bold: true,
        backgroundColorHex: ExcelColor.fromHexString('#4472C4'),
        fontColorHex: ExcelColor.white,
      );

      // 헤더 행 작성
      for (var col = 0; col < headers.length; col++) {
        final cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0),
        );
        cell.value = TextCellValue(headers[col]);
        cell.cellStyle = headerStyle;
      }

      // 데이터 행 작성
      for (var row = 0; row < rows.length; row++) {
        for (var col = 0; col < rows[row].length; col++) {
          final cell = sheet.cell(
            CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row + 1),
          );
          cell.value = TextCellValue(rows[row][col]);
        }
      }

      // 컬럼 너비 설정
      for (var col = 0; col < headers.length; col++) {
        sheet.setColumnWidth(col, 18);
      }

      // 파일 저장 및 공유
      final bytes = excel.encode();
      if (bytes == null) throw Exception('Failed to encode Excel file');

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes, flush: true);

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')],
        subject: fileName,
      );
    } catch (e) {
      debugPrint('[ExcelExportService] Export error: $e');
      rethrow;
    }
  }
}