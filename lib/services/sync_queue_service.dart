// import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'google_photos_service.dart';

class SyncQueueService {
  static const String _queueKey = 'unsynced_media';

  static Future<void> addFileToQueue(String path) async {
    final prefs = await SharedPreferences.getInstance();
    final queue = prefs.getStringList(_queueKey) ?? [];
    if (!queue.contains(path)) {
      queue.add(path);
      await prefs.setStringList(_queueKey, queue);
    }
  }

  static Future<void> tryUploadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final queue = prefs.getStringList(_queueKey) ?? [];

    List<String> success = [];

    for (String path in queue) {
      final file = File(path);
      if (file.existsSync()) {
        try {
          await GooglePhotosService.uploadMedia(file);
          success.add(path);
        } catch (e) {
          print('Upload failed for $path: $e');
        }
      } else {
        success.add(path); // remove missing files
      }
    }

    // Remove successfully uploaded or deleted files from queue
    final remaining = queue.where((p) => !success.contains(p)).toList();
    await prefs.setStringList(_queueKey, remaining);
  }
}
