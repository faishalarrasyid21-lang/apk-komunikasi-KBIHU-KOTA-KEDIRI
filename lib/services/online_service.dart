import 'dart:async';
import 'dart:typed_data';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

/// OnlineService — Komunikasi via MQTT over WebSocket (internet/data seluler)
///
/// Gunakan HiveMQ publik: wss://broker.hivemq.com:8884/mqtt
/// Topic format:
///   kbihu/{roomId}/audio      — stream audio PCM
///   kbihu/{roomId}/stage      — perubahan tahapan ibadah
///   kbihu/{roomId}/heartbeat  — detak jantung Ketua
class OnlineService {
  static const String _brokerUrl = 'wss://broker.hivemq.com:8884/mqtt';

  String _roomId = 'KLOTER-01';
  bool _isLeader = false;

  WebSocketChannel? _channel;
  StreamSubscription? _wsSub;
  Timer? _reconnectTimer;
  Timer? _heartbeatTimer;
  Timer? _pingTimer;
  Timer? _speechPauseTimer;

  bool _isConnected = false;
  bool _disposed = false;

  // Sequence ID untuk deduplikasi paket online
  int _audioSeq = 0;
  int _lastAudioSeq = -1;

  // Stream Controllers
  final _audioController = StreamController<Uint8List>.broadcast();
  final _stageController = StreamController<String>.broadcast();
  final _heartbeatController = StreamController<bool>.broadcast();
  final _connectedController = StreamController<bool>.broadcast();

  Stream<Uint8List> get onAudioReceived => _audioController.stream;
  Stream<String> get onStageReceived => _stageController.stream;
  Stream<bool> get onHeartbeat => _heartbeatController.stream;
  Stream<bool> get onConnected => _connectedController.stream;

  bool get isConnected => _isConnected;

  String get _topicAudio => 'kbihu/$_roomId/audio';
  String get _topicStage => 'kbihu/$_roomId/stage';
  String get _topicHeartbeat => 'kbihu/$_roomId/heartbeat';

  // ── MQTT Packet Builders ───────────────────────────────────────────────────

  /// MQTT CONNECT packet (simple, no auth, clean session)
  Uint8List _buildConnect() {
    final clientId = 'kbihu_${DateTime.now().millisecondsSinceEpoch}';
    final clientIdBytes = utf8.encode(clientId);

    // Variable header: Protocol Name (MQTT), Level (4), Flags, KeepAlive
    final variableHeader = <int>[
      0, 4, 77, 81, 84, 84, // "MQTT"
      4,          // Protocol Level = 4 (MQTT 3.1.1)
      2,          // Connect Flags: CleanSession = 1
      0, 60,      // Keep-Alive = 60 seconds
    ];

    // Payload: Client ID
    final payload = <int>[
      (clientIdBytes.length >> 8) & 0xFF,
      clientIdBytes.length & 0xFF,
      ...clientIdBytes,
    ];

    final remaining = [...variableHeader, ...payload];
    return Uint8List.fromList([
      0x10, // CONNECT packet type
      remaining.length,
      ...remaining,
    ]);
  }

  /// MQTT SUBSCRIBE packet untuk satu topic
  Uint8List _buildSubscribe(String topic, int packetId) {
    final topicBytes = utf8.encode(topic);
    final payload = <int>[
      (topicBytes.length >> 8) & 0xFF,
      topicBytes.length & 0xFF,
      ...topicBytes,
      0, // QoS 0
    ];
    final variableHeader = [(packetId >> 8) & 0xFF, packetId & 0xFF];
    final remaining = [...variableHeader, ...payload];
    return Uint8List.fromList([
      0x82, // SUBSCRIBE packet type
      remaining.length,
      ...remaining,
    ]);
  }

  /// MQTT PUBLISH packet (QoS 0, no packet ID)
  Uint8List _buildPublish(String topic, Uint8List payload) {
    final topicBytes = utf8.encode(topic);
    final variableHeader = <int>[
      (topicBytes.length >> 8) & 0xFF,
      topicBytes.length & 0xFF,
      ...topicBytes,
    ];
    final remaining = [...variableHeader, ...payload];

    // Encode remaining length (variable-length encoding)
    final lenBytes = <int>[];
    var len = remaining.length;
    do {
      var byte = len % 128;
      len ~/= 128;
      if (len > 0) byte |= 0x80;
      lenBytes.add(byte);
    } while (len > 0);

    return Uint8List.fromList([
      0x30, // PUBLISH, QoS 0, no retain
      ...lenBytes,
      ...remaining,
    ]);
  }

  /// MQTT PINGREQ
  Uint8List _buildPingReq() => Uint8List.fromList([0xC0, 0x00]);

  // ── Koneksi ────────────────────────────────────────────────────────────────

  Future<void> connect({required String roomId, required bool isLeader}) async {
    _roomId = roomId;
    _isLeader = isLeader;
    _disposed = false;
    await _doConnect();
  }

