import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'dart:convert';

class GooglePhotosService {
  // Your existing shared album ID
  static const String _existingAlbumId =
      '0AVMBsJiQ6_HSJCRYGIzbbK1RTKw_yWC3YpVd9P1N8GpFOmf6fccCx_YL4bvfWTEH7Gn0gw';

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

  // Return the existing album ID (no creation here)
  static Future<String?> _getAlbumId() async {
    // You can optionally add logic to verify album exists or fetch it
    return _existingAlbumId;
  }

  // Upload media to Google Photos and add to album
  static Future<void> uploadMedia(File file) async {
    final token = await _getAccessToken();
    if (token == null) {
      print("❌ Google Sign-In failed");
      return;
    }

    // Step 1: Upload the file to get an uploadToken
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

    // Step 2: Get album ID (your shared album)
    final albumId = await _getAlbumId();
    if (albumId == null) {
      print("❌ Album ID not found");
      return;
    }

    // Step 3: Create media item in album
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
      print("✅ Media uploaded successfully to shared album.");
    } else {
      print("❌ Media item creation failed: ${createItemRes.body}");
    }
  }

  // List media items in the shared album, return list of baseUrls
  static Future<List<String>> listMediaInAlbum() async {
    final token = await _getAccessToken();
    final albumId = await _getAlbumId();

    if (token == null || albumId == null) {
      print("❌ Missing token or album ID");
      return [];
    }

    final response = await http.post(
      Uri.parse('https://photoslibrary.googleapis.com/v1/mediaItems:search'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({"albumId": albumId, "pageSize": 50}),
    );

    if (response.statusCode == 200) {
      final jsonData = jsonDecode(response.body);
      final mediaItems = jsonData['mediaItems'] as List<dynamic>?;

      if (mediaItems == null) return [];

      // Return the baseUrls for thumbnails
      return mediaItems
          .map<String>((item) => item['baseUrl'] as String)
          .toList();
    } else {
      print("❌ Failed to fetch media items: ${response.body}");
      return [];
    }
  }
}
