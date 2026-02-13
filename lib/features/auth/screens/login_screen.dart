import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/utils/responsive.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with TickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _autoLogin = false;

  late AnimationController _entranceController;
  late Animation<double> _logoFade;
  late Animation<double> _logoScale;
  late Animation<double> _formFade;
  late Animation<Offset> _formSlide;
  late Animation<double> _socialFade;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _logoFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.3, curve: Curves.easeOut),
      ),
    );
    _logoScale = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOutBack),
      ),
    );
    _formFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.25, 0.6, curve: Curves.easeOut),
      ),
    );
    _formSlide = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.25, 0.6, curve: Curves.easeOutCubic),
    ));
    _socialFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.5, 1.0, curve: Curves.easeOut),
      ),
    );

    _entranceController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _entranceController.dispose();
    super.dispose();
  }

  Future<void> _signInWithEmail() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await ref.read(supabaseServiceProvider).signInWithEmail(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      await ref.read(autoLoginServiceProvider).setEnabled(_autoLogin);
      if (mounted) context.go('/home');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      await ref.read(supabaseServiceProvider).signInWithGoogle();
      await ref.read(autoLoginServiceProvider).setEnabled(_autoLogin);
      if (mounted) context.go('/home');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hPadding = Responsive.horizontalPadding(context);
    final fontScale = Responsive.fontScale(context);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: hPadding),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: Responsive.value(context, mobile: 60.0, tablet: 100.0)),

                // Logo / Title
                FadeTransition(
                  opacity: _logoFade,
                  child: ScaleTransition(
                    scale: _logoScale,
                    child: Column(
                      children: [
                        Text(
                          'Mapae',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2,
                            fontSize: 34 * fontScale,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Business Card Manager',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.5),
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                SizedBox(height: Responsive.value(context, mobile: 48.0, tablet: 64.0)),

                // Email & Password fields
                SlideTransition(
                  position: _formSlide,
                  child: FadeTransition(
                    opacity: _formFade,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            hintText: '이메일',
                            prefixIcon: Icon(Icons.email_outlined, size: 20),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return '이메일을 입력해주세요';
                            }
                            if (!value.contains('@')) {
                              return '올바른 이메일을 입력해주세요';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),

                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            hintText: '비밀번호',
                            prefixIcon: const Icon(Icons.lock_outlined, size: 20),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                size: 20,
                              ),
                              onPressed: () => setState(
                                      () => _obscurePassword = !_obscurePassword),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return '비밀번호를 입력해주세요';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 8),

                        // Auto-login & Forgot password row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            GestureDetector(
                              onTap: () =>
                                  setState(() => _autoLogin = !_autoLogin),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: Checkbox(
                                      value: _autoLogin,
                                      onChanged: (v) => setState(
                                              () => _autoLogin = v ?? false),
                                      materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '자동 로그인',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: theme.colorScheme.onSurface
                                          .withOpacity(0.6),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            TextButton(
                              onPressed: () {},
                              child: Text(
                                '비밀번호 찾기',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.5),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Login button with micro-interaction
                        SizedBox(
                          height: 52,
                          child: _AnimatedButton(
                            isLoading: _isLoading,
                            onPressed: _signInWithEmail,
                            child: const Text('로그인'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Social login section
                FadeTransition(
                  opacity: _socialFade,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                              child: Divider(color: theme.dividerColor)),
                          Padding(
                            padding:
                            const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              '또는',
                              style: TextStyle(
                                fontSize: 13,
                                color: theme.colorScheme.onSurface
                                    .withOpacity(0.4),
                              ),
                            ),
                          ),
                          Expanded(
                              child: Divider(color: theme.dividerColor)),
                        ],
                      ),
                      const SizedBox(height: 24),

                      SizedBox(
                        height: 52,
                        child: OutlinedButton.icon(
                          onPressed: _isLoading ? null : _signInWithGoogle,
                          icon: const Text(
                            'G',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          label: const Text('Google로 로그인'),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Sign up link
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '계정이 없으신가요? ',
                            style: TextStyle(
                              fontSize: 14,
                              color: theme.colorScheme.onSurface
                                  .withOpacity(0.5),
                            ),
                          ),
                          TextButton(
                            onPressed: () => context.push('/signup'),
                            child: const Text(
                              '회원가입',
                              style:
                              TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Elevated button with scale-on-tap micro-interaction.
class _AnimatedButton extends StatefulWidget {
  final bool isLoading;
  final VoidCallback onPressed;
  final Widget child;
  const _AnimatedButton({
    required this.isLoading,
    required this.onPressed,
    required this.child,
  });

  @override
  State<_AnimatedButton> createState() => _AnimatedButtonState();
}

class _AnimatedButtonState extends State<_AnimatedButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
      reverseDuration: const Duration(milliseconds: 150),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.isLoading ? null : (_) => _controller.forward(),
      onTapUp: widget.isLoading
          ? null
          : (_) {
        _controller.reverse();
        widget.onPressed();
      },
      onTapCancel: () => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) => Transform.scale(
          scale: 1.0 - (_controller.value * 0.04),
          child: child,
        ),
        child: ElevatedButton(
          onPressed: null,
          child: widget.isLoading
              ? const SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
              : widget.child,
        ),
      ),
    );
  }
}