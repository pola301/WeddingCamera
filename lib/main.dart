import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'services/sync_queue_service.dart';
import 'utils/connectivity_util.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Optional: Try uploading queued media before app UI starts
  final online = await ConnectivityUtil.isOnline();
  if (online) {
    await SyncQueueService.tryUploadAll();
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Media Upload App',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const HomeScreen(),
    );
  }
}
//client ID : 1068498260817-uvtb37rb77rjp4phlnucdnpoigllu1hu.apps.googleusercontent.com
//client secret : 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
// android client id : 1068498260817-otie21lo7d0kc1rkqs2d62nfl4il8lcq.apps.googleusercontent.com
// web client Id : 1068498260817-bu2t5ggg5ng62dm0504jesaj1eet82ov.apps.googleusercontent.com
// web client secret : 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