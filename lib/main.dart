import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'firebase_options.dart';
import 'theme.dart';
import 'screens/splash_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/welcome_screen.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/home_screen.dart';
import 'screens/preference_setup_screen.dart';
import 'screens/trip_generation_screen.dart';
import 'screens/loading_screen.dart';
import 'screens/enhanced_map_screen_v2_functional.dart';
import 'screens/place_detail_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/trips_screen.dart';
import 'widgets/bottom_nav.dart';
import 'widgets/auth_required_dialog.dart';
import 'models/user_preferences.dart';
import 'models/itinerary.dart';
import 'services/auth_service.dart';
import 'services/guest_mode_service.dart';
import 'services/onboarding_service.dart';
import 'services/server_warmer.dart';
import 'services/feedback_service.dart';

void main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize Mapbox
  MapboxOptions.setAccessToken(
    'pk.eyJ1IjoiYWJyYWFtcmVmYWF0IiwiYSI6ImNtbG9rNnVkZjEybGszZ3M5bzZlYm1yZzUifQ.RssBN3uPfDb1Z5LWxycpsQ',
  );

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  // Start server warmer to prevent cold starts
  ServerWarmer.startWarming();

  // Deliver any feedback that was queued offline (fire-and-forget)
  FeedbackService().flushQueue();

  FlutterNativeSplash.remove();
  runApp(const NileQuestApp());
}

class NileQuestApp extends StatelessWidget {
  const NileQuestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nile Quest',
      theme: AppTheme.theme,
      debugShowCheckedModeBanner: false,
      home: const AppNavigator(),
    );
  }
}

enum AppScreen {
  splash,
  onboarding,
  welcome,
  login,
  home,
  preferences,
  tripGeneration,
  loading,
  itinerary,
  map,
  placeDetail,
  profile,
  myTrips,
}

class AppNavigator extends StatefulWidget {
  const AppNavigator({super.key});

  @override
  State<AppNavigator> createState() => _AppNavigatorState();
}

class _AppNavigatorState extends State<AppNavigator> {
  AppScreen _currentScreen = AppScreen.splash;
  BottomNavTab _activeTab = BottomNavTab.home;
  UserPreferences? _userPreferences;
  Itinerary? _generatedItinerary;
  // Backend id of the saved copy of the current trip; null until the first
  // save succeeds. Prevents duplicate auto-saves and lets edits update the
  // same backend document instead of creating new ones.
  String? _currentTripBackendId;
  int? _selectedDayIndex;
  bool _isHistoryView = false;
  int _preferenceInitialStep = 1;
  final AuthService _authService = AuthService();
  final GuestModeService _guestModeService = GuestModeService();
  final OnboardingService _onboardingService = OnboardingService();

  @override
  void initState() {
    super.initState();
    _checkAuthState();
  }

  Future<void> _checkAuthState() async {
    await Future.delayed(const Duration(milliseconds: 1500));

    // Check if user is signed in
    final currentUser = _authService.currentUser;
    if (currentUser != null) {
      // User is authenticated, go to home
      if (mounted) {
        setState(() {
          _currentScreen = AppScreen.home;
          _activeTab = BottomNavTab.home;
        });
      }
      return;
    }

    // Check if user has enabled guest mode
    final isGuest = await _guestModeService.isGuestMode();
    if (isGuest) {
      // User is in guest mode, go to home
      if (mounted) {
        setState(() {
          _currentScreen = AppScreen.home;
          _activeTab = BottomNavTab.home;
        });
      }
      return;
    }

    // Check if user has seen onboarding (first launch)
    final hasSeenOnboarding = await _onboardingService.hasSeenOnboarding();
    if (!hasSeenOnboarding) {
      if (mounted) {
        setState(() {
          _currentScreen = AppScreen.onboarding;
        });
      }
      return;
    }

    // No authentication, show welcome screen
    if (mounted) {
      setState(() {
        _currentScreen = AppScreen.welcome;
      });
    }
  }

  void _navigateToScreen(AppScreen screen) {
    setState(() {
      _currentScreen = screen;
    });
  }

  void _savePreferences(UserPreferences prefs) {
    setState(() {
      _userPreferences = prefs;
    });
  }

  void _saveItinerary(Itinerary itinerary) {
    setState(() {
      _generatedItinerary = itinerary;
    });
  }

  void _selectDay(int dayIndex) {
    setState(() {
      _selectedDayIndex = dayIndex;
    });
  }

  void _handleTabChange(BottomNavTab tab) {
    setState(() {
      _activeTab = tab;
      switch (tab) {
        case BottomNavTab.home:
          _currentScreen = AppScreen.home;
          break;
        case BottomNavTab.itinerary:
          _currentScreen = AppScreen.itinerary;
          break;
        case BottomNavTab.map:
          _currentScreen = AppScreen.map;
          break;
        case BottomNavTab.profile:
          _currentScreen = AppScreen.profile;
          break;
      }
    });
  }

  bool get _showBottomNav {
    return [
      AppScreen.home,
      AppScreen.itinerary,
      AppScreen.map,
      AppScreen.profile,
    ].contains(_currentScreen);
  }

