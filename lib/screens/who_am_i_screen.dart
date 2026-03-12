import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';
import '../theme.dart';

class WhoAmIScreen extends StatefulWidget {
  const WhoAmIScreen({super.key});

  @override
  State<WhoAmIScreen> createState() => _WhoAmIScreenState();
}

enum _ScanState { idle, imageSelected, loading, result, error }

class _Particle {
  double x, y, size, speed, opacity;
  double angle = math.Random().nextDouble() * 2 * math.pi;
  _Particle({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.opacity,
  });

  void update() {
    y -= speed;
    angle += 0.02;
    x += math.sin(angle) * 0.5;
    if (y < -20) {
      y = 800 + math.Random().nextDouble() * 200;
      x = math.Random().nextDouble() * 400;
    }
  }
}

class _WhoAmIScreenState extends State<WhoAmIScreen>
    with TickerProviderStateMixin {
  File? _selectedImage;
  _ScanState _state = _ScanState.idle;
  final List<_Particle> _particles = [];

  // Result data
  String _artifactName = '';
  String _brief = '';
  double _confidence = 0;

  // Error message
  String _errorMessage = '';

  // Animations
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  late AnimationController _scanLineController;
  late Animation<double> _scanLineAnimation;

  late AnimationController _resultSlideController;
  late Animation<Offset> _resultSlideAnimation;
  late Animation<double> _resultFadeAnimation;

  late AnimationController _shimmerController;
  late Animation<double> _shimmerAnimation;

  late AnimationController _headerGlowController;
  late Animation<double> _headerGlowAnimation;

  late AnimationController _particleController;
  late AnimationController _eyeRotationController;

  final ImagePicker _picker = ImagePicker();
  static const String _apiUrl =
      'https://abraam-refaat-egypt-artifact-api.hf.space/predict';

  @override
  void initState() {
    super.initState();

    // Idle pulse for the eye / icon
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Scan line animation (during loading)
    _scanLineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
    _scanLineAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _scanLineController, curve: Curves.linear),
    );

    // Result slide up animation
    _resultSlideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _resultSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _resultSlideController, curve: Curves.easeOutCubic),
    );
    _resultFadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
          parent: _resultSlideController,
          curve: const Interval(0, 0.6, curve: Curves.easeIn)),
    );

    // Gold shimmer for result name
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
    _shimmerAnimation = Tween<double>(begin: -1, end: 2).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.linear),
    );

    // Header glow
    _headerGlowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _headerGlowAnimation = Tween<double>(begin: 0.3, end: 0.7).animate(
      CurvedAnimation(parent: _headerGlowController, curve: Curves.easeInOut),
    );

    // Particles initialization
    for (int i = 0; i < 40; i++) {
      _particles.add(_Particle(
        x: math.Random().nextDouble() * 400,
        y: math.Random().nextDouble() * 800,
        size: math.Random().nextDouble() * 2 + 1,
        speed: math.Random().nextDouble() * 0.5 + 0.2,
        opacity: math.Random().nextDouble() * 0.5 + 0.2,
      ));
    }
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..addListener(() {
        for (var p in _particles) {
          p.update();
        }
        setState(() {});
      })..repeat();

    _eyeRotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _scanLineController.dispose();
    _resultSlideController.dispose();
    _shimmerController.dispose();
    _headerGlowController.dispose();
    _particleController.dispose();
    _eyeRotationController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: source,
        imageQuality: 90,
        maxWidth: 1200,
      );
      if (picked != null) {
        setState(() {
          _selectedImage = File(picked.path);
          _state = _ScanState.imageSelected;
          _resultSlideController.reset();
        });
      }
    } catch (e) {
      _showSnack('Could not access ${source == ImageSource.camera ? 'camera' : 'gallery'}');
    }
  }

  Future<void> _identify() async {
    if (_selectedImage == null) return;
    setState(() => _state = _ScanState.loading);

    try {
      final request = http.MultipartRequest('POST', Uri.parse(_apiUrl));
      
      // Add standard headers
      request.headers.addAll({
        'Accept': 'application/json',
      });

      // Add file with explicit content type
      final fileExtension = _selectedImage!.path.split('.').last.toLowerCase();
      final mimeType = fileExtension == 'png' ? 'png' : 'jpeg';
      
      request.files.add(
        await http.MultipartFile.fromPath(
          'file', 
          _selectedImage!.path,
          contentType: MediaType('image', mimeType),
        ),
      );

      print('📡 Identifying artifact at: $_apiUrl');
      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 60),
      );
      final response = await http.Response.fromStream(streamedResponse);
      print('📥 Response: ${response.statusCode}');
      if (response.statusCode != 200) {
        print('❌ Error Body: ${response.body}');
      }

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['recognized'] == true) {
          setState(() {
            _artifactName = data['character'] ?? 'Unknown';
            _brief = data['brief'] ?? 'No description available.';
            _confidence = ((data['confidence'] ?? 0) * 100).toDouble();
            _state = _ScanState.result;
          });
          _resultSlideController.forward();
        } else {
          setState(() {
            _errorMessage =
                'This artifact could not be recognized. Please try a clearer photo.';
            _state = _ScanState.error;
          });
        }
      } else {
        setState(() {
          _errorMessage = 'Server error (${response.statusCode}). Please try again.';
          _state = _ScanState.error;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Connection failed. Please check your internet and try again.';
        _state = _ScanState.error;
      });
    }
  }

  void _reset() {
    setState(() {
      _selectedImage = null;
      _state = _ScanState.idle;
      _resultSlideController.reset();
    });
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.primary),
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D2733), // Very deep teal-black
      body: Stack(
        children: [
          // Background decorative elements
          _buildBackground(),
          // Main content
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: child,
                    ),
                    child: _buildBody(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackground() {
    return AnimatedBuilder(
      animation: _headerGlowAnimation,
      builder: (context, _) {
        return Stack(
          children: [
            // Deep Base Gradient
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF0D2733),
                    Color(0xFF051218),
                  ],
                ),
              ),
            ),
            // Ancient Texture Overlay (Using Opacity and Blend)
            Opacity(
              opacity: 0.04,
              child: Container(
                decoration: const BoxDecoration(
                  image: DecorationImage(
                    image: NetworkImage('https://www.transparenttextures.com/patterns/dark-matter.png'),
                    repeat: ImageRepeat.repeat,
                  ),
                ),
              ),
            ),
            // Top radial glow
            Positioned(
              top: -100,
              left: -50,
              right: -50,
              child: Container(
                height: 450,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      AppColors.secondary.withValues(alpha: _headerGlowAnimation.value * 0.18),
                      Colors.transparent,
                    ],
                    radius: 0.8,
                  ),
                ),
              ),
            ),
            // Floating Particles
            CustomPaint(
              painter: _ParticlePainter(particles: _particles),
              size: Size.infinite,
            ),
          ],
        );
      },
    );
  }

  List<Widget> _buildGoldDots() {
    final positions = [
      [0.1, 0.15], [0.85, 0.12], [0.05, 0.45],
      [0.92, 0.48], [0.2, 0.82], [0.75, 0.78],
      [0.5, 0.08], [0.4, 0.92],
    ];
    return positions.asMap().entries.map((entry) {
      final i = entry.key;
      final pos = entry.value;
      return AnimatedBuilder(
        animation: _pulseController,
        builder: (context, _) {
          final pulse = 0.4 + (_pulseAnimation.value * 0.6) * ((i % 3) * 0.15 + 0.7);
          return Positioned(
            left: MediaQuery.of(context).size.width * pos[0],
            top: MediaQuery.of(context).size.height * pos[1],
            child: Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.secondary.withValues(alpha: pulse.clamp(0.0, 1.0)),
              ),
            ),
          );
        },
      );
    }).toList();
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          // Back button
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.secondary.withValues(alpha: 0.2),
                ),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
          const Spacer(),
          // Title
          Column(
            children: [
              Text(
                'Who Am I?!',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.secondary,
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                'Egyptian Artifact Identifier',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.5),
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const Spacer(),
          const SizedBox(width: 42), // Balance
        ],
      ),
    );
  }

  Widget _buildBody() {
    switch (_state) {
      case _ScanState.idle:
        return _buildIdleState();
      case _ScanState.imageSelected:
        return _buildImageSelectedState();
      case _ScanState.loading:
        return _buildLoadingState();
      case _ScanState.result:
        return _buildResultState();
      case _ScanState.error:
        return _buildErrorState();
    }
  }

  // ─── Idle State ───────────────────────────────────────────────────────────

  Widget _buildIdleState() {
    return SingleChildScrollView(
      key: const ValueKey('idle'),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        children: [
          const SizedBox(height: 20),
          // Layered Eye of Ra visual
          Center(
            child: SizedBox(
              width: 200,
              height: 200,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Outer Glow
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, _) => Container(
                      width: 160 * _pulseAnimation.value,
                      height: 160 * _pulseAnimation.value,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.secondary.withValues(alpha: 0.15),
                            blurRadius: 40,
                            spreadRadius: 10 * _pulseAnimation.value,
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Rotating Ring 1
                  RotationTransition(
                    turns: _eyeRotationController,
                    child: Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.secondary.withValues(alpha: 0.2),
                          width: 1,
                        ),
                      ),
                      padding: const EdgeInsets.all(4),
                      child: CustomPaint(
                        painter: _DashCirclePainter(
                          color: AppColors.secondary.withValues(alpha: 0.3),
                        ),
                      ),
                    ),
                  ),
                  // Rotating Ring 2 (Counter)
                  RotationTransition(
                    turns: Tween<double>(begin: 1, end: 0).animate(_eyeRotationController),
                    child: Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.secondary.withValues(alpha: 0.1),
                          width: 4,
                        ),
                      ),
                    ),
                  ),
                  // The Eye
                  Text(
                    '𓂀',
                    style: TextStyle(
                      fontSize: 64,
                      color: AppColors.secondary,
                      shadows: [
                        Shadow(
                          color: AppColors.secondary.withValues(alpha: 0.8),
                          blurRadius: 20,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Unlock Ancient Secrets',
            style: GoogleFonts.playfairDisplay(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Upload a photo of an Egyptian artifact or monument and our AI will identify it with historical context.',
            style: GoogleFonts.inter(
              fontSize: 15,
              color: Colors.white.withValues(alpha: 0.55),
              height: 1.6,
              letterSpacing: 0.2,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 44),
          // Camera button
          _buildSourceButton(
            icon: Icons.camera_enhance_rounded,
            label: 'Immersive Capture',
            subtitle: 'Take a photo of the artifact',
            onTap: () => _pickImage(ImageSource.camera),
            isPrimary: true,
          ),
          const SizedBox(height: 18),
          // Gallery button
          _buildSourceButton(
            icon: Icons.auto_awesome_motion_rounded,
            label: 'Ancient Records',
            subtitle: 'Select from your gallery',
            onTap: () => _pickImage(ImageSource.gallery),
            isPrimary: false,
          ),
          const SizedBox(height: 40),
          // Supported artifacts hint
          _buildSupportedHint(),
        ],
      ),
    );
  }

  Widget _buildSourceButton({
    required IconData icon,
    required String label,
    required String subtitle,
    required VoidCallback onTap,
    required bool isPrimary,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isPrimary 
                ? AppColors.primary.withValues(alpha: 0.45)
                : Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: isPrimary
                    ? AppColors.secondary.withValues(alpha: 0.4)
                    : Colors.white.withValues(alpha: 0.15),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: (isPrimary ? AppColors.primary : Colors.black).withValues(alpha: 0.2),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                )
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.secondary.withValues(alpha: 0.2),
                        AppColors.secondary.withValues(alpha: 0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.secondary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Icon(
                    icon,
                    color: AppColors.secondary,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: AppColors.secondary.withValues(alpha: 0.5),
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSupportedHint() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.secondary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.secondary.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded,
              color: AppColors.secondary.withValues(alpha: 0.7), size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Supports Egyptian artifacts & monuments including Tutankhamun, Nefertiti, the Great Sphinx and more.',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.55),
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Image Selected State ─────────────────────────────────────────────────

  Widget _buildImageSelectedState() {
    return SingleChildScrollView(
      key: const ValueKey('imageSelected'),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Text(
            'Ready to Identify',
            style: GoogleFonts.playfairDisplay(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap Identify to analyze the artifact',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.55),
            ),
          ),
          const SizedBox(height: 28),
          // Image preview
          Hero(
            tag: 'artifact_image',
            child: Container(
              height: 300,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.secondary.withValues(alpha: 0.2),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
                border: Border.all(
                  color: AppColors.secondary.withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(19),
                child: Image.file(
                  _selectedImage!,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
          // Identify button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _identify,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.secondary,
                foregroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 12,
                shadowColor: AppColors.secondary.withValues(alpha: 0.4),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.document_scanner_rounded, size: 20),
                  const SizedBox(width: 10),
                  Text(
                    'Identify Artifact',
                    style: GoogleFonts.inter(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Change photo
          TextButton.icon(
            onPressed: _reset,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Choose Different Photo'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.white.withValues(alpha: 0.55),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Loading State ────────────────────────────────────────────────────────

  Widget _buildLoadingState() {
    return Column(
      key: const ValueKey('loading'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (_selectedImage != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Hero(
                  tag: 'artifact_image',
                  child: Container(
                    height: 320,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: AppColors.secondary.withValues(alpha: 0.5),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.secondary.withValues(alpha: 0.2),
                          blurRadius: 40,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(23),
                      child: Image.file(_selectedImage!, fit: BoxFit.cover),
                    ),
                  ),
                ),
                // Dark scan overlay
                ClipRRect(
                  borderRadius: BorderRadius.circular(19),
                  child: Container(
                    height: 280,
                    width: double.infinity,
                    color: Colors.black.withValues(alpha: 0.45),
                  ),
                ),
                // Scan line
                AnimatedBuilder(
                  animation: _scanLineAnimation,
                  builder: (context, _) {
                    return Positioned(
                      top: 320 * _scanLineAnimation.value,
                      left: 10,
                      right: 10,
                      child: Column(
                        children: [
                          Container(
                            height: 3,
                            decoration: BoxDecoration(
                              color: AppColors.secondary,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.secondary.withValues(alpha: 0.8),
                                  blurRadius: 20,
                                  spreadRadius: 4,
                                ),
                              ],
                            ),
                          ),
                          Container(
                            height: 60,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [
                                  AppColors.secondary.withValues(alpha: 0.3),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                // Corner brackets
                ..._buildScanCorners(),
              ],
            ),
          ),
        const SizedBox(height: 36),
        AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, _) {
            return Opacity(
              opacity: _pulseAnimation.value,
              child: Text(
                'Consulting the Oracle...',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 20,
                  color: AppColors.secondary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        Text(
          'Analyzing hieroglyphs & patterns',
          style: GoogleFonts.inter(
            fontSize: 13,
            color: Colors.white.withValues(alpha: 0.45),
          ),
        ),
        const SizedBox(height: 28),
        SizedBox(
          width: 36,
          height: 36,
          child: CircularProgressIndicator(
            color: AppColors.secondary,
            strokeWidth: 2.5,
          ),
        ),
      ],
    );
  }

  List<Widget> _buildScanCorners() {
    const size = 22.0;
    const width = 3.0;
    return [
      Positioned(
        top: 12, left: 12,
        child: _corner(size, width, topLeft: true),
      ),
      Positioned(
        top: 12, right: 12,
        child: _corner(size, width, topRight: true),
      ),
      Positioned(
        bottom: 12, left: 12,
        child: _corner(size, width, bottomLeft: true),
      ),
      Positioned(
        bottom: 12, right: 12,
        child: _corner(size, width, bottomRight: true),
      ),
    ];
  }

  Widget _corner(double size, double width,
      {bool topLeft = false,
      bool topRight = false,
      bool bottomLeft = false,
      bool bottomRight = false}) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _CornerPainter(
          color: AppColors.secondary,
          strokeWidth: width,
          topLeft: topLeft,
          topRight: topRight,
          bottomLeft: bottomLeft,
          bottomRight: bottomRight,
        ),
      ),
    );
  }

  // ─── Result State ─────────────────────────────────────────────────────────

  Widget _buildResultState() {
    return SingleChildScrollView(
      key: const ValueKey('result'),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        children: [
          // Image with premium frame
          if (_selectedImage != null)
            Container(
              height: 240,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: AppColors.secondary.withValues(alpha: 0.6),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.secondary.withValues(alpha: 0.3),
                    blurRadius: 40,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: Image.file(_selectedImage!, fit: BoxFit.cover),
              ),
            ),
          const SizedBox(height: 24),
          // Result card slides up
          SlideTransition(
            position: _resultSlideAnimation,
            child: FadeTransition(
              opacity: _resultFadeAnimation,
              child: Column(
                children: [
                  // Artifact name with shimmer
                  AnimatedBuilder(
                    animation: _shimmerAnimation,
                    builder: (context, child) {
                      return ShaderMask(
                        blendMode: BlendMode.srcIn,
                        shaderCallback: (bounds) {
                          return LinearGradient(
                            colors: const [
                              Color(0xFFD4AF7A),
                              Color(0xFFFFF3C0),
                              Color(0xFFD4AF7A),
                              Color(0xFFE8C97A),
                            ],
                            stops: const [0.0, 0.4, 0.6, 1.0],
                            begin: Alignment(_shimmerAnimation.value - 1, 0),
                            end: Alignment(_shimmerAnimation.value, 0),
                          ).createShader(bounds);
                        },
                        child: Text(
                          _artifactName,
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            height: 1.2,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  // Brief card
                  ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: AppColors.secondary.withValues(alpha: 0.22),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppColors.secondary.withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Text('𓂀', style: TextStyle(fontSize: 18, color: AppColors.secondary)),
                                ),
                                const SizedBox(width: 14),
                                Text(
                                  'Historical Chronicle',
                                  style: GoogleFonts.playfairDisplay(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.secondary,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            Text(
                              _brief,
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                color: Colors.white.withValues(alpha: 0.85),
                                height: 1.7,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Try Another button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _reset,
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: Text(
                        'Try Another Artifact',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 8,
                        shadowColor: AppColors.primary.withValues(alpha: 0.4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Error State ──────────────────────────────────────────────────────────

  Widget _buildErrorState() {
    return Padding(
      key: const ValueKey('error'),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.red.withValues(alpha: 0.1),
              border: Border.all(
                color: Colors.red.withValues(alpha: 0.3),
              ),
            ),
            child: const Icon(
              Icons.search_off_rounded,
              color: Colors.redAccent,
              size: 42,
            ),
          ),
          const SizedBox(height: 28),
          Text(
            'Not Recognized',
            style: GoogleFonts.playfairDisplay(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _errorMessage,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.6),
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _reset,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(
                'Try Again',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Corner Painter ───────────────────────────────────────────────────────────

class _CornerPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final bool topLeft, topRight, bottomLeft, bottomRight;

  _CornerPainter({
    required this.color,
    required this.strokeWidth,
    this.topLeft = false,
    this.topRight = false,
    this.bottomLeft = false,
    this.bottomRight = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final p = size.width;
    if (topLeft) {
      canvas.drawLine(const Offset(0, 0), Offset(p, 0), paint);
      canvas.drawLine(const Offset(0, 0), Offset(0, p), paint);
    }
    if (topRight) {
      canvas.drawLine(Offset(0, 0), Offset(p, 0), paint);
      canvas.drawLine(Offset(p, 0), Offset(p, p), paint);
    }
    if (bottomLeft) {
      canvas.drawLine(Offset(0, 0), Offset(0, p), paint);
      canvas.drawLine(Offset(0, p), Offset(p, p), paint);
    }
    if (bottomRight) {
      canvas.drawLine(Offset(p, 0), Offset(p, p), paint);
      canvas.drawLine(Offset(0, p), Offset(p, p), paint);
    }
  }

  @override
  bool shouldRepaint(_CornerPainter old) => false;
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  _ParticlePainter({required this.particles});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = AppColors.secondary;
    for (var p in particles) {
      paint.color = AppColors.secondary.withValues(alpha: p.opacity);
      canvas.drawCircle(Offset(p.x * (size.width / 400), p.y * (size.height / 800)), p.size, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _DashCirclePainter extends CustomPainter {
  final Color color;
  _DashCirclePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    const dashCount = 8;
    const dashLength = 0.2;
    for (int i = 0; i < dashCount; i++) {
      canvas.drawArc(
        Rect.fromLTWH(0, 0, size.width, size.height),
        (i * 2 * math.pi / dashCount),
        dashLength,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
