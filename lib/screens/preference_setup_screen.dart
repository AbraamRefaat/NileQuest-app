import 'package:flutter/material.dart';
import '../theme.dart';
import '../models/user_preferences.dart';

class PreferenceSetupScreen extends StatefulWidget {
  final Function(UserPreferences) onComplete;
  final VoidCallback onBack;

  const PreferenceSetupScreen({
    super.key,
    required this.onComplete,
    required this.onBack,
  });

  @override
  State<PreferenceSetupScreen> createState() => _PreferenceSetupScreenState();
}

class _PreferenceSetupScreenState extends State<PreferenceSetupScreen> {
  int _currentStep = 1;
  final int _totalSteps = 6;

  String? _selectedCity;
  String? _selectedDuration;
  String? _selectedBudget;
  final List<String> _selectedInterests = [];
  String? _selectedPace;
  String? _specificInterest;

  void _nextStep() {
    if (_currentStep < _totalSteps) {
      setState(() {
        _currentStep++;
      });
    } else {
      // Dismiss keyboard before navigating
      FocusScope.of(context).unfocus();
      
      // Create UserPreferences object and pass it back
      final prefs = UserPreferences(
        city: _selectedCity,
        durationDays: int.tryParse(_selectedDuration ?? '1'),
        budgetTier: _selectedBudget,
        interests: List.from(_selectedInterests),
        pace: _selectedPace,
        specificInterest: (_specificInterest ?? '').trim().isEmpty
            ? null
            : _specificInterest!.trim(),
      );
      widget.onComplete(prefs);
    }
  }

  void _previousStep() {
    if (_currentStep > 1) {
      setState(() {
        _currentStep--;
      });
    } else {
      widget.onBack();
    }
  }

  bool _isStepValid() {
    switch (_currentStep) {
      case 1:
        return _selectedCity != null;
      case 2:
        if (_selectedDuration == null || _selectedDuration!.isEmpty) {
          return false;
        }
        final days = int.tryParse(_selectedDuration!);
        return days != null && days > 0;
      case 3:
        return _selectedBudget != null;
      case 4:
        return _selectedInterests.isNotEmpty;
      case 5:
        return _selectedPace != null;
      case 6:
        return true; // Optional step — always valid
      default:
        return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: Column(
          children: [
            // Header with Progress
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: _previousStep,
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
                      Text(
                        'Step $_currentStep of $_totalSteps',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: AppColors.primary,
                            ),
                      ),
                      // Skip button only on the optional step 6
                      if (_currentStep == 6)
                        TextButton(
                          onPressed: () {
                            setState(() => _specificInterest = null);
                            _nextStep();
                          },
                          child: const Text(
                            'Skip',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        )
                      else
                        const SizedBox(width: 40),
                    ],
                  ),
                  const SizedBox(height: 24),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: _currentStep / _totalSteps,
                      backgroundColor: AppColors.secondary.withValues(alpha: 0.2),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        AppColors.primary,
                      ),
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _buildStep(),
                ),
              ),
            ),

            // Action Button
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.cream.withValues(alpha: 0),
                    AppColors.cream,
                    AppColors.cream,
                  ],
                ),
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isStepValid() ? _nextStep : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isStepValid()
                        ? AppColors.primary
                        : Colors.grey[300],
                    foregroundColor:
                        _isStepValid() ? Colors.white : Colors.grey[400],
                    disabledBackgroundColor: Colors.grey[300],
                    disabledForegroundColor: Colors.grey[400],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _currentStep == _totalSteps ? 'Generate ✨' : 'Next',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward_rounded, size: 20),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep() {
    switch (_currentStep) {
      case 1:
        return _StepCity(
          key: const ValueKey(1),
          selectedCity: _selectedCity,
          onSelect: (city) => setState(() => _selectedCity = city),
        );
      case 2:
        return _StepDuration(
          key: const ValueKey(2),
          selectedDuration: _selectedDuration,
          onSelect: (duration) => setState(() => _selectedDuration = duration),
        );
      case 3:
        return _StepBudget(
          key: const ValueKey(3),
          selectedBudget: _selectedBudget,
          onSelect: (budget) => setState(() => _selectedBudget = budget),
        );
      case 4:
        return _StepInterests(
          key: const ValueKey(4),
          selectedInterests: _selectedInterests,
          onToggle: (interest) {
            setState(() {
              if (_selectedInterests.contains(interest)) {
                _selectedInterests.remove(interest);
              } else {
                _selectedInterests.add(interest);
              }
            });
          },
          onReorder: (oldIndex, newIndex) {
            setState(() {
              if (newIndex > oldIndex) {
                newIndex -= 1;
              }
              final item = _selectedInterests.removeAt(oldIndex);
              _selectedInterests.insert(newIndex, item);
            });
          },
        );
      case 5:
        return _StepPace(
          key: const ValueKey(5),
          selectedPace: _selectedPace,
          onSelect: (pace) => setState(() => _selectedPace = pace),
        );
      case 6:
        return _StepSpecificInterest(
          key: const ValueKey(6),
          value: _specificInterest,
          onChanged: (val) => setState(() => _specificInterest = val),
        );
      default:
        return Container();
    }
  }
}

