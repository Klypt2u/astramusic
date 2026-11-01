import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme.dart';
import 'screens/root_shell.dart';
import 'services/audio_handler.dart';
import 'services/library_storage.dart';
import 'services/yt_music_service.dart';
import 'state/library_provider.dart';
import 'state/player_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Respect interruptions (phone calls, Siri) and other apps' audio focus.
  final session = await AudioSession.instance;
  await session.configure(const AudioSessionConfiguration.music());

  // Start the background audio handler — this is what keeps music alive
  // when the app is minimized, with lock-screen / notification controls.
  final audioHandler = await AudioService.init(
    builder: () => AstraAudioHandler(YtMusicService()),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'app.astra.playback',
      androidNotificationChannelName: 'Astra playback',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
    ),
  );

  final library = LibraryProvider(LibraryStorage());
  await library.load();

  runApp(
    MultiProvider(
      providers: [
        Provider<AstraAudioHandler>.value(value: audioHandler),
        ChangeNotifierProvider<PlayerProvider>(
          create: (_) => PlayerProvider(audioHandler),
        ),
        ChangeNotifierProvider<LibraryProvider>.value(value: library),
      ],
      child: const AstraApp(),
    ),
  );
}

class AstraApp extends StatelessWidget {
  const AstraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Astra',
      debugShowCheckedModeBanner: false,
      theme: AstraTheme.dark(),
      darkTheme: AstraTheme.dark(),
      themeMode: ThemeMode.dark,
      home: const RootShell(),
    );
  }
}
