import 'dart:convert';
import 'dart:typed_data';
import 'package:nfc_manager/nfc_manager.dart';
import '../constants/app_constants.dart';
import '../../features/shared/models/business_card.dart';

class NfcService {
  /// Check if NFC is available on this device.
  Future<bool> isNfcAvailable() async {
    return await NfcManager.instance.isAvailable();
  }

  /// Start NFC session to send a business card.
  Future<void> sendCard({
    required BusinessCard card,
    required Function() onSending,
    required Function() onSuccess,
    required Function(String error) onError,
  }) async {
    try {
      final isAvailable = await isNfcAvailable();
      if (!isAvailable) {
        onError('NFC is not available');
        return;
      }

      final cardJson = jsonEncode(card.toJson());
      final bytes = utf8.encode(cardJson);

      NfcManager.instance.startSession(
        onDiscovered: (NfcTag tag) async {
          try {
            onSending();
            final ndef = Ndef.from(tag);
            if (ndef == null || !ndef.isWritable) {
              onError('Tag is not writable');
              NfcManager.instance.stopSession();
              return;
            }

            final ndefMessage = NdefMessage([
              NdefRecord.createMime(
                AppConstants.nfcMimeType,
                Uint8List.fromList(bytes),
              ),
            ]);

            await ndef.write(ndefMessage);
            onSuccess();
            NfcManager.instance.stopSession();
          } catch (e) {
            onError(e.toString());
            NfcManager.instance.stopSession(errorMessage: e.toString());
          }
        },
      );
    } catch (e) {
      onError(e.toString());
    }
  }

  /// Start NFC session to receive a business card.
  Future<void> receiveCard({
    required Function(BusinessCard card) onReceived,
    required Function(String error) onError,
  }) async {
    try {
      final isAvailable = await isNfcAvailable();
      if (!isAvailable) {
        onError('NFC is not available');
        return;
      }

      NfcManager.instance.startSession(
        onDiscovered: (NfcTag tag) async {
          try {
            final ndef = Ndef.from(tag);
            if (ndef == null) {
              onError('Not an NDEF tag');
              NfcManager.instance.stopSession();
              return;
            }

            final cachedMessage = ndef.cachedMessage;
            if (cachedMessage == null || cachedMessage.records.isEmpty) {
              onError('Empty NFC tag');
              NfcManager.instance.stopSession();
              return;
            }

            for (final record in cachedMessage.records) {
              final mimeType = String.fromCharCodes(record.type);
              if (mimeType == AppConstants.nfcMimeType ||
                  record.typeNameFormat == NdefTypeNameFormat.media) {
                final payload = String.fromCharCodes(record.payload);
                final json = jsonDecode(payload) as Map<String, dynamic>;
                final card = BusinessCard.fromJson(json);
                onReceived(card);
                NfcManager.instance.stopSession();
                return;
              }
            }

            onError('No business card data found');
            NfcManager.instance.stopSession();
          } catch (e) {
            onError(e.toString());
            NfcManager.instance.stopSession(errorMessage: e.toString());
          }
        },
      );
    } catch (e) {
      onError(e.toString());
    }
  }

  /// Stop any active NFC session.
  void stopSession() {
    NfcManager.instance.stopSession();
  }
}
