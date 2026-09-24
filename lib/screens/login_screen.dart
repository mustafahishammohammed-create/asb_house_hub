import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import '../services/hierarchy_service.dart';
import '../theme/app_theme.dart';
import 'signup_screen.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _scholarController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();

  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _isAdminLogin = false;
  String? _errorMessage;

  @override
  void dispose() {
    _scholarController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final idText = _scholarController.text.trim().toLowerCase();
      if (_isAdminLogin &&
          (idText == 'admin' || idText == '2310910' || idText.isEmpty)) {
        await _authService.signInAdmin(password: _passwordController.text);
      } else {
        final cred = await _authService.signIn(
          scholarNo: _scholarController.text.trim(),
          password: _passwordController.text,
        );

        if (_isAdminLogin) {
          final profile = await _authService.getUserProfile(cred.user!.uid);
          final roleStr = profile?['role']?.toString();
          final nameStr = profile?['full_name']?.toString();
          final scholarNo = profile?['scholar_no']?.toString() ??
              _scholarController.text.trim();

          final isAuthorized = HierarchyService.isAdmin(
            scholarNo: scholarNo,
            role: roleStr,
            fullName: nameStr,
          );

          if (!isAuthorized) {
            await _authService.signOut();
            throw Exception(
              'Access Denied: Your account does not have Admin, Captain, or Council privileges in the database.',
            );
          }
        }
      }

      if (!mounted) return;

      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
    } on Exception catch (e) {
      setState(() {
        _errorMessage = _parseFirebaseError(e.toString());
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _parseFirebaseError(String error) {
    if (error.contains('user-not-found')) {
      return 'No account found with these credentials.';
    }
    if (error.contains('wrong-password') ||
        error.contains('invalid-credential')) {
      return 'Incorrect password. Please try again.';
    }
    if (error.contains('too-many-requests')) {
      return 'Too many attempts. Please try again later.';
    }
    if (error.contains('network-request-failed')) {
      return 'Network error. Check your connection.';
    }
    if (error.contains('invalid-email')) {
      return 'Invalid ID format.';
    }
    return error
        .replaceAll('Exception: ', '')
        .replaceAll('[firebase_auth/', '[');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = _isAdminLogin
        ? Colors.amber.shade700
        : HouseColors.ruby;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Portal Selector Tabs
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF1E293B)
                            : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                if (_isAdminLogin) {
                                  setState(() {
                                    _isAdminLogin = false;
                                    _errorMessage = null;
                                    _scholarController.clear();
                                  });
                                }
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: !_isAdminLogin
                                      ? (isDark
                                            ? const Color(0xFF334155)
                                            : Colors.white)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: !_isAdminLogin
                                      ? [
                                          BoxShadow(
                                            color: Colors.black.withValues(
                                              alpha: 0.05,
                                            ),
                                            blurRadius: 4,
                                          ),
                                        ]
                                      : [],
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.school_rounded,
                                      size: 18,
                                      color: !_isAdminLogin
                                          ? HouseColors.ruby
                                          : Colors.grey,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Student Login',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                        color: !_isAdminLogin
                                            ? (isDark
                                                  ? Colors.white
                                                  : Colors.black87)
                                            : Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                if (!_isAdminLogin) {
                                  setState(() {
                                    _isAdminLogin = true;
                                    _errorMessage = null;
                                    _scholarController.text = 'admin';
                                  });
                                }
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: _isAdminLogin
                                      ? (isDark
                                            ? const Color(0xFF334155)
                                            : Colors.white)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: _isAdminLogin
                                      ? [
                                          BoxShadow(
                                            color: Colors.black.withValues(
                                              alpha: 0.05,
                                            ),
                                            blurRadius: 4,
                                          ),
                                        ]
                                      : [],
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.admin_panel_settings_rounded,
                                      size: 18,
                                      color: _isAdminLogin
                                          ? Colors.amber.shade700
                                          : Colors.grey,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Admin Login',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                        color: _isAdminLogin
                                            ? (isDark
                                                  ? Colors.white
                                                  : Colors.black87)
                                            : Colors.grey,
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
                    const SizedBox(height: 32),

                    // Logo
                    Center(
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          color: isDark
                              ? const Color(0xFF1A2338)
                              : const Color(0xFFF8FAFC),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: GridView.count(
                            crossAxisCount: 2,
                            padding: const EdgeInsets.all(3),
                            mainAxisSpacing: 3,
                            crossAxisSpacing: 3,
                            physics: const NeverScrollableScrollPhysics(),
                            children: [
                              _logoQuad(HouseColors.ruby, HouseColors.rubyDark),
                              _logoQuad(
                                HouseColors.sapphire,
                                HouseColors.sapphireDark,
                              ),
                              _logoQuad(
                                HouseColors.emerald,
                                HouseColors.emeraldDark,
                              ),
                              _logoQuad(
                                HouseColors.topaz,
                                HouseColors.topazDark,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Heading
                    Text(
                      _isAdminLogin ? 'Admin Portal.' : 'Welcome back.',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isAdminLogin
                          ? 'Teacher & Council Review Access.'
                          : 'Sign in to check your house standings.',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.55),
                      ),
                    ),
                    const SizedBox(height: 36),

                    // Error banner
                    if (_errorMessage != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 20),
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

                    // Input Field (Scholar Number or Admin ID)
                    if (!_isAdminLogin)
                      TextFormField(
                        controller: _scholarController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(6),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Scholar Number',
                          prefixIcon: Icon(Icons.badge_rounded),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return 'Enter your scholar number';
                          }
                          if (v.length < 5) {
                            return 'Must be 5–6 digits';
                          }
                          return null;
                        },
                      )
                    else
                      TextFormField(
                        controller: _scholarController,
                        decoration: const InputDecoration(
                          labelText: 'Scholar Number / Admin ID',
                          prefixIcon: Icon(Icons.admin_panel_settings_rounded),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return 'Enter scholar number or ID';
                          }
                          return null;
                        },
                      ),
                    const SizedBox(height: 18),

                    // Password
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_rounded),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off_rounded
                                : Icons.visibility_rounded,
                          ),
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return 'Enter your password';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),

                    // Forgot Password
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Password reset contact school administrator.',
                              ),
                            ),
                          );
                        },
                        child: const Text('Forgot Password?'),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Sign In Button
                    SizedBox(
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: primaryColor.withValues(
                            alpha: 0.6,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(9999),
                          ),
                          elevation: _isLoading ? 0 : 4,
                          shadowColor: primaryColor.withValues(alpha: 0.4),
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
                                _isAdminLogin
                                    ? 'Sign In to Admin Portal'
                                    : 'Sign In',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Switch to Sign Up (Only shown for Student Login)
                    if (!_isAdminLogin)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'New to House Hub? ',
                            style: TextStyle(
                              fontSize: 15,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.55),
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).push(
                                PageRouteBuilder(
                                  pageBuilder:
                                      (
                                        context,
                                        animation,
                                        secondaryAnimation,
                                      ) => const SignupScreen(),
                                  transitionsBuilder:
                                      (context, anim, secondaryAnim, child) {
                                        return SlideTransition(
                                          position:
                                              Tween<Offset>(
                                                begin: const Offset(1, 0),
                                                end: Offset.zero,
                                              ).animate(
                                                CurvedAnimation(
                                                  parent: anim,
                                                  curve: Curves.easeOutCubic,
                                                ),
                                              ),
                                          child: child,
                                        );
                                      },
                                  transitionDuration: const Duration(
                                    milliseconds: 400,
                                  ),
                                ),
                              );
                            },
                            child: const Text(
                              'Create an account',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _logoQuad(Color c1, Color c2) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        gradient: LinearGradient(colors: [c1, c2]),
      ),
    );
  }
}
