import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:audio_metadata_reader/audio_metadata_reader.dart';

// ==============================================================================
// 1. CORE INITIALIZATION & CACHE
// ==============================================================================

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Initialize SharedPreferences in main.dart');
});

// GLOBAL MEMORY CACHE for Artwork (Prevents stutter while scrolling)
final Map<String, Uint8List?> _artworkCache = {};

// GLOBAL MEMORY CACHE for Colors (Prevents recalculating color for same image)
final Map<String, Color> _colorCache = {};

// ==============================================================================
// 2. MODELS
// ==============================================================================

class LocalSong {
  final String id;
  final String path;
  final String title;
  final String artist;
  final String album;
  final String genre;
  final int year;
  final int durationMs;
  final int bitrate;
  final int fileSizeBytes;
  final String format;
  final int addedDate;

  LocalSong({
    required this.id,
    required this.path,
    required this.title,
    this.artist = 'Unknown Artist',
    this.album = 'Unknown Album',
    this.genre = 'Unknown Genre',
    this.year = 0,
    this.durationMs = 0,
    this.bitrate = 0,
    this.fileSizeBytes = 0,
    this.format = '',
    required this.addedDate,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'path': path,
    'title': title,
    'artist': artist,
    'album': album,
    'genre': genre,
    'year': year,
    'durationMs': durationMs,
    'bitrate': bitrate,
    'fileSizeBytes': fileSizeBytes,
    'format': format,
    'addedDate': addedDate,
  };

  factory LocalSong.fromJson(Map<String, dynamic> map) => LocalSong(
    id: map['id'] ?? '',
    path: map['path'] ?? '',
    title: map['title'] ?? 'Unknown',
    artist: map['artist'] ?? 'Unknown Artist',
    album: map['album'] ?? 'Unknown Album',
    genre: map['genre'] ?? 'Unknown Genre',
    year: map['year'] ?? 0,
    durationMs: map['durationMs'] ?? 0,
    bitrate: map['bitrate'] ?? 0,
    fileSizeBytes: map['fileSizeBytes'] ?? 0,
    format: map['format'] ?? '',
    addedDate: map['addedDate'] ?? 0,
  );

  String get durationString {
    if (durationMs == 0) return "--:--";
    final d = Duration(milliseconds: durationMs);
    return '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
  }

  String get sizeString {
    if (fileSizeBytes == 0) return "Unknown";
    final mb = fileSizeBytes / (1024 * 1024);
    return "${mb.toStringAsFixed(1)} MB";
  }
}

// ==============================================================================
// 3. PERMISSION SERVICE
// ==============================================================================

class PermissionService {
  final SharedPreferences prefs;
  static const _kPermissionRequestedKey = 'has_requested_audio_permission';

  PermissionService(this.prefs);

  Future<bool> hasPermission() async {
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      if (androidInfo.version.sdkInt >= 33) {
        return await Permission.audio.status.isGranted;
      } else {
        return await Permission.storage.status.isGranted;
      }
    }
    return true;
  }

  Future<bool> requestPermission() async {
    if (await hasPermission()) return true;

    final bool alreadyRequested =
        prefs.getBool(_kPermissionRequestedKey) ?? false;

    PermissionStatus status;
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      if (androidInfo.version.sdkInt >= 33) {
        status = await Permission.audio.request();
      } else {
        status = await Permission.storage.request();
      }
    } else {
      status = await Permission.mediaLibrary.request();
    }

    await prefs.setBool(_kPermissionRequestedKey, true);

    if (status.isPermanentlyDenied && alreadyRequested) {
      await openAppSettings();
      return false;
    }

    return status.isGranted;
  }
}

final permissionServiceProvider = Provider<PermissionService>((ref) {
  return PermissionService(ref.watch(sharedPreferencesProvider));
});

// ==============================================================================
// 4. SONG REPOSITORY & SMART CACHING
// ==============================================================================

class SongsNotifier extends StateNotifier<List<LocalSong>> {
  final SharedPreferences prefs;
  final PermissionService permissionService;
  static const _kCachedSongsKey = 'cached_local_songs';

  SongsNotifier(this.prefs, this.permissionService) : super([]) {
    _init();
  }

