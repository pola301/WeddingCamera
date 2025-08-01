import 'package:flutter/material.dart';
import '../services/media_services.dart';
import '../services/google_photos_service.dart';
import '../services/sync_queue_service.dart';
import '../utils/connectivity_util.dart';
import 'dart:io';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<String> _photoUrls = [];
  bool _loadingPhotos = false;

  @override
  void initState() {
    super.initState();
    _tryUploadOfflineFiles();
    _loadSharedAlbumPhotos();
  }

  void _tryUploadOfflineFiles() async {
    final online = await ConnectivityUtil.isOnline();
    if (online) {
      await SyncQueueService.tryUploadAll();
      // Reload photos after upload to show new uploads
      _loadSharedAlbumPhotos();
    }
  }

  Future<void> _loadSharedAlbumPhotos() async {
    setState(() {
      _loadingPhotos = true;
    });

    final photos = await GooglePhotosService.listMediaInAlbum();
    setState(() {
      _photoUrls = photos;
      _loadingPhotos = false;
    });
  }

  void _handleMedia(bool isVideo) async {
    final file = await MediaService.captureMedia(isVideo: isVideo);
    if (file == null) return;

    await MediaService.saveToGallery(file.path);

    final online = await ConnectivityUtil.isOnline();
    if (online) {
      await GooglePhotosService.uploadMedia(File(file.path));
      await SyncQueueService.tryUploadAll();
      _showMessage("Uploaded to Google Photos");
      _loadSharedAlbumPhotos(); // refresh photos after upload
    } else {
      await SyncQueueService.addFileToQueue(file.path);
      _showMessage("Saved locally. Will upload when online.");
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Media Uploader')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () => _handleMedia(false),
                  child: const Text('Take Photo'),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: () => _handleMedia(true),
                  child: const Text('Record Video'),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loadingPhotos
                ? const Center(child: CircularProgressIndicator())
                : _photoUrls.isEmpty
                ? const Center(child: Text('No photos uploaded yet.'))
                : GridView.builder(
                    padding: const EdgeInsets.all(8),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                    itemCount: _photoUrls.length,
                    itemBuilder: (context, index) {
                      final url = _photoUrls[index];
                      // Add some params to make thumbnails smaller and faster
                      final thumbnailUrl = "$url=w200-h200";
                      return Image.network(
                        thumbnailUrl,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.broken_image),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
