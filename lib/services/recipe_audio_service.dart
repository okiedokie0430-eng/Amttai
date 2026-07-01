import 'dart:io';
import 'package:appwrite/appwrite.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class RecipeAudioService {
  // Singleton instance
  static final RecipeAudioService _instance = RecipeAudioService._internal();

  factory RecipeAudioService() {
    return _instance;
  }

  RecipeAudioService._internal();

  Storage? _storage;
  final AudioPlayer _audioPlayer = AudioPlayer();

  // Replace with your actual Appwrite bucket ID for TTS voices
  static const String _bucketId = 'tts_voices';

  /// Initialize the service with the Appwrite Storage instance.
  /// Must be called before using the service.
  void init(Storage storage) {
    _storage = storage;
  }

  /// Plays the audio for a specific recipe step.
  /// Downloads and caches the file locally if it hasn't been downloaded yet.
  Future<void> playStepAudio(
    String recipeId,
    String fileId,
    int stepIndex,
  ) async {
    if (_storage == null) {
      throw Exception(
        'RecipeAudioService must be initialized with a Storage instance first.',
      );
    }

    try {
      // 1. Get the local documents directory
      final directory = await getApplicationDocumentsDirectory();

      // 2. Create audio cache directory if it doesn't exist
      final cacheDir = Directory('${directory.path}/audio_cache');
      if (!await cacheDir.exists()) {
        await cacheDir.create(recursive: true);
      }

      // 3. Construct local file path
      final fileName = '${recipeId}_step_$stepIndex.mp3';
      final file = File('${cacheDir.path}/$fileName');

      // 4. Offline Check & Download Phase
      if (await file.exists()) {
        debugPrint('[Audio] Cache hit for $fileName (Step $stepIndex)');
      } else {
        debugPrint('[Audio] Downloading step $stepIndex ($fileName)...');

        // Download bytes from Appwrite
        final Uint8List bytes = await _storage!.getFileDownload(
          bucketId: _bucketId,
          fileId: fileId,
        );

        // Write bytes to local file
        await file.writeAsBytes(bytes, flush: true);
        debugPrint('[Audio] Download complete and cached: $fileName');
      }

      // 5. Playback Phase
      await _audioPlayer.stop(); // Stop any currently playing audio
      await _audioPlayer.play(DeviceFileSource(file.path));
    } catch (e) {
      debugPrint('[Audio] Error playing step audio: $e');
      // Rethrow or handle gracefully based on UI needs
    }
  }

  /// Stops the currently playing audio.
  Future<void> stopAudio() async {
    try {
      await _audioPlayer.stop();
      debugPrint('[Audio] Playback stopped.');
    } catch (e) {
      debugPrint('[Audio] Error stopping audio: $e');
    }
  }

  /// Disposes of the AudioPlayer resources.
  Future<void> dispose() async {
    try {
      await _audioPlayer.dispose();
      debugPrint('[Audio] Service disposed.');
    } catch (e) {
      debugPrint('[Audio] Error disposing audio service: $e');
    }
  }
}
