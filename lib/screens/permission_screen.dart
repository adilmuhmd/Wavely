// screens/permission_screen.dart

import 'dart:ui';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';
import 'package:wavely/providers/audio_providers.dart';
import 'package:wavely/screens/home_screen.dart';

class PermissionScreen extends ConsumerWidget {
  const PermissionScreen({super.key});

  Future<void> _requestPermission(WidgetRef ref, BuildContext context) async {
    final permissionService = ref.read(permissionServiceProvider);
    final granted = await permissionService.requestPermission();

    if (granted && context.mounted) {
      // Navigate to HomeScreen with smooth transition
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 600),
          pageBuilder: (_, __, ___) => const HomeScreen(),
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Force light icons on dark navigation bar
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      extendBody: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Global Background (Deep Dark Gradient)
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0A0A0A),
                  Color(0xFF16161D),
                  Color(0xFF0F0F1A),
                ],
              ),
            ),
          ),

          // 2. Liquid Glass Background Layer (Subtle Refraction)
          LiquidGlassLayer(
            settings: LiquidGlassSettings(
              thickness: 20.0,
              blur: 10.0,
              refractiveIndex: 1.6,
              lightIntensity: BorderSide.strokeAlignCenter,
              lightAngle: pi / 4,
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Spacer(flex: 3),

                    // 3. Hero Icon (wavely.png) in Liquid Glass Container
                    LiquidGlass.grouped(
                      shape: LiquidRoundedSuperellipse(borderRadius: 40),
                      child: Container(
                        padding: const EdgeInsets.all(40),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(40),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.1),
                            width: 1.0,
                          ),
                        ),
                        // CHANGED: Using Image.asset instead of Icon
                        child: Image.asset(
                          'assets/wavely.png',
                          width: 80,
                          height: 80,
                          fit: BoxFit.contain,
                          // Optional: Remove color to show original image colors
                          // color: const Color(0xFF6366F1),
                        ),
                      ),
                    ),

                    const SizedBox(height: 40),

                    // 4. Title
                    Text(
                      'Access Your Music',
                      style: GoogleFonts.poppins(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 16),

                    // 5. Description
                    Text(
                      'Wavely needs permission to scan your device for audio files. No data leaves your device.',
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        color: Colors.white70,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 32),

                    // 6. Path Information (Glass Card)
                    LiquidGlass.grouped(
                      shape: LiquidRoundedSuperellipse(borderRadius: 24),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Column(
                          children: [
                            Text(
                              "Please ensure your music files are in one of these folders:",
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: const Color(0xFF6366F1), // Accent color
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _PathItem(path: '/storage/emulated/0/Music'),
                            const SizedBox(height: 8),
                            _PathItem(path: '/storage/emulated/0/Download'),
                            const SizedBox(height: 8),
                            _PathItem(path: '/storage/emulated/0/Audio'),
                          ],
                        ),
                      ),
                    ),

                    const Spacer(flex: 4),

                    // 7. Action Button (Liquid Style)
                    GestureDetector(
                      onTap: () => _requestPermission(ref, context),
                      child: LiquidStretch(
                        stretch: 0.05,
                        child: Container(
                          width: double.infinity,
                          height: 60,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                            ),
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF6366F1).withOpacity(0.4),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Grant Permission',
                            style: GoogleFonts.poppins(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // 8. Footer Info
                    Text(
                      'You can manage this later in Settings',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: Colors.white38,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const Spacer(flex: 2),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PathItem extends StatelessWidget {
  final String path;
  const _PathItem({required this.path});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.folder_open_rounded, size: 16, color: Colors.white38),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            path,
            style: GoogleFonts.sourceCodePro(
              fontSize: 12,
              color: Colors.white60,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
