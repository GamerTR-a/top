import 'dart:async' show StreamSubscription, runZonedGuarded, unawaited;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;
import 'screens/community_maze_screen.dart';
import 'screens/home_screen.dart';
import 'screens/calendar_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/nev_plus_screen.dart';
import 'screens/login_screen.dart';
import 'screens/privacy_policy_screen.dart';
import 'theme/app_theme.dart';
import 'models/auth_user_model.dart';
import 'services/supabase_auth_service.dart';
import 'services/fcm_service.dart';
import 'services/local_notification_service.dart';
import 'services/socket_service.dart';
import 'services/secure_local_storage.dart';
import 'services/joined_communities_service.dart';
import 'config/app_config.dart';

import 'services/local_storage_service.dart';
import 'services/force_update_service.dart';
import 'services/connectivity_service.dart';
import 'widgets/offline_banner.dart';
import 'utils/navigation_service.dart';
import 'utils/timeout_http_client.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

SupabaseClient get supabase => Supabase.instance.client;

/// Üretimde yakalanmamış bir hatanın uygulamayı kullanıcı önünde çökertmesini
/// önlemek için Flutter'ın kırmızı hata ekranı yerine sade bir uyarı gösterir.
/// Bkz. güvenlik denetimi: "Global hata yönetimi eksik".
void _installErrorHandlers() {
  ErrorWidget.builder = (FlutterErrorDetails details) {
    if (kDebugMode) {
      return ErrorWidget(details.exception);
    }
    return Material(
      color: Colors.white,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.error_outline_rounded,
                    size: 40, color: Colors.black38),
                SizedBox(height: 12),
                Text(
                  'Bir şeyler ters gitti.\nLütfen uygulamayı yeniden başlatın.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black54),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  };

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('FlutterError yakalandı: ${details.exceptionAsString()}');
    try {
      FirebaseCrashlytics.instance.recordFlutterFatalError(details);
    } catch (_) {}
  };

  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    debugPrint('Yakalanmamış platform hatası: $error\n$stack');
    try {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    } catch (_) {}
    return true;
  };
}

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Crashlytics'in kullanıcı onayına (Ayarlar > Gizlilik) bağlı olabilmesi
    // için tercih deposu Firebase'den ÖNCE hazır olmalı (bkz. kontrol.md
    // Bölüm 12.6 — önceden onay sorulmadan otomatik başlıyordu).
    try {
      await LocalStorageService.getInstance();
    } catch (e) {
      debugPrint('LocalStorageService init error: $e');
    }
    final crashConsent =
        LocalStorageService.instance?.crashReportingEnabled ?? true;

    try {
      await Firebase.initializeApp();
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
        !kDebugMode && crashConsent,
      );
      // Aynı "çökme raporu" onayı performans izleme için de kullanılıyor —
      // ikisi de kullanıcı tarafından tek bir "tanılama verisi" anahtarıyla
      // yönetiliyor (bkz. kontrol.md Bölüm 32.3).
      await FirebasePerformance.instance.setPerformanceCollectionEnabled(
        !kDebugMode && crashConsent,
      );
    } catch (e) {
      debugPrint('Firebase/Crashlytics init error: $e');
    }

    _installErrorHandlers();

    // Android 15 Edge-to-Edge desteği (Deprecated Window renk parametreleri kaldırıldı)
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );

    try {
      await Supabase.initialize(
        url: AppConfig.supabaseUrl,
        anonKey: AppConfig.supabaseAnonKey,
        authOptions: FlutterAuthClientOptions(
          localStorage: SecureLocalStorage(),
          authFlowType: AuthFlowType.pkce,
        ),
        httpClient: TimeoutHttpClient(http.Client(), const Duration(seconds: 15)),
      );
    } catch (e) {
      debugPrint('Supabase init error: $e');
    }

    await loadSavedTheme();
    try {
      unawaited(
        fcmService
            .initialize()
            .catchError((e) => debugPrint('FCM init error: $e')),
      );
    } catch (_) {}

    try {
      unawaited(
        localNotificationService.initialize().catchError(
              (e) => debugPrint('Local notification init error: $e'),
            ),
      );
    } catch (_) {}

    ConnectivityService.instance.start();

    runApp(const NevGencApp());
  }, (error, stack) {
    debugPrint('Yakalanmamış zone hatası: $error\n$stack');
    try {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    } catch (_) {}
  });
}

