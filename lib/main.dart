import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:metadata_god/metadata_god.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:wavely/providers/audio_providers.dart';
import 'package:wavely/screens/home_screen.dart';
import 'package:wavely/screens/permission_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initialize background audio playback (for notifications & lock screen controls)
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.ryanheise.bg_demo.channel.audio',
    androidNotificationChannelName: 'Audio playback',
    androidNotificationOngoing: true,
    androidNotificationIcon: 'mipmap/ic_launcher', // optional: custom icon
  );

  // 2. Initialize metadata_god (required for reading song tags)
  await MetadataGod.initialize();

  // 3. Load SharedPreferences
  final prefs = await SharedPreferences.getInstance();

  // 4. Set edge-to-edge UI (transparent status & navigation bar)
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const WavelyApp(),
    ),
  );
}

class WavelyApp extends StatelessWidget {
  const WavelyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wavely',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF050505),
        primaryColor: const Color(0xFF6366F1),
        textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF6366F1),
          secondary: Color(0xFF8B5CF6),
          surface: Color(0xFF151517),
          background: Color(0xFF050505),
        ),
        useMaterial3: true,
      ),
      home: const _StartupWrapper(),
    );
  }
}

class _StartupWrapper extends ConsumerStatefulWidget {
  const _StartupWrapper();

  @override
  ConsumerState<_StartupWrapper> createState() => _StartupWrapperState();
}

class _StartupWrapperState extends ConsumerState<_StartupWrapper> {
  bool _isLoading = true;
  bool _hasPermission = false;

  @override
  void initState() {
    super.initState();
    // Wait one frame to ensure providers are fully ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPermission();
    });
  }

  Future<void> _checkPermission() async {
    try {
      final permissionService = ref.read(permissionServiceProvider);
      final status = await permissionService.hasPermission();

      if (mounted) {
        setState(() {
          _hasPermission = status;
          _isLoading = false;
        });
      }
    } catch (e, stack) {
      debugPrint("Permission check error: $e\n$stack");
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasPermission = false; // Show permission screen on error
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFF050505),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // You can replace this with your actual app logo
              // Image.asset('assets/logo.png', width: 120),
              const SizedBox(height: 40),
              const CircularProgressIndicator(
                color: Color(0xFF6366F1),
                strokeWidth: 3,
              ),
              const SizedBox(height: 32),
              Text(
                "Wavely",
                style: GoogleFonts.poppins(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Loading your music...",
                style: GoogleFonts.poppins(fontSize: 16, color: Colors.white54),
              ),
            ],
          ),
        ),
      );
    }

    // Final navigation
    return _hasPermission ? const HomeScreen() : const PermissionScreen();
  }
}
