import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:pocketbase/pocketbase.dart';
import 'pb_client.dart';

class ChatService {
  String? get _myUid => PbClient.currentUserId;

  String getChatId(String uid1, String uid2) {
    final ids = [uid1, uid2]..sort();
    return '${ids[0]}_${ids[1]}';
  }

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  String _dateKeyDaysAgo(int days) {
    final date = DateTime.now().subtract(Duration(days: days));
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<RecordModel?> _findChatRecord(String chatId) async {
    try {
      return await PbClient.pb
          .collection('chats')
          .getFirstListItem('chatId = "$chatId"');
    } catch (_) {
      return null;
    }
  }

  Future<RecordModel> _getOrCreateChatRecord(String chatId) async {
    final existing = await _findChatRecord(chatId);
    if (existing != null) return existing;
    return await PbClient.pb.collection('chats').create(body: {
      'chatId': chatId,
    });
  }

  // ================================================================
  // METİN MESAJI GÖNDER
  // ================================================================
  Future<void> sendTextMessage({
    required String partnerId,
    required String text,
  }) async {
    final myUid = _myUid;
    if (myUid == null || text.trim().isEmpty) return;

    final chatId = getChatId(myUid, partnerId);

    await PbClient.pb.collection('messages').create(body: {
      'chatId': chatId,
      'senderId': myUid,
      'text': text.trim(),
    });

    await _updateLastMessage(chatId, text.trim());
    await _updateStreak(chatId, myUid);
  }

  // ================================================================
  // FOTOĞRAF MESAJI GÖNDER (viewOnce: true ise tek açımlık olur)
  // ================================================================
  Future<void> sendImageMessage({
    required String partnerId,
    required File imageFile,
    bool viewOnce = false,
  }) async {
    final myUid = _myUid;
    if (myUid == null) return;

    final chatId = getChatId(myUid, partnerId);

    await PbClient.pb.collection('messages').create(
      body: {
        'chatId': chatId,
        'senderId': myUid,
        'viewOnce': viewOnce,
      },
      files: [
        await http.MultipartFile.fromPath('image', imageFile.path),
      ],
    );

    await _updateLastMessage(
        chatId, viewOnce ? '📷 Tek açımlık fotoğraf' : '📷 Fotoğraf');
    await _updateStreak(chatId, myUid);
  }

  // ================================================================
  // SESLİ MESAJ GÖNDER
  // ================================================================
  Future<void> sendVoiceMessage({
    required String partnerId,
    required File audioFile,
  }) async {
    final myUid = _myUid;
    if (myUid == null) return;

    final chatId = getChatId(myUid, partnerId);

    await PbClient.pb.collection('messages').create(
      body: {
        'chatId': chatId,
        'senderId': myUid,
      },
      files: [
        await http.MultipartFile.fromPath('audio', audioFile.path),
      ],
    );

    await _updateLastMessage(chatId, '🎤 Sesli mesaj');
    await _updateStreak(chatId, myUid);
  }

  // Fotoğrafı "görüntülendi" olarak işaretler (tek açımlık mesajlar için).
  Future<void> markImageAsViewed(String messageId) async {
    await PbClient.pb.collection('messages').update(messageId, body: {
      'viewedAt': DateTime.now().toUtc().toIso8601String(),
    });
  }

  String getImageUrl(RecordModel messageRecord) {
    final fileName = messageRecord.data['image'] as String?;
    if (fileName == null || fileName.isEmpty) return '';
    return PbClient.pb.files.getUrl(messageRecord, fileName).toString();
  }

  String getAudioUrl(RecordModel messageRecord) {
    final fileName = messageRecord.data['audio'] as String?;
    if (fileName == null || fileName.isEmpty) return '';
    return PbClient.pb.files.getUrl(messageRecord, fileName).toString();
  }

  Future<void> _updateLastMessage(String chatId, String preview) async {
    final record = await _getOrCreateChatRecord(chatId);
    await PbClient.pb.collection('chats').update(record.id, body: {
      'lastMessage': preview,
      'lastMessageAt': DateTime.now().toUtc().toIso8601String(),
    });
  }

  // ================================================================
  // STREAK MANTIĞI
  // ================================================================
  Future<void> _updateStreak(String chatId, String myUid) async {
    final today = _todayKey();
    final chatRecord = await _getOrCreateChatRecord(chatId);
    final data = chatRecord.data;

    final sendersTodayDate = data['sendersTodayDate'] as String?;
    List<String> sendersToday =
        List<String>.from(data['sendersToday'] as List? ?? []);

    if (sendersTodayDate != today) {
      sendersToday = [];
    }
    if (!sendersToday.contains(myUid)) {
      sendersToday.add(myUid);
    }

    int streakCount = (data['streakCount'] as num?)?.toInt() ?? 0;
    final lastIncrementDate = data['lastStreakIncrementDate'] as String?;
    final bothSentToday = sendersToday.length >= 2;
    final alreadyIncrementedToday = lastIncrementDate == today;

    if (bothSentToday && !alreadyIncrementedToday) {
      final yesterday = _dateKeyDaysAgo(1);
      final isConsecutive = lastIncrementDate == yesterday;
      streakCount = isConsecutive ? streakCount + 1 : 1;

      await PbClient.pb.collection('chats').update(chatRecord.id, body: {
        'streakCount': streakCount,
        'lastStreakIncrementDate': today,
        'sendersToday': sendersToday,
        'sendersTodayDate': today,
      });
    } else {
      await PbClient.pb.collection('chats').update(chatRecord.id, body: {
        'sendersToday': sendersToday,
        'sendersTodayDate': today,
      });
    }

    await _resetStreakIfBroken(chatId);
  }

  Future<void> _resetStreakIfBroken(String chatId) async {
    final record = await _findChatRecord(chatId);
    if (record == null) return;

    final data = record.data;
    final lastIncrementDate = data['lastStreakIncrementDate'] as String?;
    final streakCount = (data['streakCount'] as num?)?.toInt() ?? 0;
    if (lastIncrementDate == null || streakCount == 0) return;

    final today = _todayKey();
    final yesterday = _dateKeyDaysAgo(1);

    if (lastIncrementDate != today && lastIncrementDate != yesterday) {
      await PbClient.pb.collection('chats').update(record.id, body: {
        'streakCount': 0,
      });
    }
  }

  Stream<int> watchStreak(String partnerId) {
    final myUid = _myUid;
    if (myUid == null) return const Stream.empty();
    final chatId = getChatId(myUid, partnerId);

    late StreamController<int> controller;
    Function()? unsubscribe;

    controller = StreamController<int>(
      onListen: () async {
        final existing = await _findChatRecord(chatId);
        controller.add((existing?.data['streakCount'] as num?)?.toInt() ?? 0);

        unsubscribe =
            await PbClient.pb.collection('chats').subscribe('*', (e) {
          final record = e.record;
          if (record == null) return;
          if (record.data['chatId'] != chatId) return;
          controller.add((record.data['streakCount'] as num?)?.toInt() ?? 0);
        });
      },
      onCancel: () async {
        await unsubscribe?.call();
      },
    );

    return controller.stream;
  }

  // ================================================================
  // MESAJLARI DİNLE
  // ================================================================
  Stream<List<RecordModel>> watchMessages(String partnerId) {
    final myUid = _myUid;
    if (myUid == null) return const Stream.empty();
    final chatId = getChatId(myUid, partnerId);

    late StreamController<List<RecordModel>> controller;
    Function()? unsubscribe;
    final List<RecordModel> messages = [];

    controller = StreamController<List<RecordModel>>(
      onListen: () async {
        try {
          final result = await PbClient.pb.collection('messages').getList(
                filter: 'chatId = "$chatId"',
                sort: '-created',
                perPage: 100,
              );
          messages.addAll(result.items);
          controller.add(List.from(messages));
        } catch (e) {
          controller.addError(e);
        }

        unsubscribe =
            await PbClient.pb.collection('messages').subscribe('*', (e) {
          final record = e.record;
          if (record == null) return;
          if (record.data['chatId'] != chatId) return;

          if (e.action == 'create') {
            messages.insert(0, record);
            controller.add(List.from(messages));
          } else if (e.action == 'update') {
            final index = messages.indexWhere((m) => m.id == record.id);
            if (index != -1) {
              messages[index] = record;
              controller.add(List.from(messages));
            }
          }
        });
      },
      onCancel: () async {
        await unsubscribe?.call();
      },
    );

    return controller.stream;
  }
}