import 'dart:async';
import 'package:flutter/material.dart';
import '../models/app_mode.dart';
import '../models/stage_model.dart';
import '../services/audio_service.dart';
import '../services/online_service.dart';
import '../services/udp_service.dart';

class LeaderScreen extends StatefulWidget {
  final AppMode appMode;
  final String roomId;

  const LeaderScreen({
    super.key,
    this.appMode = AppMode.offline,
    this.roomId = 'KLOTER-01',
  });

  @override
  State<LeaderScreen> createState() => _LeaderScreenState();
}

class _LeaderScreenState extends State<LeaderScreen> {
  final UdpService _udpService = UdpService();
  final OnlineService _onlineService = OnlineService();
  final AudioService _audioService = AudioService();

  HajjStage _currentStage = HajjStage.defaultStages.first;
  bool _isMicOn = false;
  int _connectedCount = 0;
  bool _isOnlineConnected = false;

  StreamSubscription<int>? _clientCountSub;
  StreamSubscription<bool>? _onlineConnectedSub;

  bool get _isOnlineMode => widget.appMode == AppMode.online;

  @override
  void initState() {
    super.initState();
    _initServices();
  }

  Future<void> _initServices() async {
    // Selalu init UDP untuk mode offline
    await _udpService.initAsLeader();
    _udpService.sendStage(_currentStage);

    _clientCountSub = _udpService.onClientCountChanged.listen((count) {
      if (mounted) setState(() => _connectedCount = count);
    });

    // Jika mode online: juga init OnlineService
    if (_isOnlineMode) {
      await _onlineService.connect(
          roomId: widget.roomId, isLeader: true);
      _onlineConnectedSub = _onlineService.onConnected.listen((connected) {
        if (mounted) setState(() => _isOnlineConnected = connected);
      });
    }

    await _audioService.initRecorder();
  }

  /// Ketuk tombol mic untuk ON / OFF (tanpa perlu tahan)
  void _toggleMic() async {
    if (_isMicOn) {
      setState(() => _isMicOn = false);
      await _audioService.stopRecording();
    } else {
      setState(() => _isMicOn = true);
      await _audioService.startRecording((audioChunk) {
        if (_isMicOn) {
          _udpService.sendAudioChunk(audioChunk);
          if (_isOnlineMode) _onlineService.sendAudioChunk(audioChunk);
        }
      });
    }
  }

