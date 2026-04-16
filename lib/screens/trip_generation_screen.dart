import 'package:flutter/material.dart';
import '../theme.dart';
import '../models/user_preferences.dart';
import '../models/itinerary.dart';
import '../services/recommendation_api.dart';

class TripGenerationScreen extends StatefulWidget {
  final UserPreferences preferences;
  final Function(Itinerary) onGenerate;
  final VoidCallback onBack;

  const TripGenerationScreen({
    super.key,
    required this.preferences,
    required this.onGenerate,
    required this.onBack,
  });

  @override
  State<TripGenerationScreen> createState() => _TripGenerationScreenState();
}

class _TripGenerationScreenState extends State<TripGenerationScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _isGenerating = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _generateTrip() async {
    setState(() {
      _isGenerating = true;
      _errorMessage = null;
    });

    try {
      final itinerary = await RecommendationApi.generateItinerary(widget.preferences);
      if (mounted) {
        widget.onGenerate(itinerary);
      }
    } on RecommendationApiException catch (e) {
      if (mounted) {
        setState(() {
          _isGenerating = false;
          _errorMessage = e.message;
        });
        _showErrorDialog(
          e.message,
          canRetry: true,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isGenerating = false;
          _errorMessage = 'An unexpected error occurred: $e';
        });
        _showErrorDialog(
          'An unexpected error occurred. Please try again.',
          canRetry: true,
        );
      }
    }
  }

  void _showErrorDialog(String message, {bool canRetry = false}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red[700]),
            const SizedBox(width: 8),
            const Text('Connection Issue'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.lightbulb_outline, size: 16, color: Colors.blue[700]),
                      const SizedBox(width: 4),
                      Text(
                        'Quick Fix:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[700],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text('1. Connect phone to WiFi', style: TextStyle(fontSize: 13)),
                  const Text('2. Make sure server is running', style: TextStyle(fontSize: 13)),
                  const Text('3. Check same network', style: TextStyle(fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (canRetry)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _generateTrip();
              },
              child: const Text('Retry'),
            ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, viewportConstraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: viewportConstraints.maxHeight,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Top content (Logo, Title, Summary Card)
                      Column(
                        children: [
                          // Header with Back Button
                          Row(
                            children: [
                              GestureDetector(
                                onTap: widget.onBack,
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: AppColors.secondary.withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.arrow_back_rounded,
                                    color: AppColors.charcoal,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          FadeTransition(
                            opacity: _animation,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0, 0.2),
                                end: Offset.zero,
                              ).animate(_animation),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // Icon
                                  Container(
                                    width: 80,
                                    height: 80,
                                    decoration: BoxDecoration(
                                      color: AppColors.accent.withValues(alpha: 0.2),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.auto_awesome_rounded,
                                      size: 40,
                                      color: AppColors.accent,
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  
                                  // Title
                                  Text(
                                    'Ready to Plan?',
                                    style: Theme.of(context).textTheme.displayMedium,
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 12),
                                  
                                  // Description
                                  Text(
                                    'We\'ve gathered your preferences and are ready to build your perfect Egyptian adventure.',
                                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                          color: AppColors.charcoal.withValues(alpha: 0.6),
                                        ),
                                    textAlign: TextAlign.center,
                                    maxLines: 3,
                                  ),
                                  const SizedBox(height: 40),
                                  
                                  // Summary Card
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(24),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: AppColors.secondary.withValues(alpha: 0.2),
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.05),
                                          blurRadius: 20,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Trip Summary',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleLarge
                                              ?.copyWith(
                                                color: AppColors.charcoal,
                                              ),
                                        ),
                                        const Divider(height: 24),
                                        _SummaryItem(
                                          icon: Icons.location_on_rounded,
                                          label: 'Destination',
                                          value: '${widget.preferences.city ?? 'Cairo'}, Egypt',
                                        ),
                                        const SizedBox(height: 16),
                                        _SummaryItem(
                                          icon: Icons.calendar_today_rounded,
                                          label: 'Duration',
                                          value: '${widget.preferences.durationDays ?? 1} Days',
                                        ),
                                        const SizedBox(height: 16),
                                        _SummaryItem(
                                          icon: Icons.account_balance_wallet_rounded,
                                          label: 'Budget',
                                          value: widget.preferences.getBudgetDisplay(),
                                        ),
                                        const SizedBox(height: 16),
                                        _SummaryItem(
                                          icon: Icons.favorite_rounded,
                                          label: 'Interests',
                                          value: widget.preferences.interests.join(', '),
                                        ),
                                        if (widget.preferences.specificInterest != null && widget.preferences.specificInterest!.isNotEmpty) ...[
                                          const SizedBox(height: 16),
                                          _SummaryItem(
                                            icon: Icons.tips_and_updates_rounded,
                                            label: 'Specific Request',
                                            value: widget.preferences.specificInterest!,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 40),
                      
                      // Bottom content (Button and Error Message)
                      Column(
                        children: [
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _isGenerating ? null : _generateTrip,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                elevation: 12,
                                shadowColor: AppColors.primary.withValues(alpha: 0.3),
                                disabledBackgroundColor: Colors.grey[300],
                              ),
                              child: _isGenerating
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    )
                                  : const Text(
                                      'Generate My Trip',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                            ),
                          ),
                          if (_errorMessage != null) ...[
                            const SizedBox(height: 24),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.red.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.red.withValues(alpha: 0.2),
                                ),
                              ),
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontSize: 13,
                                  height: 1.5,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _SummaryItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: 16,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[400],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.charcoal,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