  Future<void> _init() async {
    _loadFromCache();
    final hasPerm = await permissionService.hasPermission();
    if (hasPerm) refreshSongs();
  }

  void _loadFromCache() {
    final jsonString = prefs.getString(_kCachedSongsKey);
    if (jsonString != null) {
      try {
        final List<dynamic> decoded = json.decode(jsonString);
        state = decoded.map((e) => LocalSong.fromJson(e)).toList();
      } catch (e) {
        prefs.remove(_kCachedSongsKey);
      }
    }
  }

  Future<void> refreshSongs() async {
    final granted = await permissionService.requestPermission();
    if (!granted) return;

    try {
      final newSongs = await compute(_scanWorker, null);
      if (newSongs.isNotEmpty) {
        state = newSongs;
        _saveToCache(newSongs);
      }
    } catch (e) {
      debugPrint("Scan Error: $e");
    }
  }

  Future<void> _saveToCache(List<LocalSong> songs) async {
    final jsonString = json.encode(songs.map((e) => e.toJson()).toList());
    await prefs.setString(_kCachedSongsKey, jsonString);
  }

  Future<void> deleteSong(LocalSong song) async {
    try {
      final file = File(song.path);
      if (await file.exists()) {
        await file.delete();
        state = state.where((s) => s.id != song.id).toList();
        _saveToCache(state);
      }
    } catch (e) {
      debugPrint("Error deleting song: $e");
    }
  }
}

final songsProvider = StateNotifierProvider<SongsNotifier, List<LocalSong>>((
  ref,
) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final permService = ref.watch(permissionServiceProvider);
  return SongsNotifier(prefs, permService);
});

final searchQueryProvider = StateProvider<String>((ref) => '');

final filteredSongsProvider = Provider<List<LocalSong>>((ref) {
  final allSongs = ref.watch(songsProvider);
  final query = ref.watch(searchQueryProvider).toLowerCase().trim();
  if (query.isEmpty) return allSongs;

  return allSongs.where((song) {
    return song.title.toLowerCase().contains(query) ||
        song.artist.toLowerCase().contains(query) ||
        song.album.toLowerCase().contains(query);
  }).toList();
});

// ==============================================================================
// 5. CACHED ARTWORK & COLOR PROVIDERS (UPDATED)
// ==============================================================================

final artworkProvider = FutureProvider.family<Uint8List?, String>((
  ref,
  filePath,
) async {
  ref.keepAlive();

  if (_artworkCache.containsKey(filePath)) {
    return _artworkCache[filePath];
  }

  try {
    final fullMetadata = await readAllMetadata(File(filePath), getImage: true);
    List<Picture>? pictures;
    switch (fullMetadata) {
      case Mp3Metadata m:
        pictures = m.pictures;
      case VorbisMetadata m:
        pictures = m.pictures;
      case RiffMetadata m:
        pictures = m.pictures;
      default:
        pictures = null;
    }

    final bytes = pictures?.firstOrNull?.bytes;
    _artworkCache[filePath] = bytes;
    return bytes;
  } catch (e) {
    _artworkCache[filePath] = null;
    return null;
  }
});

// 🚀 NATIVE FLUTTER COLOR EXTRACTION (No Palette Generator)
final dominantColorProvider = FutureProvider.family<Color, String>((
  ref,
  songPath,
) async {
  const defaultColor = Color(0xFF6366F1); // Fallback Indigo

  // 1. Check Color Cache
  if (_colorCache.containsKey(songPath)) {
    return _colorCache[songPath]!;
  }

  // 2. Get bytes from existing artwork provider
  final artworkBytes = await ref.watch(artworkProvider(songPath).future);

  if (artworkBytes == null || artworkBytes.isEmpty) {
    return defaultColor;
  }

  try {
    // 3. Use Native Flutter `ColorScheme.fromImageProvider`
    final scheme = await ColorScheme.fromImageProvider(
      provider: MemoryImage(artworkBytes),
      brightness: Brightness.dark, // Enforce dark scheme preference
    );

    // 4. Extract desired color (primary is usually the best accent)
    final extractedColor = scheme.primary;

    // 5. Cache and return
    _colorCache[songPath] = extractedColor;
    return extractedColor;
  } catch (e) {
    debugPrint("Color extraction error: $e");
    return defaultColor;
  }
});