// Step Widgets
class _StepCity extends StatelessWidget {
  final String? selectedCity;
  final Function(String) onSelect;

  const _StepCity({
    super.key,
    required this.selectedCity,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final cities = [
      {'name': 'Cairo', 'image': 'assets/images/cities/cairo.jpg', 'available': true},
      {'name': 'Luxor', 'image': 'assets/images/cities/luxor.jpg', 'available': false},
      {'name': 'Aswan', 'image': 'assets/images/cities/aswan.jpg', 'available': false},
      {'name': 'Alexandria', 'image': 'assets/images/cities/alexandria.jpg', 'available': false},
      {'name': 'Hurghada', 'image': 'assets/images/cities/hurghada.jpg', 'available': false},
      {'name': 'Sharm', 'image': 'assets/images/cities/sharm.jpg', 'available': false},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Where to?',
          style: Theme.of(context).textTheme.displayMedium,
        ),
        const SizedBox(height: 8),
        Text(
          'Choose your primary destination',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppColors.charcoal.withValues(alpha: 0.6),
              ),
        ),
        const SizedBox(height: 32),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 0.85,
          ),
          itemCount: cities.length,
          itemBuilder: (context, index) {
            final city = cities[index];
            final isSelected = selectedCity == city['name'];
            final isAvailable = city['available'] as bool;
            
            return GestureDetector(
              onTap: isAvailable ? () => onSelect(city['name'] as String) : null,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primary
                        : Colors.transparent,
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                    if (isSelected)
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // City Image
                      Image.asset(
                        city['image'] as String,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          // Fallback gradient if image not found
                          return Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  AppColors.primary.withValues(alpha: 0.3),
                                  AppColors.secondary.withValues(alpha: 0.3),
                                ],
                              ),
                            ),
                            child: Center(
                              child: Icon(
                                Icons.location_city_rounded,
                                size: 48,
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                            ),
                          );
                        },
                      ),
                      
                      // Overlay for unavailable cities
                      if (!isAvailable)
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                      
                      // Gradient overlay for text readability
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.7),
                            ],
                          ),
                        ),
                      ),
                      
                      // City name and coming soon badge
                      Positioned(
                        left: 12,
                        right: 12,
                        bottom: 12,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              city['name'] as String,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isAvailable ? Colors.white : Colors.grey[800],
                                shadows: isAvailable
                                    ? [
                                        Shadow(
                                          color: Colors.black.withValues(alpha: 0.5),
                                          blurRadius: 4,
                                        ),
                                      ]
                                    : null,
                              ),
                            ),
                            if (!isAvailable) ...[
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.grey[700],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Coming Soon',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      
                      // Check mark for selected
                      if (isSelected)
                        Positioned(
                          top: 12,
                          right: 12,
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.check_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _StepDuration extends StatefulWidget {
  final String? selectedDuration;
  final Function(String) onSelect;

  const _StepDuration({
    super.key,
    required this.selectedDuration,
    required this.onSelect,
  });

  @override
  State<_StepDuration> createState() => _StepDurationState();
}

class _StepDurationState extends State<_StepDuration> {
  late TextEditingController _customController;
  bool _showCustomInput = false;

  @override
  void initState() {
    super.initState();
    _customController = TextEditingController(text: widget.selectedDuration ?? '');
    // Check if the selected duration is a custom value
    final selectedInt = int.tryParse(widget.selectedDuration ?? '');
    if (selectedInt != null && !_quickSelectDays.contains(selectedInt)) {
      _showCustomInput = true;
    }
  }

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  final List<int> _quickSelectDays = [1, 2, 3, 4, 5, 6, 7, 10, 14, 21, 30];

  void _selectDay(int days) {
    setState(() {
      _showCustomInput = false;
      _customController.clear();
    });
    widget.onSelect(days.toString());
  }

  @override
  Widget build(BuildContext context) {
    final selectedInt = int.tryParse(widget.selectedDuration ?? '');
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'How long?',
          style: Theme.of(context).textTheme.displayMedium,
        ),
        const SizedBox(height: 8),
        Text(
          'Select your trip duration',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppColors.charcoal.withValues(alpha: 0.6),
              ),
        ),
        const SizedBox(height: 32),
        
        // Quick select grid
        Container(
          padding: const EdgeInsets.all(20),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.calendar_month_rounded,
                    color: AppColors.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Quick Select',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1.0,
                ),
                itemCount: _quickSelectDays.length,
                itemBuilder: (context, index) {
                  final days = _quickSelectDays[index];
                  final isSelected = !_showCustomInput && selectedInt == days;
                  
                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _selectDay(days),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected 
                              ? AppColors.primary 
                              : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected 
                                ? AppColors.primary 
                                : AppColors.secondary.withValues(alpha: 0.15),
                            width: isSelected ? 2 : 1,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: AppColors.primary.withValues(alpha: 0.25),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ]
                              : [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.03),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                        ),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                days.toString(),
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected 
                                      ? Colors.white 
                                      : AppColors.charcoal,
                                  height: 1.2,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                days == 1 ? 'day' : 'days',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: isSelected 
                                      ? Colors.white.withValues(alpha: 0.85)
                                      : AppColors.charcoal.withValues(alpha: 0.5),
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 20),
        
        // Divider with text
        Row(
          children: [
            Expanded(
              child: Divider(
                color: AppColors.secondary.withValues(alpha: 0.3),
                thickness: 1,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'OR',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.charcoal.withValues(alpha: 0.4),
                ),
              ),
            ),
            Expanded(
              child: Divider(
                color: AppColors.secondary.withValues(alpha: 0.3),
                thickness: 1,
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 20),
        
        // Custom input option
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: Row(
                  children: [
                    Icon(
                      Icons.edit_calendar_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Enter Custom Duration',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: AppColors.cream,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _showCustomInput && _customController.text.isNotEmpty
                        ? AppColors.primary
                        : AppColors.secondary.withValues(alpha: 0.2),
                    width: 2,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _customController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.charcoal,
                          letterSpacing: 0.5,
                        ),
                        decoration: InputDecoration(
                          hintText: '0',
                          hintStyle: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[350],
                            letterSpacing: 0.5,
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                          counterText: '',
                        ),
                        maxLength: 3,
                        textAlign: TextAlign.center,
                        onTap: () {
                          setState(() {
                            _showCustomInput = true;
                          });
                        },
                        onChanged: (value) {
                          setState(() {
                            _showCustomInput = true;
                          });
                          widget.onSelect(value);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'days',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.charcoal.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StepBudget extends StatelessWidget {
  final String? selectedBudget;
  final Function(String) onSelect;

  const _StepBudget({
    super.key,
    required this.selectedBudget,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final options = [
      {'id': 'budget', 'label': 'Budget', 'icon': '\$'},
      {'id': 'moderate', 'label': 'Moderate', 'icon': '\$\$'},
      {'id': 'luxury', 'label': 'Luxury', 'icon': '\$\$\$'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your Budget',
          style: Theme.of(context).textTheme.displayMedium,
        ),
        const SizedBox(height: 8),
        Text(
          'Select your budget level',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppColors.charcoal.withValues(alpha: 0.6),
              ),
        ),
        const SizedBox(height: 32),
        ...options.map((option) {
          final isSelected = selectedBudget == option['id'];
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: GestureDetector(
              onTap: () => onSelect(option['id'] as String),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary.withValues(alpha: 0.05)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.secondary.withValues(alpha: 0.2),
                    width: 2,
                  ),
                  boxShadow: [
                    if (isSelected)
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Text(
                            option['icon'] as String,
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: isSelected
                                  ? AppColors.primary
                                  : Colors.grey[400],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Text(
                            option['label'] as String,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.charcoal,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isSelected)
                      Container(
                        width: 32,
                        height: 32,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _StepInterests extends StatelessWidget {
  final List<String> selectedInterests;
  final Function(String) onToggle;
  final Function(int, int) onReorder;

  const _StepInterests({
    super.key,
    required this.selectedInterests,
    required this.onToggle,
    required this.onReorder,
  });

  @override
  Widget build(BuildContext context) {
    final allInterests = [
      'History',
      'Food',
      'Nature',
      'Shopping',
      'Entertainment',
      'Religious',
    ];

    final availableInterests = allInterests
        .where((interest) => !selectedInterests.contains(interest))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Interests',
          style: Theme.of(context).textTheme.displayMedium,
        ),
        const SizedBox(height: 8),
        Text(
          'Tap to add, then reorder by priority',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppColors.charcoal.withValues(alpha: 0.6),
              ),
        ),
        const SizedBox(height: 24),
        
        // Priority List
        if (selectedInterests.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.3),
                width: 2,
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
                      'Your Priorities (Drag to reorder)',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ReorderableListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: selectedInterests.length,
                  onReorder: onReorder,
                  itemBuilder: (context, index) {
                    final interest = selectedInterests[index];
                    return Container(
                      key: ValueKey(interest),
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.2),
                          width: 2,
                        ),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        leading: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '${index + 1}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                        title: Text(
                          interest,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.charcoal,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.drag_handle_rounded,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(width: 4),
                            GestureDetector(
                              onTap: () => onToggle(interest),
                              child: Icon(
                                Icons.close_rounded,
                                color: Colors.grey[400],
                                size: 20,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
        
        // Available Interests
        if (availableInterests.isNotEmpty) ...[
          Text(
            'Available Interests',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.charcoal.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: availableInterests.map((interest) {
              return GestureDetector(
                onTap: () => onToggle(interest),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: AppColors.secondary.withValues(alpha: 0.2),
                      width: 2,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.add_circle_outline_rounded,
                        size: 18,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        interest,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.charcoal,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}

class _StepPace extends StatelessWidget {
  final String? selectedPace;
  final Function(String) onSelect;

  const _StepPace({
    super.key,
    required this.selectedPace,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final options = [
      {'id': 'relaxed', 'label': 'Relaxed', 'desc': 'Take it easy, 1-2 activities per day'},
      {'id': 'moderate', 'label': 'Moderate', 'desc': 'Balanced mix of sights and rest'},
      {'id': 'packed', 'label': 'Packed', 'desc': 'See as much as possible!'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Travel Pace',
          style: Theme.of(context).textTheme.displayMedium,
        ),
        const SizedBox(height: 8),
        Text(
          'How fast do you want to go?',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppColors.charcoal.withValues(alpha: 0.6),
              ),
        ),
        const SizedBox(height: 32),
        ...options.map((option) {
          final isSelected = selectedPace == option['id'];
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: GestureDetector(
              onTap: () => onSelect(option['id'] as String),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary.withValues(alpha: 0.05)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.secondary.withValues(alpha: 0.2),
                    width: 2,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.speed_rounded,
                      color: isSelected
                          ? AppColors.primary
                          : Colors.grey[400],
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            option['label'] as String,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.charcoal,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            option['desc'] as String,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.charcoal.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}

// ── Step 6 ──────────────────────────────────────────────────────────────────

class _StepSpecificInterest extends StatefulWidget {
  final String? value;
  final ValueChanged<String?> onChanged;

  const _StepSpecificInterest({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  State<_StepSpecificInterest> createState() => _StepSpecificInterestState();
}

class _StepSpecificInterestState extends State<_StepSpecificInterest> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Anything specific?',
          style: Theme.of(context).textTheme.displayMedium,
        ),
        const SizedBox(height: 8),
        Text(
          'Optional — describe a specific interest',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppColors.charcoal.withValues(alpha: 0.6),
              ),
        ),
        const SizedBox(height: 32),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Row(
                  children: [
                    Icon(
                      Icons.tips_and_updates_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Tell us more',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    const Spacer(),
                    if (_controller.text.isNotEmpty)
                      TextButton.icon(
                        onPressed: () {
                          _controller.clear();
                          widget.onChanged(null);
                          setState(() {});
                        },
                        icon: const Icon(Icons.clear_rounded, size: 16),
                        label: const Text('Clear'),
                        style: TextButton.styleFrom(
                          foregroundColor:
                              AppColors.charcoal.withValues(alpha: 0.5),
                          padding: EdgeInsets.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          textStyle: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: TextFormField(
                  controller: _controller,
                  maxLines: 3,
                  maxLength: 200,
                  onChanged: (val) {
                    widget.onChanged(val.isEmpty ? null : val);
                    setState(() {}); // rebuild to show/hide Clear button
                  },
                  decoration: InputDecoration(
                    hintText:
                        'e.g. I want to see the Nile, ancient pyramids, street food…',
                    hintStyle: TextStyle(
                      color: AppColors.charcoal.withValues(alpha: 0.35),
                      fontSize: 14,
                      height: 1.5,
                    ),
                    filled: true,
                    fillColor: AppColors.cream,
                    contentPadding: const EdgeInsets.all(16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: AppColors.secondary.withValues(alpha: 0.2),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: AppColors.secondary.withValues(alpha: 0.2),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: AppColors.primary,
                        width: 2,
                      ),
                    ),
                    counterStyle: TextStyle(
                      color: AppColors.charcoal.withValues(alpha: 0.4),
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Hint row
        Row(
          children: [
            Icon(
              Icons.info_outline_rounded,
              size: 14,
              color: AppColors.charcoal.withValues(alpha: 0.4),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Leave blank to skip — your itinerary will still be great!',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.charcoal.withValues(alpha: 0.45),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
