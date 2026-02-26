import 'package:shared_preferences/shared_preferences.dart';

class GuestModeService {
  static const String _guestModeKey = 'is_guest_mode';

  // Check if user has chosen to continue as guest
  Future<bool> isGuestMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_guestModeKey) ?? false;
  }

  // Enable guest mode
  Future<void> enableGuestMode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_guestModeKey, true);
  }

  // Disable guest mode (when user signs in)
  Future<void> disableGuestMode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_guestModeKey);
  }

  // Clear all guest mode data
  Future<void> clearGuestMode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_guestModeKey);
  }
}
