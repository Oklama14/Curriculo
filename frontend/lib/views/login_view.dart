import 'package:flutter/material.dart';
import '../providers/app_state.dart';
import '../services/auth_service.dart';
import '../theme.dart';
import '../widgets/glass_container.dart';

class LoginView extends StatefulWidget {
  final AppState state;
  const LoginView({super.key, required this.state});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = await AuthService().signInWithGoogle();
      if (user != null) {
        widget.state.setAuthUser(user);
      } else {
        setState(() {
          _errorMessage = 'Falha ao autenticar com o Google.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Erro no login: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AmethystTheme.bgGradient,
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 450),
                child: GlassContainer(
                  padding: const EdgeInsets.all(40.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Logo / Icon
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AmethystTheme.accentAmethyst.withOpacity(0.1),
                          shape: BoxShape.circle,
                          boxShadow: AmethystTheme.glowShadow(
                            AmethystTheme.accentAmethyst,
                            radius: 20.0,
                            opacity: 0.15,
                          ),
                        ),
                        child: const Icon(
                          Icons.auto_awesome,
                          size: 60,
                          color: AmethystTheme.accentAmethyst,
                        ),
                      ),
                      const SizedBox(height: 32),
                      
                      // App Name
                      Text(
                        'TailorCV_ACS',
                        style: Theme.of(context).textTheme.displayMedium?.copyWith(
                          color: AmethystTheme.textPrimary,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1.0,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '& Job Scraper',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: AmethystTheme.accentIndigo,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.0,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Otimize seu currículo LaTeX com Inteligência Artificial e candidate-se instantaneamente.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AmethystTheme.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 40),
                      
                      if (_errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: AmethystTheme.neonRed.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AmethystTheme.neonRed.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline, color: AmethystTheme.neonRed, size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: const TextStyle(color: AmethystTheme.neonRed, fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Google Sign In Button
                      if (_isLoading)
                        const CircularProgressIndicator(color: AmethystTheme.accentAmethyst)
                      else
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            gradient: AmethystTheme.accentGradient,
                            boxShadow: AmethystTheme.glowShadow(
                              AmethystTheme.accentAmethyst,
                              radius: 12.0,
                              opacity: 0.3,
                            ),
                          ),
                          child: ElevatedButton(
                            onPressed: _handleGoogleSignIn,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              padding: const EdgeInsets.symmetric(vertical: 20),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.g_mobiledata_rounded,
                                  color: Colors.white,
                                  size: 32,
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Entrar com o Google',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: 24),
                      Text(
                        'Autenticação segura via Firebase',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AmethystTheme.textMuted,
                        ),
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
}