  void _changeStage(HajjStage stage) {
    setState(() => _currentStage = stage);
    _udpService.sendStage(stage);
    if (_isOnlineMode) _onlineService.sendStage(stage.toJson());
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Tahapan disiarkan: ${stage.title}'),
        duration: const Duration(seconds: 2),
        backgroundColor: const Color(0xFF0D5C3A),
      ),
    );
  }

  void _openStageSelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final stages = HajjStage.defaultStages;
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    children: [
                      Icon(Icons.format_list_bulleted, color: Color(0xFF0D5C3A)),
                      SizedBox(width: 8),
                      Text(
                        'Pilih Tahapan / Doa untuk Disiarkan',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                Expanded(
                  child: ListView.separated(
                    controller: scrollController,
                    itemCount: stages.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = stages[index];
                      final isSelected = item.id == _currentStage.id;
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isSelected ? const Color(0xFF0D5C3A) : Colors.grey.shade200,
                          foregroundColor: isSelected ? Colors.white : Colors.black87,
                          child: Text('${index + 1}'),
                        ),
                        title: Text(
                          item.title,
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected ? const Color(0xFF0D5C3A) : Colors.black87,
                          ),
                        ),
                        subtitle: Text(
                          item.instruction,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: isSelected
                            ? const Icon(Icons.check_circle, color: Color(0xFF0D5C3A))
                            : null,
                        onTap: () {
                          Navigator.pop(context);
                          _changeStage(item);
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    if (_isMicOn) {
      _audioService.stopRecording();
    }
    _clientCountSub?.cancel();
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
            ? 'Ketua • Kode: ${widget.roomId}'
            : 'Mode Ketua (Pemancar)'),
        backgroundColor: const Color(0xFF0D5C3A),
        foregroundColor: Colors.white,
        actions: [
          if (_isOnlineMode)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Icon(
                _isOnlineConnected ? Icons.cell_tower : Icons.signal_wifi_off,
                color: _isOnlineConnected
                    ? Colors.greenAccent
                    : Colors.orange.shade300,
                size: 20,
              ),
            ),
          IconButton(
            tooltip: 'Kirim Ulang Status',
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _udpService.sendStage(_currentStage);
              if (_isOnlineMode) _onlineService.sendStage(_currentStage.toJson());
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Banner Status Hotspot & Jumlah Jamaah
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: _connectedCount > 0 ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3E0),
              child: Row(
                children: [
                  Icon(
                    Icons.wifi_tethering,
                    color: _connectedCount > 0 ? const Color(0xFF2E7D32) : Colors.orange.shade800,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _connectedCount > 0
                          ? '$_connectedCount Jamaah Terhubung • Siaran Audio Aktif'
                          : 'Hotspot Aktif: Menunggu HP Jamaah tersambung...',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _connectedCount > 0 ? const Color(0xFF1B5E20) : Colors.orange.shade900,
                      ),
                    ),
                  ),
                  if (_connectedCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D5C3A),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$_connectedCount HP',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Kartu Tahapan Saat Ini
                    Container(
                      padding: const EdgeInsets.all(18),
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
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0D5C3A).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  _currentStage.category.toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0D5C3A),
                                  ),
                                ),
                              ),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0D5C3A),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                onPressed: _openStageSelector,
                                icon: const Icon(Icons.swap_horiz, size: 16),
                                label: const Text('Ubah Tahapan', style: TextStyle(fontSize: 12)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _currentStage.title,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _currentStage.instruction,
                            style: const TextStyle(fontSize: 13, color: Colors.black54),
                          ),
                          if (_currentStage.arabicText != null) ...[
                            const SizedBox(height: 14),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF9FBF9),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    _currentStage.arabicText!,
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF0D5C3A),
                                      height: 1.6,
                                    ),
                                  ),
                                  if (_currentStage.latinText != null) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      _currentStage.latinText!,
                                      textAlign: TextAlign.left,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontStyle: FontStyle.italic,
                                        color: Colors.black54,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 30),

                    // Section Tombol Mic (Toggle Tap ON / OFF)
                    Center(
                      child: Column(
                        children: [
                          GestureDetector(
                            onTap: _toggleMic,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 115,
                              height: 115,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _isMicOn ? Colors.red.shade600 : const Color(0xFF0D5C3A),
                                boxShadow: [
                                  BoxShadow(
                                    color: (_isMicOn ? Colors.red : const Color(0xFF0D5C3A))
                                        .withValues(alpha: 0.35),
                                    blurRadius: _isMicOn ? 20 : 10,
                                    spreadRadius: _isMicOn ? 6 : 1,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    _isMicOn ? Icons.mic_rounded : Icons.mic_none_rounded,
                                    color: Colors.white,
                                    size: 42,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _isMicOn ? 'MIC AKTIF' : 'MIC MATI',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                      letterSpacing: 0.6,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _isMicOn
                                ? '🔴 Mic Menyala: Suara terdengar di HP jamaah\n(Ketuk untuk mematikan)'
                                : 'Ketuk tombol untuk mulai bicara',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: _isMicOn ? FontWeight.bold : FontWeight.normal,
                              color: _isMicOn ? Colors.red.shade700 : Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 30),

                    // Tombol Cepat Darurat
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red.shade700,
                        side: BorderSide(color: Colors.red.shade300),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        final alertStage = HajjStage.defaultStages.firstWhere((s) => s.id == 'kumpul_darurat');
                        _changeStage(alertStage);
                      },
                      icon: const Icon(Icons.warning_amber_rounded),
                      label: const Text(
                        'Siarkan Pengumuman: Kumpul di Titik Temu',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
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
