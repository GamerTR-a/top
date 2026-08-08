import 'dart:async' show StreamSubscription, unawaited;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;
import 'screens/community_maze_screen.dart';
import 'screens/home_screen.dart';
import 'screens/calendar_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/leaderboard_screen.dart';
import 'screens/nev_plus_screen.dart';
import 'screens/login_screen.dart';
import 'theme/app_theme.dart';
import 'models/auth_user_model.dart';
import 'services/supabase_auth_service.dart';
import 'services/notification_service.dart';
import 'services/fcm_service.dart';
import 'services/socket_service.dart';
import 'config/app_config.dart';

import 'services/local_storage_service.dart';
import 'services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

SupabaseClient get supabase => Supabase.instance.client;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await LocalStorageService.getInstance();
  } catch (e) {
    debugPrint('LocalStorageService init error: $e');
  }

  try {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      anonKey: AppConfig.supabaseAnonKey,
    );
  } catch (e) {
    debugPrint('Supabase init error: $e');
  }

  await loadSavedTheme();
  try {
    unawaited(
      fcmService.initialize().catchError((e) => debugPrint('FCM init error: $e')),
    );
  } catch (_) {}

  runApp(const NevGencApp());
}

class NevGencApp extends StatelessWidget {
  const NevGencApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppTheme>(
      valueListenable: themeNotifier,
      builder: (context, theme, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'NevGenç',
          theme: theme.themeData,
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
    } catch (_) {}
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  void _onAuthStateChange(AuthState event) async {
    if (event.event == AuthChangeEvent.signedOut) {
      try { socketService.disconnect(); } catch (_) {}
      if (mounted) setState(() => _currentUser = null);
    } else if (event.event == AuthChangeEvent.signedIn) {
      final user = await SupabaseAuthService.getCurrentUser();
      if (mounted && user != null) {
        setState(() => _currentUser = user);
        try { socketService.connect(); } catch (_) {}
        try { unawaited(fcmService.registerTokenForCurrentUser()); } catch (_) {}
      }
    } else if (event.event == AuthChangeEvent.tokenRefreshed) {
      if (_currentUser != null) {
        try { unawaited(fcmService.registerTokenForCurrentUser()); } catch (_) {}
      }
    }
  }

  Future<void> _checkSession() async {
    AuthUser? user;
    try {
      user = await SupabaseAuthService.getCurrentUser();
    } catch (_) {}
    try {
      user ??= await AuthService.getCurrentUser();
    } catch (_) {}

    if (mounted) {
      setState(() {
        _currentUser = user;
        _checking = false;
      });
      if (_currentUser != null) {
        try { socketService.connect(); } catch (_) {}
        try { unawaited(fcmService.registerTokenForCurrentUser()); } catch (_) {}
      }
    }
  }

  void _onLogin(AuthUser user) {
    setState(() => _currentUser = user);
    socketService.connect();
    unawaited(fcmService.registerTokenForCurrentUser());
  }

  Future<void> _onLogout() async {
    // FCM token'ı Supabase'den sil — çift bildirim riskini önler
    if (kPushEnabled) {
      try {
        final token = await FirebaseMessaging.instance.getToken();
        if (token != null) {
          await Supabase.instance.client
              .from('fcm_tokens')
              .delete()
              .eq('token', token);
        }
      } catch (_) {}
    }
    socketService.disconnect();
    await SupabaseAuthService.logout();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('current_user_id');
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
    1 => const CommunityMazeScreen(),
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
    _pageCache = {0: HomeScreen(currentUser: widget.user)};
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
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildNavItem(
                      index: 0,
                      icon: Icons.home_rounded,
                      label: 'Anasayfa',
                      theme: theme,
                    ),
                    _buildNavItem(
                      index: 1,
                      icon: Icons.grid_view_rounded,
                      label: 'Topluluklar',
                      theme: theme,
                    ),
                    _buildNavItem(
                      index: 2,
                      icon: Icons.star_rounded,
                      label: 'NEV +',
                      theme: theme,
                    ),
                    _buildNavItem(
                      index: 3,
                      icon: Icons.edit_calendar_rounded,
                      label: 'Takvim',
                      theme: theme,
                    ),
                    _buildNavItem(
                      index: 4,
                      icon: Icons.person_rounded,
                      label: 'Profil',
                      theme: theme,
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
    bool customIcon = false,
    Widget? customWidget,
  }) {
    final isSelected = _currentIndex == index;
    final color = isSelected ? theme.primary : theme.textMuted;
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmall = screenWidth < 380;
    final isTablet = screenWidth >= 600;
    final iconSize = isSmall ? 20.0 : (isTablet ? 28.0 : 24.0);
    final labelFontSize = isSmall ? 8.0 : (isTablet ? 12.0 : 10.0);
    final hPad = isSmall ? 2.0 : (isTablet ? 12.0 : 4.0);
    final isNevPlus = index == 2;

    // Seçili ikon %15 daha büyük, seçilmemiş daha küçük
    final selectedIconSize = iconSize * 1.15;
    final unselectedIconSize = iconSize * 0.92;

    return GestureDetector(
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
                  width: iconSize * 1.6,
                  height: iconSize * 1.6,
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
                      width: iconSize * 1.2,
                      height: iconSize * 1.2,
                      fit: BoxFit.contain,
                      errorBuilder: (ctx, err, stack) => Icon(
                        Icons.add_rounded,
                        color: isSelected ? const Color(0xFFFFD700) : theme.textMuted,
                        size: iconSize * 1.2,
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
                  width: iconSize * 1.6,
                  height: iconSize * 1.6,
                  child: Center(
                    child: Icon(icon, color: color, size: iconSize),
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
              child: Text(label, overflow: TextOverflow.ellipsis, maxLines: 1),
            ),
          ],
        ),
      ),
    );
  }
}
