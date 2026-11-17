import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import '../models/stage_model.dart';

enum PacketType {
  audio(1),
  stage(2),
  heartbeat(3),
  clientJoin(4); // Sinyal pendaftaran berkala dari HP Jamaah ke HP Ketua

  final int value;
  const PacketType(this.value);

  static PacketType? fromValue(int val) {
    for (var type in PacketType.values) {
      if (type.value == val) return type;
    }
    return null;
  }
}

class _ClientInfo {
  final InternetAddress address;
  DateTime lastSeen;
  _ClientInfo(this.address, this.lastSeen);
}

class UdpService {
  static final InternetAddress multicastAddress = InternetAddress('239.255.0.1');
  static final InternetAddress broadcastAddress = InternetAddress('255.255.255.255');
  static const int port = 50005;

  RawDatagramSocket? _socket;
  Timer? _heartbeatTimer;
  Timer? _speechTimeoutTimer;
  Timer? _presenceTimeoutTimer;
  Timer? _pingTimer;
  Timer? _cleanupTimer;

  // Stream Controllers
  final _audioController = StreamController<Uint8List>.broadcast();
  final _stageController = StreamController<HajjStage>.broadcast();
  final _isLeaderSpeakingController = StreamController<bool>.broadcast();
  final _isLeaderOnlineController = StreamController<bool>.broadcast();
  final _clientCountController = StreamController<int>.broadcast();
  final _flushController = StreamController<bool>.broadcast();

  Stream<Uint8List> get onAudioReceived => _audioController.stream;
  Stream<HajjStage> get onStageReceived => _stageController.stream;
  Stream<bool> get onLeaderSpeaking => _isLeaderSpeakingController.stream;
  Stream<bool> get onLeaderOnline => _isLeaderOnlineController.stream;
  Stream<int> get onClientCountChanged => _clientCountController.stream;
  Stream<bool> get onFlushBuffer => _flushController.stream;

  bool _isLeaderSpeaking = false;
  bool _isLeaderOnline = false;
  HajjStage? _lastKnownStage;
  InternetAddress? _leaderAddress;

  // Sequence ID untuk deduplikasi paket audio
  int _audioSeq = 0;
  int _lastAudioSeq = -1;

  // Daftar klien Jamaah yang terhubung (di sisi Ketua)
  final Map<String, _ClientInfo> _knownClients = {};
  List<InternetAddress> _cachedTargets = [];

  int get connectedClientsCount => _knownClients.length;