  void _showAuthRequiredDialog() {
    showAuthRequiredSheet(
      context,
      onSignIn: () {
        Navigator.of(context).pop();
        _navigateToScreen(AppScreen.login);
      },
      onSignUp: () {
        Navigator.of(context).pop();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SignUpScreen(
              onBack: () => Navigator.pop(context),
              onSignUpSuccess: () async {
                final nav = Navigator.of(context);
                await _guestModeService.disableGuestMode();
                if (!mounted) return;
                nav.pop();
                setState(() {
                  _currentScreen = AppScreen.home;
                  _activeTab = BottomNavTab.home;
                });
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildCurrentScreen() {
    switch (_currentScreen) {
      case AppScreen.splash:
        return const SplashScreen();
      case AppScreen.onboarding:
        return OnboardingScreen(
          onDone: () => _navigateToScreen(AppScreen.welcome),
        );
      case AppScreen.welcome:
        return WelcomeScreen(
          onLogin: () => _navigateToScreen(AppScreen.login),
          onGuest: () async {
            // Enable guest mode
            await _guestModeService.enableGuestMode();
            setState(() {
              _currentScreen = AppScreen.home;
              _activeTab = BottomNavTab.home;
            });
          },
        );
      case AppScreen.login:
        return LoginScreen(
          onBack: () => _navigateToScreen(AppScreen.welcome),
          onLoginSuccess: () async {
            // Disable guest mode when user logs in
            await _guestModeService.disableGuestMode();
            setState(() {
              _currentScreen = AppScreen.home;
              _activeTab = BottomNavTab.home;
            });
          },
        );
      case AppScreen.home:
        final isAuthenticated = _authService.currentUser != null;
        return HomeScreen(
          isGuest: !isAuthenticated,
          onGenerateTrip: () async {
            final isGuest = await _guestModeService.isGuestMode();
            if (!isAuthenticated && isGuest) {
              _showAuthRequiredDialog();
            } else {
              setState(() => _preferenceInitialStep = 1);
              _navigateToScreen(AppScreen.preferences);
            }
          },
        );
      case AppScreen.preferences:
        return PreferenceSetupScreen(
          initialStep: _preferenceInitialStep,
          initialPreferences: _userPreferences,
          onComplete: (prefs) {
            _savePreferences(prefs);
            _navigateToScreen(AppScreen.tripGeneration);
          },
          onBack: () {
            setState(() {
              _currentScreen = AppScreen.home;
              _activeTab = BottomNavTab.home;
            });
          },
        );
      case AppScreen.tripGeneration:
        return TripGenerationScreen(
          preferences: _userPreferences!,
          onGenerate: (itinerary) {
            _isHistoryView = false;
            _currentTripBackendId = null;
            _saveItinerary(itinerary);
            _navigateToScreen(AppScreen.loading);
          },
          onBack: () {
            setState(() => _preferenceInitialStep = 6);
            _navigateToScreen(AppScreen.preferences);
          },
        );
      case AppScreen.loading:
        return LoadingScreen(
          onComplete: () {
            setState(() {
              _currentScreen = AppScreen.itinerary;
              _activeTab = BottomNavTab.itinerary;
            });
          },
        );
      case AppScreen.itinerary:
        return TripsScreen(
          currentItinerary: _generatedItinerary,
          currentPreferences: _userPreferences,
          isHistoryView: _isHistoryView,
          tripBackendId: _currentTripBackendId,
          onTripSaved: (id) {
            setState(() => _currentTripBackendId = id);
          },
          onItineraryChanged: (updated) {
            setState(() => _generatedItinerary = updated);
          },
          onPlaceClick: (dayIndex) {
            _selectDay(dayIndex);
            _navigateToScreen(AppScreen.placeDetail);
          },
          OnViewTrip: (itinerary, backendId) {
            _isHistoryView = true;
            _currentTripBackendId = backendId;
            _saveItinerary(itinerary);
            // Also need to set some dummy preferences so ItineraryScreen doesn't crash
            if (_userPreferences == null) {
              _userPreferences = UserPreferences(
                city: 'Saved Trip',
                durationDays: itinerary.totalDays,
                interests: [],
                pace: 'moderate',
                budgetTier: 'moderate',
              );
            }
          },
        );
      case AppScreen.map:
        return EnhancedMapScreenV2Functional(
          itinerary: _generatedItinerary,
          selectedDay: _selectedDayIndex,
        );
      case AppScreen.placeDetail:
        return PlaceDetailScreen(
          event: _selectedDayIndex != null && _generatedItinerary != null
              ? _generatedItinerary!.days[_selectedDayIndex]?.first
              : null,
          onBack: () => _navigateToScreen(AppScreen.itinerary),
        );
      case AppScreen.profile:
        return ProfileScreen(
          onSignOut: () async {
            // Clear guest mode and auth, then go to welcome screen
            await _guestModeService.clearGuestMode();
            setState(() {
              _currentScreen = AppScreen.welcome;
              _activeTab = BottomNavTab.home;
              _userPreferences = null;
              _generatedItinerary = null;
              _isHistoryView = false;
            });
          },
        );
      case AppScreen.myTrips:
        // This screen is now embedded in TripsScreen
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.1, 0),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              );
            },
            child: Container(
              key: ValueKey(_currentScreen),
              child: _buildCurrentScreen(),
            ),
          ),
          if (_showBottomNav)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: BottomNav(
                activeTab: _activeTab,
                onTabChange: _handleTabChange,
              ),
            ),
        ],
      ),
    );
  }
}
