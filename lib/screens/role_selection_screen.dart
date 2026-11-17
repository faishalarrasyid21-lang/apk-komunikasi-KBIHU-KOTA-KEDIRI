import 'package:flutter/material.dart';
import '../models/app_mode.dart';
import 'leader_screen.dart';
import 'listener_screen.dart';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  final TextEditingController _pinController = TextEditingController();
  final TextEditingController _roomIdController =
      TextEditingController(text: 'KLOTER-01');
  static const List<String> _validPasswords = ["9988", "2026", "haji2026"];

  AppMode _appMode = AppMode.offline;

  void _showPinDialog() {
    _pinController.clear();
    bool obscureText = true;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.security, color: Color(0xFF0D5C3A)),
                  SizedBox(width: 8),
                  Text(
                    'Akses Ketua / Pembimbing',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Masukkan Password / PIN khusus Ketua Rombongan:',
                    style: TextStyle(fontSize: 13, color: Colors.black87),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _pinController,
                    keyboardType: TextInputType.text,
                    obscureText: obscureText,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      letterSpacing: 4,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: InputDecoration(
                      hintText: '••••••',
                      counterText: '',
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscureText
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: Colors.grey.shade600,
                          size: 20,
                        ),
                        onPressed: () {
                          setDialogState(() {
                            obscureText = !obscureText;
                          });
                        },
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: Color(0xFF0D5C3A), width: 2),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child:
                      const Text('Batal', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D5C3A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    final enteredText = _pinController.text.trim();
                    if (_validPasswords.contains(enteredText)) {
                      Navigator.pop(context);
                      final roomId = _roomIdController.text.trim().isEmpty
                          ? 'KLOTER-01'
                          : _roomIdController.text.trim();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => LeaderScreen(
                            appMode: _appMode,
                            roomId: roomId,
                          ),
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Password / PIN Salah! Akses ditolak.'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                  child: const Text('Masuk'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isOnline = _appMode == AppMode.online;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9F8),
      body: SafeArea(
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              // Logo & App Header
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D5C3A),
                    shape: BoxShape.circle,
                    image: const DecorationImage(
                      image: AssetImage('assets/logo.jpg'),
                      fit: BoxFit.cover,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0D5C3A).withValues(alpha: 0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'KBIHU NU KOTA KEDIRI',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0D5C3A),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Walkie-Talkie & Bimbingan Doa Haji/Umrah',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13, color: Colors.black54, height: 1.4),
              ),
              const SizedBox(height: 20),

              // ── Toggle Mode Jaringan ─────────────────────────────────────
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _appMode = AppMode.offline),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: !isOnline
                                ? const Color(0xFF0D5C3A)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.wifi_tethering,
                                size: 16,
                                color: !isOnline
                                    ? Colors.white
                                    : Colors.black54,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Wi-Fi / Hotspot',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: !isOnline
                                      ? Colors.white
                                      : Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _appMode = AppMode.online),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: isOnline
                                ? const Color(0xFF1565C0)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.cell_tower,
                                size: 16,
                                color: isOnline ? Colors.white : Colors.black54,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Data Seluler',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: isOnline ? Colors.white : Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Info banner berdasarkan mode
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: isOnline
                    ? _buildOnlineBanner()
                    : _buildOfflineBanner(),
              ),

              // Jika online: TextField roomId (Kode Rombongan)
              if (isOnline) ...[
                const SizedBox(height: 10),
                TextField(
                  controller: _roomIdController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    labelText: 'Kode Rombongan',
                    hintText: 'cth: KLOTER-01',
                    prefixIcon:
                        const Icon(Icons.group, color: Color(0xFF1565C0)),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: Color(0xFF1565C0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: Color(0xFF1565C0), width: 2),
                    ),
                    helperText:
                        'Semua anggota rombongan harus pakai kode yang sama',
                    helperStyle: const TextStyle(fontSize: 11),
                  ),
                ),
              ],

              const Spacer(),

              // Pilihan 1: Masuk sebagai Jamaah
              InkWell(
                onTap: () {
                  final roomId = _roomIdController.text.trim().isEmpty
                      ? 'KLOTER-01'
                      : _roomIdController.text.trim();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ListenerScreen(
                        appMode: _appMode,
                        roomId: roomId,
                      ),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      vertical: 20, horizontal: 20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isOnline
                          ? [
                              const Color(0xFF1565C0),
                              const Color(0xFF1E88E5)
                            ]
                          : [
                              const Color(0xFF0D5C3A),
                              const Color(0xFF198754)
                            ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: (isOnline
                                ? const Color(0xFF1565C0)
                                : const Color(0xFF0D5C3A))
                            .withValues(alpha: 0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: const BoxDecoration(
                          color: Colors.white24,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.headphones_rounded,
                            color: Colors.white, size: 32),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Masuk sebagai Jamaah',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Dengarkan suara ketua & bacaan doa',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios_rounded,
                          color: Colors.white70, size: 18),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Pilihan 2: Masuk sebagai Ketua / Pembimbing
              InkWell(
                onTap: _showPinDialog,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      vertical: 18, horizontal: 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade300),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: const BoxDecoration(
                          color: Color(0xFFF1F8E9),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.mic_rounded,
                            color: Color(0xFF0D5C3A), size: 28),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Masuk sebagai Ketua / Pembimbing',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Siarkan suara & atur tahapan rukun (Perlu PIN)',
                              style: TextStyle(
                                  fontSize: 11, color: Colors.black54),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.lock_outline_rounded,
                          color: Colors.black38, size: 18),
                    ],
                  ),
                ),
              ),

              const Spacer(),

              const Center(
                child: Text(
                  'Versi 1.0.0 • KBIHU NU Kota Kediri',
                  style: TextStyle(fontSize: 11, color: Colors.black38),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOfflineBanner() {
    return Container(
      key: const ValueKey('offline'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFA5D6A7)),
      ),
      child: const Row(
        children: [
          Icon(Icons.wifi_tethering, color: Color(0xFF2E7D32), size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Mode Wi-Fi: Pastikan semua HP terhubung ke Hotspot / Wi-Fi yang sama. Tidak perlu internet.',
              style: TextStyle(
                  fontSize: 11,
                  color: Color(0xFF1B5E20),
                  fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOnlineBanner() {
    return Container(
      key: const ValueKey('online'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFE3F2FD),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF90CAF9)),
      ),
      child: const Row(
        children: [
          Icon(Icons.cell_tower, color: Color(0xFF1565C0), size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Mode Data Seluler: Semua HP cukup punya koneksi internet (4G/5G). Jangkauan tanpa batas.',
              style: TextStyle(
                  fontSize: 11,
                  color: Color(0xFF0D47A1),
                  fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
