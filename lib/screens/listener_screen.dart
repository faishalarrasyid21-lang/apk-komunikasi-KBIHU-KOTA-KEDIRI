import 'dart:async';
import 'package:flutter/material.dart';
import '../models/app_mode.dart';
import '../models/stage_model.dart';
import '../services/audio_service.dart';
import '../services/online_service.dart';
import '../services/udp_service.dart';

class ListenerScreen extends StatefulWidget {
  final AppMode appMode;
  final String roomId;

  const ListenerScreen({
    super.key,
    this.appMode = AppMode.offline,
    this.roomId = 'KLOTER-01',
  });

  @override
  State<ListenerScreen> createState() => _ListenerScreenState();
}

class _ListenerScreenState extends State<ListenerScreen> with SingleTickerProviderStateMixin {
  final UdpService _udpService = UdpService();
  final OnlineService _onlineService = OnlineService();
  final AudioService _audioService = AudioService();

  HajjStage _currentStage = HajjStage.defaultStages.first;
  bool _isLeaderOnline = false;
  bool _isLeaderSpeaking = false;
  StreamSubscription? _audioSub;
  StreamSubscription? _stageSub;
  StreamSubscription? _speakingSub;
  StreamSubscription? _onlineSub;
  StreamSubscription? _onlineAudioSub;
  StreamSubscription? _onlineStageSub;
  StreamSubscription? _onlineHeartbeatSub;
  StreamSubscription? _onlineConnectedSub;

