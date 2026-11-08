import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import '../models/academic_class.dart';
import '../theme/app_theme.dart';
import '../widgets/house_card.dart';
import '../widgets/pill_selector.dart';
import '../widgets/strength_meter.dart';
import 'home_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _authService = AuthService();

  // Controllers
  final _nameController = TextEditingController();
  final _scholarController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // Form State
  int _currentStep = 0;
  int _maxStepReached = 0;
  String? _classLevel;
  String? _division;
  int _age = 14;
  String? _houseName;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  String? _errorMessage;

  final List<String> _grades = AcademicStructure.gradeLevels;
  final List<String> _divisions = ['A', 'B', 'C', 'D', 'E', 'F'];

  @override
  void dispose() {
    _nameController.dispose();
    _scholarController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Color get _activeHouseColor => _houseName != null
      ? HouseColors.getHouseColor(_houseName!)
      : HouseColors.ruby;

  Color get _activeHouseDarkColor => _houseName != null
      ? HouseColors.getHouseDarkColor(_houseName!)
      : HouseColors.rubyDark;

  Color get _activeHouseGlowColor => _houseName != null
      ? HouseColors.getHouseGlowColor(_houseName!)
      : HouseColors.rubyGlow;

  Color get _activeHouseAccentColor => _houseName != null
      ? HouseColors.getHouseAccentColor(_houseName!)
      : HouseColors.rubyAccent;

  bool _validateCurrentStep() {
    setState(() => _errorMessage = null);

    if (_currentStep == 0) {
      if (_nameController.text.trim().length < 2) {
        setState(() => _errorMessage = 'Please enter your full name');
        return false;
      }
      final scholar = _scholarController.text.trim();
      if (scholar.length < 5 || scholar.length > 6) {
        setState(() => _errorMessage = 'Scholar number must be 5 or 6 digits');
        return false;
      }
    } else if (_currentStep == 1) {
      if (_classLevel == null || _division == null) {
        setState(() => _errorMessage = 'Please select both Grade and Section');
        return false;
      }
    } else if (_currentStep == 2) {
      if (_houseName == null) {
        setState(() => _errorMessage = 'Please select your House to continue');
        return false;
      }
    } else if (_currentStep == 3) {
      if (_passwordController.text.length < 6) {
        setState(
          () => _errorMessage = 'Password must be at least 6 characters',
        );
        return false;
      }
      if (_passwordController.text != _confirmPasswordController.text) {
        setState(() => _errorMessage = 'Passwords do not match');
        return false;
      }
    }
    return true;
  }

  void _nextStep() {
    if (_validateCurrentStep()) {
      if (_currentStep < 3) {
        setState(() {
          _currentStep++;
          if (_currentStep > _maxStepReached) {
            _maxStepReached = _currentStep;
          }
        });
      } else {
        _handleSignup();
      }
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
        _errorMessage = null;
      });
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _handleSignup() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _authService.signUp(
        scholarNo: _scholarController.text.trim(),
        password: _passwordController.text,
        fullName: _nameController.text.trim(),
        age: _age,
        classLevel: _classLevel ?? 'Grade 10',
        division: _division ?? 'A',
        houseName: _houseName ?? 'ruby',
      );

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (_) => false,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = _parseFirebaseError(e.toString());
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _parseFirebaseError(String error) {
    if (error.contains('email-already-in-use')) {
      return 'An account already exists for this scholar number.';
    }
    if (error.contains('weak-password')) {
      return 'Password is too weak. Choose a stronger password.';
    }
    if (error.contains('network-request-failed')) {
      return 'Network error. Check your connection.';
    }
    return error
        .replaceAll('Exception: ', '')
        .replaceAll('[firebase_auth/', '[');
  }

  @override
  Widget build(BuildContext context) {
    final activeColor = _activeHouseColor;
    final activeDarkColor = _activeHouseDarkColor;
    final activeGlowColor = _activeHouseGlowColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final customTheme = Theme.of(context).copyWith(
      colorScheme: Theme.of(context).colorScheme.copyWith(
        primary: activeColor,
        secondary: activeDarkColor,
        tertiary: _activeHouseAccentColor,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: activeColor,
        selectionColor: activeColor.withValues(alpha: 0.3),
        selectionHandleColor: activeColor,
      ),
      inputDecorationTheme: Theme.of(context).inputDecorationTheme.copyWith(
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: activeColor, width: 2),
        ),
        floatingLabelStyle: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: activeColor,
        ),
        prefixIconColor: activeColor,
      ),
    );

    return Theme(
      data: customTheme,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            tooltip: 'Back',
            onPressed: _prevStep,
          ),
          title: Text(
            'Step ${_currentStep + 1} of 4',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          actions: [
            if (_houseName != null && _houseName!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: activeColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(9999),
                      border: Border.all(
                        color: activeColor.withValues(alpha: 0.35),
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          HouseColors.getHouseEmoji(_houseName!),
                          style: const TextStyle(fontSize: 14),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '${_houseName![0].toUpperCase()}${_houseName!.substring(1)}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: activeColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
        body: SafeArea(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, -0.65),
                radius: 1.25,
                colors: [
                  activeColor.withValues(alpha: isDark ? 0.18 : 0.08),
                  activeDarkColor.withValues(alpha: isDark ? 0.06 : 0.02),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.45, 1.0],
              ),
            ),
            child: Column(
              children: [
                // Step Bar & Indicators
                _buildStepIndicators(activeColor, activeDarkColor, isDark),

                // Linear Progress Indicator
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  child: LinearProgressIndicator(
                    value: (_currentStep + 1) / 4.0,
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.outline.withValues(alpha: 0.35),
                    valueColor: AlwaysStoppedAnimation<Color>(activeColor),
                    minHeight: 3.5,
                  ),
                ),

                // Scrollable Form Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 24,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 520),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Error banner
                            if (_errorMessage != null)
                              _buildErrorBanner(),

                            // Step Content
                            _buildStepContent(activeColor, activeDarkColor, isDark),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Pinned Action Button Bar
                _buildBottomActionBar(
                  activeColor,
                  activeDarkColor,
                  activeGlowColor,
                  isDark,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFFCA5A5),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: Color(0xFFDC2626),
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _errorMessage!,
              style: const TextStyle(
                color: Color(0xFFDC2626),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActionBar(
    Color activeColor,
    Color activeDarkColor,
    Color activeGlowColor,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF0F172A).withValues(alpha: 0.95)
            : Colors.white.withValues(alpha: 0.95),
        border: Border(
          top: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.25),
            width: 0.8,
          ),
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeInOutCubic,
            height: 54,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(9999),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: _isLoading
                    ? [
                        activeColor.withValues(alpha: 0.6),
                        activeDarkColor.withValues(alpha: 0.6),
                      ]
                    : [
                        activeColor,
                        activeDarkColor,
                      ],
              ),
              boxShadow: [
                BoxShadow(
                  color: activeGlowColor.withValues(
                    alpha: _isLoading ? 0.2 : 0.45,
                  ),
                  blurRadius: 18,
                  spreadRadius: 1,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(9999),
                onTap: _isLoading
                    ? null
                    : () {
                        AppHaptics.medium();
                        _nextStep();
                      },
                child: Center(
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation(
                              Colors.white,
                            ),
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                _currentStep == 3
                                    ? 'Complete Registration'
                                    : 'Continue',
                                style: const TextStyle(
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  letterSpacing: 0.3,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              _currentStep == 3
                                  ? Icons.check_circle_outline_rounded
                                  : Icons.arrow_forward_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
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

  Widget _buildStepIndicators(
    Color activeColor,
    Color activeDarkColor,
    bool isDark,
  ) {
    final steps = [
      {'title': 'Identity', 'icon': Icons.badge_outlined},
      {'title': 'Academic', 'icon': Icons.school_outlined},
      {'title': 'House', 'icon': Icons.shield_outlined},
      {'title': 'Security', 'icon': Icons.lock_outline_rounded},
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF151D2E) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.4),
            width: 0.8,
          ),
        ),
      ),
      child: Row(
        children: List.generate(steps.length, (index) {
          final isCompleted = _currentStep > index || _maxStepReached > index;
          final isCurrent = _currentStep == index;
          final isUnlocked = index <= _maxStepReached;
          final stepColor = (isCompleted || isCurrent)
              ? activeColor
              : (isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8));

          final stepTitle = (index == 2 && _houseName != null)
              ? '${_houseName![0].toUpperCase()}${_houseName!.substring(1)}'
              : (steps[index]['title'] as String);

          return Expanded(
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: isUnlocked && !isCurrent
                        ? () {
                            if (index < _currentStep || _validateCurrentStep()) {
                              setState(() {
                                _currentStep = index;
                                _errorMessage = null;
                              });
                            }
                          }
                        : null,
                    borderRadius: BorderRadius.circular(8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isCurrent
                                ? activeColor
                                : (isCompleted
                                    ? activeColor.withValues(alpha: 0.15)
                                    : (isDark
                                        ? const Color(0xFF1E293B)
                                        : const Color(0xFFF1F5F9))),
                            border: Border.all(
                              color: isCurrent
                                  ? activeColor
                                  : (isCompleted
                                      ? activeColor
                                      : (isDark
                                          ? const Color(0xFF334155)
                                          : const Color(0xFFCBD5E1))),
                              width: isCurrent || isCompleted ? 2 : 1.2,
                            ),
                            boxShadow: isCurrent
                                ? [
                                    BoxShadow(
                                      color: activeColor.withValues(alpha: 0.4),
                                      blurRadius: 10,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Center(
                            child: (index == 2 && _houseName != null)
                                ? Text(
                                    HouseColors.getHouseEmoji(_houseName!),
                                    style: const TextStyle(fontSize: 14),
                                  )
                                : (isCompleted
                                    ? Icon(
                                        Icons.check_rounded,
                                        size: 18,
                                        color: isCurrent
                                            ? Colors.white
                                            : activeColor,
                                      )
                                    : Text(
                                        '${index + 1}',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                          color: isCurrent
                                              ? Colors.white
                                              : stepColor,
                                        ),
                                      )),
                          ),
                        ),
                        const SizedBox(height: 4),
                        AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 250),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight:
                                isCurrent ? FontWeight.w800 : FontWeight.w600,
                            color: isCurrent
                                ? activeColor
                                : (isCompleted
                                    ? Theme.of(context).colorScheme.onSurface
                                    : (isDark
                                        ? const Color(0xFF64748B)
                                        : const Color(0xFF94A3B8))),
                          ),
                          child: Text(
                            stepTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (index < steps.length - 1)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 14,
                    height: 2,
                    margin: const EdgeInsets.only(bottom: 16),
                    color: (_currentStep > index || _maxStepReached > index)
                        ? activeColor
                        : (isDark
                            ? const Color(0xFF334155)
                            : const Color(0xFFE2E8F0)),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildStepContent(
    Color activeColor,
    Color activeDarkColor,
    bool isDark,
  ) {
    switch (_currentStep) {
      case 0:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Student Identity',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Enter your full name and official ASB scholar number.',
              style: TextStyle(
                fontSize: 15,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 32),
            TextFormField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Full Name',
                prefixIcon: Icon(
                  Icons.person_outline_rounded,
                  color: activeColor,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: activeColor, width: 2),
                ),
                floatingLabelStyle: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: activeColor,
                ),
              ),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _scholarController,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              decoration: InputDecoration(
                labelText: 'Scholar Number (5-6 digits)',
                prefixIcon: Icon(
                  Icons.badge_outlined,
                  color: activeColor,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: activeColor, width: 2),
                ),
                floatingLabelStyle: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: activeColor,
                ),
              ),
            ),
          ],
        );

      case 1:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Academic Details',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Select your grade, section, and current age.',
              style: TextStyle(
                fontSize: 15,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 32),
            PillSelector(
              label: 'GRADE',
              options: _grades,
              selectedValue: _classLevel,
              activeColor: activeColor,
              activeDarkColor: activeDarkColor,
              onSelected: (v) => setState(() => _classLevel = v),
            ),
            const SizedBox(height: 24),
            PillSelector(
              label: 'SECTION',
              options: _divisions,
              selectedValue: _division,
              activeColor: activeColor,
              activeDarkColor: activeDarkColor,
              onSelected: (v) => setState(() => _division = v),
            ),
            const SizedBox(height: 24),
            Text(
              'AGE',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.6),
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1E293B)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: activeColor.withValues(alpha: 0.25),
                    width: 1.2,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _age > 4
                            ? () {
                                AppHaptics.selectionClick();
                                setState(() => _age--);
                              }
                            : null,
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: activeColor.withValues(
                              alpha: _age > 4 ? 0.15 : 0.05,
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.remove_rounded,
                            size: 18,
                            color: _age > 4
                                ? activeColor
                                : (isDark ? Colors.white30 : Colors.black26),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Text(
                        '$_age years old',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _age < 20
                            ? () {
                                AppHaptics.selectionClick();
                                setState(() => _age++);
                              }
                            : null,
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: activeColor.withValues(
                              alpha: _age < 20 ? 0.15 : 0.05,
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.add_rounded,
                            size: 18,
                            color: _age < 20
                                ? activeColor
                                : (isDark ? Colors.white30 : Colors.black26),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );

      case 2:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'House Selection',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Choose your assigned ASB house to activate its live theme.',
              style: TextStyle(
                fontSize: 15,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 24),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.95,
              children: [
                HouseCard(
                  houseName: 'Ruby',
                  motto: 'Courage & Passion',
                  isSelected: _houseName == 'ruby',
                  onTap: () {
                    setState(() => _houseName = 'ruby');
                  },
                ),
                HouseCard(
                  houseName: 'Sapphire',
                  motto: 'Wisdom & Truth',
                  isSelected: _houseName == 'sapphire',
                  onTap: () {
                    setState(() => _houseName = 'sapphire');
                  },
                ),
                HouseCard(
                  houseName: 'Emerald',
                  motto: 'Honor & Growth',
                  isSelected: _houseName == 'emerald',
                  onTap: () {
                    setState(() => _houseName = 'emerald');
                  },
                ),
                HouseCard(
                  houseName: 'Topaz',
                  motto: 'Light & Excellence',
                  isSelected: _houseName == 'topaz',
                  onTap: () {
                    setState(() => _houseName = 'topaz');
                  },
                ),
              ],
            ),

            // Dynamic Confirmation / Celebration Details Banner upon Selection
            AnimatedSize(
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOutCubic,
              child: _houseName == null
                  ? const SizedBox.shrink()
                  : Container(
                      margin: const EdgeInsets.only(top: 24),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        color: isDark ? const Color(0xFF151D2E) : Colors.white,
                        border: Border.all(
                          color: activeColor.withValues(alpha: 0.45),
                          width: 1.8,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: activeColor.withValues(
                              alpha: isDark ? 0.25 : 0.12,
                            ),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      activeColor,
                                      activeDarkColor,
                                    ],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: activeColor.withValues(alpha: 0.4),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  HouseColors.getHouseEmoji(_houseName!),
                                  style: const TextStyle(fontSize: 26),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 4,
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      children: [
                                        Text(
                                          '${_houseName![0].toUpperCase()}${_houseName!.substring(1)} House',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w800,
                                            color: activeColor,
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: activeColor.withValues(
                                              alpha: 0.15,
                                            ),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            'THEME ACTIVATED ✨',
                                            style: TextStyle(
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.w900,
                                              color: activeColor,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      HouseColors.getHouseMascotName(
                                        _houseName!,
                                      ),
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w600,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withValues(alpha: 0.85),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Divider(
                            color: activeColor.withValues(alpha: 0.18),
                            height: 1,
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 12,
                            runSpacing: 8,
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.auto_awesome_rounded,
                                    size: 16,
                                    color: activeColor,
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      'Motto: "${HouseColors.getHouseMotto(_houseName!)}"',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                        fontStyle: FontStyle.italic,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withValues(alpha: 0.75),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: activeColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(9999),
                                ),
                                child: Text(
                                  HouseColors.getHouseVirtue(_houseName!),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: activeColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        );

      case 3:
      default:
        final house = _houseName ?? 'ruby';
        final classId = AcademicStructure.classIdFrom(
          _classLevel ?? '',
          _division ?? '',
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Security',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create a strong password to protect your account.',
              style: TextStyle(
                fontSize: 15,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 24),

            // Enrollment Summary Banner Celebrating Chosen House Theme
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: isDark ? const Color(0xFF151D2E) : Colors.white,
                border: Border.all(
                  color: activeColor.withValues(alpha: 0.35),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: activeColor.withValues(alpha: isDark ? 0.2 : 0.08),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          activeColor,
                          activeDarkColor,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: activeColor.withValues(alpha: 0.35),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      HouseColors.getHouseEmoji(house),
                      style: const TextStyle(fontSize: 26),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _nameController.text.trim().isEmpty
                                    ? 'ASB Scholar'
                                    : _nameController.text.trim(),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.3,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2.5,
                              ),
                              decoration: BoxDecoration(
                                color: activeColor,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${house.toUpperCase()} HOUSE',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Scholar #${_scholarController.text.trim().isEmpty ? "Pending" : _scholarController.text.trim()} • Class ${classId.isEmpty ? '?' : classId} • $_age yrs',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.7),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Mascot: ${HouseColors.getHouseMascotName(house)}',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: activeColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Password Field
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: Icon(
                  Icons.lock_outline_rounded,
                  color: activeColor,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: activeColor,
                    width: 2,
                  ),
                ),
                floatingLabelStyle: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: activeColor,
                ),
                suffixIcon: Semantics(
                  button: true,
                  label: _obscurePassword ? 'Show password' : 'Hide password',
                  child: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                      color: activeColor.withValues(alpha: 0.8),
                    ),
                    tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            StrengthMeter(
              password: _passwordController.text,
              houseColor: activeColor,
            ),
            const SizedBox(height: 24),

            // Confirm Password Field
            TextFormField(
              controller: _confirmPasswordController,
              obscureText: _obscureConfirm,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Confirm Password',
                prefixIcon: Icon(
                  Icons.lock_reset_rounded,
                  color: activeColor,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: activeColor,
                    width: 2,
                  ),
                ),
                floatingLabelStyle: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: activeColor,
                ),
                suffixIcon: Semantics(
                  button: true,
                  label: _obscureConfirm ? 'Show password' : 'Hide password',
                  child: IconButton(
                    icon: Icon(
                      _obscureConfirm
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                      color: activeColor.withValues(alpha: 0.8),
                    ),
                    tooltip: _obscureConfirm ? 'Show password' : 'Hide password',
                    onPressed: () =>
                        setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                ),
              ),
            ),
          ],
        );
    }
  }
}
