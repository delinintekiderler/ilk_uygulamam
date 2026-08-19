import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:record/record.dart';

import 'app_theme.dart';
import 'chat_service.dart';
import 'pb_client.dart';

class ChatPage extends StatefulWidget {
  final String partnerId;

  const ChatPage({super.key, required this.partnerId});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _chatService = ChatService();
  final _textController = TextEditingController();
  final _imagePicker = ImagePicker();
  final _audioRecorder = AudioRecorder();

  bool _isSending = false;
  bool _isRecording = false;
  DateTime? _recordStartTime;

  String? get _myUid => PbClient.currentUserId;

  Future<void> _sendText() async {
    final text = _textController.text;
    if (text.trim().isEmpty) return;
    _textController.clear();
    await _chatService.sendTextMessage(partnerId: widget.partnerId, text: text);
  }

  // ============================================================
  // FOTOĞRAF GÖNDERME
  // ============================================================
  Future<void> _pickAndSendImage(ImageSource source, {required bool viewOnce}) async {
    final pickedFile = await _imagePicker.pickImage(
      source: source,
      imageQuality: 70,
      maxWidth: 1600,
    );
    if (pickedFile == null) return;

    setState(() => _isSending = true);
    try {
      await _chatService.sendImageMessage(
        partnerId: widget.partnerId,
        imageFile: File(pickedFile.path),
        viewOnce: viewOnce,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fotoğraf gönderilemedi: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _showImageSourceSheet() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text('Fotoğraf gönder',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Kamera ile çek'),
              onTap: () {
                Navigator.pop(context);
                _pickAndSendImage(ImageSource.camera, viewOnce: false);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Galeriden seç'),
              onTap: () {
                Navigator.pop(context);
                _pickAndSendImage(ImageSource.gallery, viewOnce: false);
              },
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.local_fire_department,
                  color: AppColors.roseEmber),
              title: const Text('Tek açımlık fotoğraf'),
              subtitle: const Text('Açıldıktan sonra bir daha görüntülenemez'),
              onTap: () {
                Navigator.pop(context);
                _showImageSourceSheetForViewOnce();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showImageSourceSheetForViewOnce() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Kamera ile çek'),
              onTap: () {
                Navigator.pop(context);
                _pickAndSendImage(ImageSource.camera, viewOnce: true);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Galeriden seç'),
              onTap: () {
                Navigator.pop(context);
                _pickAndSendImage(ImageSource.gallery, viewOnce: true);
              },
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // SESLİ MESAJ KAYDI
  // ============================================================
  Future<void> _startRecording() async {
    final hasPermission = await _audioRecorder.hasPermission();
    if (!hasPermission) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mikrofon izni gerekli')),
        );
      }
      return;
    }

    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

    await _audioRecorder.start(const RecordConfig(), path: path);
    setState(() {
      _isRecording = true;
      _recordStartTime = DateTime.now();
    });
  }

  Future<void> _stopRecordingAndSend() async {
    final path = await _audioRecorder.stop();
    setState(() => _isRecording = false);

    if (path == null) return;

    // Çok kısa kayıtları (yanlışlıkla dokunma) gönderme.
    final duration = DateTime.now().difference(_recordStartTime ?? DateTime.now());
    if (duration.inMilliseconds < 500) return;

    setState(() => _isSending = true);
    try {
      await _chatService.sendVoiceMessage(
        partnerId: widget.partnerId,
        audioFile: File(path),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sesli mesaj gönderilemedi: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _cancelRecording() async {
    await _audioRecorder.stop();
    setState(() => _isRecording = false);
  }

  @override
  void dispose() {
    _textController.dispose();
    _audioRecorder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sohbet'),
        actions: [
          StreamBuilder<int>(
            stream: _chatService.watchStreak(widget.partnerId),
            builder: (context, snapshot) {
              final streak = snapshot.data ?? 0;
              if (streak == 0) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Row(
                  children: [
                    const Icon(Icons.local_fire_department,
                        color: AppColors.roseEmber),
                    const SizedBox(width: 4),
                    Text('$streak',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<RecordModel>>(
              stream: _chatService.watchMessages(widget.partnerId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Bir hata oluştu: ${snapshot.error}'));
                }

                final messages = snapshot.data ?? [];
                if (messages.isEmpty) {
                  return const Center(
                    child: Text('Henüz mesaj yok, ilk mesajı sen gönder!',
                        style: TextStyle(color: Colors.grey)),
                  );
                }

                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(12),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final record = messages[index];
                    final isMe = record.data['senderId'] == _myUid;
                    return _MessageBubble(
                      record: record,
                      isMe: isMe,
                      chatService: _chatService,
                    );
                  },
                );
              },
            ),
          ),
          if (_isSending)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: LinearProgressIndicator(),
            ),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    if (_isRecording) {
      return SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: AppColors.roseEmber.withValues(alpha: 0.08),
          child: Row(
            children: [
              const Icon(Icons.mic, color: AppColors.roseEmber),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('Kayıt yapılıyor...',
                    style: TextStyle(color: AppColors.roseEmber)),
              ),
              TextButton(
                onPressed: _cancelRecording,
                child: const Text('İptal'),
              ),
              FilledButton(
                onPressed: _stopRecordingAndSend,
                child: const Text('Gönder'),
              ),
            ],
          ),
        ),
      );
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.add_photo_alternate_outlined),
              onPressed: _isSending ? null : _showImageSourceSheet,
            ),
            Expanded(
              child: TextField(
                controller: _textController,
                decoration: const InputDecoration(
                  hintText: 'Mesaj yaz...',
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendText(),
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.mic_none),
              onPressed: _isSending ? null : _startRecording,
            ),
            IconButton(
              icon: const Icon(Icons.send),
              color: Theme.of(context).colorScheme.primary,
              onPressed: _sendText,
            ),
          ],
        ),
      ),
    );
  }
}

