import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'dart:convert';

class GooglePhotosService {
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'https://www.googleapis.com/auth/photoslibrary.appendonly',
      'https://www.googleapis.com/auth/photoslibrary.readonly',
      'https://www.googleapis.com/auth/photoslibrary.readonly.appcreateddata',
      'https://www.googleapis.com/auth/photoslibrary.sharing',
    ],
  );

  // Sign in and get access token
  static Future<String?> _getAccessToken() async {
    final user = await _googleSignIn.signIn();
    final auth = await user?.authentication;
    return auth?.accessToken;
  }

  // List albums and find album by title
  static Future<String?> _getAlbumIdByTitle(String title, String token) async {
    String? nextPageToken;
    do {
      final url = Uri.parse(
        'https://photoslibrary.googleapis.com/v1/albums?pageSize=50${nextPageToken != null ? '&pageToken=$nextPageToken' : ''}',
      );

      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode != 200) {
        print('❌ Failed to list albums: ${response.body}');
        return null;
      }

      final Map<String, dynamic> json = jsonDecode(response.body);
      final List albums = json['albums'] ?? [];

      for (final album in albums) {
        if ((album['title'] ?? '') == title) {
          return album['id'];
        }
      }

      nextPageToken = json['nextPageToken'];
    } while (nextPageToken != null);

    return null;
  }

  // Create album with given title
  static Future<String?> _createAlbum(String title, String token) async {
    final response = await http.post(
      Uri.parse('https://photoslibrary.googleapis.com/v1/albums'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        "album": {"title": title},
      }),
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      return json['id'];
    } else {
      print('❌ Failed to create album: ${response.body}');
      return null;
    }
  }

  // Get album ID by title or create album if it does not exist
  static Future<String?> getOrCreateAlbumId(String title) async {
    final token = await _getAccessToken();
    if (token == null) {
      print("❌ Google Sign-In failed");
      return null;
    }

    var albumId = await _getAlbumIdByTitle(title, token);
    if (albumId == null) {
      print("ℹ️ Album '$title' not found. Creating new album...");
      albumId = await _createAlbum(title, token);
      if (albumId == null) {
        print("❌ Failed to create album '$title'");
      }
    } else {
      print("ℹ️ Album '$title' found with ID: $albumId");
    }
    return albumId;
  }

  // Upload media and add to album
  static Future<void> uploadMedia(
    File file, {
    String albumTitle = "Shared Album",
  }) async {
    final token = await _getAccessToken();
    if (token == null) {
      print("❌ Google Sign-In failed");
      return;
    }

    // Upload the photo bytes to get an upload token
    final uploadRes = await http.post(
      Uri.parse('https://photoslibrary.googleapis.com/v1/uploads'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-type': 'application/octet-stream',
        'X-Goog-Upload-File-Name': file.path.split('/').last,
        'X-Goog-Upload-Protocol': 'raw',
      },
      body: await file.readAsBytes(),
    );

    if (uploadRes.statusCode != 200) {
      print("❌ Upload failed: ${uploadRes.body}");
      return;
    }

    final uploadToken = uploadRes.body;

    // Get or create the album ID
    final albumId = await getOrCreateAlbumId(albumTitle);
    if (albumId == null) return;

    // Create the media item in the album using upload token
    final createItemRes = await http.post(
      Uri.parse(
        'https://photoslibrary.googleapis.com/v1/mediaItems:batchCreate',
      ),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        "newMediaItems": [
          {
            "description": "Uploaded from Flutter app",
            "simpleMediaItem": {"uploadToken": uploadToken},
          },
        ],
        "albumId": albumId,
      }),
    );

    if (createItemRes.statusCode == 200) {
      print("✅ Media uploaded successfully to album '$albumTitle'.");
    } else {
      print("❌ Media item creation failed: ${createItemRes.body}");
    }
  }

  // List media URLs in album (supports pagination)
  static Future<List<String>> listMediaInAlbum({
    String albumTitle = "Shared Album",
  }) async {
    final token = await _getAccessToken();
    if (token == null) {
      print("❌ Google Sign-In failed");
      return [];
    }

    final albumId = await getOrCreateAlbumId(albumTitle);
    if (albumId == null) return [];

    List<String> mediaUrls = [];
    String? nextPageToken;

    do {
      final response = await http.post(
        Uri.parse('https://photoslibrary.googleapis.com/v1/mediaItems:search'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          "albumId": albumId,
          "pageSize": 50,
          if (nextPageToken != null) "pageToken": nextPageToken,
        }),
      );

      if (response.statusCode != 200) {
        print("❌ Failed to fetch media items: ${response.body}");
        break;
      }

      final json = jsonDecode(response.body);
      final List items = json['mediaItems'] ?? [];
      mediaUrls.addAll(items.map<String>((item) => item['baseUrl'] as String));

      nextPageToken = json['nextPageToken'];
    } while (nextPageToken != null);

    return mediaUrls;
  }
}
