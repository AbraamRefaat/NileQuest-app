import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme.dart';
import '../services/auth_service.dart';
import '../services/guest_mode_service.dart';
import '../models/user.dart';

class ProfileScreen extends StatefulWidget {
  final VoidCallback onSignOut;


  const ProfileScreen({
    super.key,
    required this.onSignOut,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _authService = AuthService();
  final _guestModeService = GuestModeService();
  bool _isLoading = false;

  Future<void> _handleSignOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);

    try {
      await _authService.signOut();
      await _guestModeService.clearGuestMode();
      if (!mounted) return;
      widget.onSignOut();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleSendVerificationEmail() async {
    try {
      await _authService.sendEmailVerification();
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Verification email sent! Please check your inbox.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: StreamBuilder<AppUser?>(
          stream: _authService.authStateChanges,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final user = snapshot.data;

            if (user == null) {
              // Guest mode UI
              return SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),
                      
                      // Title
                      Text(
                        'Profile',
                        style: Theme.of(context).textTheme.displayMedium,
                      ),
                      
                      const SizedBox(height: 40),
                      
                      // Guest Card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            // Avatar
                            CircleAvatar(
                              radius: 50,
                              backgroundColor: AppColors.secondary.withValues(alpha: 0.2),
                              child: const Icon(
                                Icons.person_outline,
                                size: 50,
                                color: AppColors.secondary,
                              ),
                            ),
                            
                            const SizedBox(height: 16),
                            
                            // Name
                            Text(
                              'Guest User',
                              style: Theme.of(context).textTheme.headlineSmall,
                              textAlign: TextAlign.center,
                            ),
                            
                            const SizedBox(height: 8),
                            
                            // Description
                            Text(
                              'Sign in to save your trips and preferences',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AppColors.charcoal.withValues(alpha: 0.6),
                                  ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Benefits section
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.1),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.star_rounded,
                                  color: AppColors.accent,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Sign in to unlock:',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _buildBenefitItem('Save your favorite trips'),
                            _buildBenefitItem('Sync across devices'),
                            _buildBenefitItem('Personalized recommendations'),
                            _buildBenefitItem('Access trip history'),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 32),
                      
                      // Emergency Section
                      Text(
                        'Emergency (Egypt)',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      _buildEmergencyCard(
                        icon: Icons.local_police_outlined,
                        title: 'Egyptian Police Hotline',
                        number: '122',
                        iconColor: AppColors.primary,
                      ),
                      
                      const SizedBox(height: 12),
                      
                      _buildEmergencyCard(
                        icon: Icons.shield_outlined,
                        title: 'Egyptian Tourist Police',
                        number: '126',
                        iconColor: AppColors.secondary,
                      ),
                      
                      const SizedBox(height: 12),
                      
                      _buildEmergencyCard(
                        icon: Icons.medical_services_outlined,
                        title: 'Egyptian Ambulance Service',
                        number: '123',
                        iconColor: AppColors.accent,
                      ),
                      
                      const SizedBox(height: 32),
                      
                      // Sign Out Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleSignOut,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Text(
                                  'Exit Guest Mode',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                      
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              );
            }

            return SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    
                    // Title
                    Text(
                      'Profile',
                      style: Theme.of(context).textTheme.displayMedium,
                    ),
                    
                    const SizedBox(height: 40),
                    
                    // Profile Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Avatar
                          CircleAvatar(
                            radius: 50,
                            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                            backgroundImage: user.photoURL != null
                                ? NetworkImage(user.photoURL!)
                                : null,
                            child: user.photoURL == null
                                ? Text(
                                    user.displayName?.isNotEmpty == true
                                        ? user.displayName![0].toUpperCase()
                                        : user.email?.isNotEmpty == true
                                            ? user.email![0].toUpperCase()
                                            : '?',
                                    style: const TextStyle(
                                      fontSize: 40,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                    ),
                                  )
                                : null,
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // Name
                          Text(
                            user.displayName ?? 'User',
                            style: Theme.of(context).textTheme.headlineSmall,
                            textAlign: TextAlign.center,
                          ),
                          
                          const SizedBox(height: 8),
                          
                          // Email
                          Text(
                            user.email ?? 'No email',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: AppColors.charcoal.withValues(alpha: 0.6),
                                ),
                            textAlign: TextAlign.center,
                          ),
                          
                          // Email Verification Status
                          if (!user.isEmailVerified && user.email != null) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.warning_amber_rounded,
                                    size: 16,
                                    color: Colors.orange[700],
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Email not verified',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.orange[700],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: _handleSendVerificationEmail,
                              child: const Text('Send Verification Email'),
                            ),
                          ],
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 32),
                    
                    const SizedBox(height: 32),
                    
                    // Account Info
                    Text(
                      'Account Information',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    _buildInfoCard(
                      icon: Icons.person_outline,
                      title: 'Display Name',
                      value: user.displayName ?? 'Not set',
                    ),
                    
                    const SizedBox(height: 12),
                    
                    _buildInfoCard(
                      icon: Icons.email_outlined,
                      title: 'Email',
                      value: user.email ?? 'Not set',
                    ),
                    
                    const SizedBox(height: 12),
                    
                    _buildInfoCard(
                      icon: Icons.calendar_today_outlined,
                      title: 'Member Since',
                      value: user.createdAt != null
                          ? '${user.createdAt!.day}/${user.createdAt!.month}/${user.createdAt!.year}'
                          : 'Unknown',
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Emergency Section
                    Text(
                      'Emergency (Egypt)',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    _buildEmergencyCard(
                      icon: Icons.local_police_outlined,
                      title: 'Egyptian Police Hotline',
                      number: '122',
                      iconColor: AppColors.primary,
                    ),
                    
                    const SizedBox(height: 12),
                    
                    _buildEmergencyCard(
                      icon: Icons.shield_outlined,
                      title: 'Egyptian Tourist Police',
                      number: '126',
                      iconColor: AppColors.secondary,
                    ),
                    
                    const SizedBox(height: 12),
                    
                    _buildEmergencyCard(
                      icon: Icons.medical_services_outlined,
                      title: 'Egyptian Ambulance Service',
                      number: '123',
                      iconColor: AppColors.accent,
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Sign Out Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleSignOut,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Text(
                                'Sign Out',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                    
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.secondary.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: AppColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.charcoal.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.charcoal,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(
            Icons.check_circle_rounded,
            color: AppColors.primary,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.charcoal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmergencyCard({
    required IconData icon,
    required String title,
    required String number,
    required Color iconColor,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.secondary.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.charcoal,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  number,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.charcoal.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () => _makePhoneCall(number),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 10,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 0,
            ),
            child: const Text(
              'Call',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber);
    try {
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not launch phone dialer for $phoneNumber'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
