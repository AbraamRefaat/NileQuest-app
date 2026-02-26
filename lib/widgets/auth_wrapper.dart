import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../models/user.dart';

/// A widget that wraps content and provides authentication state
/// 
/// Usage:
/// ```dart
/// AuthWrapper(
///   onSignedIn: (user) => MainScreen(user: user),
///   onSignedOut: () => LoginScreen(),
/// )
/// ```
class AuthWrapper extends StatelessWidget {
  final Widget Function(AppUser user) onSignedIn;
  final Widget Function() onSignedOut;
  final Widget? loading;

  const AuthWrapper({
    super.key,
    required this.onSignedIn,
    required this.onSignedOut,
    this.loading,
  });

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();

    return StreamBuilder<AppUser?>(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        // Show loading while checking auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return loading ??
              const Scaffold(
                body: Center(
                  child: CircularProgressIndicator(),
                ),
              );
        }

        // Check if user is signed in
        final user = snapshot.data;

        if (user != null) {
          return onSignedIn(user);
        } else {
          return onSignedOut();
        }
      },
    );
  }
}

/// A simple auth guard that redirects to login if not authenticated
class AuthGuard extends StatelessWidget {
  final Widget child;
  final Widget Function()? onSignedOut;

  const AuthGuard({
    super.key,
    required this.child,
    this.onSignedOut,
  });

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();

    return StreamBuilder<AppUser?>(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        final user = snapshot.data;

        if (user != null) {
          return child;
        } else {
          // User is not signed in
          if (onSignedOut != null) {
            return onSignedOut!();
          }
          
          // Default: show message
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.lock_outline,
                    size: 80,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Please sign in to access this page',
                    style: TextStyle(fontSize: 16),
                  ),
                ],
              ),
            ),
          );
        }
      },
    );
  }
}
