import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/db/app_database.dart';
import '../features/auth/auth_local_prefs.dart';
import '../features/auth/login_page.dart';
import '../features/auth/reset_password_page.dart';
import '../features/ledger/ledger_home.dart';
import '../services/app_log.dart';
import '../services/cloud_bill_sync_service.dart';
import '../ui/pet/pet_config.dart';
import '../ui/pet/pet_overlay.dart';
import 'theme.dart';

class MyApp extends StatefulWidget {
  final AppDatabase db;

  const MyApp({super.key, required this.db});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  static const _kDarkModePref = 'app_dark_mode';
  static const _kThemeStylePref = 'app_theme_style';
  static const _kThemeBgImagePref = 'app_theme_bg_image';
  static const _kThemeBgMistPref = 'app_theme_bg_mist';
  Locale _locale = const Locale('zh');
  bool _darkMode = false;
  AppThemeStyle _themeStyle = AppThemeStyle.indigo;
  String? _themeBgImagePath;
  double _themeBgMist = 0.35;
  ui.Image? _themeBgDecodedImage;
  Session? _session;
  bool _authReady = false;
  StreamSubscription<AuthState>? _authSub;
  bool _syncingAfterLogin = false;
  bool _inPasswordRecovery = false;

  @override
  void initState() {
    super.initState();
    PetConfig.I.load();
    unawaited(_initAuthSessionGate());
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((event) {
      if (!mounted) return;
      AppLog.i(
        'Auth',
        'Auth state changed: ${event.event.name}, hasSession=${event.session != null}',
      );
      if (event.event == AuthChangeEvent.passwordRecovery) {
        setState(() {
          _session = event.session;
          _authReady = true;
          _inPasswordRecovery = true;
        });
        AppLog.i('Auth', 'Password recovery flow entered');
        return;
      }
      setState(() {
        _session = event.session;
        _authReady = true;
      });
      if (event.event == AuthChangeEvent.signedOut) {
        setState(() => _inPasswordRecovery = false);
      }
      if (event.session != null &&
          (event.event == AuthChangeEvent.signedIn ||
              event.event == AuthChangeEvent.initialSession)) {
        unawaited(_syncAfterLogin());
      }
    });
    _loadThemePrefs();
  }

  Future<void> _initAuthSessionGate() async {
    final auth = Supabase.instance.client.auth;
    Session? session = auth.currentSession;
    AppLog.i(
      'Auth',
      'Initial session state: ${session == null ? 'signed_out' : 'signed_in'}',
    );
    if (session != null) {
      final keep = await AuthLocalPrefs.shouldKeepExistingSession();
      if (!keep) {
        await auth.signOut();
        session = null;
        AppLog.i('Auth', 'Auto login policy denied persisted session');
      }
    }
    if (!mounted) return;
    setState(() {
      _session = session;
      _authReady = true;
    });
  }

  Future<void> _syncAfterLogin() async {
    if (_syncingAfterLogin) return;
    if (Supabase.instance.client.auth.currentUser == null) return;
    _syncingAfterLogin = true;
    try {
      final svc = CloudBillSyncService(
        db: widget.db,
        client: Supabase.instance.client,
      );
      await svc.downloadFromCloudNow(reason: 'login');
    } catch (e, st) {
      AppLog.e('CloudSync', e, st);
    } finally {
      _syncingAfterLogin = false;
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _themeBgDecodedImage?.dispose();
    super.dispose();
  }

  void _toggleLocale() {
    setState(() {
      _locale = _locale.languageCode == 'zh'
          ? const Locale('en')
          : const Locale('zh');
    });
  }

  Future<void> _loadThemePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final dark = prefs.getBool(_kDarkModePref) ?? false;
    final style = appThemeStyleFromId(prefs.getString(_kThemeStylePref));
    final imagePath = prefs.getString(_kThemeBgImagePref);
    final mist = (prefs.getDouble(_kThemeBgMistPref) ?? 0.35).clamp(0.0, 1.0);
    final imageExists = imagePath != null && File(imagePath).existsSync();
    Uint8List? imageBytes;
    ui.Image? decoded;
    if (imageExists) {
      try {
        imageBytes = await File(imagePath).readAsBytes();
        decoded = await _decodeUiImage(imageBytes);
      } catch (_) {
        imageBytes = null;
        decoded = null;
      }
    }
    if (!mounted) return;
    _themeBgDecodedImage?.dispose();
    setState(() {
      _darkMode = dark;
      _themeStyle = style;
      _themeBgImagePath = imageExists ? imagePath : null;
      _themeBgMist = mist;
      _themeBgDecodedImage = decoded;
    });
  }

  Future<void> _toggleTheme() async {
    final next = !_darkMode;
    setState(() => _darkMode = next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kDarkModePref, next);
  }