  Future<void> _doConnect() async {
    if (_disposed) return;

    _channel?.sink.close();
    _wsSub?.cancel();

    try {
      _channel = WebSocketChannel.connect(Uri.parse(_brokerUrl));
      await _channel!.ready;

      _wsSub = _channel!.stream.listen(
        _onData,
        onDone: _onDisconnected,
        onError: (_) => _onDisconnected(),
        cancelOnError: true,
      );

      // Kirim CONNECT
      _channel!.sink.add(_buildConnect());

      // Kirim PINGREQ setiap 30 detik untuk menjaga koneksi
      _pingTimer?.cancel();
      _pingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        _send(_buildPingReq());
      });

      _isConnected = true;
      _connectedController.add(true);

      // Subscribe topik yang relevan
      if (_isLeader) {
        // Ketua tidak perlu subscribe audio (dia yang kirim)
        _send(_buildSubscribe(_topicHeartbeat, 1));
      } else {
        _send(_buildSubscribe(_topicAudio, 1));
        _send(_buildSubscribe(_topicStage, 2));
        _send(_buildSubscribe(_topicHeartbeat, 3));
      }

      // Ketua: kirim heartbeat tiap 2 detik
      if (_isLeader) {
        _heartbeatTimer?.cancel();
        _heartbeatTimer = Timer.periodic(const Duration(seconds: 2), (_) {
          _publishHeartbeat();
        });
      }

      _reconnectTimer?.cancel();
    } catch (_) {
      _onDisconnected();
    }
  }

  void _onDisconnected() {
    if (_disposed) return;
    _isConnected = false;
    _connectedController.add(false);
    _heartbeatTimer?.cancel();
    _pingTimer?.cancel();
    _speechPauseTimer?.cancel();

    // Auto-reconnect setelah 5 detik
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), _doConnect);
  }

  void _send(Uint8List data) {
    try {
      _channel?.sink.add(data);
    } catch (_) {}
  }

  // ── Parsing MQTT ───────────────────────────────────────────────────────────

  void _onData(dynamic raw) {
    Uint8List data;
    if (raw is Uint8List) {
      data = raw;
    } else if (raw is List<int>) {
      data = Uint8List.fromList(raw);
    } else {
      return;
    }

    if (data.isEmpty) return;

    final type = (data[0] >> 4) & 0xF;

    switch (type) {
      case 2: // CONNACK
        // Connected OK — subscribe sudah dilakukan saat connect
        break;

      case 3: // PUBLISH
        _parsePublish(data);
        break;

      case 13: // PINGRESP
        break;
    }
  }

  void _parsePublish(Uint8List data) {
    try {
      // Decode remaining length
      int index = 1;
      // Skip remaining-length bytes
      while (index < data.length) {
        final byte = data[index++];
        if ((byte & 128) == 0) break;
      }
      if (index >= data.length) return;

      // Topic length
      final topicLen = (data[index] << 8) | data[index + 1];
      index += 2;
      if (index + topicLen > data.length) return;
      final topic = utf8.decode(data.sublist(index, index + topicLen));
      index += topicLen;

      // Payload
      final payload = data.sublist(index);

      _handleMessage(topic, payload);
    } catch (_) {}
  }

  void _handleMessage(String topic, Uint8List payload) {
    if (topic == _topicAudio) {
      if (payload.length < 2) return;
      final seq = (payload[0] << 8) | payload[1];

      // Deduplikasi
      if (_lastAudioSeq >= 0) {
        final diff = seq - _lastAudioSeq;
        if (diff <= 0 && diff > -1000) return;
      }
      _lastAudioSeq = seq;
      _speechPauseTimer?.cancel();
      _speechPauseTimer = Timer(const Duration(milliseconds: 500), () {
        _lastAudioSeq = -1;
      });

      final pcm = payload.sublist(2);
      if (pcm.isNotEmpty) _audioController.add(pcm);
    } else if (topic == _topicStage) {
      final json = utf8.decode(payload);
      _stageController.add(json);
    } else if (topic == _topicHeartbeat) {
      _heartbeatController.add(true);
    }
  }

  // ── Publish ────────────────────────────────────────────────────────────────

  void sendAudioChunk(Uint8List audioBytes) {
    if (!_isConnected || audioBytes.isEmpty) return;
    _audioSeq = (_audioSeq + 1) & 0xFFFF;

    final packet = Uint8List(2 + audioBytes.length);
    packet[0] = (_audioSeq >> 8) & 0xFF;
    packet[1] = _audioSeq & 0xFF;
    packet.setRange(2, packet.length, audioBytes);

    _send(_buildPublish(_topicAudio, packet));
  }

  void sendStage(String stageJson) {
    if (!_isConnected) return;
    _send(_buildPublish(_topicStage, Uint8List.fromList(utf8.encode(stageJson))));
  }

  void _publishHeartbeat() {
    if (!_isConnected) return;
    _send(_buildPublish(_topicHeartbeat, Uint8List.fromList([1])));
  }

  // ── Dispose ────────────────────────────────────────────────────────────────

  Future<void> close() async {
    _disposed = true;
    _reconnectTimer?.cancel();
    _heartbeatTimer?.cancel();
    _pingTimer?.cancel();
    _speechPauseTimer?.cancel();
    _wsSub?.cancel();
    await _channel?.sink.close();
    _isConnected = false;
    _lastAudioSeq = -1;
    _audioSeq = 0;
  }
}
