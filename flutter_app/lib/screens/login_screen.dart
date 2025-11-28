import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants/app_colors.dart';
import '../models/auth_models.dart';
import '../services/auth_provider.dart';
import '../services/localization_service.dart';

/// Login screen with real authentication
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );

    // Start animations
    _fadeController.forward();
    Future.delayed(const Duration(milliseconds: 300), () {
      _scaleController.forward();
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scaleController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localization = context.watch<LocalizationProvider>();

    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) => Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.primary,
                AppColors.primaryLight,
                AppColors.success,
              ],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 32.0),
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // App Logo/Icon
                        _buildLogo(),
                        const SizedBox(height: 32),

                        // App Title
                        Text(
                          localization.tr('app_name'),
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: 8),

                        // Subtitle
                        Text(
                          localization.tr('app_subtitle'),
                          style:
                              Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: Colors.white.withOpacity(0.9),
                                  ),
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: 48),

                        // Error message display
                        if (authProvider.authState.status == AuthStatus.error)
                          _buildErrorMessage(
                              authProvider.authState.errorMessage ??
                                  localization.tr('error_unknown')),

                        // Login form
                        _buildLoginForm(authProvider, localization),

                        const SizedBox(height: 24),

                        // Register link
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              localization.tr('login_no_account'),
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.of(context).pushNamed('/register');
                              },
                              child: Text(
                                localization.tr('login_register'),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 32),

                        // Version info
                        Text(
                          '${localization.tr('version')} 1.0.0',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.white.withOpacity(0.7),
                                  ),
                        ),

                        // Language toggle
                        const SizedBox(height: 16),
                        _buildLanguageToggle(localization),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageToggle(LocalizationProvider localization) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        TextButton(
          onPressed: () => localization.setLanguage(AppLanguage.en),
          child: Text(
            'EN',
            style: TextStyle(
              color: localization.currentLanguage == AppLanguage.en
                  ? Colors.white
                  : Colors.white.withOpacity(0.5),
              fontWeight: localization.currentLanguage == AppLanguage.en
                  ? FontWeight.bold
                  : FontWeight.normal,
            ),
          ),
        ),
        Text(
          '|',
          style: TextStyle(color: Colors.white.withOpacity(0.5)),
        ),
        TextButton(
          onPressed: () => localization.setLanguage(AppLanguage.hu),
          child: Text(
            'HU',
            style: TextStyle(
              color: localization.currentLanguage == AppLanguage.hu
                  ? Colors.white
                  : Colors.white.withOpacity(0.5),
              fontWeight: localization.currentLanguage == AppLanguage.hu
                  ? FontWeight.bold
                  : FontWeight.normal,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLogo() {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Icon(
        Icons.local_florist,
        size: 60,
        color: AppColors.primary,
      ),
    );
  }

  Widget _buildErrorMessage(String message) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginForm(
      AuthProvider authProvider, LocalizationProvider localization) {
    final isLoading =
        authProvider.authState.status == AuthStatus.authenticating;

    return Form(
      key: _formKey,
      child: Column(
        children: [
          // Email field
          TextFormField(
            controller: _emailController,
            enabled: !isLoading,
            keyboardType: TextInputType.emailAddress,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: localization.tr('login_email'),
              labelStyle: TextStyle(color: Colors.white.withOpacity(0.8)),
              prefixIcon:
                  Icon(Icons.email, color: Colors.white.withOpacity(0.8)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.5)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.white, width: 2),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.redAccent),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.redAccent, width: 2),
              ),
              errorStyle: const TextStyle(color: Colors.white70),
              filled: true,
              fillColor: Colors.white.withOpacity(0.1),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return localization.tr('validation_email_required');
              }
              if (!value.contains('@')) {
                return localization.tr('validation_email_invalid');
              }
              return null;
            },
          ),

          const SizedBox(height: 16),

          // Password field
          TextFormField(
            controller: _passwordController,
            enabled: !isLoading,
            obscureText: _obscurePassword,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: localization.tr('login_password'),
              labelStyle: TextStyle(color: Colors.white.withOpacity(0.8)),
              prefixIcon:
                  Icon(Icons.lock, color: Colors.white.withOpacity(0.8)),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility : Icons.visibility_off,
                  color: Colors.white.withOpacity(0.8),
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.5)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.white, width: 2),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.redAccent),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.redAccent, width: 2),
              ),
              errorStyle: const TextStyle(color: Colors.white70),
              filled: true,
              fillColor: Colors.white.withOpacity(0.1),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return localization.tr('validation_password_required');
              }
              if (value.length < 4) {
                return localization.tr('validation_password_short');
              }
              return null;
            },
          ),

          const SizedBox(height: 24),

          // Login button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: isLoading ? null : _handleLogin,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 8,
              ),
              child: isLoading
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                                AppColors.primary),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          localization.tr('login_loading'),
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.login, size: 24),
                        const SizedBox(width: 8),
                        Text(
                          localization.tr('login_button'),
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.login(
      _emailController.text.trim(),
      _passwordController.text,
    );

    if (success && mounted) {
      _navigateToDashboard();
    }
  }

  void _navigateToDashboard() {
    // Navigate to home route - AuthWrapper will handle role-based routing
    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
  }
}
