import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:provider/provider.dart';

import 'providers/poultry_provider.dart';
import 'screens/dashboard_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const PoultryInventoryApp());
}

class PoultryInventoryApp extends StatelessWidget {
  const PoultryInventoryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => PoultryProvider(),
      child: MaterialApp(
        title: 'Poultry Inventory',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.cyan),
          useMaterial3: true,
          brightness: Brightness.light,
          appBarTheme: AppBarTheme(
            backgroundColor: Colors.transparent,
            elevation: 0,
            centerTitle: true,
            titleTextStyle: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.cyan.shade400,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              textStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          floatingActionButtonTheme: FloatingActionButtonThemeData(
            backgroundColor: Colors.cyan.shade400,
            foregroundColor: Colors.white,
          ),
        ),
        home: DashboardScreen(),
      ),
    );
  }
}
