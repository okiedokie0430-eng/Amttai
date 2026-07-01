import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/cart_provider.dart';
import 'providers/connectivity_provider.dart';
import 'providers/favorites_provider.dart';
import 'providers/payment_provider.dart';
import 'providers/recipe_provider.dart';
import 'providers/theme_provider.dart';
import 'services/appwrite_service.dart';
import 'services/push_notification_service.dart';
import 'services/recipe_audio_service.dart';
import 'services/recommendation_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  LicenseRegistry.addLicense(() async* {
    final license = await rootBundle.loadString(
      'assets/fonts/Montserrat-OFL.txt',
    );
    yield LicenseEntryWithLineBreaks(['Montserrat'], license);
  });

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Edge-to-edge + transparent system bars.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  AppwriteService.instance.init();
  RecipeAudioService().init(AppwriteService.instance.storage);

  // Initialize Native Recommendation Engine
  unawaited(RecommendationService.initEngine('default_user'));

  runApp(const AmttaiApp());

  // Never block first frame on push setup; initialize it asynchronously.
  unawaited(
    PushNotificationService.instance.ensureInitialized().catchError((error, _) {
      debugPrint('[Push] Startup init failed: $error');
    }),
  );
}

class AmttaiApp extends StatelessWidget {
  const AmttaiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => RecipeProvider()),
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => FavoritesProvider()),
        ChangeNotifierProvider(create: (_) => PaymentProvider()),
        ChangeNotifierProvider(create: (_) => ConnectivityProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (_, themeProvider, __) {
          return MaterialApp.router(
            title: 'Amttai',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: themeProvider.mode,
            routerConfig: AppRouter.router,
          );
        },
      ),
    );
  }
}