  /// Cari subnet broadcast & gateway lokal agar kompatibel dengan Hotspot HP & Router
  Future<void> _refreshTargetAddresses() async {
    final targets = <String>{
      '255.255.255.255',
      '239.255.0.1',
      // Subnet bawaan Android Hotspot paling umum
      '192.168.43.255',
      '192.168.43.1',
      '192.168.49.255',
      '192.168.49.1',
      '192.168.50.255',
      '192.168.50.1',
      '192.168.137.255',
      '192.168.137.1',
      '192.168.1.255',
      '192.168.1.1',
      '192.168.0.255',
      '192.168.0.1',
    };

    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          final parts = addr.address.split('.');
          if (parts.length == 4) {
            final prefix = '${parts[0]}.${parts[1]}.${parts[2]}';
            targets.add('$prefix.255'); // Subnet broadcast
            targets.add('$prefix.1');   // Hotspot Gateway / IP Ketua
          }
        }
      }
    } catch (_) {}

    final list = <InternetAddress>[];
    for (final ipStr in targets) {
      try {
        list.add(InternetAddress(ipStr));
      } catch (_) {}
    }
    _cachedTargets = list;
  }

  /// Inisialisasi Mode KETUA (Admin / Broadcaster)
  Future<void> initAsLeader() async {
    await close();
    await _refreshTargetAddresses();

    try {
      _socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        port,
        reuseAddress: true,
        reusePort: true,
      );
    } catch (_) {
      // Jika port 50005 bentrok, bind ke ephemeral port
      _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    }

    _socket?.broadcastEnabled = true;
    _socket?.multicastLoopback = false;

    // Listen paket dari Jamaah (misal: Sinyal Join / Ping)
    _socket?.listen((RawSocketEvent event) {
      if (event == RawSocketEvent.read) {
        final datagram = _socket?.receive();
        if (datagram != null && datagram.data.isNotEmpty) {
          _processIncomingLeaderPacket(datagram);
        }
      }
    });

    // Kirim sinyal heartbeat setiap 2 detik
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      sendHeartbeat();
    });

    // Bersihkan daftar jamaah yang disconnect (tidak kirim ping > 12 detik)
    _cleanupTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _cleanExpiredClients();
      _refreshTargetAddresses();
    });
  }

  /// Inisialisasi Mode JAMAAH (Listener)
  Future<void> initAsListener() async {
    await close();
    await _refreshTargetAddresses();

    try {
      _socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        port,
        reuseAddress: true,
        reusePort: true,
      );

      _socket?.broadcastEnabled = true;

      // Coba gabung multicast di semua interface yang tersedia
      try {
        final interfaces = await NetworkInterface.list(
          includeLoopback: false,
          type: InternetAddressType.IPv4,
        );
        for (final iface in interfaces) {
          try {
            _socket?.joinMulticast(multicastAddress, iface);
          } catch (_) {}
        }
      } catch (_) {
        try {
          _socket?.joinMulticast(multicastAddress);
        } catch (_) {}
      }

      _socket?.listen((RawSocketEvent event) {
        if (event == RawSocketEvent.read) {
          final datagram = _socket?.receive();
          if (datagram != null && datagram.data.isNotEmpty) {
            _leaderAddress = datagram.address;
            _processIncomingListenerPacket(datagram.data);
          }
        }
      });
    } catch (_) {}

    // Segera kirim sinyal Join ke Ketua begitu masuk
    sendClientJoin();

    // Kirim sinyal ping berkala setiap 2 detik agar Ketua tahu Jamaah aktif
    _pingTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      sendClientJoin();
    });
  }

  /// Memproses paket yang diterima di sisi KETUA (dari Jamaah)
  void _processIncomingLeaderPacket(Datagram datagram) {
    final packet = datagram.data;
    final typeVal = packet[0];
    final type = PacketType.fromValue(typeVal);

    if (type == PacketType.clientJoin) {
      _registerClient(datagram.address);

      // Balas langsung ke Jamaah tersebut dengan Heartbeat dan Tahapan terakhir
      _sendDirectPacket(
        Uint8List.fromList([PacketType.heartbeat.value]),
        datagram.address,
      );

      if (_lastKnownStage != null) {
        final jsonBytes = utf8.encode(_lastKnownStage!.toJson());
        final stagePacket = Uint8List(1 + jsonBytes.length);
        stagePacket[0] = PacketType.stage.value;
        stagePacket.setRange(1, stagePacket.length, jsonBytes);
        _sendDirectPacket(stagePacket, datagram.address);
      }
    }
  }

  void _registerClient(InternetAddress address) {
    final now = DateTime.now();
    _knownClients[address.address] = _ClientInfo(address, now);
    _clientCountController.add(_knownClients.length);
  }

  void _cleanExpiredClients() {
    final now = DateTime.now();
    final beforeCount = _knownClients.length;
    _knownClients.removeWhere((_, info) => now.difference(info.lastSeen).inSeconds > 12);
    if (_knownClients.length != beforeCount) {
      _clientCountController.add(_knownClients.length);
    }
  }

  /// Memproses paket yang diterima di sisi JAMAAH (dari Ketua)
  void _processIncomingListenerPacket(Uint8List packet) {
    final typeVal = packet[0];
    final type = PacketType.fromValue(typeVal);

    // Update status bahwa Ketua online & terjangkau
    _markLeaderOnline();

    switch (type) {
      case PacketType.audio:
        // Paket audio ber-header 3 bytes: [type, seq_high, seq_low]
        if (packet.length < 3) break;
        final seq = (packet[1] << 8) | packet[2];

        // Deduplikasi: buang paket yang sudah/lebih lama (kecuali rollover)
        if (_lastAudioSeq >= 0) {
          final diff = seq - _lastAudioSeq;
          // diff negatif atau nol → duplikat; hanya lewatkan jika rollover (diff < -1000)
          if (diff <= 0 && diff > -1000) break;
        }
        _lastAudioSeq = seq;

        final payload = packet.sublist(3);
        _markLeaderSpeaking();
        _audioController.add(payload);
        break;

      case PacketType.stage:
        final payload = packet.sublist(1);
        try {
          final jsonString = utf8.decode(payload);
          final stage = HajjStage.fromJson(jsonString);
          _stageController.add(stage);
        } catch (_) {}
        break;

      case PacketType.heartbeat:
        // Presence ketua ter-update
        break;

      case PacketType.clientJoin:
      case null:
        break;
    }
  }

  void _markLeaderOnline() {
    if (!_isLeaderOnline) {
      _isLeaderOnline = true;
      _isLeaderOnlineController.add(true);
    }
    _presenceTimeoutTimer?.cancel();
    _presenceTimeoutTimer = Timer(const Duration(seconds: 6), () {
      _isLeaderOnline = false;
      _isLeaderOnlineController.add(false);
    });
  }

  void _markLeaderSpeaking() {
    if (!_isLeaderSpeaking) {
      _isLeaderSpeaking = true;
      _isLeaderSpeakingController.add(true);
    }
    _speechTimeoutTimer?.cancel();
    _speechTimeoutTimer = Timer(const Duration(milliseconds: 500), () {
      _isLeaderSpeaking = false;
      _isLeaderSpeakingController.add(false);
      _lastAudioSeq = -1; // Reset urutan saat ketua jeda/berhenti bicara
    });
  }

  /// Mengirim potongan audio (Mic PCM) — unicast saja ke Jamaah terdaftar
  void sendAudioChunk(Uint8List audioBytes) {
    if (_socket == null || audioBytes.isEmpty) return;

    // Header 3 bytes: [type, seq_high, seq_low]
    final seq = _audioSeq & 0xFFFF;
    _audioSeq = (_audioSeq + 1) & 0xFFFF;

    final packet = Uint8List(3 + audioBytes.length);
    packet[0] = PacketType.audio.value;
    packet[1] = (seq >> 8) & 0xFF;
    packet[2] = seq & 0xFF;
    packet.setRange(3, packet.length, audioBytes);

    _sendAudioPacket(packet);
  }

  /// Kirim paket audio HANYA unicast ke IP Jamaah terdaftar (tidak broadcast)
  void _sendAudioPacket(Uint8List packet) {
    if (_socket == null) return;
    for (final client in _knownClients.values) {
      _sendDirectPacket(packet, client.address);
    }
  }

  /// Mengirim status / tahapan rukun ibadah
  void sendStage(HajjStage stage) {
    _lastKnownStage = stage;
    if (_socket == null) return;
    final jsonBytes = utf8.encode(stage.toJson());
    final packet = Uint8List(1 + jsonBytes.length);
    packet[0] = PacketType.stage.value;
    packet.setRange(1, packet.length, jsonBytes);

    // Kirim BURST 4x (0ms, 40ms, 100ms, 200ms) agar update tahapan
    // langsung diterima di HP Jamaah saat itu juga secara REALTIME (0 lag)
    _sendPacket(packet);
    Future.delayed(const Duration(milliseconds: 40), () => _sendPacket(packet));
    Future.delayed(const Duration(milliseconds: 100), () => _sendPacket(packet));
    Future.delayed(const Duration(milliseconds: 200), () => _sendPacket(packet));
  }

  /// Mengirim detak jantung (Heartbeat) & Sinkronisasi Otomatis Tahapan Berjalan
  void sendHeartbeat() {
    if (_socket == null) return;
    final packet = Uint8List.fromList([PacketType.heartbeat.value]);
    _sendPacket(packet);

    // Selalu kirimkan tahapan aktif secara berkala agar jamaah yang baru membuka
    // aplikasi atau sempat terputus langsung tersinkronisasi otomatis
    if (_lastKnownStage != null) {
      final jsonBytes = utf8.encode(_lastKnownStage!.toJson());
      final stagePacket = Uint8List(1 + jsonBytes.length);
      stagePacket[0] = PacketType.stage.value;
      stagePacket.setRange(1, stagePacket.length, jsonBytes);
      _sendPacket(stagePacket);
    }
  }

  /// Sinyal dari Jamaah ke Ketua untuk mendaftarkan IP di Hotspot
  void sendClientJoin() {
    if (_socket == null) return;
    final packet = Uint8List.fromList([PacketType.clientJoin.value]);

    // 1. Jika sudah tahu IP Ketua, kirim unicast langsung
    if (_leaderAddress != null) {
      _sendDirectPacket(packet, _leaderAddress!);
    }

    // 2. Kirim ke seluruh target gateway & subnet broadcast
    for (final target in _cachedTargets) {
      _sendDirectPacket(packet, target);
    }
  }

  void _sendDirectPacket(Uint8List packet, InternetAddress target) {
    try {
      _socket?.send(packet, target, port);
    } catch (_) {}
  }

  /// Multi-send cerdas:
  /// 1. UNICAST langsung ke setiap HP Jamaah yang terdaftar (100% tembus Hotspot Android)
  /// 2. Subnet Broadcast (/24) ke semua interface jaringan
  /// 3. Multicast & Limited Broadcast sebagai pelengkap
  void _sendPacket(Uint8List packet) {
    if (_socket == null) return;

    // Kirim Unicast ke seluruh Jamaah terdaftar
    for (final client in _knownClients.values) {
      _sendDirectPacket(packet, client.address);
    }

    // Kirim ke seluruh subnet broadcast & gateway terdeteksi
    for (final target in _cachedTargets) {
      _sendDirectPacket(packet, target);
    }
  }

  Future<void> close() async {
    _heartbeatTimer?.cancel();
    _speechTimeoutTimer?.cancel();
    _presenceTimeoutTimer?.cancel();
    _pingTimer?.cancel();
    _cleanupTimer?.cancel();
    _socket?.close();
    _socket = null;
    _isLeaderSpeaking = false;
    _isLeaderOnline = false;
    _leaderAddress = null;
    _knownClients.clear();
  }
}
