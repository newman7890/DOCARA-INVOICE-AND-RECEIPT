import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'providers/invoice_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/auth_provider.dart';
import 'theme/app_theme.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'screens/auth/reset_password_screen.dart';

import 'config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProxyProvider<AuthProvider, SettingsProvider>(
          create: (_) => SettingsProvider(),
          update: (ctx, auth, settings) => settings!
            ..updateBusinessConfig(auth.businessId),
        ),
        ChangeNotifierProxyProvider<AuthProvider, InvoiceProvider>(
          create: (_) => InvoiceProvider(),
          update: (ctx, auth, invoice) => invoice!
            ..updateBusinessConfig(
              auth.businessId,
              ctx.read<SettingsProvider>().stationName,
            ),
        ),
      ],
      child: const DocaraApp(),
    ),
  );
}

class DocaraApp extends StatefulWidget {
  const DocaraApp({super.key});

  @override
  State<DocaraApp> createState() => _DocaraAppState();
}

class _DocaraAppState extends State<DocaraApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    // Listen for password recovery events to trigger redirect
    auth.addListener(_handleAuthChanges);
    
    // Check if we are already in recovery mode on start
    if (auth.isRecoveringPassword) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _handleAuthChanges());
    }
  }

  @override
  void dispose() {
    context.read<AuthProvider>().removeListener(_handleAuthChanges);
    super.dispose();
  }

  void _handleAuthChanges() {
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    if (auth.isRecoveringPassword) {
      debugPrint('Redirecting to Reset Password Screen...');
      _navigatorKey.currentState?.pushNamedAndRemoveUntil('/reset-password', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'Docara Invoice & Receipt',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: settings.themeMode,
      initialRoute: '/login',
      routes: {
        '/login': (_) => const LoginScreen(),
        '/home': (_) => const HomeScreen(),
        '/signup': (_) => const SignupScreen(),
        '/reset-password': (_) => const ResetPasswordScreen(),
      },
    );
  }
}
