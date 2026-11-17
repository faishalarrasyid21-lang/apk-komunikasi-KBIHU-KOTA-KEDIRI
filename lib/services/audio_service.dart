import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_pcm_sound/flutter_pcm_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart' hide IosAudioCategory;

class AudioService {
  final AudioRecorder _recorder = AudioRecorder();
  StreamSubscription<Uint8List>? _micSubscription;

  bool _isRecording = false;
  bool _isPlayerInitialized = false;

  bool get isRecording => _isRecording;

  /// Inisialisasi Recorder untuk HP KETUA (Admin)
  Future<bool> initRecorder() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  /// Mulai merekam suara saat tombol PTT ditekan
  Future<void> startRecording(Function(Uint8List) onAudioChunk) async {
    if (_isRecording) return;

    try {
      if (await _recorder.hasPermission()) {
        final stream = await _recorder.startStream(
          const RecordConfig(
            encoder: AudioEncoder.pcm16bits,
            sampleRate: 16000,
            numChannels: 1,
          ),
        );
        _isRecording = true;

        await _micSubscription?.cancel();
        _micSubscription = stream.listen((chunk) {
          if (_isRecording && chunk.isNotEmpty) {
            onAudioChunk(chunk);
          }
        });
      }
    } catch (_) {}
  }

  /// Berhenti merekam saat tombol PTT dilepas
  Future<void> stopRecording() async {
    if (!_isRecording) return;
    try {
      _isRecording = false;
      await _micSubscription?.cancel();
      _micSubscription = null;
      await _recorder.stop();
    } catch (_) {}
  }

  /// Inisialisasi Player untuk HP JAMAAH (Listener)
  Future<bool> initPlayer() async {
    try {
      await FlutterPcmSound.setup(
        sampleRate: 16000,
        channelCount: 1,
        iosAudioCategory: IosAudioCategory.playback,
      );
      await FlutterPcmSound.setLogLevel(LogLevel.none);
      _isPlayerInitialized = true;
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Memutar potongan audio ke earphone jamaah
  void playChunk(Uint8List chunk) {
    if (!_isPlayerInitialized || chunk.isEmpty) return;
    try {
      final pcm = PcmArrayInt16(
        bytes: chunk.buffer.asByteData(chunk.offsetInBytes, chunk.lengthInBytes),
      );
      FlutterPcmSound.feed(pcm);
    } catch (_) {}
  }

  /// Flush buffer audio (reset player) jika buffer menumpuk > 180ms
  Future<void> flushBuffer() async {
    if (!_isPlayerInitialized) return;
    try {
      await FlutterPcmSound.release();
      await FlutterPcmSound.setup(
        sampleRate: 16000,
        channelCount: 1,
        iosAudioCategory: IosAudioCategory.playback,
      );
    } catch (_) {}
  }

  Future<void> dispose() async {
    _isRecording = false;
    await _micSubscription?.cancel();
    await _recorder.dispose();
    if (_isPlayerInitialized) {
      await FlutterPcmSound.release();
    }
  }
}