final lyricsProvider = FutureProvider.family<String, LocalSong>((
  ref,
  song,
) async {
  ref.keepAlive();
  final prefs = ref.watch(sharedPreferencesProvider);
  final cacheKey = 'lyrics_${song.id}';

  if (prefs.containsKey(cacheKey)) return prefs.getString(cacheKey)!;

  try {
    final query = '${song.title} ${song.artist}'.trim();
    final url = Uri.parse(
      'https://lrclib.net/api/search?q=${Uri.encodeComponent(query)}',
    );
    final response = await http.get(url).timeout(const Duration(seconds: 4));

    if (response.statusCode == 200) {
      final List data = json.decode(response.body);
      if (data.isNotEmpty) {
        String lyrics = data[0]['syncedLyrics'] ?? data[0]['plainLyrics'] ?? '';
        if (lyrics.isNotEmpty) {
          await prefs.setString(cacheKey, lyrics);
          return lyrics;
        }
      }
    }
  } catch (_) {}

  return "No lyrics found.";
});

// ==============================================================================
// 6. AUDIO CONTROLLER
// ==============================================================================

final currentSongProvider = StateProvider<LocalSong?>((ref) => null);

final audioPlayerProvider = Provider<AudioPlayer>((ref) {
  final player = AudioPlayer();

  player.sequenceStateStream.listen((state) {
    if (state?.currentSource != null) {
      final mediaItem = state!.currentSource!.tag as MediaItem;
      final song = LocalSong(
        id: mediaItem.id,
        path: mediaItem.id,
        title: mediaItem.title,
        artist: mediaItem.artist ?? 'Unknown Artist',
        album: mediaItem.album ?? 'Unknown Album',
        durationMs: mediaItem.duration?.inMilliseconds ?? 0,
        addedDate: 0,
      );
      ref.read(currentSongProvider.notifier).state = song;
    }
  });

  ref.onDispose(() => player.dispose());
  return player;
});

final playbackStateProvider = StreamProvider<PlayerState>(
  (ref) => ref.watch(audioPlayerProvider).playerStateStream,
);
final positionProvider = StreamProvider<Duration>(
  (ref) => ref.watch(audioPlayerProvider).positionStream,
);
final durationProvider = StreamProvider<Duration?>(
  (ref) => ref.watch(audioPlayerProvider).durationStream,
);
final shuffleModeProvider = StreamProvider<bool>(
  (ref) => ref.watch(audioPlayerProvider).shuffleModeEnabledStream,
);
final loopModeProvider = StreamProvider<LoopMode>(
  (ref) => ref.watch(audioPlayerProvider).loopModeStream,
);

class AudioController {
  final Ref ref;
  AudioController(this.ref);
  AudioPlayer get _player => ref.read(audioPlayerProvider);

  Future<void> playPlaylist(
    List<LocalSong> songs, {
    int initialIndex = 0,
  }) async {
    try {
      final playlist = ConcatenatingAudioSource(
        useLazyPreparation: true,
        children: songs.map((song) {
          return AudioSource.uri(
            Uri.file(song.path),
            tag: MediaItem(
              id: song.path,
              title: song.title,
              artist: song.artist,
              album: song.album,
              duration: Duration(milliseconds: song.durationMs),
            ),
          );
        }).toList(),
      );

      await _player.setAudioSource(
        playlist,
        initialIndex: initialIndex,
        preload: true,
      );
      _player.play();
    } catch (e) {
      debugPrint("Play error: $e");
    }
  }

  void togglePlayPause() => _player.playing ? _player.pause() : _player.play();
  void seek(Duration pos) => _player.seek(pos);
  void skipNext() => _player.hasNext ? _player.seekToNext() : null;
  void skipPrevious() => _player.hasPrevious ? _player.seekToPrevious() : null;

  void toggleShuffle() async {
    final enable = !_player.shuffleModeEnabled;
    await _player.setShuffleModeEnabled(enable);
    if (enable) await _player.shuffle();
  }

  void cycleLoopMode() async {
    switch (_player.loopMode) {
      case LoopMode.off:
        await _player.setLoopMode(LoopMode.all);
        break;
      case LoopMode.all:
        await _player.setLoopMode(LoopMode.one);
        break;
      case LoopMode.one:
        await _player.setLoopMode(LoopMode.off);
        break;
    }
  }