class NevGencApp extends StatelessWidget {
  const NevGencApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppTheme>(
      valueListenable: themeNotifier,
      builder: (context, theme, _) {
        return MaterialApp(
          navigatorKey: navigatorKey,
          debugShowCheckedModeBanner: false,
          title: 'NevGenç',
          theme: theme.themeData,
          builder: (context, child) =>
              OfflineBanner(child: child ?? const SizedBox.shrink()),
          home: const AuthGate(),
        );
      },
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _checking = true;
  AuthUser? _currentUser;
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _checkSession();
    try {
      _authSubscription = supabase.auth.onAuthStateChange.listen(
        _onAuthStateChange,
        onError: (e) => debugPrint('Auth error: $e'),
      );
    } catch (e) {
      // Bu abonelik kurulamazsa uygulama hiçbir auth state değişikliğini
      // yakalayamaz (login/logout UI'da yansımaz) — sessizce yutmak yerine
      // en azından Crashlytics'e düşür.
      debugPrint('Auth state listener kurulamadı: $e');
      FirebaseCrashlytics.instance.recordError(e, StackTrace.current);
    }
    // Zorunlu güncelleme kontrolü — ilk frame çizildikten sonra (Navigator/
    // MaterialApp hazır olsun diye), sessizce başarısız olabilir (bkz.
    // kontrol.md Bölüm 31.6).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ForceUpdateService.checkAndPromptIfNeeded(context);
    });
    // Uygulama bir bildirime tıklanarak soğuk başlatıldıysa yönlendir
    // (bkz. kontrol.md Bölüm 25.4).
    unawaited(fcmService.checkInitialMessage());
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  void _onAuthStateChange(AuthState event) async {
    if (event.event == AuthChangeEvent.signedOut) {
      try {
        socketService.disconnect();
      } catch (_) {}
      if (mounted) setState(() => _currentUser = null);
    } else if (event.event == AuthChangeEvent.signedIn) {
      final user = await SupabaseAuthService.getCurrentUser();
      if (mounted && user != null) {
        setState(() => _currentUser = user);
        try {
          socketService.connect();
        } catch (_) {}
        try {
          unawaited(fcmService.registerTokenForCurrentUser());
        } catch (_) {}
        unawaited(JoinedCommunitiesService.instance.syncWithServer());
      }
    } else if (event.event == AuthChangeEvent.tokenRefreshed) {
      if (_currentUser != null) {
        try {
          unawaited(fcmService.registerTokenForCurrentUser());
        } catch (_) {}
      }
    }
  }

  Future<void> _checkSession() async {
    AuthUser? user;
    try {
      user = await SupabaseAuthService.getCurrentUser();
    } catch (e) {
      // Geçici bir ağ hatası burada kullanıcıyı sessizce "çıkış yapılmış"
      // gibi gösterebilir — davranışı değiştirmiyoruz (fail-closed doğru
      // varsayılan) ama en azından gözlemlenebilir olsun diye logluyoruz.
      debugPrint('Oturum kontrolü başarısız: $e');
    }

    if (mounted) {
      setState(() {
        _currentUser = user;
        _checking = false;
      });
      if (_currentUser != null) {
        try {
          socketService.connect();
        } catch (_) {}
        try {
          unawaited(fcmService.registerTokenForCurrentUser());
        } catch (_) {}
        unawaited(JoinedCommunitiesService.instance.syncWithServer());
      }
    }
  }

  void _onLogin(AuthUser user) {
    setState(() => _currentUser = user);
    socketService.connect();
    unawaited(fcmService.registerTokenForCurrentUser());
    unawaited(JoinedCommunitiesService.instance.syncWithServer());
  }

  Future<void> _onLogout() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    // FCM token'ı Supabase'den sil — çift bildirim riskini önler
    if (kPushEnabled) {
      try {
        final token = await FirebaseMessaging.instance.getToken();
        if (token != null && uid != null) {
          await Supabase.instance.client
              .from('fcm_tokens')
              .delete()
              .eq('token', token)
              .eq('user_id', uid);
        }
      } catch (_) {}
    }
    socketService.disconnect();
    await SupabaseAuthService.logout();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('current_user_id');
    } catch (_) {}
    // Paylaşılan cihazlarda önceki kullanıcının önbelleğinin bir sonraki
    // kullanıcıya sızmasını engelle (bkz. kontrol.md Bölüm 2.8).
    try {
      final store = await LocalStorageService.getInstance();
      await store.clearUserSessionCache(userId: uid);
    } catch (_) {}
    if (mounted) setState(() => _currentUser = null);
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      final theme = themeNotifier.value;
      return Scaffold(
        backgroundColor: theme.background,
        body: Center(child: CircularProgressIndicator(color: theme.primary)),
      );
    }
    if (_currentUser == null) {
      return LoginScreen(onLoginSuccess: _onLogin);
    }
    // Kullanım şartları (topluluk kuralları) onaylanmadan içerik gösterilmez
    // — App Store Kural 1.2.
    if (!(LocalStorageService.instance?.isPrivacyPolicyAccepted ?? false)) {
      return PrivacyPolicyScreen(
        isFirstTime: true,
        onAccepted: () {
          if (mounted) setState(() {});
        },
      );
    }
    return MainScaffold(user: _currentUser!, onLogout: _onLogout);
  }
}