  bool get _isOnlineMode => widget.appMode == AppMode.online;

  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _initServices();
  }

  Future<void> _initServices() async {
    // 1. Siapkan Audio Player
    await _audioService.initPlayer();

    // 2. Siapkan UDP Listener (selalu aktif, untuk Wi-Fi lokal)
    await _udpService.initAsListener();

    // Listen audio packets dan langsung kirim ke earphone
    _audioSub = _udpService.onAudioReceived.listen((chunk) {
      _audioService.playChunk(chunk);
    });

    // Listen perubahan tahapan rukun dari Ketua
    _stageSub = _udpService.onStageReceived.listen((stage) {
      if (mounted && _currentStage.id != stage.id) {
        setState(() => _currentStage = stage);
      }
    });

    // Listen status bicara Ketua
    _speakingSub = _udpService.onLeaderSpeaking.listen((isSpeaking) {
      setState(() => _isLeaderSpeaking = isSpeaking);
    });

    // Listen detak jantung (presence) Ketua via UDP
    _onlineSub = _udpService.onLeaderOnline.listen((isOnline) {
      setState(() => _isLeaderOnline = isOnline);
    });

    // 3. Jika mode online: juga subscribe via OnlineService
    if (_isOnlineMode) {
      await _onlineService.connect(
          roomId: widget.roomId, isLeader: false);

      _onlineConnectedSub = _onlineService.onConnected.listen((_) {
        // connected state tracked via onHeartbeat
      });

      _onlineAudioSub = _onlineService.onAudioReceived.listen((chunk) {
        _audioService.playChunk(chunk);
      });

      _onlineStageSub = _onlineService.onStageReceived.listen((json) {
        try {
          final stage = HajjStage.fromJson(json);
          if (mounted && _currentStage.id != stage.id) {
            setState(() => _currentStage = stage);
          }
        } catch (_) {}
      });

      _onlineHeartbeatSub = _onlineService.onHeartbeat.listen((_) {
        if (mounted) setState(() => _isLeaderOnline = true);
      });
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _audioSub?.cancel();
    _stageSub?.cancel();
    _speakingSub?.cancel();
    _onlineSub?.cancel();
    _onlineAudioSub?.cancel();
    _onlineStageSub?.cancel();
    _onlineHeartbeatSub?.cancel();
    _onlineConnectedSub?.cancel();
    _audioService.dispose();
    _udpService.close();
    _onlineService.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9F8),
      appBar: AppBar(
        title: Text(_isOnlineMode
            ? 'Jamaah • Kode: ${widget.roomId}'
            : 'Mode Jamaah (Mendengar)'),
        backgroundColor: const Color(0xFF0D5C3A),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Status Bar Koneksi ke Ketua
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: _isLeaderOnline ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3E0),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isLeaderOnline ? Colors.green.shade600 : Colors.orange.shade700,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _isLeaderOnline
                          ? 'Ketua Rombongan Terhubung (Sinyal Bagus)'
                          : 'Mencari sinyal Ketua... Pastikan tersambung ke Hotspot / Wi-Fi.',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _isLeaderOnline ? const Color(0xFF1B5E20) : const Color(0xFFE65100),
                      ),
                    ),
                  ),
                  if (!_isLeaderOnline)
                    IconButton(
                      icon: const Icon(Icons.sync, size: 18),
                      tooltip: 'Pindai Ulang',
                      onPressed: () => _udpService.sendClientJoin(),
                    ),
                ],
              ),
            ),

            if (!_isLeaderOnline)
              Container(
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade300),
                ),
                child: Row(
                  children: [
                    Icon(Icons.tips_and_updates_outlined, color: Colors.amber.shade900, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Tips Hotspot: Matikan Data Seluler di HP Jamaah dan pilih "Tetap Terhubung" agar Android tidak memutus jaringan lokal.',
                        style: TextStyle(fontSize: 11, color: Colors.amber.shade900),
                      ),
                    ),
                  ],
                ),
              ),

            // Banner Indikator Suara Real-Time
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              color: _isLeaderSpeaking ? const Color(0xFF2E7D32) : Colors.grey.shade200,
              child: Row(
                children: [
                  Icon(
                    _isLeaderSpeaking ? Icons.volume_up_rounded : Icons.headphones_outlined,
                    color: _isLeaderSpeaking ? Colors.white : Colors.black54,
                    size: 28,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isLeaderSpeaking ? 'KETUA SEDANG BICARA' : 'STANDBY MENDENGAR',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                            color: _isLeaderSpeaking ? Colors.white : Colors.black87,
                          ),
                        ),
                        Text(
                          _isLeaderSpeaking
                              ? 'Dengarkan suara langsung di earphone Anda'
                              : 'Pasang earphone agar instruksi terdengar jelas',
                          style: TextStyle(
                            fontSize: 11,
                            color: _isLeaderSpeaking ? Colors.white70 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_isLeaderSpeaking)
                    FadeTransition(
                      opacity: _pulseController,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.redAccent,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'LIVE',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Konten Utama: Tahapan & Teks Doa
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Tag Kategori
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0D5C3A),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _currentStage.category.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Tahapan Saat Ini',
                          style: TextStyle(fontSize: 12, color: Colors.black45),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Judul Tahapan
                    Text(
                      _currentStage.title,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Petunjuk dari Ketua
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.info_outline, color: Color(0xFF0D5C3A), size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _currentStage.instruction,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF1B5E20),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Kotak Teks Doa Bahasa Arab
                    if (_currentStage.arabicText != null) ...[
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFF0D5C3A).withValues(alpha: 0.3)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.menu_book_rounded, color: Color(0xFF0D5C3A), size: 18),
                                SizedBox(width: 6),
                                Text(
                                  'Bacaan Doa:',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0D5C3A),
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 24),
                            Text(
                              _currentStage.arabicText!,
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0D5C3A),
                                height: 1.8,
                              ),
                            ),
                            if (_currentStage.latinText != null) ...[
                              const SizedBox(height: 16),
                              Text(
                                _currentStage.latinText!,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontStyle: FontStyle.italic,
                                  color: Colors.black87,
                                  height: 1.4,
                                ),
                              ),
                            ],
                            if (_currentStage.translation != null) ...[
                              const SizedBox(height: 12),
                              Text(
                                'Artinya:\n"${_currentStage.translation!}"',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.black54,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    // Reminder Earphone
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amber.shade300),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.headset, color: Colors.amber, size: 24),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Gunakan earphone agar tetap mendengar aba-aba ketua dengan jelas di keramaian.',
                              style: TextStyle(fontSize: 12, color: Colors.brown),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
