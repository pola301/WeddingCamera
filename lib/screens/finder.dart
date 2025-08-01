import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class SharedAlbumHelper extends StatefulWidget {
  const SharedAlbumHelper({super.key});

  @override
  State<SharedAlbumHelper> createState() => _SharedAlbumHelperState();
}

class _SharedAlbumHelperState extends State<SharedAlbumHelper> {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'https://www.googleapis.com/auth/photoslibrary.readonly',
      'https://www.googleapis.com/auth/photoslibrary.sharing',
    ],
  );

  String? _userEmail;
  bool _loading = false;
  String _output = '';

  Future<void> _listSharedAlbums() async {
    setState(() {
      _loading = true;
      _output = '';
      _userEmail = null;
    });

    try {
      final user = await _googleSignIn.signIn();
      if (user == null) {
        setState(() {
          _output = '❌ Sign-in cancelled or failed.';
          _loading = false;
        });
        return;
      }

      setState(() {
        _userEmail = user.email;
        _output = '✅ Signed in as: $_userEmail\n\nFetching shared albums...';
      });

      final auth = await user.authentication;
      final token = auth.accessToken;
      if (token == null) {
        setState(() {
          _output = '❌ Failed to get access token.';
          _loading = false;
        });
        return;
      }

      final response = await http.get(
        Uri.parse('https://photoslibrary.googleapis.com/v1/sharedAlbums'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        final albums = jsonResponse['sharedAlbums'] as List<dynamic>?;

        if (albums == null || albums.isEmpty) {
          setState(() {
            _output = 'No shared albums found.';
            _loading = false;
          });
          return;
        }

        String albumList = '';
        for (var album in albums) {
          albumList += '• ${album['title']} (ID: ${album['id']})\n';
        }

        setState(() {
          _output = 'Shared albums:\n$albumList';
          _loading = false;
        });
      } else {
        setState(() {
          _output = '❌ Failed to fetch shared albums:\n${response.body}';
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _output = '❌ Error: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Google Photos Shared Albums')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ElevatedButton(
              onPressed: _loading ? null : _listSharedAlbums,
              child: const Text('Get Shared Albums'),
            ),
            const SizedBox(height: 24),
            if (_userEmail != null)
              Text(
                'Signed in as: $_userEmail',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            const SizedBox(height: 24),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      child: Text(
                        _output,
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