  Future<void> _setThemeStyle(AppThemeStyle style) async {
    if (_themeStyle == style) return;
    setState(() => _themeStyle = style);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kThemeStylePref, appThemeStyleId(style));
  }

  Future<void> _setThemeBackgroundImagePath(String? path) async {
    final prevPath = _themeBgImagePath;
    final hasPath = path != null && path.isNotEmpty && File(path).existsSync();
    Uint8List? bytes;
    ui.Image? decoded;
    if (hasPath) {
      try {
        bytes = await File(path).readAsBytes();
        decoded = await _decodeUiImage(bytes);
      } catch (_) {
        bytes = null;
        decoded = null;
      }
    }
    _themeBgDecodedImage?.dispose();
    setState(() {
      _themeBgImagePath = hasPath ? path : null;
      _themeBgDecodedImage = decoded;
    });

    final prefs = await SharedPreferences.getInstance();
    if (path == null || path.isEmpty) {
      await prefs.remove(_kThemeBgImagePref);
    } else {
      await prefs.setString(_kThemeBgImagePref, path);
    }

    if (prevPath != null && prevPath != path) {
      try {
        final oldFile = File(prevPath);
        if (await oldFile.exists()) {
          await oldFile.delete();
        }
      } catch (_) {
        // Ignore failed cleanup; new path is already persisted.
      }
    }
  }

  Future<void> _setThemeBackgroundMist(double value) async {
    final next = value.clamp(0.0, 1.0);
    setState(() => _themeBgMist = next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kThemeBgMistPref, next);
  }

  Future<ui.Image?> _decodeUiImage(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  Widget _buildThemeBackdrop() {
    if (_themeBgDecodedImage == null) {
      return DecoratedBox(
        decoration: appBackdropDecoration(
          style: _themeStyle,
          isDarkMode: _darkMode,
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        RawImage(
          image: _themeBgDecodedImage,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.low,
        ),
        if (_themeBgMist > 0)
          ImageFiltered(
            imageFilter: ui.ImageFilter.blur(
              sigmaX: 12.0 * _themeBgMist,
              sigmaY: 12.0 * _themeBgMist,
            ),
            child: Container(color: Colors.transparent),
          ),
        if (_themeBgMist > 0)
          Container(color: Colors.white.withValues(alpha: 0.32 * _themeBgMist)),
        if (_themeBgMist > 0)
          Opacity(
            opacity: _themeBgMist,
            child: DecoratedBox(
              decoration: appImageOverlayDecoration(
                style: _themeStyle,
                isDarkMode: _darkMode,
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasCustomBg =
        _themeBgImagePath != null && _themeBgImagePath!.isNotEmpty;
    return MaterialApp(
      builder: (context, child) {
        return Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (_) => FocusManager.instance.primaryFocus?.unfocus(),
          child: Stack(
            children: [
              const Positioned.fill(child: ColoredBox(color: Colors.black)),
              Positioned.fill(child: _buildThemeBackdrop()),
              child ?? const SizedBox.shrink(),
              AnimatedBuilder(
                animation: PetConfig.I,
                builder: (context, child) => PetConfig.I.enabled
                    ? const PetOverlay()
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        );
      },
      debugShowCheckedModeBanner: false,
      title: 'Ledger',
      locale: _locale,
      supportedLocales: const [Locale('en'), Locale('zh')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: buildLightTheme(
        style: _themeStyle,
        hasCustomBackgroundImage: hasCustomBg,
        backgroundMist: _themeBgMist,
      ),
      darkTheme: buildDarkTheme(
        style: _themeStyle,
        hasCustomBackgroundImage: hasCustomBg,
        backgroundMist: _themeBgMist,
      ),
      themeMode: _darkMode ? ThemeMode.dark : ThemeMode.light,
      // Keep route animation short to reduce perceived overlap during rapid taps.
      themeAnimationDuration: const Duration(milliseconds: 120),
      home: !_authReady
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : _inPasswordRecovery
          ? ResetPasswordPage(
              onDone: () async {
                await Supabase.instance.client.auth.signOut();
                if (!mounted) return;
                setState(() => _inPasswordRecovery = false);
              },
            )
          : (_session == null
                ? LoginPage(locale: _locale, onToggleLocale: _toggleLocale)
                : LedgerHome(
                    db: widget.db,
                    onToggleLocale: _toggleLocale,
                    onToggleTheme: _toggleTheme,
                    isDarkMode: _darkMode,
                    themeStyle: _themeStyle,
                    onThemeStyleChanged: _setThemeStyle,
                    themeBackgroundImagePath: _themeBgImagePath,
                    onThemeBackgroundImageChanged: _setThemeBackgroundImagePath,
                    themeBackgroundMist: _themeBgMist,
                    onThemeBackgroundMistChanged: _setThemeBackgroundMist,
                  )),
    );
  }
}
