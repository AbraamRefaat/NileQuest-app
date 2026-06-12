import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../theme.dart';
import '../models/trip_session.dart';

/// BeReal-style capture: the tourist takes 3 photos at the current stop.
/// Returns the list of saved photo paths via Navigator.pop.
class StopPhotoScreen extends StatefulWidget {
  final TripStop stop;
  final int stopNumber;

  const StopPhotoScreen({
    super.key,
    required this.stop,
    required this.stopNumber,
  });

  @override
  State<StopPhotoScreen> createState() => _StopPhotoScreenState();
}

class _StopPhotoScreenState extends State<StopPhotoScreen>
    with SingleTickerProviderStateMixin {
  final ImagePicker _picker = ImagePicker();
  final List<String> _photos = [];
  bool _capturing = false;
  late AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _takePhoto() async {
    if (_capturing || _photos.length >= 3) return;
    setState(() => _capturing = true);
    try {
      final shot = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1600,
        imageQuality: 85,
      );
      if (shot != null) {
        // Persist into app documents so the Wrapped can find it later
        final dir = await getApplicationDocumentsDirectory();
        final tripDir = Directory('${dir.path}/trip_photos');
        if (!tripDir.existsSync()) tripDir.createSync(recursive: true);
        final dest =
            '${tripDir.path}/${widget.stop.poiId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        await File(shot.path).copy(dest);
        setState(() => _photos.add(dest));
      }
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final remaining = 3 - _photos.length;
    return Scaffold(
      backgroundColor: const Color(0xFF101418),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context, _photos),
                    icon: const Icon(Icons.close_rounded,
                        color: Colors.white, size: 28),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        const Text(
                          '📸 NileReal.',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                          ),
                        ),
                        Text(
                          'Stop ${widget.stopNumber} • ${widget.stop.name}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 44),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              remaining > 0
                  ? 'Capture $remaining more ${remaining == 1 ? "photo" : "photos"} of this moment ✨'
                  : 'Perfect! All 3 captured 🎉',
              style: TextStyle(
                color: remaining > 0
                    ? Colors.white.withValues(alpha: 0.85)
                    : const Color(0xFF6EE7A0),
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 20),

            // 3 photo slots
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: List.generate(3, (i) {
                    final hasPhoto = i < _photos.length;
                    final isNext = i == _photos.length;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: GestureDetector(
                          onTap: isNext ? _takePhoto : null,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(
                                color: hasPhoto
                                    ? const Color(0xFF6EE7A0)
                                    : isNext
                                        ? AppColors.secondary
                                        : Colors.white.withValues(alpha: 0.15),
                                width: hasPhoto || isNext ? 2.5 : 1.5,
                              ),
                              color: Colors.white.withValues(alpha: 0.05),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: hasPhoto
                                ? Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      Image.file(File(_photos[i]),
                                          fit: BoxFit.cover),
                                      const Positioned(
                                        top: 10,
                                        right: 10,
                                        child: CircleAvatar(
                                          radius: 14,
                                          backgroundColor: Color(0xFF6EE7A0),
                                          child: Icon(Icons.check_rounded,
                                              size: 18, color: Colors.black),
                                        ),
                                      ),
                                    ],
                                  )
                                : Center(
                                    child: isNext
                                        ? FadeTransition(
                                            opacity: Tween(begin: 0.5, end: 1.0)
                                                .animate(_pulse),
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.photo_camera_rounded,
                                                  color: AppColors.secondary,
                                                  size: 38,
                                                ),
                                                const SizedBox(height: 6),
                                                const Text(
                                                  'Tap to shoot',
                                                  style: TextStyle(
                                                    color: Colors.white70,
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          )
                                        : Icon(
                                            Icons.lock_outline_rounded,
                                            color: Colors.white
                                                .withValues(alpha: 0.2),
                                            size: 26,
                                          ),
                                  ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),

            // Done button
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _photos.isNotEmpty
                      ? () => Navigator.pop(context, _photos)
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _photos.length >= 3
                        ? const Color(0xFF6EE7A0)
                        : AppColors.secondary,
                    foregroundColor: Colors.black,
                    disabledBackgroundColor:
                        Colors.white.withValues(alpha: 0.1),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    _photos.length >= 3
                        ? 'Done — memory saved! 🎉'
                        : _photos.isEmpty
                            ? 'Take at least 1 photo'
                            : 'Save ${_photos.length} photo${_photos.length == 1 ? "" : "s"}',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
