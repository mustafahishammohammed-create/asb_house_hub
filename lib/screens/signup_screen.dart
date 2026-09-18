import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
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
  String? _classLevel;
  String? _division;
  int _age = 14;
  String? _houseName;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  String? _errorMessage;

  final List<String> _grades = ['6', '7', '8', '9', '10', '11', '12'];
  final List<String> _divisions = ['A', 'B', 'C', 'D', 'E', 'F'];

  @override
  void dispose() {
    _nameController.dispose();
    _scholarController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

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
        setState(() => _errorMessage = 'Please select your House');
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
        setState(() => _currentStep++);
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
        classLevel: _classLevel!,
        division: _division!,
        houseName: _houseName!,
      );

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (_) => false,
      );
    } on Exception catch (e) {
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
    // Strip redundant Firebase prefix for cleaner display of exact error
    return error
        .replaceAll('Exception: ', '')
        .replaceAll('[firebase_auth/', '[');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: _prevStep,
        ),
        title: Text('Step ${_currentStep + 1} of 4'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Progress Bar
            LinearProgressIndicator(
              value: (_currentStep + 1) / 4.0,
              backgroundColor: Theme.of(context).colorScheme.outline,
              valueColor: const AlwaysStoppedAnimation(HouseColors.ruby),
              minHeight: 3,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 32,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Error banner
                      if (_errorMessage != null)
                        Container(
                          margin: const EdgeInsets.only(bottom: 24),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEE2E2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFFCA5A5)),
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
                        ),

                      // Step Content
                      _buildStepContent(),
                      const SizedBox(height: 40),

                      // Next / Submit Button
                      SizedBox(
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _nextStep,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: HouseColors.ruby,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: HouseColors.ruby
                                .withValues(alpha: 0.6),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(9999),
                            ),
                            elevation: _isLoading ? 0 : 4,
                            shadowColor: HouseColors.ruby.withValues(
                              alpha: 0.4,
                            ),
                          ),
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
                              : Text(
                                  _currentStep == 3
                                      ? 'Complete Registration'
                                      : 'Continue',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                      ),
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

  Widget _buildStepContent() {
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
              decoration: const InputDecoration(
                labelText: 'Full Name',
                prefixIcon: Icon(Icons.person_outline_rounded),
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
              decoration: const InputDecoration(
                labelText: 'Scholar Number (5-6 digits)',
                prefixIcon: Icon(Icons.badge_outlined),
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
              onSelected: (v) => setState(() => _classLevel = v),
            ),
            const SizedBox(height: 28),
            PillSelector(
              label: 'SECTION',
              options: _divisions,
              selectedValue: _division,
              onSelected: (v) => setState(() => _division = v),
            ),
            const SizedBox(height: 28),
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
            Row(
              children: [
                IconButton(
                  onPressed: _age > 10 ? () => setState(() => _age--) : null,
                  style: IconButton.styleFrom(
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.outline.withValues(alpha: 0.3),
                  ),
                  icon: const Icon(Icons.remove_rounded),
                ),
                const SizedBox(width: 20),
                Text(
                  '$_age years old',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 20),
                IconButton(
                  onPressed: _age < 20 ? () => setState(() => _age++) : null,
                  style: IconButton.styleFrom(
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.outline.withValues(alpha: 0.3),
                  ),
                  icon: const Icon(Icons.add_rounded),
                ),
              ],
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
              'Choose your assigned ASB house.',
              style: TextStyle(
                fontSize: 15,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 32),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 0.85,
              children: [
                HouseCard(
                  houseName: 'Ruby',
                  motto: 'Courage & Passion',
                  isSelected: _houseName == 'ruby',
                  onTap: () => setState(() => _houseName = 'ruby'),
                ),
                HouseCard(
                  houseName: 'Sapphire',
                  motto: 'Wisdom & Truth',
                  isSelected: _houseName == 'sapphire',
                  onTap: () => setState(() => _houseName = 'sapphire'),
                ),
                HouseCard(
                  houseName: 'Emerald',
                  motto: 'Honor & Growth',
                  isSelected: _houseName == 'emerald',
                  onTap: () => setState(() => _houseName = 'emerald'),
                ),
                HouseCard(
                  houseName: 'Topaz',
                  motto: 'Light & Excellence',
                  isSelected: _houseName == 'topaz',
                  onTap: () => setState(() => _houseName = 'topaz'),
                ),
              ],
            ),
          ],
        );

      case 3:
      default:
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
            const SizedBox(height: 32),
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
            ),
            const SizedBox(height: 12),
            StrengthMeter(password: _passwordController.text),
            const SizedBox(height: 24),
            TextFormField(
              controller: _confirmPasswordController,
              obscureText: _obscureConfirm,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Confirm Password',
                prefixIcon: const Icon(Icons.lock_reset_rounded),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConfirm
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                  ),
                  onPressed: () =>
                      setState(() => _obscureConfirm = !_obscureConfirm),
                ),
              ),
            ),
          ],
        );
    }
  }
}
