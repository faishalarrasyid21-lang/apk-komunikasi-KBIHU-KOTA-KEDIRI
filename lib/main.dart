import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/role_selection_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const HajjWalkieTalkieApp());
}

class HajjWalkieTalkieApp extends StatelessWidget {
  const HajjWalkieTalkieApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KBIHU NU KOTA KEDIRI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0D5C3A),
          primary: const Color(0xFF0D5C3A),
        ),
        scaffoldBackgroundColor: const Color(0xFFF7F9F8),
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
        ),
      ),
      home: const RoleSelectionScreen(),
    );
  }
}