  void deleteSong(LocalSong song) {
    if (_player.playing && ref.read(currentSongProvider)?.id == song.id)
      _player.stop();
    ref.read(songsProvider.notifier).deleteSong(song);
  }

  void shareSong(LocalSong song) {
    Share.shareXFiles([XFile(song.path)]);
  }
}

final audioControllerProvider = Provider<AudioController>(
  (ref) => AudioController(ref),
);

// ==============================================================================
// 7. FAVORITES
// ==============================================================================

class FavoritesNotifier extends StateNotifier<Set<String>> {
  final SharedPreferences prefs;
  static const _key = 'favorites_list_ids';
  FavoritesNotifier(this.prefs) : super({}) {
    _load();
  }
  void _load() {
    final list = prefs.getStringList(_key);
    if (list != null) state = list.toSet();
  }

  void toggleFavorite(String songId) {
    if (state.contains(songId))
      state = {...state}..remove(songId);
    else
      state = {...state}..add(songId);
    prefs.setStringList(_key, state.toList());
  }
}

final favoritesProvider = StateNotifierProvider<FavoritesNotifier, Set<String>>(
  (ref) {
    return FavoritesNotifier(ref.watch(sharedPreferencesProvider));
  },
);

final favoriteSongsProvider = Provider<List<LocalSong>>((ref) {
  final allSongs = ref.watch(songsProvider);
  final favIds = ref.watch(favoritesProvider);
  return allSongs.where((s) => favIds.contains(s.id)).toList();
});

// ==============================================================================
// 8. OPTIMIZED SCANNER WORKER
// ==============================================================================

Future<List<LocalSong>> _scanWorker(dynamic _) async {
  debugPrint("SCANNING WITH audio_metadata_reader (FAST MODE)...");

  final List<LocalSong> songs = [];
  final extensions = {'.mp3', '.m4a', '.wav', '.flac', '.aac', '.ogg'};
  final searchPaths = [
    '/storage/emulated/0/Music',
    '/storage/emulated/0/Download',
    '/storage/emulated/0/Audio',
    '/storage/emulated/0/WhatsApp/Media/WhatsApp Audio',
  ];

  for (var rootPath in searchPaths) {
    final dir = Directory(rootPath);
    if (!await dir.exists()) continue;

    try {
      final entities = dir.listSync(recursive: true, followLinks: false);

      for (var entity in entities) {
        if (entity is File) {
          final ext = p.extension(entity.path).toLowerCase();
          if (extensions.contains(ext)) {
            final stat = entity.statSync();
            final fileSize = stat.size;
            // Ignore tiny files < 100KB
            if (fileSize < 100 * 1024) continue;

            AudioMetadata? metadata;
            try {
              // 🚀 PERFORMANCE: getImage: false saves HUGE amounts of RAM
              metadata = await readMetadata(entity, getImage: false);
            } catch (_) {}

            String title =
                metadata?.title?.trim() ??
                p.basenameWithoutExtension(entity.path);
            if (title.isEmpty) title = "Unknown Title";

            String artist = (metadata?.artist?.isNotEmpty == true)
                ? metadata!.artist!
                : 'Unknown Artist';

            String album = metadata?.album ?? 'Unknown Album';
            String genre = (metadata?.genres?.isNotEmpty == true)
                ? metadata!.genres!.first
                : 'Unknown Genre';

            int year = 0;
            int durationMs = metadata?.duration?.inMilliseconds ?? 0;

            int bitrate = 0;
            if (durationMs > 0 && fileSize > 0) {
              final secs = durationMs / 1000;
              bitrate = (fileSize * 8 / secs / 1000).round();
            }

            songs.add(
              LocalSong(
                id: entity.path,
                path: entity.path,
                title: title,
                artist: artist,
                album: album,
                genre: genre,
                year: year,
                durationMs: durationMs,
                bitrate: bitrate,
                fileSizeBytes: fileSize,
                format: ext.replaceAll('.', '').toUpperCase(),
                addedDate: stat.modified.millisecondsSinceEpoch,
              ),
            );
          }
        }
      }
    } catch (_) {
      // Silently ignore directory permission errors
    }
  }

  songs.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
  return songs;
}