// ================================================================
// MESAJ BALONU
// ================================================================
class _MessageBubble extends StatefulWidget {
  final RecordModel record;
  final bool isMe;
  final ChatService chatService;

  const _MessageBubble({
    required this.record,
    required this.isMe,
    required this.chatService,
  });

  @override
  State<_MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<_MessageBubble> {
  final _audioPlayer = AudioPlayer();
  bool _isPlaying = false;

  Future<void> _toggleAudioPlayback(String url) async {
    if (_isPlaying) {
      await _audioPlayer.stop();
      setState(() => _isPlaying = false);
      return;
    }

    setState(() => _isPlaying = true);
    await _audioPlayer.play(UrlSource(url));
    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _isPlaying = false);
    });
  }

  Future<void> _openViewOnceImage(String url) async {
    await showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Image.network(url, fit: BoxFit.contain),
        ),
      ),
    );

    // Kapatılınca "görüntülendi" olarak işaretle.
    await widget.chatService.markImageAsViewed(widget.record.id);
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.record.data;
    final text = data['text'] as String?;
    final hasImage = (data['image'] as String?)?.isNotEmpty ?? false;
    final hasAudio = (data['audio'] as String?)?.isNotEmpty ?? false;
    final isViewOnce = data['viewOnce'] as bool? ?? false;
    final isViewed = (data['viewedAt'] as String?)?.isNotEmpty ?? false;

    final bubbleColor = widget.isMe
        ? Theme.of(context).colorScheme.primary
        : Colors.grey.shade200;
    final textColor = widget.isMe ? Colors.white : AppColors.inkPlum;

    Widget content;

    if (hasImage) {
      if (isViewOnce && isViewed) {
        // Tek açımlık, zaten görüntülenmiş.
        content = Container(
          width: 150,
          height: 100,
          decoration: BoxDecoration(
            color: Colors.grey.shade300,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.visibility_off, color: Colors.grey),
              SizedBox(height: 4),
              Text('Görüntülendi',
                  style: TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
        );
      } else if (isViewOnce && !widget.isMe) {
        // Tek açımlık, karşı taraftan gelmiş, henüz açılmamış.
        content = GestureDetector(
          onTap: () =>
              _openViewOnceImage(widget.chatService.getImageUrl(widget.record)),
          child: Container(
            width: 150,
            height: 100,
            decoration: BoxDecoration(
              color: AppColors.roseEmber.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.local_fire_department, color: AppColors.roseEmber),
                SizedBox(height: 4),
                Text('Açmak için dokun',
                    style: TextStyle(color: AppColors.roseEmber, fontSize: 12)),
              ],
            ),
          ),
        );
      } else {
        // Normal fotoğraf, ya da kendi gönderdiğin tek açımlık fotoğraf.
        final url = widget.chatService.getImageUrl(widget.record);
        content = ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            url,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return const SizedBox(
                  width: 150,
                  height: 150,
                  child: Center(child: CircularProgressIndicator()));
            },
            errorBuilder: (context, error, stackTrace) => const SizedBox(
                width: 150,
                height: 150,
                child: Center(child: Icon(Icons.broken_image))),
          ),
        );
      }
    } else if (hasAudio) {
      final url = widget.chatService.getAudioUrl(widget.record);
      content = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(
              _isPlaying ? Icons.stop_circle : Icons.play_circle_fill,
              color: widget.isMe ? Colors.white : AppColors.roseEmber,
              size: 32,
            ),
            onPressed: () => _toggleAudioPlayback(url),
          ),
          Icon(Icons.graphic_eq,
              color: widget.isMe ? Colors.white70 : Colors.grey, size: 20),
          const SizedBox(width: 4),
          Text('Sesli mesaj',
              style: TextStyle(color: textColor, fontSize: 13)),
        ],
      );
    } else {
      content = Text(text ?? '', style: TextStyle(color: textColor, fontSize: 15));
    }

    return Align(
      alignment: widget.isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: (hasImage)
            ? const EdgeInsets.all(4)
            : const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.7,
        ),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: content,
      ),
    );
  }
}