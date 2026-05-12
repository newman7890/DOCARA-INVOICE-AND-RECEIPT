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
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
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

class DocaraApp extends StatelessWidget {
  const DocaraApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return MaterialApp(
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
      },
    );
  }
}