class MainScaffold extends StatefulWidget {
  final AuthUser user;
  final Future<void> Function() onLogout;

  const MainScaffold({super.key, required this.user, required this.onLogout});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _currentIndex = 0;

  // Sayfa önbelleği — yalnızca ilk ziyarette oluşturulur
  late final Map<int, Widget> _pageCache;

  Widget _buildPage(int index) => switch (index) {
        0 => HomeScreen(currentUser: widget.user),
        1 => CommunityMazeScreen(currentUser: widget.user),
        2 => NevPlusScreen(user: widget.user),
        3 => const CalendarScreen(),
        4 => ProfileScreen(user: widget.user, onLogout: widget.onLogout),
        _ => const SizedBox.shrink(),
      };

  // Önbellekte varsa döndür, yoksa placeholder — gerçek widget ilk ziyarette oluşur
  Widget _getPage(int index) => _pageCache[index] ?? const SizedBox.shrink();

  @override
  void initState() {
    super.initState();
    // Yalnızca ana ekranı (index 0 - en baştaki Anasayfa) başlangıçta yükle
    _pageCache = {
      0: HomeScreen(currentUser: widget.user),
      1: CommunityMazeScreen(currentUser: widget.user)
    };
  }

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
      // İlk ziyarette sayfayı önbelleğe al
      _pageCache.putIfAbsent(index, () => _buildPage(index));
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppTheme>(
      valueListenable: themeNotifier,
      builder: (context, theme, _) {
        return Scaffold(
          body: IndexedStack(
            index: _currentIndex,
            children: [
              TickerMode(enabled: _currentIndex == 0, child: _getPage(0)),
              TickerMode(enabled: _currentIndex == 1, child: _getPage(1)),
              TickerMode(enabled: _currentIndex == 2, child: _getPage(2)),
              TickerMode(enabled: _currentIndex == 3, child: _getPage(3)),
              TickerMode(enabled: _currentIndex == 4, child: _getPage(4)),
            ],
          ),
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              color: theme.surface.withValues(alpha: 0.9),
              border: Border(
                top: BorderSide(
                  color: theme.primary.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: theme.primary.withValues(alpha: 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8.0,
                  vertical: 8.0,
                ),
                child: Row(
                  // Not: önceden spaceAround + shrink-wrap Container'lar
                  // kullanılıyordu — küçük ekranlarda dokunma alanı genişliği
                  // ~36dp'ye düşüyordu (min 44dp önerisinin altında, bkz.
                  // kontrol.md Bölüm 21.3). Expanded ile her öğe satırın
                  // 1/5'ini kaplıyor, tüm bu alan artık dokunulabilir.
                  children: [
                    Expanded(
                      child: _buildNavItem(
                        index: 0,
                        icon: Icons.home_rounded,
                        label: 'Anasayfa',
                        theme: theme,
                      ),
                    ),
                    Expanded(
                      child: _buildNavItem(
                        index: 1,
                        icon: Icons.grid_view_rounded,
                        label: 'Topluluklar',
                        theme: theme,
                      ),
                    ),
                    Expanded(
                      child: _buildNavItem(
                        index: 2,
                        icon: Icons.star_rounded,
                        label: 'NEV +',
                        theme: theme,
                      ),
                    ),
                    Expanded(
                      child: _buildNavItem(
                        index: 3,
                        icon: Icons.edit_calendar_rounded,
                        label: 'Takvim',
                        theme: theme,
                      ),
                    ),
                    Expanded(
                      child: _buildNavItem(
                        index: 4,
                        icon: Icons.person_rounded,
                        label: 'Profil',
                        theme: theme,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required String label,
    required AppTheme theme,
  }) {
    final isSelected = _currentIndex == index;
    final color = isSelected ? theme.primary : theme.textMuted;
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmall = screenWidth < 380;
    final isTablet = screenWidth >= 600;
    final baseIconSize = isSmall ? 20.0 : (isTablet ? 28.0 : 24.0);
    final labelFontSize = isSmall ? 8.0 : (isTablet ? 12.0 : 10.0);
    final hPad = isSmall ? 2.0 : (isTablet ? 12.0 : 4.0);
    final isNevPlus = index == 2;

    final effectiveIconSize =
        isSelected ? (baseIconSize * 1.15) : (baseIconSize * 0.92);

    return Semantics(
      label: label,
      selected: isSelected,
      button: true,
      child: GestureDetector(
        onTap: () => _onTabTapped(index),
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (isNevPlus)
                AnimatedScale(
                  scale: isSelected ? 1.15 : 0.92,
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutBack,
                  child: Container(
                    width: baseIconSize * 1.6,
                    height: baseIconSize * 1.6,
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.transparent,
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFFFFD700)
                            : theme.textMuted,
                        width: isSelected ? 2.2 : 1.5,
                      ),
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/nev_plus_logo.png',
                        width: baseIconSize * 1.2,
                        height: baseIconSize * 1.2,
                        fit: BoxFit.contain,
                        errorBuilder: (ctx, err, stack) => Icon(
                          Icons.add_rounded,
                          color: isSelected
                              ? const Color(0xFFFFD700)
                              : theme.textMuted,
                          size: baseIconSize * 1.2,
                        ),
                      ),
                    ),
                  ),
                )
              else
                AnimatedScale(
                  scale: isSelected ? 1.15 : 0.92,
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutBack,
                  child: SizedBox(
                    width: baseIconSize * 1.6,
                    height: baseIconSize * 1.6,
                    child: Center(
                      child: Icon(icon, color: color, size: effectiveIconSize),
                    ),
                  ),
                ),
              const SizedBox(height: 4),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  color: isNevPlus
                      ? (isSelected ? const Color(0xFFFFD700) : theme.textMuted)
                      : color,
                  fontSize: labelFontSize,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                ),
                child:
                    Text(label, overflow: TextOverflow.ellipsis, maxLines: 1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
