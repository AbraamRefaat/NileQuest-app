import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme.dart';
import '../services/nearby_discoveries_service.dart';

// Panel Type Enum — only panels that actually do something.
enum MapPanelType {
  nearby,
  emergency,
}

/// Bottom-sheet panels for the map: Nearby discoveries and Emergency (SOS).
class ModernMapPanel extends StatefulWidget {
  final MapPanelType type;
  final VoidCallback onClose;
  final Position? userLocation;
  final List<NearbyDiscovery> nearbyDiscoveries;

  /// Called when a nearby place is tapped so the map can fly to it.
  final void Function(NearbyDiscovery discovery)? onDiscoveryTap;

  const ModernMapPanel({
    super.key,
    required this.type,
    required this.onClose,
    this.userLocation,
    this.nearbyDiscoveries = const [],
    this.onDiscoveryTap,
  });

  @override
  State<ModernMapPanel> createState() => _ModernMapPanelState();
}

class _ModernMapPanelState extends State<ModernMapPanel>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _call(String number) async {
    final uri = Uri(scheme: 'tel', path: number);
    // No canLaunchUrl pre-check — unreliable on Android 11+ without
    // package-visibility queries; just try.
    bool ok = false;
    try {
      ok = await launchUrl(uri);
    } catch (_) {}
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not start a call to $number')),
      );
    }
  }

  /// Opens Google Maps searching for the given place type near the user.
  Future<void> _searchNearby(String query) async {
    final loc = widget.userLocation;
    final uri = Uri.parse(
      loc != null
          ? 'https://www.google.com/maps/search/?api=1&query=$query&center=${loc.lat},${loc.lng}'
          : 'https://www.google.com/maps/search/?api=1&query=$query',
    );
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {}, // Prevent closing when tapping panel
      child: Container(
        color: Colors.black.withValues(alpha: 0.3),
        child: GestureDetector(
          onTap: widget.onClose,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: GestureDetector(
              onTap: () {}, // Prevent closing when tapping panel content
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Container(
                  height: MediaQuery.of(context).size.height * 0.65,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white,
                        Colors.grey.shade50,
                      ],
                    ),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(30),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 30,
                        offset: const Offset(0, -10),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      _buildPanelHeader(),
                      Expanded(child: _buildPanelContent()),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPanelHeader() {
    final (title, icon, color) = _getPanelInfo();

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.1), Colors.transparent],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        children: [
          // Drag Handle
          Container(
            width: 50,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(height: 20),

          // Header Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color, color.withValues(alpha: 0.8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.charcoal,
                      ),
                    ),
                    Text(
                      _getSubtitle(),
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.charcoal.withValues(alpha: 0.6),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: widget.onClose,
                  color: AppColors.charcoal,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPanelContent() {
    switch (widget.type) {
      case MapPanelType.nearby:
        return _buildNearbyContent();
      case MapPanelType.emergency:
        return _buildEmergencyContent();
    }
  }

  // 🔍 NEARBY CONTENT
  Widget _buildNearbyContent() {
    if (widget.nearbyDiscoveries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.explore_rounded,
                size: 64,
                color: AppColors.primary.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Discovering nearby places...',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.charcoal,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Finding the best spots around you',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.charcoal.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: widget.nearbyDiscoveries.length,
      itemBuilder: (context, index) {
        final discovery = widget.nearbyDiscoveries[index];
        return _buildNearbyCard(discovery);
      },
    );
  }

  Widget _buildNearbyCard(NearbyDiscovery discovery) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => widget.onDiscoveryTap?.call(discovery),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary.withValues(alpha: 0.2),
                        AppColors.primary.withValues(alpha: 0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.location_on_rounded,
                    color: AppColors.primary,
                    size: 36,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        discovery.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.charcoal,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.directions_walk_rounded,
                            size: 14,
                            color: AppColors.charcoal.withValues(alpha: 0.6),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${discovery.distance.toStringAsFixed(1)} km',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.charcoal.withValues(alpha: 0.6),
                            ),
                          ),
                          const SizedBox(width: 12),
                          if (discovery.rating != null) ...[
                            const Icon(
                              Icons.star_rounded,
                              size: 14,
                              color: Color(0xFFF39C12),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              discovery.rating!.toStringAsFixed(1),
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.charcoal.withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _getDiscoveryTypeLabel(discovery.type),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: AppColors.charcoal.withValues(alpha: 0.3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 🆘 EMERGENCY CONTENT
  Widget _buildEmergencyContent() {
    final emergencyNumbers = [
      ('Tourist Police', '126', Icons.local_police_rounded, const Color(0xFF3498DB)),
      ('Ambulance', '123', Icons.local_hospital_rounded, const Color(0xFFE74C3C)),
      ('Fire Department', '180', Icons.local_fire_department_rounded, const Color(0xFFF39C12)),
      ('General Police', '122', Icons.shield_rounded, const Color(0xFF9B59B6)),
    ];

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Emergency Banner
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFE74C3C), Color(0xFFC0392B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFE74C3C).withValues(alpha: 0.3),
                blurRadius: 15,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.emergency_rounded,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Emergency Help',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Tap a number to call right away',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Emergency Numbers
        ...emergencyNumbers.map((emergency) {
          final (title, number, icon, color) = emergency;
          return _buildEmergencyCard(title, number, icon, color);
        }),

        const SizedBox(height: 16),

        // Quick Actions
        Row(
          children: [
            Expanded(
              child: _buildQuickEmergencyButton(
                'Nearest Embassy',
                Icons.location_city_rounded,
                const Color(0xFF3498DB),
                () => _searchNearby('embassy'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildQuickEmergencyButton(
                'Nearest Hospital',
                Icons.local_hospital_rounded,
                const Color(0xFFE74C3C),
                () => _searchNearby('hospital'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEmergencyCard(String title, String number, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _call(number),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.charcoal,
                        ),
                      ),
                      Text(
                        number,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.charcoal.withValues(alpha: 0.6),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.phone_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickEmergencyButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withValues(alpha: 0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              children: [
                Icon(icon, color: Colors.white, size: 28),
                const SizedBox(height: 8),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Helper Methods
  (String, IconData, Color) _getPanelInfo() {
    switch (widget.type) {
      case MapPanelType.nearby:
        return ('Nearby Places', Icons.explore_rounded, const Color(0xFF27AE60));
      case MapPanelType.emergency:
        return ('Emergency', Icons.emergency_rounded, const Color(0xFFE74C3C));
    }
  }

  String _getSubtitle() {
    switch (widget.type) {
      case MapPanelType.nearby:
        return '${widget.nearbyDiscoveries.length} places found';
      case MapPanelType.emergency:
        return 'Quick access to help';
    }
  }

  String _getDiscoveryTypeLabel(DiscoveryType type) {
    switch (type) {
      case DiscoveryType.attraction:
        return 'Attraction';
      case DiscoveryType.hiddenGem:
        return 'Hidden Gem';
      case DiscoveryType.detour:
        return 'Quick Detour';
      case DiscoveryType.photoSpot:
        return 'Photo Spot';
      case DiscoveryType.service:
        return 'Essential';
    }
  }
}
